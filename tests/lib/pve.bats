#!/usr/bin/env bats
#
# pve.bats — tests for scripts/lib/pve.sh, using a stub `pvesh` (see
# tests/fixtures/bin/pvesh) so these run without a real Proxmox host.
#
# Only pve::wait_task is covered — it has real logic (polling, output
# parsing, timeout). The other functions are thin pass-through wrappers
# around pvesh and aren't worth testing separately.

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	FIXTURES_BIN="${BATS_TEST_DIRNAME}/../fixtures/bin"
	PATH="${FIXTURES_BIN}:${PATH}"
	source "${LIB_DIR}/log.sh"
	source "${LIB_DIR}/pve.sh"
	unset PVESH_STUB_TASK PVESH_STUB_SET_FAIL PVESH_STUB_STATE_FILE
	unset PVESM_STUB_STATUS PVESM_STUB_KNOWN_ID
}

@test "pve::wait_task succeeds immediately when the task is already stopped OK" {
	export PVESH_STUB_TASK=ok
	run pve::wait_task "UPID:pve:test::"
	[ "$status" -eq 0 ]
}

@test "pve::wait_task fails when the task stops with a non-OK exitstatus" {
	export PVESH_STUB_TASK=fail
	run pve::wait_task "UPID:pve:test::"
	[ "$status" -eq 1 ]
}

@test "pve::wait_task polls until a task transitions from running to stopped" {
	export PVESH_STUB_TASK=running-then-ok
	export PVESH_STUB_STATE_FILE="${BATS_TEST_TMPDIR}/task-state"
	run pve::wait_task "UPID:pve:test::"
	[ "$status" -eq 0 ]
}

@test "pve::wait_task fails after timing out on a task that never stops" {
	export PVESH_STUB_TASK=hang
	run pve::wait_task "UPID:pve:test::" 2
	[ "$status" -eq 1 ]
}

@test "pve::storage_disabled returns success for a disabled storage" {
	export PVESM_STUB_KNOWN_ID=local
	export PVESM_STUB_STATUS=disabled
	run pve::storage_disabled local
	[ "$status" -eq 0 ]
}

@test "pve::storage_disabled returns failure for an active storage" {
	export PVESM_STUB_KNOWN_ID=local
	export PVESM_STUB_STATUS=active
	run pve::storage_disabled local
	[ "$status" -eq 1 ]
}

@test "pve::storage_disabled returns failure for an unknown storage id" {
	export PVESM_STUB_KNOWN_ID=local
	export PVESM_STUB_STATUS=disabled
	run pve::storage_disabled nonexistent
	[ "$status" -eq 1 ]
}
