#!/bin/bash
#
# log.sh — logging helpers. Functions only; sourcing this file has no side
# effects other than defining functions below.
[[ -n "${SERVERLAB_LIB_LOG:-}" ]] && return 0
readonly SERVERLAB_LIB_LOG=1

# log::info <message...>
# Prints an informational message to stderr.
log::info() {
  printf '[INFO]  %s\n' "$*" >&2
}

# log::warn <message...>
# Prints a warning message to stderr.
log::warn() {
  printf '[WARN]  %s\n' "$*" >&2
}

# log::error <message...>
# Prints an error message to stderr.
log::error() {
  printf '[ERROR] %s\n' "$*" >&2
}

# log::reboot_required <reason...>
# Warns that the administrator must reboot the node, and records the reason
# in a reminder file (default /run/serverlab/reboot-required; override with
# SERVERLAB_REBOOT_FILE). /run is cleared on boot, so the reminder ends with
# the reboot. The stage name (SERVERLAB_STAGE, set by remote-run.sh) is
# prefixed when known. A reason already recorded is not added twice.
# Never reboots and never fails the caller.
log::reboot_required() {
  local file="${SERVERLAB_REBOOT_FILE:-/run/serverlab/reboot-required}"
  local entry="${SERVERLAB_STAGE:+${SERVERLAB_STAGE}: }$*"

  log::warn "Reboot required: $*"
  if ! mkdir -p "$(dirname "${file}")" 2>/dev/null; then
    log::warn "Could not record the reboot reminder in ${file}."
    return 0
  fi
  if ! grep -qxF -- "${entry}" "${file}" 2>/dev/null; then
    printf '%s\n' "${entry}" >>"${file}" ||
      log::warn "Could not record the reboot reminder in ${file}."
  fi
  return 0
}

# log::die [--code <n>] <message...>
# Prints an error message and exits with status <n> (default 1).
log::die() {
  local code=1
  if [[ "${1:-}" == "--code" ]]; then
    code="$2"
    shift 2
  fi
  log::error "$*"
  exit "${code}"
}
