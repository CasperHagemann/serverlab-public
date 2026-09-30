#!/usr/bin/env bash
#
# remote-run.sh — run a scripts/host/*.sh script on a remote Proxmox host
# over SSH, without needing a clone of this repo on that host.
#
# Bundles scripts/lib/*.sh (except common.sh, which only sources files that
# won't exist remotely) and the target script, plus the config file matching
# the remote host's own hostname, into a single shell command run via
# `ssh -t ... bash -c '<bundle>' <script-name> <args>`. Nothing is written to
# the remote host's filesystem by this step (the target script itself may
# write backups/logs as part of its own work).
#
# Usage:
#   scripts/remote-run.sh <user@host> <host-script> [-- <script-args>...]
#
# Example:
#   scripts/remote-run.sh root@192.168.88.101 10-network.sh -- --dry-run
#
# See scripts/README.md for background and the fallback (copy-then-run)
# approach if you need to debug on the host directly.

set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${_script_dir}/lib/common.sh"

usage() {
	log::error "Usage: $(basename "${BASH_SOURCE[0]}") <user@host> <host-script> [-- <script-args>...]"
	exit 1
}

main() {
	[[ $# -ge 2 ]] || usage

	local target="$1"
	local script_name="$2"
	shift 2

	if [[ "${1:-}" == "--" ]]; then
		shift
	fi

	local script_path="${_script_dir}/host/${script_name}"
	if [[ ! -f "${script_path}" ]]; then
		log::die "No such host script: ${script_path}"
	fi

	log::info "Resolving remote hostname..."
	local remote_host
	remote_host="$(ssh "${target}" hostname -f)"

	local config_path="${_script_dir}/../config/hosts/${remote_host}.env"
	if [[ ! -f "${config_path}" ]]; then
		log::die "No config file for remote host '${remote_host}': ${config_path}"
	fi

	log::info "Bundling scripts/lib/*.sh (except common.sh) + ${script_name} + ${remote_host}.env..."

	local bundle="export SERVERLAB_BUNDLED=1"$'\n'
	local lib_file
	for lib_file in "${_script_dir}"/lib/*.sh; do
		[[ "$(basename "${lib_file}")" == "common.sh" ]] && continue
		bundle+="$(cat "${lib_file}")"$'\n'
	done
	# Exported so config::require sees the values without config::load
	# needing to read a file that doesn't exist on the remote host.
	bundle+="$(sed 's/^\([A-Za-z_][A-Za-z0-9_]*=\)/export \1/' "${config_path}")"$'\n'
	bundle+="$(cat "${script_path}")"

	log::info "Running ${script_name} on ${target} (${remote_host})..."
	ssh -t "${target}" bash -c "${bundle@Q}" "${script_name}" "$@"
}

main "$@"
