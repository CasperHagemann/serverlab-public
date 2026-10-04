#!/usr/bin/env bash
#
# 05-proxmox-install.sh — Proxmox-node post-install configuration, per
# docs/design/02-proxmox-install.md. Currently: NTP (chrony) servers.
#
# NTP_SERVERS (array in the node config) is the exact set of time servers the
# node uses; the default chrony pool/server lines are disabled. An empty
# array reverts to the OS default chrony configuration, which is kept in
# /etc/chrony/chrony.conf.orig the first time this script changes anything.
#
# Usage:
#   05-proxmox-install.sh [--config <file>] [--dry-run] [--yes]
#
#   --config <file>  Path to a Proxmox-node config file (default:
#                     config/proxmox-nodes/$(hostname -f).env;
#                     see config/README.md)
#   --dry-run        Show what would change; make no changes
#   --yes            Skip the confirmation prompt (for non-interactive runs,
#                     e.g. over `remote-run.sh`)
#
# See scripts/README.md for the phase structure this script follows, and
# docs/decisions/0003-proxmox-node-script-structure-and-conventions.md for the
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
readonly LOCK_FILE="/run/serverlab/05-proxmox-install.lock"

dry_run=false
auto_yes=""
config_file=""
tmp_dir=""
new_conf=""
new_sources=""
conf_changed=false
sources_changed=false
backup_conf=""
backup_sources=""

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
		*)
			log::die "Unknown argument: $1"
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

preflight() {
	log::info "Checking current NTP (chrony) state..."

	if [[ ! -f "${CHRONY_CONF}" ]]; then
		log::die "${CHRONY_CONF} not found — chrony does not appear to be" \
			"installed."
	fi

	if [[ "${#NTP_SERVERS[@]}" -gt 0 ]]; then
		local base
		base="$(ntp_base_conf)"
		if ! ntp::has_sourcedir "${base}" "${CHRONY_SOURCES_DIR}"; then
			log::die "${base} has no 'sourcedir ${CHRONY_SOURCES_DIR}'" \
				"line — refusing to guess how to add the NTP servers."
		fi
	fi

	log::info "Pre-flight checks passed."
}

# --- Phase 3: plan / diff / confirm -----------------------------------------

plan_and_confirm() {
	local base
	base="$(ntp_base_conf)"
	tmp_dir="$(mktemp -d)"
	new_conf="${tmp_dir}/chrony.conf"
	new_sources="${tmp_dir}/ntp-servers.sources"

	if [[ "${#NTP_SERVERS[@]}" -gt 0 ]]; then
		log::info "Staging: use only these NTP servers: ${NTP_SERVERS[*]}"
		ntp::disable_default_sources "${base}" >"${new_conf}"
		ntp::render_sources "${NTP_SERVERS[@]}" >"${new_sources}"
	else
		log::info "Staging: revert to the OS default NTP configuration."
		cat "${base}" >"${new_conf}"
		: >"${new_sources}"
	fi

	if ! cmp -s "${CHRONY_CONF}" "${new_conf}"; then
		conf_changed=true
		log::info "Staged diff (${CHRONY_CONF}):"
		files::diff "${CHRONY_CONF}" "${new_conf}" >&2
	fi

	if [[ "${#NTP_SERVERS[@]}" -gt 0 ]]; then
		if [[ ! -e "${CHRONY_SOURCES}" ]] ||
			! cmp -s "${CHRONY_SOURCES}" "${new_sources}"; then
			sources_changed=true
			log::info "Staged diff (${CHRONY_SOURCES}):"
			if [[ -e "${CHRONY_SOURCES}" ]]; then
				files::diff "${CHRONY_SOURCES}" "${new_sources}" >&2
			else
				files::diff /dev/null "${new_sources}" >&2
			fi
		fi
	elif [[ -e "${CHRONY_SOURCES}" ]]; then
		sources_changed=true
		log::info "Staged: remove ${CHRONY_SOURCES}"
	fi

	if [[ "${conf_changed}" == false && "${sources_changed}" == false ]]; then
		log::info "NTP configuration already matches — nothing to do."
		exit 0
	fi

	if [[ "${dry_run}" == true ]]; then
		log::info "--dry-run: no changes were applied."
		exit 0
	fi

	if ! prompt::confirm "Apply the above change now?" "${auto_yes}"; then
		log::info "Aborted by user (no changes were applied)."
		exit 1
	fi
}

# --- Phase 4/5: backup, apply ------------------------------------------------

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

apply_change() {
	backup_conf="$(files::backup "${CHRONY_CONF}")"
	log::info "Backed up ${CHRONY_CONF} to ${backup_conf}"
	backup_sources="$(files::backup "${CHRONY_SOURCES}" || true)"
	if [[ -n "${backup_sources}" ]]; then
		log::info "Backed up ${CHRONY_SOURCES} to ${backup_sources}"
	fi

	if [[ ! -e "${CHRONY_ORIG}" && "${#NTP_SERVERS[@]}" -gt 0 ]]; then
		cp -p "${CHRONY_CONF}" "${CHRONY_ORIG}"
		log::info "Saved the OS default configuration as ${CHRONY_ORIG}"
	fi

	guards::ignore_hangup
	log::info "Applying..."

	if [[ "${conf_changed}" == true ]]; then
		install -m 644 "${new_conf}" "${CHRONY_CONF}" ||
			report_failure "Writing ${CHRONY_CONF} failed"
	fi

	if [[ "${#NTP_SERVERS[@]}" -gt 0 ]]; then
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

	if [[ "${#NTP_SERVERS[@]}" -gt 0 ]]; then
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
	local expected="${#NTP_SERVERS[@]}"
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
	guards::require_cmd chronyc systemctl
	guards::acquire_lock "${LOCK_FILE}"

	if [[ -z "${SERVERLAB_BUNDLED:-}" ]]; then
		config::load "${config_file}"
	fi
	config::require_array NTP_SERVERS

	preflight
	plan_and_confirm
	apply_change

	log::info "Done. NTP is configured and verified."
	log::info "Backup: ${backup_conf}"
	log::info "No reboot required."
}

main "$@"
