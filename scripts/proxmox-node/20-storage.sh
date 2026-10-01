#!/usr/bin/env bash
#
# 20-storage.sh — Proxmox-node storage configuration, per
# docs/design/04-storage.md. Currently: creates a btrfs partition
# ("local-data") in whatever free space remains on the OS NVMe, registers
# it as a Proxmox storage holding all content types, and disables the
# OS-disk storages (local, local-btrfs) so guest content only lands on
# local-data.
#
# This script only ever creates a new partition in unused space — it never
# touches existing partitions or their data.
#
# Usage:
#   20-storage.sh [--config <file>] [--dry-run] [--yes]
#
#   --config <file>  Path to a Proxmox-node config file (default:
#                     config/proxmox-nodes/$(hostname -f).env;
#                     see config/README.md)
#   --dry-run        Show what would change; make no changes
#   --yes            Skip the confirmation prompt (for non-interactive runs,
#                     e.g. over `remote-run.sh`)
#
# On failure after the apply step starts, this script stops and prints the
# manual undo steps rather than rolling back automatically — see
# docs/decisions/0003-proxmox-node-script-structure-and-conventions.md.
#
# See scripts/README.md for the phase structure this script follows.

set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
if [[ -z "${SERVERLAB_BUNDLED:-}" ]]; then
	# shellcheck source=scripts/lib/common.sh
	source "${_script_dir}/lib/common.sh"
fi

readonly FSTAB_FILE="/etc/fstab"
readonly LOCK_FILE="/run/serverlab/20-storage.lock"

dry_run=false
auto_yes=""
config_file=""

disk=""
sector_size=""
align_sectors=""
part_num=""
part_path=""
first_sector=""
last_sector=""
size_bytes=""
gpt_backup_path=""
fstab_backup_path=""
disable_only=false
pending_storages=""

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

preflight() {
	log::info "Checking current storage state..."

	local mounted=false
	local registered=false

	if findmnt -no SOURCE "${LOCAL_DATA_MOUNTPOINT}" >/dev/null 2>&1; then
		mounted=true
	fi
	if pvesm status --storage "${LOCAL_DATA_STORAGE_ID}" >/dev/null 2>&1; then
		registered=true
	fi

	if [[ "${mounted}" == true && "${registered}" == true ]]; then
		local pending=""
		local os_storage
		for os_storage in ${OS_STORAGES}; do
			if ! pve::storage_disabled "${os_storage}"; then
				pending="${pending} ${os_storage}"
			fi
		done
		pending="${pending# }"

		if [[ -z "${pending}" ]]; then
			log::info "${LOCAL_DATA_STORAGE_ID} is already mounted at" \
				"${LOCAL_DATA_MOUNTPOINT} and registered, and all OS" \
				"storages are disabled — nothing to do."
			exit 0
		fi

		disable_only=true
		pending_storages="${pending}"
		log::info "${LOCAL_DATA_STORAGE_ID} is already mounted and" \
			"registered; still need to disable:${pending}"
		return
	fi

	if [[ "${mounted}" == true || "${registered}" == true ]]; then
		log::die "${LOCAL_DATA_STORAGE_ID} setup is only partly done" \
			"(mounted: ${mounted}, registered: ${registered}) —" \
			"resolve manually before re-running."
	fi

	if [[ -n "${LOCAL_DATA_DISK:-}" ]]; then
		disk="${LOCAL_DATA_DISK}"
	else
		disk="$(disk::os_disk)"
	fi
	log::info "Target disk: ${disk}"

	sector_size="$(disk::sector_size "${disk}")"
	local alignment_offset optimal_io_size geometry_error
	alignment_offset="$(disk::alignment_offset "${disk}")"
	optimal_io_size="$(disk::optimal_io_size "${disk}")"
	if ! geometry_error="$(disk::validate_geometry \
		"${alignment_offset}" "${optimal_io_size}")"; then
		log::die "Refusing to partition ${disk}: ${geometry_error}"
	fi

	align_sectors="$(disk::align_sectors "${sector_size}")"
	part_num="$(disk::next_partnum "${disk}")"
	part_path="$(disk::partition_path "${disk}" "${part_num}")"

	read -r first_sector last_sector < <(
		disk::free_extent "${disk}" "${align_sectors}"
	)
	if [[ -z "${first_sector}" || -z "${last_sector}" ]]; then
		log::die "No free space found on ${disk}."
	fi
	last_sector="$(disk::round_down_sector "${last_sector}" "${align_sectors}")"

	size_bytes="$(disk::extent_bytes \
		"${first_sector}" "${last_sector}" "${sector_size}")"
	local min_bytes=$((LOCAL_DATA_MIN_GIB * 1073741824))
	if ((size_bytes < min_bytes)); then
		log::die "Free space on ${disk} is only" \
			"$((size_bytes / 1073741824)) GiB, below the" \
			"${LOCAL_DATA_MIN_GIB} GiB minimum (LOCAL_DATA_MIN_GIB)."
	fi

	if [[ -e "${part_path}" ]]; then
		log::die "${part_path} already exists — refusing to overwrite an" \
			"existing partition. Resolve manually."
	fi

	log::info "Pre-flight checks passed."
}

# --- Phase 3: plan / diff / confirm -----------------------------------------

plan_and_confirm() {
	log::info "Plan:"

	if [[ "${disable_only}" == true ]]; then
		log::info "  ${LOCAL_DATA_STORAGE_ID} already mounted and registered."
		log::info "  Disabling:       ${pending_storages}"

		if [[ "${dry_run}" == true ]]; then
			log::info "--dry-run: no changes were made."
			exit 0
		fi

		if ! prompt::confirm "Apply the above change now?" "${auto_yes}"; then
			log::info "Aborted by user. No changes were made."
			exit 1
		fi
		return
	fi

	log::info "  Disk:            ${disk} (sector size: ${sector_size} B)"
	log::info "  New partition:   ${part_path} (number ${part_num})"
	log::info "  Sector range:    ${first_sector}-${last_sector}" \
		"($((size_bytes / 1073741824)) GiB)"
	log::info "  Filesystem:      btrfs, label ${LOCAL_DATA_STORAGE_ID}"
	log::info "  Mountpoint:      ${LOCAL_DATA_MOUNTPOINT}" \
		"(fstab: noatime,compress=zstd:1,nofail)"
	log::info "  Proxmox storage: ${LOCAL_DATA_STORAGE_ID}" \
		"at ${LOCAL_DATA_STORAGE_PATH} (content: ${LOCAL_DATA_CONTENT})"
	log::info "  Disabling:       ${OS_STORAGES}"

	if [[ "${dry_run}" == true ]]; then
		log::info "--dry-run: no changes were made."
		exit 0
	fi

	if ! prompt::confirm "Apply the above change now?" "${auto_yes}"; then
		log::info "Aborted by user. No changes were made."
		exit 1
	fi
}

# --- Phase 4/5: backup, apply ------------------------------------------------

report_failure() {
	log::error "$* — not rolling back automatically."
	log::error "To restore the previous state by hand:"
	log::error "  sgdisk --load-backup=${gpt_backup_path} ${disk}"
	if [[ -n "${fstab_backup_path}" ]]; then
		log::error "  cp -p ${fstab_backup_path} ${FSTAB_FILE}"
	fi
	log::die "Stopped. ${LOCAL_DATA_STORAGE_ID} may be partially" \
		"configured — resolve manually (see above)."
}

apply_change() {
	if [[ "${disable_only}" == true ]]; then
		local os_storage
		for os_storage in ${pending_storages}; do
			log::info "Disabling ${os_storage}..."
			pvesm set "${os_storage}" --disable 1 ||
				report_failure "pvesm set --disable failed for" \
					"${os_storage}"
		done
		verify_change
		return
	fi

	local timestamp
	timestamp="$(date +%Y%m%d%H%M%S)"
	gpt_backup_path="/root/$(basename "${disk}")-gpt.${timestamp}"
	sgdisk --backup="${gpt_backup_path}" "${disk}"
	log::info "Backed up ${disk}'s partition table to ${gpt_backup_path}"

	log::info "Creating partition ${part_num} (${part_path})..."
	if ! sgdisk -a "${align_sectors}" \
		-n "${part_num}:${first_sector}:${last_sector}" \
		-t "${part_num}:8300" \
		-c "${part_num}:${LOCAL_DATA_STORAGE_ID}" \
		"${disk}"; then
		report_failure "sgdisk failed to create the partition"
	fi

	log::info "Loading the new partition (partx)..."
	if ! partx -a --nr "${part_num}" "${disk}"; then
		report_failure "partx failed to load the new partition"
	fi
	udevadm settle

	log::info "Creating the btrfs filesystem on ${part_path}..."
	if ! mkfs.btrfs -L "${LOCAL_DATA_STORAGE_ID}" "${part_path}"; then
		report_failure "mkfs.btrfs failed"
	fi

	local uuid
	uuid="$(blkid -s UUID -o value "${part_path}")"
	if [[ -z "${uuid}" ]]; then
		report_failure "Could not read the new filesystem's UUID"
	fi

	fstab_backup_path="$(files::backup "${FSTAB_FILE}")"
	log::info "Backed up ${FSTAB_FILE} to ${fstab_backup_path}"

	if ! grep -q "${uuid}" "${FSTAB_FILE}"; then
		local fstab_entry="UUID=${uuid} ${LOCAL_DATA_MOUNTPOINT} btrfs"
		fstab_entry+=" defaults,noatime,compress=zstd:1,nofail 0 0"
		echo "${fstab_entry}" >>"${FSTAB_FILE}"
		if ! systemctl daemon-reload; then
			report_failure "systemctl daemon-reload failed after" \
				"updating ${FSTAB_FILE}"
		fi
	fi

	mkdir -p "${LOCAL_DATA_MOUNTPOINT}"
	if ! findmnt -no SOURCE "${LOCAL_DATA_MOUNTPOINT}" >/dev/null 2>&1; then
		if ! mount "${LOCAL_DATA_MOUNTPOINT}"; then
			report_failure "mount failed"
		fi
	fi

	mkdir -p "${LOCAL_DATA_STORAGE_PATH}"

	log::info "Registering ${LOCAL_DATA_STORAGE_ID} with Proxmox..."
	if ! pvesm add btrfs "${LOCAL_DATA_STORAGE_ID}" \
		--path "${LOCAL_DATA_STORAGE_PATH}" \
		--is_mountpoint "${LOCAL_DATA_MOUNTPOINT}" \
		--content "${LOCAL_DATA_CONTENT}"; then
		report_failure "pvesm add failed"
	fi

	local os_storage
	for os_storage in ${OS_STORAGES}; do
		log::info "Disabling ${os_storage}..."
		pvesm set "${os_storage}" --disable 1 ||
			report_failure "pvesm set --disable failed for ${os_storage}"
	done

	verify_change
}

# --- Phase 6: post-verify ---------------------------------------------------

verify_change() {
	log::info "Verifying..."

	if ! findmnt -no SOURCE "${LOCAL_DATA_MOUNTPOINT}" >/dev/null 2>&1; then
		report_failure "${LOCAL_DATA_MOUNTPOINT} is not mounted"
	fi

	if ! pvesm status --storage "${LOCAL_DATA_STORAGE_ID}" >/dev/null 2>&1; then
		report_failure "${LOCAL_DATA_STORAGE_ID} is not registered with Proxmox"
	fi

	local os_storage
	for os_storage in ${OS_STORAGES}; do
		if ! pve::storage_disabled "${os_storage}"; then
			report_failure "${os_storage} is not disabled"
		fi
	done

	log::info "Verified: ${LOCAL_DATA_MOUNTPOINT} is mounted," \
		"${LOCAL_DATA_STORAGE_ID} is registered, and OS storages" \
		"(${OS_STORAGES}) are disabled."
}

# --- Phase 7: summary ---------------------------------------------------------

main() {
	parse_args "$@"

	guards::require_root
	guards::require_proxmox
	guards::require_cmd sgdisk partx mkfs.btrfs blkid findmnt pvesm \
		udevadm systemctl
	guards::acquire_lock "${LOCK_FILE}"

	if [[ -z "${SERVERLAB_BUNDLED:-}" ]]; then
		config::load "${config_file}"
	fi
	config::require LOCAL_DATA_STORAGE_ID LOCAL_DATA_MOUNTPOINT \
		LOCAL_DATA_STORAGE_PATH LOCAL_DATA_CONTENT LOCAL_DATA_MIN_GIB \
		OS_STORAGES

	preflight
	plan_and_confirm
	apply_change

	if [[ "${disable_only}" == true ]]; then
		log::info "Done. ${LOCAL_DATA_STORAGE_ID} OS storages" \
			"(${OS_STORAGES}) are now disabled."
	else
		log::info "Done. ${LOCAL_DATA_STORAGE_ID} (${part_path} at" \
			"${LOCAL_DATA_STORAGE_PATH}, mounted at" \
			"${LOCAL_DATA_MOUNTPOINT}) is configured and verified."
		log::info "GPT backup: ${gpt_backup_path}"
		log::info "fstab backup: ${fstab_backup_path}"
	fi
	log::info "No reboot required."
}

main "$@"
