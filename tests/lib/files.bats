#!/usr/bin/env bats
#
# files.bats — tests for the backup pruning in scripts/lib/files.sh

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	source "${LIB_DIR}/files.sh"
	target="${BATS_TEST_TMPDIR}/interfaces"
	printf 'current\n' >"${target}"
}

@test "files::prune_backups keeps the newest N backups of the file" {
	for ts in 20260101000001 20260101000002 20260101000003 20260101000004; do
		printf 'x\n' >"${target}.bak.${ts}"
	done
	SERVERLAB_BACKUP_KEEP=2 files::prune_backups "${target}"
	[ ! -e "${target}.bak.20260101000001" ]
	[ ! -e "${target}.bak.20260101000002" ]
	[ -e "${target}.bak.20260101000003" ]
	[ -e "${target}.bak.20260101000004" ]
}

@test "files::prune_backups leaves other files and the original alone" {
	printf 'x\n' >"${target}.bak.20260101000001"
	printf 'x\n' >"${BATS_TEST_TMPDIR}/other.bak.20250101000001"
	printf 'x\n' >"${target}.orig"
	SERVERLAB_BACKUP_KEEP=1 files::prune_backups "${target}"
	[ -e "${target}" ]
	[ -e "${target}.orig" ]
	[ -e "${BATS_TEST_TMPDIR}/other.bak.20250101000001" ]
	[ -e "${target}.bak.20260101000001" ]
}

@test "files::prune_backups falls back to 5 for an invalid keep value" {
	for n in 1 2 3 4 5 6 7; do
		printf 'x\n' >"${target}.bak.2026010100000${n}"
	done
	SERVERLAB_BACKUP_KEEP=abc files::prune_backups "${target}"
	[ ! -e "${target}.bak.20260101000002" ]
	[ -e "${target}.bak.20260101000003" ]
	[ -e "${target}.bak.20260101000007" ]
}

@test "files::backup creates a backup, prints its path and prunes" {
	for ts in 20260101000001 20260101000002; do
		printf 'x\n' >"${target}.bak.${ts}"
	done
	SERVERLAB_BACKUP_KEEP=2 run files::backup "${target}"
	[ "$status" -eq 0 ]
	[[ "${output}" == "${target}.bak."* ]]
	[ -e "${output}" ]
	[ "$(<"${output}")" == "current" ]
	[ ! -e "${target}.bak.20260101000001" ]
	[ -e "${target}.bak.20260101000002" ]
}

@test "files::backup returns 1 and prints nothing for a missing file" {
	run files::backup "${BATS_TEST_TMPDIR}/missing"
	[ "$status" -eq 1 ]
	[ -z "${output}" ]
}
