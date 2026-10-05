#!/usr/bin/env bats
#
# log.bats — tests for scripts/lib/log.sh

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	source "${LIB_DIR}/log.sh"
	export SERVERLAB_REBOOT_FILE="${BATS_TEST_TMPDIR}/run/reboot-required"
	unset SERVERLAB_STAGE
}

@test "log::reboot_required warns and records the reason" {
	run log::reboot_required "new kernel"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Reboot required: new kernel"* ]]
	[ "$(cat "${SERVERLAB_REBOOT_FILE}")" == "new kernel" ]
}

@test "log::reboot_required prefixes the stage name when known" {
	SERVERLAB_STAGE="05-proxmox-install.sh" log::reboot_required "new kernel" 2>/dev/null
	[ "$(cat "${SERVERLAB_REBOOT_FILE}")" == "05-proxmox-install.sh: new kernel" ]
}

@test "log::reboot_required does not record the same reason twice" {
	log::reboot_required "new kernel" 2>/dev/null
	log::reboot_required "new kernel" 2>/dev/null
	[ "$(wc -l <"${SERVERLAB_REBOOT_FILE}")" -eq 1 ]
}

@test "log::reboot_required keeps different reasons" {
	log::reboot_required "new kernel" 2>/dev/null
	log::reboot_required "cgroup change" 2>/dev/null
	[ "$(wc -l <"${SERVERLAB_REBOOT_FILE}")" -eq 2 ]
}

@test "log::reboot_required succeeds even if the file cannot be written" {
	export SERVERLAB_REBOOT_FILE="/proc/nope/reboot-required"
	run log::reboot_required "new kernel"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Could not record"* ]]
}
