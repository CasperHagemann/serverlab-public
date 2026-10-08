#!/bin/bash
#
# files.sh — file backup/restore/diff helpers. Functions only.
[[ -n "${SERVERLAB_LIB_FILES:-}" ]] && return 0
readonly SERVERLAB_LIB_FILES=1

# files::prune_backups <path>
# Deletes the oldest <path>.bak.<timestamp> files, keeping the newest
# SERVERLAB_BACKUP_KEEP (default 5; a non-number or 0 means the default).
# Only backups of this one file are touched.
files::prune_backups() {
  local path="$1"
  local keep="${SERVERLAB_BACKUP_KEEP:-5}"
  [[ "${keep}" =~ ^[0-9]+$ ]] && ((keep > 0)) || keep=5

  local backups=() candidate
  # The glob sorts by name, and the timestamp makes that oldest first.
  for candidate in "${path}".bak.*; do
    [[ -e "${candidate}" ]] && backups+=("${candidate}")
  done

  local excess=$((${#backups[@]} - keep)) i
  for ((i = 0; i < excess; i++)); do
    rm -f -- "${backups[i]}"
  done
}

# files::backup <path>
# Copies <path> to <path>.bak.<timestamp> and prints the backup path to
# stdout, then removes the oldest backups of <path> beyond the newest
# SERVERLAB_BACKUP_KEEP (default 5). No-op (prints nothing, returns 1) if
# <path> doesn't exist.
files::backup() {
  local path="$1"
  local backup_path

  if [[ ! -e "${path}" ]]; then
    return 1
  fi

  backup_path="${path}.bak.$(date +%Y%m%d%H%M%S)"
  cp -p "${path}" "${backup_path}"
  files::prune_backups "${path}"
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
