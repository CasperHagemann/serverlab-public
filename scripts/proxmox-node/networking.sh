#!/bin/bash
#
# networking.sh — Proxmox-node networking configuration, per
# docs/design/networking.md. Currently: creates the general VM network
# bridge (vmbr1) on top of its physical NIC.
#
# The management bridge (vmbr0) is expected to already exist from the
# Proxmox installer — this script only touches the general VM network.
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

dry_run=false
auto_yes=""
config_file=""
backup_path=""

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
    if [[ "${existing_master}" == "${NET_VM_BRIDGE}" ]]; then
      log::info "${NET_VM_BRIDGE} already exists with ${NET_VM_IFACE}" \
        "attached."
      log::info "Nothing to do."
      exit 0
    fi
    log::die "${NET_VM_BRIDGE} already exists but ${NET_VM_IFACE} is not its" \
      "member (master: '${existing_master:-none}')." \
      "Refusing to change an existing bridge — resolve manually."
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
  log::info "Staging: create bridge '${NET_VM_BRIDGE}' on '${NET_VM_IFACE}'" \
    "(no IP address)."

  pve::create "/nodes/$(pve::node)/network" \
    --iface "${NET_VM_BRIDGE}" \
    --type bridge \
    --bridge_ports "${NET_VM_IFACE}" \
    --autostart 1 \
    --comments "${NET_VM_BRIDGE_COMMENT}"

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

  log::info "Verified: ${NET_VM_IFACE} is attached to ${NET_VM_BRIDGE}."
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
  config::require NET_VM_IFACE NET_VM_BRIDGE NET_VM_BRIDGE_COMMENT

  preflight
  plan_and_confirm
  apply_change

  log::info "Done. ${NET_VM_BRIDGE} (${NET_VM_IFACE})" \
    "is configured and verified."
  log::info "Backup: ${backup_path}"
  log::info "No reboot required."
}

main "$@"
