#!/bin/bash
#
# networking.sh — Proxmox-node networking configuration, per
# docs/design/networking.md. Currently: creates the VM trunk bridge (vmbr1)
# on top of its physical NIC, or updates its VLAN settings (VLAN aware,
# bridge VIDs) when the bridge already exists.
#
# The management bridge (vmbr0) is expected to already exist from the
# Proxmox installer — this script only touches the VM trunk network.
#
# Run with --help for the options and exit status.
#
# See scripts/README.md for the phase structure this script follows, and
# docs/decisions/0008-proxmox-node-script-contract.md for the
# reasoning.

set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
if [[ -z "${SERVERLAB_BUNDLED:-}" ]]; then
  # shellcheck source=scripts/lib/common.sh
  source "${_script_dir}/lib/common.sh"
fi

readonly INTERFACES_FILE="/etc/network/interfaces"
readonly LOCK_FILE="/run/serverlab/networking.lock"

readonly DEFAULT_VIDS="2-4094"

dry_run=false
auto_yes=""
config_file=""
backup_path=""
bridge_mode="create"
vids=""

# normalize_vids <value>
# Prints the VLAN ID list with single spaces; an empty value becomes the
# Proxmox default (2-4094), as when the GUI field is left blank.
normalize_vids() {
  local value
  value="$(printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"
  printf '%s\n' "${value:-${DEFAULT_VIDS}}"
}

# validate_vlan_config
# Checks NET_VM_BRIDGE_VLAN_AWARE and NET_VM_BRIDGE_VIDS and sets ${vids}.
validate_vlan_config() {
  if [[ "${NET_VM_BRIDGE_VLAN_AWARE}" != "0" &&
    "${NET_VM_BRIDGE_VLAN_AWARE}" != "1" ]]; then
    log::die "NET_VM_BRIDGE_VLAN_AWARE must be 0 or 1" \
      "(got '${NET_VM_BRIDGE_VLAN_AWARE}')."
  fi

  vids="$(normalize_vids "${NET_VM_BRIDGE_VIDS:-}")"
  local token first last
  for token in ${vids}; do
    if [[ ! "${token}" =~ ^([0-9]+)(-([0-9]+))?$ ]]; then
      log::die "NET_VM_BRIDGE_VIDS: '${token}' is not a VLAN ID or range."
    fi
    first="${BASH_REMATCH[1]}"
    last="${BASH_REMATCH[3]:-${first}}"
    if ((first < 2 || last > 4094 || first > last)); then
      log::die "NET_VM_BRIDGE_VIDS: '${token}' is outside 2-4094."
    fi
  done
}

# file_settings_match
# True if ${INTERFACES_FILE} already has the configured VLAN settings for
# the bridge. A missing bridge-vlan-aware line means off; a missing
# bridge-vids line counts as 2-4094. (The file is compared, not the running
# bridge: Proxmox ignores "--bridge_vlan_aware 0" and only removes the
# lines with --delete.)
file_settings_match() {
  local aware current_vids
  aware="$(net::ifupdown_option "${INTERFACES_FILE}" "${NET_VM_BRIDGE}" \
    bridge-vlan-aware)"
  if [[ "${NET_VM_BRIDGE_VLAN_AWARE}" == "0" ]]; then
    [[ "${aware}" != "yes" ]]
    return
  fi
  [[ "${aware}" == "yes" ]] || return 1
  current_vids="$(normalize_vids \
    "$(net::ifupdown_option "${INTERFACES_FILE}" "${NET_VM_BRIDGE}" \
      bridge-vids)")"
  [[ "${current_vids}" == "${vids}" ]]
}

# running_matches
# True if the running bridge's VLAN awareness matches the configuration.
running_matches() {
  if net::bridge_vlan_aware "${NET_VM_BRIDGE}"; then
    [[ "${NET_VM_BRIDGE_VLAN_AWARE}" == "1" ]]
  else
    [[ "${NET_VM_BRIDGE_VLAN_AWARE}" == "0" ]]
  fi
}

# remove_leftovers
# With VLAN aware on, deletes the <bridge>v<N> bridges and <nic>.<N>
# interfaces Proxmox created while the bridge was not VLAN aware (they
# capture the tagged traffic before the bridge sees it). Interfaces defined
# in the interfaces file are kept. With VLAN aware off they are in use, so
# nothing is deleted. Prints nothing and returns 1 if nothing was found.
remove_leftovers() {
  [[ "${NET_VM_BRIDGE_VLAN_AWARE}" == "1" ]] || return 1
  local name found=1
  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    found=0
    if [[ "${dry_run}" == true ]]; then
      log::info "--dry-run: would delete leftover interface ${name}."
    else
      log::info "Deleting leftover interface ${name}."
      ip link del "${name}"
    fi
  done < <(net::vlan_leftovers "${NET_VM_BRIDGE}" "${NET_VM_IFACE}" \
    "${INTERFACES_FILE}")
  return "${found}"
}

# --- Phase 1: parse arguments / input --------------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        if [[ $# -lt 2 ]]; then
          log::error "--config needs a file."
          args::usage "networking.sh" >&2
          exit 2
        fi
        config_file="$2"
        shift 2
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --yes)
        auto_yes="--yes"
        shift
        ;;
      -h | --help)
        args::usage "networking.sh"
        exit 0
        ;;
      *)
        log::error "Unknown argument: $1"
        args::usage "networking.sh" >&2
        exit 2
        ;;
    esac
  done

  if [[ -z "${config_file}" ]]; then
    config_file="${_script_dir}/../config/proxmox-nodes/$(hostname -f).env"
  fi
}

# --- Phase 2: pre-flight checks ---------------------------------------------

preflight() {
  log::info "Checking current network state..."

  if net::iface_exists "${NET_VM_BRIDGE}"; then
    local existing_master
    existing_master="$(net::iface_master "${NET_VM_IFACE}")"
    if [[ "${existing_master}" != "${NET_VM_BRIDGE}" ]]; then
      log::die "${NET_VM_BRIDGE} already exists but ${NET_VM_IFACE} is not" \
        "its member (master: '${existing_master:-none}')." \
        "Refusing to change an existing bridge — resolve manually."
    fi

    if [[ -e "${INTERFACES_FILE}.new" ]]; then
      log::die "${INTERFACES_FILE}.new already exists — another change" \
        "is staged but not applied/reverted. Resolve that first" \
        "(pvesh get /nodes/$(pve::node)/network, or ifreload -a /" \
        "rm the file if it's stale)."
    fi

    if file_settings_match; then
      if ! running_matches; then
        log::die "${INTERFACES_FILE} has the configured VLAN settings but" \
          "the running ${NET_VM_BRIDGE} does not — run 'ifreload -a'."
      fi
      if remove_leftovers; then
        log::info "Removed leftover VLAN interfaces. Restart (qm stop /" \
          "qm start) guests that were running on ${NET_VM_BRIDGE}."
        exit 0
      fi
      log::info "${NET_VM_BRIDGE} already exists with ${NET_VM_IFACE}" \
        "attached and the configured VLAN settings."
      log::info "Nothing to do."
      exit 0
    fi
    bridge_mode="update"
    log::info "${NET_VM_BRIDGE} exists; its VLAN settings differ from the" \
      "configuration."
    log::info "Pre-flight checks passed."
    return 0
  fi

  if ! net::iface_exists "${NET_VM_IFACE}"; then
    log::die "Interface '${NET_VM_IFACE}' not found on this Proxmox node."
  fi

  local current_master
  current_master="$(net::iface_master "${NET_VM_IFACE}")"
  if [[ -n "${current_master}" ]]; then
    log::die "Interface '${NET_VM_IFACE}' is already a member of" \
      "'${current_master}' — refusing to reattach it."
  fi

  if [[ -e "${INTERFACES_FILE}.new" ]]; then
    log::die "${INTERFACES_FILE}.new already exists — another change" \
      "is staged but not applied/reverted. Resolve that first" \
      "(pvesh get /nodes/$(pve::node)/network, or ifreload -a /" \
      "rm the file if it's stale)."
  fi

  log::info "Pre-flight checks passed."
}

# --- Phase 3: plan / diff / confirm -----------------------------------------

plan_and_confirm() {
  if [[ "${bridge_mode}" == "update" ]]; then
    local update_args=(--type bridge --bridge_ports "${NET_VM_IFACE}"
      --comments "${NET_VM_BRIDGE_COMMENT}")
    if [[ "${NET_VM_BRIDGE_VLAN_AWARE}" == "1" ]]; then
      log::info "Staging: set VLAN aware (VIDs '${vids}') on" \
        "'${NET_VM_BRIDGE}'."
      update_args+=(--bridge_vlan_aware 1 --bridge_vids "${vids}")
    else
      log::info "Staging: remove VLAN aware and VIDs from" \
        "'${NET_VM_BRIDGE}'."
      update_args+=(--delete "bridge_vlan_aware,bridge_vids")
    fi
    pve::set "/nodes/$(pve::node)/network/${NET_VM_BRIDGE}" \
      "${update_args[@]}"
  else
    local create_args=(--iface "${NET_VM_BRIDGE}" --type bridge
      --bridge_ports "${NET_VM_IFACE}" --autostart 1
      --comments "${NET_VM_BRIDGE_COMMENT}")
    if [[ "${NET_VM_BRIDGE_VLAN_AWARE}" == "1" ]]; then
      create_args+=(--bridge_vlan_aware 1 --bridge_vids "${vids}")
    fi
    log::info "Staging: create bridge '${NET_VM_BRIDGE}' on" \
      "'${NET_VM_IFACE}' (no IP address, VLAN aware" \
      "'${NET_VM_BRIDGE_VLAN_AWARE}')."
    pve::create "/nodes/$(pve::node)/network" "${create_args[@]}"
  fi

  if cmp -s "${INTERFACES_FILE}" "${INTERFACES_FILE}.new"; then
    pve::revert "/nodes/$(pve::node)/network"
    log::die "The staged change is identical to ${INTERFACES_FILE} —" \
      "Proxmox did not apply the requested VLAN settings. Nothing was" \
      "changed."
  fi

  log::info "Staged diff (${INTERFACES_FILE} -> ${INTERFACES_FILE}.new):"
  files::diff "${INTERFACES_FILE}" "${INTERFACES_FILE}.new" >&2

  if [[ "${dry_run}" == true ]]; then
    log::info "--dry-run: discarding the staged change" \
      "(no changes were applied)."
    pve::revert "/nodes/$(pve::node)/network"
    exit 0
  fi

  if ! prompt::confirm "Apply the above change now?" "${auto_yes}"; then
    log::info "Aborted by user. Discarding the staged change" \
      "(no changes were applied)."
    pve::revert "/nodes/$(pve::node)/network"
    exit 3
  fi
}

# --- Phase 4/5: backup, apply ------------------------------------------------

# report_failure <message>
# Prints the manual undo command for the interfaces file, then stops.
report_failure() {
  log::error "$* — not rolling back automatically."
  log::error "To restore the previous config by hand:"
  log::error "  cp -p ${backup_path} ${INTERFACES_FILE} && ifreload -a"
  guards::restore_hangup
  log::die "Stopped. ${NET_VM_BRIDGE} may be partially configured —" \
    "resolve manually (see above)."
}

apply_change() {
  backup_path="$(files::backup "${INTERFACES_FILE}")"
  log::info "Backed up ${INTERFACES_FILE} to ${backup_path}"

  guards::ignore_hangup
  log::info "Applying (pvesh set — runs ifreload -a)..."
  local upid
  if ! upid="$(pve::set "/nodes/$(pve::node)/network")"; then
    report_failure "Apply failed"
  fi

  log::info "Waiting for reload task (${upid}) to finish..."
  if ! pve::wait_task "${upid}"; then
    report_failure "Reload task did not finish successfully" \
      "(failed or timed out)"
  fi

  verify_change
  guards::restore_hangup
}

# --- Phase 6: post-verify (local only — no external reachability check) ----

verify_change() {
  log::info "Verifying..."

  if [[ "$(net::iface_master "${NET_VM_IFACE}")" != "${NET_VM_BRIDGE}" ]]; then
    report_failure "${NET_VM_IFACE} is not attached to ${NET_VM_BRIDGE}"
  fi

  if ! file_settings_match; then
    report_failure "${INTERFACES_FILE} does not have the configured VLAN" \
      "settings (VLAN aware '${NET_VM_BRIDGE_VLAN_AWARE}', VIDs '${vids}')"
  fi

  if ! running_matches; then
    report_failure "The running ${NET_VM_BRIDGE} does not match VLAN aware" \
      "'${NET_VM_BRIDGE_VLAN_AWARE}'"
  fi

  if remove_leftovers; then
    log::info "Restart (qm stop / qm start) guests that were running on" \
      "${NET_VM_BRIDGE}."
  fi

  log::info "Verified: ${NET_VM_IFACE} is attached to ${NET_VM_BRIDGE}" \
    "(VLAN aware '${NET_VM_BRIDGE_VLAN_AWARE}', VIDs '${vids}')."
}

# --- Phase 7: summary ---------------------------------------------------------

main() {
  parse_args "$@"

  guards::require_root
  guards::require_proxmox
  guards::require_cmd ifreload
  guards::acquire_lock "${LOCK_FILE}"

  if [[ -z "${SERVERLAB_BUNDLED:-}" ]]; then
    config::load "${config_file}"
  fi
  config::require NET_VM_IFACE NET_VM_BRIDGE NET_VM_BRIDGE_COMMENT \
    NET_VM_BRIDGE_VLAN_AWARE
  config::require_declared NET_VM_BRIDGE_VIDS
  validate_vlan_config

  preflight
  plan_and_confirm
  apply_change

  log::info "Done. ${NET_VM_BRIDGE} (${NET_VM_IFACE})" \
    "is configured and verified."
  log::info "Backup: ${backup_path}"
  log::info "No reboot required."
}

main "$@"
