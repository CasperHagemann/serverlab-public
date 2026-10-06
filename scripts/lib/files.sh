#!/bin/bash
#
# files.sh — file backup/restore/diff helpers. Functions only.
[[ -n "${SERVERLAB_LIB_FILES:-}" ]] && return 0
readonly SERVERLAB_LIB_FILES=1

# files::backup <path>
# Copies <path> to <path>.bak.<timestamp> and prints the backup path to
# stdout. No-op (prints nothing, returns 1) if <path> doesn't exist.
files::backup() {
  local path="$1"
  local backup_path

  if [[ ! -e "${path}" ]]; then
    return 1
  fi

  backup_path="${path}.bak.$(date +%Y%m%d%H%M%S)"
  cp -p "${path}" "${backup_path}"
  printf '%s\n' "${backup_path}"
}

# files::restore <backup-path> <original-path>
# Restores <backup-path> over <original-path>.
files::restore() {
  local backup_path="$1"
  local original_path="$2"
  cp -p "${backup_path}" "${original_path}"
}

# files::diff <path-a> <path-b>
# Prints a unified diff between two files (or empty output if identical).
# Never fails the caller's `set -e` due to `diff`'s non-zero "files differ"
# exit status.
files::diff() {
  local path_a="$1"
  local path_b="$2"
  diff -u "${path_a}" "${path_b}" || true
}
