#!/usr/bin/env bash
#
# base-system.sh — Proxmox-node post-install configuration, per
# docs/design/base-system.md. Currently: time zone, NTP (chrony) and
# package repositories.
#
# BASE_TIMEZONE (node config) is the IANA zone name to set. An empty value
# reverts to the zone saved in /etc/timezone.orig before the first change.
#
# BASE_NTP_SERVERS (array in the node config) is the exact set of time
# servers the node uses; the default chrony pool/server lines are disabled.
# An empty array reverts to the OS default chrony configuration, which is
# kept in /etc/chrony/chrony.conf.orig the first time this script changes
# anything.
#
# BASE_PVE_REPOSITORY and BASE_CEPH_REPOSITORY (node config) choose the APT
# repositories. The enterprise repositories are always disabled (they need a
# subscription key) and never deleted. BASE_PVE_REPOSITORY:
# "no-subscription" or "" (revert). BASE_CEPH_REPOSITORY: "disabled",
# "no-subscription" or "" (revert).
# The stock files are kept in /etc/apt/sources.list.orig the first time this
# script changes them.
#
# Each step shows its plan; one confirmation covers all steps with changes.
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

readonly CHRONY_CONF="/etc/chrony/chrony.conf"
readonly CHRONY_ORIG="/etc/chrony/chrony.conf.orig"
readonly CHRONY_SOURCES_DIR="/etc/chrony/sources.d"
readonly CHRONY_SOURCES="${CHRONY_SOURCES_DIR}/ntp-servers.sources"
readonly TZ_ORIG="/etc/timezone.orig"
readonly APT_SOURCES_DIR="/etc/apt/sources.list.d"
# Stock files and timestamped backups live here, not in sources.list.d, where
# apt would print a notice for every file with an unknown extension.
readonly APT_ORIG_DIR="/etc/apt/sources.list.orig"
readonly PVE_ENTERPRISE="${APT_SOURCES_DIR}/pve-enterprise.sources"
readonly PVE_NOSUB="${APT_SOURCES_DIR}/proxmox.sources"
readonly PVE_NOSUB_URI="http://download.proxmox.com/debian/pve"
readonly CEPH_ENTERPRISE="${APT_SOURCES_DIR}/ceph.sources"
readonly CEPH_NOSUB="${APT_SOURCES_DIR}/ceph-no-subscription.sources"
readonly LOCK_FILE="/run/serverlab/base-system.lock"

dry_run=false
auto_yes=""
config_file=""
tmp_dir=""

# Time zone step state
tz_current=""
tz_target=""
tz_changed=false

# NTP step state
new_conf=""
new_sources=""
conf_changed=false
sources_changed=false
backup_conf=""
backup_sources=""

# Package repositories step state. repo_dest[i] is written with the content
# of repo_src[i], or removed if repo_src[i] is empty.
repo_dest=()
repo_src=()
repo_backups=()

cleanup() {
  if [[ -n "${tmp_dir}" ]]; then
    rm -rf "${tmp_dir}"
  fi
}
trap cleanup EXIT

# --- Phase 1: parse arguments / input --------------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        if [[ $# -lt 2 ]]; then
          log::error "--config needs a file."
          args::usage "base-system.sh" >&2
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
        args::usage "base-system.sh"
        exit 0
        ;;
      *)
        log::error "Unknown argument: $1"
        args::usage "base-system.sh" >&2
        exit 2
        ;;
    esac
  done

  if [[ -z "${config_file}" ]]; then
    config_file="${_script_dir}/../config/proxmox-nodes/$(hostname -f).env"
  fi
}

# --- Phase 2: pre-flight checks ---------------------------------------------

# The file the desired configuration is derived from: the saved OS default
# if we already made one, otherwise the current chrony.conf.
ntp_base_conf() {
  if [[ -e "${CHRONY_ORIG}" ]]; then
    printf '%s\n' "${CHRONY_ORIG}"
  else
    printf '%s\n' "${CHRONY_CONF}"
  fi
}

ntp_preflight() {
  if [[ ! -f "${CHRONY_CONF}" ]]; then
    log::die "${CHRONY_CONF} not found — chrony does not appear to be" \
      "installed."
  fi

  if [[ "${#BASE_NTP_SERVERS[@]}" -gt 0 ]]; then
    local base
    base="$(ntp_base_conf)"
    if ! ntp::has_sourcedir "${base}" "${CHRONY_SOURCES_DIR}"; then
      log::die "${base} has no 'sourcedir ${CHRONY_SOURCES_DIR}'" \
        "line — refusing to guess how to add the NTP servers."
    fi
  fi
}

# The zone to set: the configured one, or (empty config) the saved original.
# Empty tz_target means there is nothing to set or revert to.
tz_resolve_target() {
  tz_current="$(timedatectl show -p Timezone --value)"
  if [[ -n "${BASE_TIMEZONE}" ]]; then
    tz_target="${BASE_TIMEZONE}"
  elif [[ -s "${TZ_ORIG}" ]]; then
    tz_target="$(<"${TZ_ORIG}")"
  else
    tz_target=""
  fi
}

tz_preflight() {
  tz_resolve_target
  if [[ -z "${tz_target}" ]]; then
    return 0
  fi

  if ! tz::valid "${tz_target}"; then
    log::die "'${tz_target}' is not a valid time zone under" \
      "/usr/share/zoneinfo."
  fi

  if [[ "$(timedatectl show -p LocalRTC --value)" != "no" ]]; then
    log::die "The hardware clock is set to local time. Set it to UTC" \
      "first: timedatectl set-local-rtc 0"
  fi
}

# repo_orig_path <file>
# Prints where the stock copy of <file> is (or will be) saved.
repo_orig_path() {
  printf '%s/%s\n' "${APT_ORIG_DIR}" "$(basename "$1")"
}

# The file an enterprise file's content is derived from: the saved stock
# file if we already made one, otherwise the current file (which may not
# exist).
repo_base() {
  local orig
  orig="$(repo_orig_path "$1")"
  if [[ -e "${orig}" ]]; then
    printf '%s\n' "${orig}"
  else
    printf '%s\n' "$1"
  fi
}

# repo_check_base <enterprise-file> <setting-name>
# Stops unless the stock enterprise file has what a no-subscription file is
# derived from: this OS release as the suite, and an existing keyring.
repo_check_base() {
  local base
  local codename
  local suite
  local keyring
  base="$(repo_base "$1")"

  if [[ ! -f "${base}" ]]; then
    log::die "${base} not found — refusing to guess the repository" \
      "settings for ${2}."
  fi

  codename="$(sed -n 's/^VERSION_CODENAME=//p' /etc/os-release | tr -d '"')"
  suite="$(apt::field "${base}" Suites)"
  if [[ -z "${codename}" || "${suite}" != "${codename}" ]]; then
    log::die "${base} has suite '${suite}', but this OS is" \
      "'${codename}' — refusing to continue (${2})."
  fi

  keyring="$(apt::field "${base}" Signed-By)"
  if [[ ! -f "${keyring}" ]]; then
    log::die "Keyring '${keyring}' (from ${base}) does not exist."
  fi
}

repo_preflight() {
  case "${BASE_PVE_REPOSITORY}" in
    no-subscription)
      repo_check_base "${PVE_ENTERPRISE}" BASE_PVE_REPOSITORY
      ;;
    "") ;;
    *)
      log::die "BASE_PVE_REPOSITORY must be \"no-subscription\" or empty" \
        "(got '${BASE_PVE_REPOSITORY}')."
      ;;
  esac

  case "${BASE_CEPH_REPOSITORY}" in
    no-subscription)
      repo_check_base "${CEPH_ENTERPRISE}" BASE_CEPH_REPOSITORY
      if ! apt::ceph_nosub_uri "$(apt::field \
        "$(repo_base "${CEPH_ENTERPRISE}")" URIs)" >/dev/null; then
        log::die "$(repo_base "${CEPH_ENTERPRISE}") is not a Proxmox" \
          "Ceph enterprise repository — refusing to guess the" \
          "no-subscription one."
      fi
      ;;
    disabled | "") ;;
    *)
      log::die "BASE_CEPH_REPOSITORY must be \"disabled\"," \
        "\"no-subscription\" or empty (got '${BASE_CEPH_REPOSITORY}')."
      ;;
  esac
}

preflight() {
  log::info "Checking current time zone, NTP (chrony) and package" \
    "repository state..."
  tz_preflight
  ntp_preflight
  repo_preflight
  log::info "Pre-flight checks passed."
}

# --- Phase 3: plan / diff / confirm -----------------------------------------

tz_plan() {
  if [[ -z "${tz_target}" ]]; then
    log::info "Time zone: nothing to revert to (no ${TZ_ORIG})."
    return 0
  fi

  if [[ "${tz_current}" == "${tz_target}" ]]; then
    log::info "Time zone: already ${tz_target}."
    return 0
  fi

  tz_changed=true
  log::info "Staging: time zone ${tz_current} -> ${tz_target}"
}

ntp_plan() {
  local base
  base="$(ntp_base_conf)"
  new_conf="${tmp_dir}/chrony.conf"
  new_sources="${tmp_dir}/ntp-servers.sources"

  if [[ "${#BASE_NTP_SERVERS[@]}" -gt 0 ]]; then
    ntp::disable_default_sources "${base}" >"${new_conf}"
    ntp::render_sources "${BASE_NTP_SERVERS[@]}" >"${new_sources}"
  else
    cat "${base}" >"${new_conf}"
    : >"${new_sources}"
  fi

  if ! cmp -s "${CHRONY_CONF}" "${new_conf}"; then
    conf_changed=true
  fi

  if [[ "${#BASE_NTP_SERVERS[@]}" -gt 0 ]]; then
    if [[ ! -e "${CHRONY_SOURCES}" ]] ||
      ! cmp -s "${CHRONY_SOURCES}" "${new_sources}"; then
      sources_changed=true
    fi
  elif [[ -e "${CHRONY_SOURCES}" ]]; then
    sources_changed=true
  fi

  if ! ntp_changed; then
    log::info "NTP: configuration already matches."
    return 0
  fi

  if [[ "${#BASE_NTP_SERVERS[@]}" -gt 0 ]]; then
    log::info "Staging: use only these NTP servers: ${BASE_NTP_SERVERS[*]}"
  else
    log::info "Staging: revert to the OS default NTP configuration."
  fi

  if [[ "${conf_changed}" == true ]]; then
    log::info "Staged diff (${CHRONY_CONF}):"
    files::diff "${CHRONY_CONF}" "${new_conf}" >&2
  fi

  if [[ "${sources_changed}" == true ]]; then
    if [[ "${#BASE_NTP_SERVERS[@]}" -eq 0 ]]; then
      log::info "Staged: remove ${CHRONY_SOURCES}"
    else
      log::info "Staged diff (${CHRONY_SOURCES}):"
      if [[ -e "${CHRONY_SOURCES}" ]]; then
        files::diff "${CHRONY_SOURCES}" "${new_sources}" >&2
      else
        files::diff /dev/null "${new_sources}" >&2
      fi
    fi
  fi
}

ntp_changed() {
  [[ "${conf_changed}" == true || "${sources_changed}" == true ]]
}

# repo_stage <dest> <staged-file|"">
# Records <dest> as changed if it differs from the staged content (or, with
# an empty staged file, if it exists and should be removed).
repo_stage() {
  local dest="$1"
  local src="$2"

  if [[ -n "${src}" ]]; then
    if [[ -e "${dest}" ]] && cmp -s "${dest}" "${src}"; then
      return 0
    fi
  elif [[ ! -e "${dest}" ]]; then
    return 0
  fi

  repo_dest+=("${dest}")
  repo_src+=("${src}")
}

# repo_stage_enterprise <enterprise-file> <disable: true|false>
# Disabling stages the base file with `Enabled: no`; otherwise the saved
# stock file (if there is one) is restored.
repo_stage_enterprise() {
  local file="$1"
  local base
  local staged
  base="$(repo_base "${file}")"

  if [[ "$2" == true ]]; then
    if [[ ! -f "${base}" ]]; then
      return 0
    fi
    staged="${tmp_dir}/$(basename "${file}")"
    apt::disable_source "${base}" >"${staged}"
    repo_stage "${file}" "${staged}"
  elif [[ -e "$(repo_orig_path "${file}")" ]]; then
    repo_stage "${file}" "$(repo_orig_path "${file}")"
  fi
}

# repo_stage_nosub <dest> <enterprise-file> <uri> <component>
# Stages a no-subscription file using the suite and keyring of the stock
# enterprise file.
repo_stage_nosub() {
  local dest="$1"
  local base
  local staged
  base="$(repo_base "$2")"
  staged="${tmp_dir}/$(basename "${dest}")"

  apt::render_source "$3" "$(apt::field "${base}" Suites)" "$4" \
    "$(apt::field "${base}" Signed-By)" >"${staged}"
  repo_stage "${dest}" "${staged}"
}

repo_plan() {
  local uri
  local i

  if [[ "${BASE_PVE_REPOSITORY}" == "no-subscription" ]]; then
    repo_stage_enterprise "${PVE_ENTERPRISE}" true
    repo_stage_nosub "${PVE_NOSUB}" "${PVE_ENTERPRISE}" \
      "${PVE_NOSUB_URI}" pve-no-subscription
  else
    repo_stage_enterprise "${PVE_ENTERPRISE}" false
    repo_stage "${PVE_NOSUB}" ""
  fi

  case "${BASE_CEPH_REPOSITORY}" in
    disabled)
      repo_stage_enterprise "${CEPH_ENTERPRISE}" true
      repo_stage "${CEPH_NOSUB}" ""
      ;;
    no-subscription)
      repo_stage_enterprise "${CEPH_ENTERPRISE}" true
      uri="$(apt::ceph_nosub_uri "$(apt::field \
        "$(repo_base "${CEPH_ENTERPRISE}")" URIs)")"
      repo_stage_nosub "${CEPH_NOSUB}" "${CEPH_ENTERPRISE}" \
        "${uri}" no-subscription
      ;;
    *)
      repo_stage_enterprise "${CEPH_ENTERPRISE}" false
      repo_stage "${CEPH_NOSUB}" ""
      ;;
  esac

  if ! repo_changed; then
    log::info "Package repositories: configuration already matches."
    return 0
  fi

  log::info "Staging: package repositories" \
    "(PVE: ${BASE_PVE_REPOSITORY:-revert}," \
    "Ceph: ${BASE_CEPH_REPOSITORY:-revert})"
  for i in "${!repo_dest[@]}"; do
    if [[ -z "${repo_src[i]}" ]]; then
      log::info "Staged: remove ${repo_dest[i]}"
      continue
    fi
    log::info "Staged diff (${repo_dest[i]}):"
    if [[ -e "${repo_dest[i]}" ]]; then
      files::diff "${repo_dest[i]}" "${repo_src[i]}" >&2
    else
      files::diff /dev/null "${repo_src[i]}" >&2
    fi
  done
}

repo_changed() {
  [[ "${#repo_dest[@]}" -gt 0 ]]
}

plan_and_confirm() {
  tmp_dir="$(mktemp -d)"
  tz_plan
  ntp_plan
  repo_plan

  if [[ "${tz_changed}" == false ]] && ! ntp_changed &&
    ! repo_changed; then
    log::info "Nothing to do."
    exit 0
  fi

  if [[ "${dry_run}" == true ]]; then
    log::info "--dry-run: no changes were applied."
    exit 0
  fi

  if ! prompt::confirm "Apply the above change now?" "${auto_yes}"; then
    log::info "Aborted by user (no changes were applied)."
    exit 3
  fi
}

# --- Phase 4/5: backup, apply ------------------------------------------------

# report_failure <message>
# Prints the manual undo commands for the chrony files, then stops.
report_failure() {
  log::error "$* — not rolling back automatically."
  log::error "To restore the previous config by hand:"
  if [[ -n "${backup_conf}" ]]; then
    log::error "  cp -p ${backup_conf} ${CHRONY_CONF}"
  fi
  if [[ -n "${backup_sources}" ]]; then
    log::error "  cp -p ${backup_sources} ${CHRONY_SOURCES}"
  elif [[ -e "${CHRONY_SOURCES}" ]]; then
    log::error "  rm ${CHRONY_SOURCES}"
  fi
  log::error "  systemctl restart chrony"
  guards::restore_hangup
  log::die "Stopped. NTP may be partially configured —" \
    "resolve manually (see above)."
}

tz_report_failure() {
  log::error "$* — not rolling back automatically."
  log::error "To restore the previous time zone by hand:"
  log::error "  timedatectl set-timezone ${tz_current}"
  guards::restore_hangup
  log::die "Stopped. The time zone may be partially configured —" \
    "resolve manually (see above)."
}

tz_apply() {
  if [[ ! -e "${TZ_ORIG}" && -n "${BASE_TIMEZONE}" ]]; then
    printf '%s\n' "${tz_current}" >"${TZ_ORIG}"
    log::info "Saved the previous time zone (${tz_current}) as" \
      "${TZ_ORIG}"
  fi

  guards::ignore_hangup
  log::info "Setting time zone to ${tz_target}..."
  pve::set "/nodes/$(pve::node)/time" --timezone "${tz_target}" >/dev/null ||
    tz_report_failure "Setting the time zone failed"

  if [[ "$(timedatectl show -p Timezone --value)" != "${tz_target}" ]]; then
    tz_report_failure "The time zone is not ${tz_target} after the change"
  fi
  if [[ "$(timedatectl show -p LocalRTC --value)" != "no" ]]; then
    tz_report_failure "The hardware clock is not set to UTC"
  fi
  guards::restore_hangup
  log::info "Verified: time zone is ${tz_target}."
}

repo_report_failure() {
  local i
  log::error "$* — not rolling back automatically."
  log::error "To restore the previous repository files by hand:"
  for i in "${!repo_dest[@]}"; do
    if [[ -n "${repo_backups[i]:-}" ]]; then
      log::error "  cp -p ${repo_backups[i]} ${repo_dest[i]}"
    else
      log::error "  rm -f ${repo_dest[i]}"
    fi
  done
  log::error "  apt-get update"
  guards::restore_hangup
  log::die "Stopped. The package repositories may be partially" \
    "configured — resolve manually (see above)."
}

repo_apply() {
  local i
  local dest
  local orig
  local backup
  local timestamp
  timestamp="$(date +%Y%m%d%H%M%S)"
  mkdir -p "${APT_ORIG_DIR}"

  for i in "${!repo_dest[@]}"; do
    dest="${repo_dest[i]}"
    repo_backups[i]=""
    if [[ ! -e "${dest}" ]]; then
      continue
    fi

    orig="$(repo_orig_path "${dest}")"
    if [[ ! -e "${orig}" && ("${dest}" == "${PVE_ENTERPRISE}" ||
      "${dest}" == "${CEPH_ENTERPRISE}") ]]; then
      cp -p "${dest}" "${orig}"
      log::info "Saved the stock file as ${orig}"
    fi

    backup="${APT_ORIG_DIR}/$(basename "${dest}").bak.${timestamp}"
    cp -p "${dest}" "${backup}"
    repo_backups[i]="${backup}"
    log::info "Backed up ${dest} to ${backup}"
  done

  guards::ignore_hangup
  log::info "Applying package repository changes..."
  for i in "${!repo_dest[@]}"; do
    dest="${repo_dest[i]}"
    if [[ -n "${repo_src[i]}" ]]; then
      install -m 644 "${repo_src[i]}" "${dest}" ||
        repo_report_failure "Writing ${dest} failed"
    else
      rm -f "${dest}" ||
        repo_report_failure "Removing ${dest} failed"
    fi
  done

  repo_verify
  guards::restore_hangup
}

# Returns 0 if an enterprise repository file exists and is not disabled.
repo_enterprise_enabled() {
  local file
  for file in "${PVE_ENTERPRISE}" "${CEPH_ENTERPRISE}"; do
    if [[ -e "${file}" ]] && ! apt::is_disabled "${file}"; then
      return 0
    fi
  done
  return 1
}

# Checks every changed repository file against its staged content and that
# apt still reads the sources without errors. Returns non-zero on a problem.
repo_verify() {
  local i
  local output
  local errors
  local unexpected
  local status=0
  log::info "Verifying package repositories..."

  for i in "${!repo_dest[@]}"; do
    if [[ -n "${repo_src[i]}" ]]; then
      if ! cmp -s "${repo_dest[i]}" "${repo_src[i]}"; then
        repo_report_failure "${repo_dest[i]} does not match the" \
          "intended content"
      fi
    elif [[ -e "${repo_dest[i]}" ]]; then
      repo_report_failure "${repo_dest[i]} still exists"
    fi
  done

  # Only refreshes the package lists; nothing is installed or upgraded.
  log::info "Running 'apt-get update' to check the repositories..."
  output="$(LC_ALL=C apt-get update 2>&1)" || status=$?
  printf '%s\n' "${output}" >&2
  errors="$(apt::error_lines <<<"${output}")"
  # An enabled enterprise repository fails with 401 without a subscription
  # key (expected after a revert), so those errors only warn.
  if repo_enterprise_enabled; then
    unexpected="$(grep -v 'enterprise\.proxmox\.com' <<<"${errors}" ||
      true)"
  else
    unexpected="${errors}"
  fi
  if [[ -n "${unexpected}" ]] ||
    [[ "${status}" -ne 0 && -z "${errors}" ]]; then
    repo_report_failure "'apt-get update' reported errors"
  fi
  if [[ "${errors}" != "${unexpected}" ]]; then
    log::warn "An enabled enterprise repository returned errors." \
      "It needs a subscription key; this is expected after a revert."
  fi
  if grep -q '^W:' <<<"${output}"; then
    log::warn "'apt-get update' printed warnings (see above)."
  fi
  log::info "Verified: package repositories are as intended."
}

apply_change() {
  if [[ "${tz_changed}" == true ]]; then
    tz_apply
  fi
  if ntp_changed; then
    ntp_apply
  fi
  if repo_changed; then
    repo_apply
  fi
}

ntp_apply() {
  backup_conf="$(files::backup "${CHRONY_CONF}")"
  log::info "Backed up ${CHRONY_CONF} to ${backup_conf}"
  backup_sources="$(files::backup "${CHRONY_SOURCES}" || true)"
  if [[ -n "${backup_sources}" ]]; then
    log::info "Backed up ${CHRONY_SOURCES} to ${backup_sources}"
  fi

  if [[ ! -e "${CHRONY_ORIG}" && "${#BASE_NTP_SERVERS[@]}" -gt 0 ]]; then
    cp -p "${CHRONY_CONF}" "${CHRONY_ORIG}"
    log::info "Saved the OS default configuration as ${CHRONY_ORIG}"
  fi

  guards::ignore_hangup
  log::info "Applying..."

  if [[ "${conf_changed}" == true ]]; then
    install -m 644 "${new_conf}" "${CHRONY_CONF}" ||
      report_failure "Writing ${CHRONY_CONF} failed"
  fi

  if [[ "${#BASE_NTP_SERVERS[@]}" -gt 0 ]]; then
    if [[ "${sources_changed}" == true ]]; then
      mkdir -p "${CHRONY_SOURCES_DIR}"
      install -m 644 "${new_sources}" "${CHRONY_SOURCES}" ||
        report_failure "Writing ${CHRONY_SOURCES} failed"
    fi
  elif [[ "${sources_changed}" == true ]]; then
    rm -f "${CHRONY_SOURCES}" ||
      report_failure "Removing ${CHRONY_SOURCES} failed"
  fi

  log::info "Restarting chrony..."
  systemctl restart chrony || report_failure "Restarting chrony failed"

  verify_change
  guards::restore_hangup
}

# --- Phase 6: post-verify ----------------------------------------------------

verify_change() {
  log::info "Verifying..."

  if ! systemctl is-active --quiet chrony; then
    report_failure "chrony is not active after the restart"
  fi

  if ! cmp -s "${CHRONY_CONF}" "${new_conf}"; then
    report_failure "${CHRONY_CONF} does not match the intended content"
  fi

  if [[ "${#BASE_NTP_SERVERS[@]}" -gt 0 ]]; then
    if ! cmp -s "${CHRONY_SOURCES}" "${new_sources}"; then
      report_failure "${CHRONY_SOURCES} does not match the intended" \
        "content"
    fi
  elif [[ -e "${CHRONY_SOURCES}" ]]; then
    report_failure "${CHRONY_SOURCES} still exists"
  fi

  verify_sources
  log::info "Verified: chrony is active with the intended configuration."
}

# Chrony resolves server names asynchronously after a restart, so allow a
# few seconds for the expected number of sources to appear.
verify_sources() {
  local expected="${#BASE_NTP_SERVERS[@]}"
  local actual=0

  if [[ "${expected}" -eq 0 ]]; then
    chronyc sources >&2 || report_failure "chronyc could not query chrony"
    return 0
  fi

  for _ in {1..10}; do
    actual="$(ntp::count_sources)" ||
      report_failure "chronyc could not query chrony"
    [[ "${actual}" -eq "${expected}" ]] && break
    sleep 1
  done

  chronyc sources >&2 || true
  if [[ "${actual}" -ne "${expected}" ]]; then
    report_failure "chrony has ${actual} sources, expected ${expected}"
  fi

  log::info "Waiting up to ~1 minute for chrony to synchronise..."
  if chronyc waitsync 12 0 0 5 >/dev/null 2>&1; then
    log::info "chrony is synchronised."
  else
    log::warn "chrony is not synchronised yet. This does not mean the" \
      "configuration is wrong; check 'chronyc tracking' later."
  fi
}

# --- Phase 7: summary ---------------------------------------------------------

main() {
  parse_args "$@"

  guards::require_root
  guards::require_proxmox
  guards::require_cmd chronyc systemctl timedatectl apt-get
  guards::acquire_lock "${LOCK_FILE}"

  if [[ -z "${SERVERLAB_BUNDLED:-}" ]]; then
    config::load "${config_file}"
  fi
  config::require_declared BASE_TIMEZONE
  config::require_array BASE_NTP_SERVERS
  config::require_declared BASE_PVE_REPOSITORY BASE_CEPH_REPOSITORY

  preflight
  plan_and_confirm
  apply_change

  log::info "Done. Time zone, NTP and package repositories are configured" \
    "and verified."
  if [[ -n "${backup_conf}" ]]; then
    log::info "Backup: ${backup_conf}"
  fi
  log::info "No reboot required."
}

main "$@"
