#!/usr/bin/env bash
#
# 05-proxmox-install.sh — Proxmox-node post-install configuration, per
# docs/design/02-proxmox-install.md. Currently: time zone and NTP (chrony).
#
# TIMEZONE (node config) is the IANA zone name to set. An empty value reverts
# to the zone saved in /etc/timezone.orig before the first change.
#
# NTP_SERVERS (array in the node config) is the exact set of time servers the
# node uses; the default chrony pool/server lines are disabled. An empty
# array reverts to the OS default chrony configuration, which is kept in
# /etc/chrony/chrony.conf.orig the first time this script changes anything.
#
# Each step shows its plan; one confirmation covers all steps with changes.
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
readonly TZ_ORIG="/etc/timezone.orig"
readonly LOCK_FILE="/run/serverlab/05-proxmox-install.lock"

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

ntp_preflight() {
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
}

# The zone to set: the configured one, or (empty config) the saved original.
# Empty tz_target means there is nothing to set or revert to.
tz_resolve_target() {
	tz_current="$(timedatectl show -p Timezone --value)"
	if [[ -n "${TIMEZONE}" ]]; then
		tz_target="${TIMEZONE}"
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

preflight() {
	log::info "Checking current time zone and NTP (chrony) state..."
	tz_preflight
	ntp_preflight
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

	if [[ "${#NTP_SERVERS[@]}" -gt 0 ]]; then
		ntp::disable_default_sources "${base}" >"${new_conf}"
		ntp::render_sources "${NTP_SERVERS[@]}" >"${new_sources}"
	else
		cat "${base}" >"${new_conf}"
		: >"${new_sources}"
	fi

	if ! cmp -s "${CHRONY_CONF}" "${new_conf}"; then
		conf_changed=true
	fi

	if [[ "${#NTP_SERVERS[@]}" -gt 0 ]]; then
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

	if [[ "${#NTP_SERVERS[@]}" -gt 0 ]]; then
		log::info "Staging: use only these NTP servers: ${NTP_SERVERS[*]}"
	else
		log::info "Staging: revert to the OS default NTP configuration."
	fi

	if [[ "${conf_changed}" == true ]]; then
		log::info "Staged diff (${CHRONY_CONF}):"
		files::diff "${CHRONY_CONF}" "${new_conf}" >&2
	fi

	if [[ "${sources_changed}" == true ]]; then
		if [[ "${#NTP_SERVERS[@]}" -eq 0 ]]; then
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

plan_and_confirm() {
	tmp_dir="$(mktemp -d)"
	tz_plan
	ntp_plan

	if [[ "${tz_changed}" == false ]] && ! ntp_changed; then
		log::info "Nothing to do."
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

tz_report_failure() {
	log::error "$* — not rolling back automatically."
	log::error "To restore the previous time zone by hand:"
	log::error "  timedatectl set-timezone ${tz_current}"
	guards::restore_hangup
	log::die "Stopped. The time zone may be partially configured —" \
		"resolve manually (see above)."
}

tz_apply() {
	if [[ ! -e "${TZ_ORIG}" && -n "${TIMEZONE}" ]]; then
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

apply_change() {
	if [[ "${tz_changed}" == true ]]; then
		tz_apply
	fi
	if ntp_changed; then
		ntp_apply
	fi
}

ntp_apply() {
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
	guards::require_cmd chronyc systemctl timedatectl
	guards::acquire_lock "${LOCK_FILE}"

	if [[ -z "${SERVERLAB_BUNDLED:-}" ]]; then
		config::load "${config_file}"
	fi
	config::require_declared TIMEZONE
	config::require_array NTP_SERVERS

	preflight
	plan_and_confirm
	apply_change

	log::info "Done. Time zone and NTP are configured and verified."
	if [[ -n "${backup_conf}" ]]; then
		log::info "Backup: ${backup_conf}"
	fi
	log::info "No reboot required."
}

main "$@"
