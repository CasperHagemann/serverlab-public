#!/usr/bin/env bash
#
# guards.sh — safety-check helpers that abort the script early when a
# precondition isn't met. Functions only.
[[ -n "${SERVERLAB_LIB_GUARDS:-}" ]] && return 0
readonly SERVERLAB_LIB_GUARDS=1

# guards::require_root
# Aborts unless running as root. Most Proxmox node configuration requires it.
guards::require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log::die "This script must be run as root."
  fi
}

# guards::require_proxmox
# Aborts unless the `pvesh` CLI is available, i.e. we're on a Proxmox node.
guards::require_proxmox() {
  if ! command -v pvesh >/dev/null 2>&1; then
    log::die "pvesh not found — this does not appear to be a Proxmox node."
  fi
}

# guards::require_cmd <command> [command...]
# Aborts if any of the given commands are not on PATH.
guards::require_cmd() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      log::die "Required command '${cmd}' not found on PATH."
    fi
  done
}

# guards::acquire_lock <lock-file>
# Acquires an exclusive, non-blocking lock so two instances of a
# Proxmox-node script can't run concurrently. Holds the lock for the
# lifetime of the process (released automatically on exit, including on
# error).
guards::acquire_lock() {
  local lock_file="$1"
  local lock_fd
  mkdir -p "$(dirname "${lock_file}")"
  exec {lock_fd}>"${lock_file}"
  if ! flock -n "${lock_fd}"; then
    log::die "Another instance appears to be running (lock: ${lock_file})."
  fi
}

# guards::ignore_hangup
# Ignores SIGHUP for the remainder of the current shell/subshell, so a
# dropped SSH session doesn't kill a critical section (apply/verify/rollback)
# partway through. Call guards::restore_hangup to undo, if needed.
guards::ignore_hangup() {
  trap '' HUP
}

# guards::restore_hangup
# Restores default SIGHUP handling after guards::ignore_hangup.
guards::restore_hangup() {
  trap - HUP
}
