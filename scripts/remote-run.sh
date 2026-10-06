#!/bin/bash
#
# remote-run.sh — run one or more scripts/proxmox-node/*.sh stages on a
# Proxmox node over a single SSH connection, without needing a clone of this
# repo on that Proxmox node. Runs on the control node.
#
# Bundles scripts/lib/*.sh (except common.sh, which only sources files that
# won't exist remotely), every requested stage, and every config file in
# config/proxmox-nodes/ into one script. The bundle is compressed and sent in
# one `ssh -t` command, so there is one login and one set of prompts per run.
# The Proxmox node picks the config file matching its own `hostname -f`.
# Nothing is written to the Proxmox node's filesystem by this step (the
# stages themselves may write backups/logs/locks as part of their own work).
#
# Each stage runs in its own subshell, so the `exit` at the end of a stage
# ends only that stage. The run stops at the first stage that exits non-zero
# and reports which stages finished, which stopped and which were not run.
# Stages never reboot the node; those that need a reboot call
# log::reboot_required, and the run ends with a "reboot required" summary.
#
# Run with --help for the options and exit status.
#
# Examples:
#   scripts/remote-run.sh root@192.168.88.101 networking.sh -- --dry-run
#   scripts/remote-run.sh root@192.168.88.101 all -- --yes
#
# See scripts/README.md for background and the fallback (copy-then-run)
# approach if you need to debug on the Proxmox node directly.

set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${_script_dir}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage:
  remote-run.sh <user@host> <stage>... | all [-- <stage-args>...]
  remote-run.sh --help

  <stage>        File name in scripts/proxmox-node/, e.g. networking.sh
  all            Every stage (*.sh), in name order
  <stage-args>   Passed to every stage (--config, --dry-run, --yes)
  -h, --help     Show this help

Exit status:
  0  Every stage finished, or --help
  1  A stage failed or was declined, or ssh failed
  2  Usage error
EOF
}

# resolve_stages <name...>
# Prints one stage file name per line. Expands "all". Dies, before anything
# is sent, if a name is not a file in scripts/proxmox-node/.
resolve_stages() {
  local name path
  for name in "$@"; do
    if [[ "${name}" == "all" ]]; then
      for path in "${_script_dir}"/proxmox-node/*.sh; do
        basename "${path}"
      done
      continue
    fi
    path="${_script_dir}/proxmox-node/${name}"
    if [[ "${name}" == */* || ! -f "${path}" ]]; then
      log::die "No such Proxmox-node script: ${path}"
    fi
    printf '%s\n' "${name}"
  done
}

# runner_source
# Prints the code that runs on the Proxmox node after all stages are defined
# as serverlab_stage_<n> functions and serverlab_names holds their names.
# Its "$@" are the stage arguments.
runner_source() {
  cat <<'EOF'
serverlab_reminder="${SERVERLAB_REBOOT_FILE:-/run/serverlab/reboot-required}"
serverlab_finished=()
serverlab_skipped=()
serverlab_stopped=""
serverlab_stopped_rc=0

if [[ -s "${serverlab_reminder}" ]]; then
  log::warn "Reboot still pending from an earlier run:"
  sed 's/^/[WARN]    /' "${serverlab_reminder}" >&2
fi

# No `set -e` and no `if`/`||` around the stage call: errexit must stay
# active inside the stage's subshell.
for serverlab_i in "${!serverlab_names[@]}"; do
  serverlab_name="${serverlab_names[serverlab_i]}"
  if [[ -n "${serverlab_stopped}" ]]; then
    serverlab_skipped+=("${serverlab_name}")
    continue
  fi
  log::info "=== Stage ${serverlab_name} ==="
  export SERVERLAB_STAGE="${serverlab_name}"
  "serverlab_stage_${serverlab_i}" "$@"
  serverlab_rc=$?
  if [[ "${serverlab_rc}" -eq 0 ]]; then
    serverlab_finished+=("${serverlab_name}")
  else
    serverlab_stopped="${serverlab_name}"
    serverlab_stopped_rc="${serverlab_rc}"
  fi
done
unset SERVERLAB_STAGE

log::info "=== Summary ==="
log::info "Finished: ${serverlab_finished[*]:-none}"
if [[ -n "${serverlab_stopped}" ]]; then
  log::error "Stopped:  ${serverlab_stopped}" \
    "(exit ${serverlab_stopped_rc})"
fi
log::info "Not run:  ${serverlab_skipped[*]:-none}"
if [[ -s "${serverlab_reminder}" ]]; then
  log::warn "REBOOT REQUIRED — the administrator must reboot this node:"
  sed 's/^/[WARN]    /' "${serverlab_reminder}" >&2
else
  log::info "No reboot required."
fi
if [[ -n "${serverlab_stopped}" ]]; then
  exit 1
fi
exit 0
EOF
}

# config_source
# Prints code that exports the config file matching the Proxmox node's own
# `hostname -f`, or dies if there is none.
config_source() {
  local config_path host
  local export_re='s/^\([A-Za-z_][A-Za-z0-9_]*=\)/export \1/'

  cat <<'EOF'
serverlab_host="$(hostname -f)"
case "${serverlab_host}" in
EOF
  for config_path in "${_script_dir}"/../config/proxmox-nodes/*.env; do
    [[ -f "${config_path}" ]] || continue
    host="$(basename "${config_path}" .env)"
    printf '%q)\n' "${host}"
    # Exported so config::require sees the values without config::load
    # needing to read a file that doesn't exist on the Proxmox node.
    sed "${export_re}" "${config_path}"
    printf '\n;;\n'
  done
  cat <<'EOF'
*)
  log::die "No config file for Proxmox node '${serverlab_host}'"
  ;;
esac
EOF
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    return 0
  fi
  if [[ $# -lt 2 ]]; then
    usage >&2
    return 2
  fi

  local target="$1"
  shift

  local names=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    names+=("$1")
    shift
  done
  if [[ ${#names[@]} -lt 1 ]]; then
    usage >&2
    return 2
  fi
  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  # Check every name before connecting.
  # Command substitution (not process substitution) so a bad name stops
  # the run under errexit.
  local resolved stages=()
  resolved="$(resolve_stages "${names[@]}")"
  mapfile -t stages <<<"${resolved}"
  [[ ${#stages[@]} -ge 1 ]] || log::die "No stages to run."

  log::info "Bundling scripts/lib/*.sh (except common.sh)" \
    "+ config files + ${stages[*]}..."

  local bundle="export SERVERLAB_BUNDLED=1"$'\n'
  local lib_file
  for lib_file in "${_script_dir}"/lib/*.sh; do
    [[ "$(basename "${lib_file}")" == "common.sh" ]] && continue
    bundle+="$(cat "${lib_file}")"$'\n'
  done
  bundle+="$(config_source)"$'\n'

  local i name
  bundle+="serverlab_names=("
  for name in "${stages[@]}"; do
    bundle+="$(printf '%q' "${name}") "
  done
  bundle+=")"$'\n'
  for i in "${!stages[@]}"; do
    bundle+="serverlab_stage_${i}() {"$'\n'
    bundle+="("$'\n'
    bundle+="$(cat "${_script_dir}/proxmox-node/${stages[i]}")"$'\n'
    bundle+=")"$'\n'
    bundle+="}"$'\n'
  done
  bundle+="$(runner_source)"

  # Compressed so the single command argument stays far below the Linux
  # limit of 128 KiB. The remote shell decodes it; ssh -t keeps the
  # terminal, so prompts still work.
  local payload
  payload="$(printf '%s' "${bundle}" | gzip -9 | base64 -w0)"

  local remote_cmd
  remote_cmd="bash -c \"\$(printf %s ${payload} | base64 -d | gzip -dc)\""
  remote_cmd+=" serverlab-run"
  local arg
  for arg in "$@"; do
    remote_cmd+=" $(printf '%q' "${arg}")"
  done

  log::info "If the connection drops (a network change reloads" \
    "interfaces), reconnect and re-run the same command."
  log::info "Running ${stages[*]} on ${target}..."
  ssh -t "${target}" "${remote_cmd}"
}

main "$@"
