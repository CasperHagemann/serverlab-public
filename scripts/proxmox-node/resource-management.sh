#!/bin/bash
#
# resource-management.sh — gives the Proxmox node's own processes priority
# over guests for CPU time, disk I/O and memory, per
# docs/design/resource-management.md and ADR-0013. Weights only, no
# limits: capacity that is idle stays available to guests.
#
# Node config settings (an empty value reverts that setting):
#   RESOURCE_CPU_WEIGHT  CPUWeight (1-10000) of system.slice and user.slice.
#   RESOURCE_IO_WEIGHT   IOWeight (1-10000) of system.slice and user.slice. BFQ
#                    scales it to 1-1000, so 10000 gives BFQ weight 1000
#                    against 100 for qemu.slice.
#   RESOURCE_MEMORY_LOW  MemoryLow of system.slice, e.g. 4G.
#   RESOURCE_IO_SCHEDULER     I/O scheduler of the OS disk (STORAGE_DISK or the
#                    detected OS disk), persisted by a udev rule. Empty
#                    reverts to the scheduler saved in /etc/io-scheduler.orig
#                    the first time this script changes it.
#
# The slice settings are systemd drop-ins in /etc/systemd/system. systemd
# does not write a changed drop-in value to a running slice, and writes no
# io.bfq.weight to system.slice at boot (it exists before the bfq module is
# loaded). So the script also writes the values to the running slices
# (empty settings: the defaults), and installs a oneshot unit,
# serverlab-resource-priority.service, that does the same at every boot.
#
# Each step shows its plan; one confirmation covers all changes.
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

readonly SLICES=(system.slice user.slice)
readonly SYSTEMD_DIR="/etc/systemd/system"
readonly DROPIN_FILE="50-resource-priority.conf"
readonly RUNTIME_CONTROL_DIR="/run/systemd/system.control"
readonly UNIT_NAME="serverlab-resource-priority.service"
readonly UNIT_FILE="${SYSTEMD_DIR}/${UNIT_NAME}"
readonly UDEV_RULE="/etc/udev/rules.d/60-io-scheduler.rules"
readonly SCHED_ORIG="/etc/io-scheduler.orig"
readonly CGROUP_ROOT="/sys/fs/cgroup"
readonly LOCK_FILE="/run/serverlab/resource-management.lock"

dry_run=false
auto_yes=""
config_file=""
tmp_dir=""

# I/O scheduler state
disk=""
disk_name=""
sched_file=""
sched_active=""
sched_target=""
sched_changed=false

# Files to change. res_dest[i] is written with the content of res_src[i], or
# removed if res_src[i] is empty.
res_dest=()
res_src=()
res_backups=()

# Boot unit and live cgroup value state
unit_wanted=false
unit_enable_needed=false
live_changed=false

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
          args::usage "resource-management.sh" >&2
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
        args::usage "resource-management.sh"
        exit 0
        ;;
      *)
        log::error "Unknown argument: $1"
        args::usage "resource-management.sh" >&2
        exit 2
        ;;
    esac
  done

  if [[ -z "${config_file}" ]]; then
    config_file="${_script_dir}/../config/proxmox-nodes/$(hostname -f).env"
  fi
}

# --- Phase 2: pre-flight checks ---------------------------------------------

# slice_dropin <slice>
# Prints the path of the systemd drop-in file for <slice>.
slice_dropin() {
  printf '%s/%s.d/%s\n' "${SYSTEMD_DIR}" "$1" "${DROPIN_FILE}"
}

# MemoryLow applies to system.slice only.
slice_memory() {
  if [[ "$1" == "system.slice" ]]; then
    printf '%s\n' "${RESOURCE_MEMORY_LOW}"
  fi
}

# Stops with a clear message if a RESOURCE_* value is out of range.
validate_settings() {
  local name
  for name in RESOURCE_CPU_WEIGHT RESOURCE_IO_WEIGHT; do
    if [[ -n "${!name}" ]] && ! cgroup::valid_weight "${!name}"; then
      log::die "${name} must be a whole number from 1 to 10000 or" \
        "empty (got '${!name}')."
    fi
  done

  if [[ -n "${RESOURCE_MEMORY_LOW}" ]] &&
    ! cgroup::valid_memory "${RESOURCE_MEMORY_LOW}"; then
    log::die "RESOURCE_MEMORY_LOW must be a number of bytes with an" \
      "optional K, M, G or T suffix, or empty (got" \
      "'${RESOURCE_MEMORY_LOW}')."
  fi

  if [[ -n "${RESOURCE_IO_SCHEDULER}" ]] &&
    ! cgroup::valid_scheduler "${RESOURCE_IO_SCHEDULER}"; then
    log::die "RESOURCE_IO_SCHEDULER must be bfq, mq-deadline, kyber, none or" \
      "empty (got '${RESOURCE_IO_SCHEDULER}')."
  fi
}

# check_controller <controller> <setting>
# Stops unless the kernel offers the cgroup <controller>.
check_controller() {
  local controller="$1"
  local setting="$2"
  if ! grep -qw "${controller}" "${CGROUP_ROOT}/cgroup.controllers"; then
    log::die "The cgroup controller '${controller}' is not available" \
      "— ${setting} cannot be applied."
  fi
}

controllers_preflight() {
  if [[ ! -r "${CGROUP_ROOT}/cgroup.controllers" ]]; then
    log::die "${CGROUP_ROOT}/cgroup.controllers not found — cgroup v2" \
      "is required."
  fi
  if [[ -n "${RESOURCE_CPU_WEIGHT}" ]]; then
    check_controller cpu RESOURCE_CPU_WEIGHT
  fi
  if [[ -n "${RESOURCE_IO_WEIGHT}" ]]; then
    check_controller io RESOURCE_IO_WEIGHT
  fi
  if [[ -n "${RESOURCE_MEMORY_LOW}" ]]; then
    check_controller memory RESOURCE_MEMORY_LOW
  fi
}

scheduler_preflight() {
  disk="${STORAGE_DISK:-$(disk::os_disk)}"
  disk_name="$(basename "${disk}")"
  sched_file="/sys/block/${disk_name}/queue/scheduler"

  if [[ ! -r "${sched_file}" ]]; then
    log::die "${sched_file} not found — cannot read the I/O scheduler" \
      "of ${disk}."
  fi

  # A scheduler built as a module is only listed once it is loaded.
  if [[ -n "${RESOURCE_IO_SCHEDULER}" ]] &&
    ! cgroup::scheduler_listed "${RESOURCE_IO_SCHEDULER}" "${sched_file}" &&
    ! modinfo "${RESOURCE_IO_SCHEDULER}" >/dev/null 2>&1; then
    log::die "The I/O scheduler '${RESOURCE_IO_SCHEDULER}' is not" \
      "available for ${disk}."
  fi
}

preflight() {
  log::info "Checking the resource priority settings and the current" \
    "state..."
  validate_settings
  controllers_preflight
  scheduler_preflight
  log::info "Pre-flight checks passed."
}

# --- Phase 3: plan / diff / confirm -----------------------------------------

# plan_file <destination> <new-content-file>
# Queues the file for writing if it differs from <new-content-file>, or for
# removal if <new-content-file> is empty and the destination exists.
plan_file() {
  local dest="$1"
  local new="$2"

  if [[ -s "${new}" ]]; then
    if [[ -e "${dest}" ]] && cmp -s "${dest}" "${new}"; then
      return 0
    fi
    res_dest+=("${dest}")
    res_src+=("${new}")
    log::info "Staged diff (${dest}):"
    if [[ -e "${dest}" ]]; then
      files::diff "${dest}" "${new}" >&2
    else
      files::diff /dev/null "${new}" >&2
    fi
  elif [[ -e "${dest}" ]]; then
    res_dest+=("${dest}")
    res_src+=("")
    log::info "Staged: remove ${dest}"
  fi
}

dropins_plan() {
  local slice
  local new

  for slice in "${SLICES[@]}"; do
    new="${tmp_dir}/${slice}.conf"
    cgroup::render_dropin "${RESOURCE_CPU_WEIGHT}" "${RESOURCE_IO_WEIGHT}" \
      "$(slice_memory "${slice}")" >"${new}"
    plan_file "$(slice_dropin "${slice}")" "${new}"
  done
}

# systemd does not write io.bfq.weight to a slice created before the bfq
# module is loaded (system.slice, early in boot), so a oneshot unit applies
# the values at runtime after udev has set the scheduler.
unit_plan() {
  local new="${tmp_dir}/${UNIT_NAME}"

  cgroup::render_unit "${RESOURCE_CPU_WEIGHT}" "${RESOURCE_IO_WEIGHT}" \
    "${RESOURCE_MEMORY_LOW}" >"${new}"
  plan_file "${UNIT_FILE}" "${new}"

  if [[ -s "${new}" ]]; then
    unit_wanted=true
    if ! systemctl is-enabled --quiet "${UNIT_NAME}" 2>/dev/null; then
      unit_enable_needed=true
      log::info "Staging: enable ${UNIT_NAME}"
    fi
  fi
}

# live_check <slice> <cgroup-file> <expected>
# Flags a change if the value the kernel holds differs from the target.
# Missing files:
#   - user.slice does not exist until the first login: skipped.
#   - cpu.weight and memory.low of system.slice: the controller is not
#     enabled, which is an error.
#   - io.bfq.weight of system.slice: a change if bfq is the active
#     scheduler and a weight is set (the file belongs to the bfq policy),
#     otherwise skipped.
live_check() {
  local actual
  local effective="${sched_target:-${sched_active}}"

  if ! actual="$(cgroup::weight_value "${CGROUP_ROOT}/$1/$2")"; then
    if [[ "$1" != "system.slice" ]]; then
      return 0
    fi
    if [[ "$2" != "io.bfq.weight" ]]; then
      log::die "${CGROUP_ROOT}/$1/$2 is missing: the controller is" \
        "not enabled."
    fi
    if [[ "${effective}" == "bfq" && "${sched_changed}" == false &&
      -n "${RESOURCE_IO_WEIGHT}" ]]; then
      live_changed=true
      log::info "Staging: $1 $2 not present -> $3 (bfq is active)"
    fi
    return 0
  fi
  if [[ "${actual}" != "$3" ]]; then
    live_changed=true
    log::info "Staging: $1 $2 ${actual} -> $3"
  fi
}

live_plan() {
  local slice
  local memory_low=0

  for slice in "${SLICES[@]}"; do
    live_check "${slice}" cpu.weight "${RESOURCE_CPU_WEIGHT:-100}"
    live_check "${slice}" io.bfq.weight \
      "$(cgroup::bfq_weight "${RESOURCE_IO_WEIGHT:-100}")"
  done
  if [[ -n "${RESOURCE_MEMORY_LOW}" ]]; then
    memory_low="$(cgroup::memory_bytes "${RESOURCE_MEMORY_LOW}")"
  fi
  live_check system.slice memory.low "${memory_low}"
}

scheduler_plan() {
  local rule="${tmp_dir}/io-scheduler.rules"
  local effective

  sched_active="$(cgroup::active_scheduler "${sched_file}")"
  if [[ -n "${RESOURCE_IO_SCHEDULER}" ]]; then
    sched_target="${RESOURCE_IO_SCHEDULER}"
    cgroup::render_udev_rule "${disk_name}" "${sched_target}" >"${rule}"
  else
    : >"${rule}"
    if [[ -s "${SCHED_ORIG}" ]]; then
      sched_target="$(<"${SCHED_ORIG}")"
    fi
  fi
  plan_file "${UDEV_RULE}" "${rule}"

  if [[ -n "${sched_target}" &&
    "${sched_active}" != "${sched_target}" ]]; then
    sched_changed=true
    log::info "Staging: I/O scheduler of ${disk_name}:" \
      "${sched_active} -> ${sched_target}"
  fi

  effective="${sched_target:-${sched_active}}"
  if [[ -n "${RESOURCE_IO_WEIGHT}" && "${effective}" != "bfq" ]]; then
    log::warn "RESOURCE_IO_WEIGHT has no effect unless the I/O scheduler" \
      "is bfq (it will be ${effective})."
  fi
}

plan_and_confirm() {
  tmp_dir="$(mktemp -d)"
  dropins_plan
  unit_plan
  scheduler_plan
  live_plan

  if [[ "${#res_dest[@]}" -eq 0 && "${sched_changed}" == false &&
    "${unit_enable_needed}" == false && "${live_changed}" == false ]]; then
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
# Prints the manual undo commands for each changed file, then stops.
report_failure() {
  local i
  log::error "$* — not rolling back automatically."
  log::error "To restore the previous files by hand:"
  for i in "${!res_dest[@]}"; do
    if [[ -n "${res_backups[i]:-}" ]]; then
      log::error "  cp -p ${res_backups[i]} ${res_dest[i]}"
    else
      log::error "  rm -f ${res_dest[i]}"
    fi
  done
  log::error "  systemctl daemon-reload"
  if [[ "${sched_changed}" == true ]]; then
    log::error "  echo ${sched_active} > ${sched_file}"
  fi
  guards::restore_hangup
  log::die "Stopped. The resource priority settings may be partially" \
    "configured — resolve manually (see above)."
}

# Writes the target values (the defaults for empty settings) to the running
# slices. The runtime drop-ins set-property creates are removed again: the
# kernel keeps the values, and the files in /etc/systemd/system stay the
# only persistent configuration.
apply_runtime() {
  local slice
  local memory
  local props

  for slice in "${SLICES[@]}"; do
    memory=""
    if [[ "${slice}" == "system.slice" ]]; then
      memory="${RESOURCE_MEMORY_LOW:-0}"
    fi
    props="$(cgroup::slice_properties "${RESOURCE_CPU_WEIGHT:-100}" \
      "${RESOURCE_IO_WEIGHT:-100}" "${memory}")"
    log::info "Applying to ${slice}: ${props}"
    # Word splitting of ${props} is intended.
    # shellcheck disable=SC2086
    systemctl set-property --runtime "${slice}" ${props} ||
      report_failure "Setting ${props} on ${slice} failed"
  done
  rm -rf "${RUNTIME_CONTROL_DIR}/system.slice.d" \
    "${RUNTIME_CONTROL_DIR}/user.slice.d"
  systemctl daemon-reload || report_failure "systemctl daemon-reload failed"
}

apply_change() {
  local i
  local dest

  if [[ -n "${RESOURCE_IO_SCHEDULER}" && ! -e "${SCHED_ORIG}" ]]; then
    printf '%s\n' "${sched_active}" >"${SCHED_ORIG}"
    log::info "Saved the current I/O scheduler (${sched_active}) as" \
      "${SCHED_ORIG}"
  fi

  guards::ignore_hangup
  log::info "Applying..."

  for i in "${!res_dest[@]}"; do
    dest="${res_dest[i]}"
    res_backups[i]=""
    if [[ -e "${dest}" ]]; then
      res_backups[i]="$(files::backup "${dest}")"
      log::info "Backed up ${dest} to ${res_backups[i]}"
    fi
    if [[ -n "${res_src[i]}" ]]; then
      mkdir -p "$(dirname "${dest}")"
      install -m 644 "${res_src[i]}" "${dest}" ||
        report_failure "Writing ${dest} failed"
    else
      if [[ "${dest}" == "${UNIT_FILE}" ]]; then
        systemctl disable "${UNIT_NAME}" >/dev/null 2>&1 || true
      fi
      rm -f "${dest}" || report_failure "Removing ${dest} failed"
    fi
  done

  # The scheduler comes first: systemd writes io.bfq.weight only while the
  # bfq policy is loaded.
  if [[ "${sched_changed}" == true ]]; then
    log::info "Setting the I/O scheduler of ${disk_name} to" \
      "${sched_target}..."
    printf '%s\n' "${sched_target}" >"${sched_file}" ||
      report_failure "Setting the I/O scheduler failed"
  fi

  log::info "Reloading systemd..."
  systemctl daemon-reload || report_failure "systemctl daemon-reload failed"
  apply_runtime
  udevadm control --reload || report_failure "udevadm control --reload failed"

  if [[ "${unit_wanted}" == true ]]; then
    log::info "Enabling ${UNIT_NAME}..."
    systemctl enable "${UNIT_NAME}" >/dev/null 2>&1 ||
      report_failure "Enabling ${UNIT_NAME} failed"
  fi

  verify_change
  guards::restore_hangup
}

# --- Phase 6: post-verify ----------------------------------------------------

# verify_value <slice> <cgroup-file> <expected>
verify_value() {
  local slice="$1"
  local file="$2"
  local expected="$3"
  local actual

  actual="$(cgroup::weight_value "${CGROUP_ROOT}/${slice}/${file}")" ||
    actual="(unreadable)"
  if [[ "${actual}" != "${expected}" ]]; then
    report_failure "${slice} ${file} is ${actual}, expected ${expected}"
  fi
}

# verify_io_weight <slice>
# Checks io.bfq.weight; warns and skips if the bfq policy is not loaded.
verify_io_weight() {
  local slice="$1"

  if [[ ! -e "${CGROUP_ROOT}/${slice}/io.bfq.weight" ]]; then
    log::warn "${slice}: io.bfq.weight does not exist (the bfq policy" \
      "is not loaded); the I/O weight was not verified."
    return 0
  fi
  verify_value "${slice}" io.bfq.weight \
    "$(cgroup::bfq_weight "${RESOURCE_IO_WEIGHT:-100}")"
}

verify_change() {
  local i
  local slice
  local now
  local memory_low=0

  log::info "Verifying..."

  for i in "${!res_dest[@]}"; do
    if [[ -n "${res_src[i]}" ]]; then
      if ! cmp -s "${res_src[i]}" "${res_dest[i]}"; then
        report_failure "${res_dest[i]} does not match the intended" \
          "content"
      fi
    elif [[ -e "${res_dest[i]}" ]]; then
      report_failure "${res_dest[i]} still exists"
    fi
  done

  now="$(cgroup::active_scheduler "${sched_file}")"
  if [[ -n "${sched_target}" && "${now}" != "${sched_target}" ]]; then
    report_failure "The I/O scheduler of ${disk_name} is not" \
      "${sched_target} after the change"
  fi

  if [[ "${unit_wanted}" == true ]] &&
    ! systemctl is-enabled --quiet "${UNIT_NAME}"; then
    report_failure "${UNIT_NAME} is not enabled"
  fi

  for slice in "${SLICES[@]}"; do
    verify_value "${slice}" cpu.weight "${RESOURCE_CPU_WEIGHT:-100}"
    verify_io_weight "${slice}"
  done

  if [[ -n "${RESOURCE_MEMORY_LOW}" ]]; then
    memory_low="$(cgroup::memory_bytes "${RESOURCE_MEMORY_LOW}")"
  fi
  verify_value system.slice memory.low "${memory_low}"

  log::info "Verified: the resource priority settings are in effect."
}

# --- Phase 7: summary ---------------------------------------------------------

main() {
  parse_args "$@"

  guards::require_root
  guards::require_proxmox
  guards::require_cmd systemctl udevadm modinfo
  guards::acquire_lock "${LOCK_FILE}"

  if [[ -z "${SERVERLAB_BUNDLED:-}" ]]; then
    config::load "${config_file}"
  fi
  config::require_declared RESOURCE_CPU_WEIGHT RESOURCE_IO_WEIGHT \
    RESOURCE_MEMORY_LOW RESOURCE_IO_SCHEDULER

  preflight
  plan_and_confirm
  apply_change

  log::info "Done. Node CPU, disk I/O and memory priority is configured" \
    "and verified."
  log::info "No reboot required."
}

main "$@"
