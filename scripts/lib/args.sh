#!/usr/bin/env bash
#
# args.sh — command-line helpers. Functions only.
[[ -n "${SERVERLAB_LIB_ARGS:-}" ]] && return 0
readonly SERVERLAB_LIB_ARGS=1

# args::usage <script-name>
# Prints the usage text shared by all Proxmox-node scripts to stdout.
# Callers redirect to stderr (>&2) when reporting a usage error.
args::usage() {
  local name="$1"

  cat <<USAGE
Usage: ${name} [--config <file>] [--dry-run] [--yes] [--help]

  --config <file>   Path to a Proxmox-node config file (default:
                    config/proxmox-nodes/\$(hostname -f).env;
                    see config/README.md)
  --dry-run         Show what would change; make no changes
  --yes             Skip the confirmation prompt (for non-interactive runs,
                    e.g. over remote-run.sh)
  -h, --help        Show this help

Exit status:
  0  Applied, nothing to do, --dry-run or --help
  1  Failure
  2  Usage error
  3  Declined at the confirmation prompt
USAGE
}
