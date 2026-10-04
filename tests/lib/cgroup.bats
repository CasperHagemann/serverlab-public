#!/usr/bin/env bats
#
# cgroup.bats — tests for scripts/lib/cgroup.sh

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	source "${LIB_DIR}/cgroup.sh"
}

@test "cgroup::valid_weight accepts 1 to 10000" {
	run cgroup::valid_weight 1
	[ "$status" -eq 0 ]
	run cgroup::valid_weight 1000
	[ "$status" -eq 0 ]
	run cgroup::valid_weight 10000
	[ "$status" -eq 0 ]
}

@test "cgroup::valid_weight rejects 0, 10001, empty and non-numbers" {
	run cgroup::valid_weight 0
	[ "$status" -ne 0 ]
	run cgroup::valid_weight 10001
	[ "$status" -ne 0 ]
	run cgroup::valid_weight ""
	[ "$status" -ne 0 ]
	run cgroup::valid_weight 12a
	[ "$status" -ne 0 ]
	run cgroup::valid_weight 0100
	[ "$status" -ne 0 ]
}

@test "cgroup::valid_memory accepts bytes and K M G T suffixes" {
	run cgroup::valid_memory 4G
	[ "$status" -eq 0 ]
	run cgroup::valid_memory 512M
	[ "$status" -eq 0 ]
	run cgroup::valid_memory 4096
	[ "$status" -eq 0 ]
}

@test "cgroup::valid_memory rejects zero, empty, decimals and odd suffixes" {
	run cgroup::valid_memory 0
	[ "$status" -ne 0 ]
	run cgroup::valid_memory ""
	[ "$status" -ne 0 ]
	run cgroup::valid_memory 1.5G
	[ "$status" -ne 0 ]
	run cgroup::valid_memory 4GB
	[ "$status" -ne 0 ]
	run cgroup::valid_memory G
	[ "$status" -ne 0 ]
}

@test "cgroup::valid_scheduler accepts known schedulers only" {
	run cgroup::valid_scheduler bfq
	[ "$status" -eq 0 ]
	run cgroup::valid_scheduler none
	[ "$status" -eq 0 ]
	run cgroup::valid_scheduler cfq
	[ "$status" -ne 0 ]
	run cgroup::valid_scheduler ""
	[ "$status" -ne 0 ]
}

@test "cgroup::memory_bytes converts suffixes (powers of 1024)" {
	run cgroup::memory_bytes 4G
	[ "$output" == "4294967296" ]
	run cgroup::memory_bytes 512M
	[ "$output" == "536870912" ]
	run cgroup::memory_bytes 2K
	[ "$output" == "2048" ]
	run cgroup::memory_bytes 1T
	[ "$output" == "1099511627776" ]
	run cgroup::memory_bytes 4096
	[ "$output" == "4096" ]
}

@test "cgroup::bfq_weight maps IOWeight to the io.bfq.weight systemd writes" {
	run cgroup::bfq_weight 1
	[ "$output" == "1" ]
	run cgroup::bfq_weight 50
	[ "$output" == "50" ]
	run cgroup::bfq_weight 100
	[ "$output" == "100" ]
	run cgroup::bfq_weight 1000
	[ "$output" == "181" ]
	run cgroup::bfq_weight 10000
	[ "$output" == "1000" ]
}

@test "cgroup::render_dropin prints all three settings" {
	run cgroup::render_dropin 1000 10000 4G
	[ "$status" -eq 0 ]
	[ "${lines[1]}" == "[Slice]" ]
	[ "${lines[2]}" == "CPUWeight=1000" ]
	[ "${lines[3]}" == "IOWeight=10000" ]
	[ "${lines[4]}" == "MemoryLow=4G" ]
}

@test "cgroup::render_dropin leaves out empty settings" {
	run cgroup::render_dropin "" 10000 ""
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -eq 3 ]
	[ "${lines[2]}" == "IOWeight=10000" ]
}

@test "cgroup::render_dropin prints nothing when all settings are empty" {
	run cgroup::render_dropin "" "" ""
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "cgroup::render_udev_rule targets the whole disk" {
	run cgroup::render_udev_rule nvme0n1 bfq
	[ "$status" -eq 0 ]
	[ "${lines[1]}" == 'ACTION=="add|change", KERNEL=="nvme0n1", ATTR{queue/scheduler}="bfq"' ]
}

@test "cgroup::active_scheduler prints the bracketed scheduler" {
	printf 'none mq-deadline [bfq] \n' >"${BATS_TEST_TMPDIR}/s"
	run cgroup::active_scheduler "${BATS_TEST_TMPDIR}/s"
	[ "$output" == "bfq" ]
	printf '[none] mq-deadline \n' >"${BATS_TEST_TMPDIR}/s"
	run cgroup::active_scheduler "${BATS_TEST_TMPDIR}/s"
	[ "$output" == "none" ]
}

@test "cgroup::scheduler_listed matches whole names only" {
	printf '[none] mq-deadline \n' >"${BATS_TEST_TMPDIR}/s"
	run cgroup::scheduler_listed none "${BATS_TEST_TMPDIR}/s"
	[ "$status" -eq 0 ]
	run cgroup::scheduler_listed mq-deadline "${BATS_TEST_TMPDIR}/s"
	[ "$status" -eq 0 ]
	run cgroup::scheduler_listed bfq "${BATS_TEST_TMPDIR}/s"
	[ "$status" -ne 0 ]
	run cgroup::scheduler_listed deadline "${BATS_TEST_TMPDIR}/s"
	[ "$status" -ne 0 ]
}

@test "cgroup::weight_value reads plain and 'default N' files" {
	printf '1000\n' >"${BATS_TEST_TMPDIR}/cpu.weight"
	run cgroup::weight_value "${BATS_TEST_TMPDIR}/cpu.weight"
	[ "$output" == "1000" ]
	printf 'default 181\n' >"${BATS_TEST_TMPDIR}/io.bfq.weight"
	run cgroup::weight_value "${BATS_TEST_TMPDIR}/io.bfq.weight"
	[ "$output" == "181" ]
	printf '0\n' >"${BATS_TEST_TMPDIR}/memory.low"
	run cgroup::weight_value "${BATS_TEST_TMPDIR}/memory.low"
	[ "$output" == "0" ]
}

@test "cgroup::weight_value fails for a missing file" {
	run cgroup::weight_value "${BATS_TEST_TMPDIR}/missing"
	[ "$status" -ne 0 ]
}

@test "cgroup::slice_properties lists the non-empty settings" {
	run cgroup::slice_properties 1000 10000 4G
	[ "$output" == "CPUWeight=1000 IOWeight=10000 MemoryLow=4G" ]
	run cgroup::slice_properties "" 10000 ""
	[ "$output" == "IOWeight=10000" ]
	run cgroup::slice_properties "" "" ""
	[ -z "$output" ]
}

@test "cgroup::render_unit sets system.slice with memory, user.slice without" {
	run cgroup::render_unit 1000 10000 4G
	[ "$status" -eq 0 ]
	[[ "$output" == *"After=systemd-udev-settle.service"* ]]
	[[ "$output" == *"set-property --runtime system.slice CPUWeight=1000 IOWeight=10000 MemoryLow=4G"* ]]
	[[ "$output" == *"set-property --runtime user.slice CPUWeight=1000 IOWeight=10000"$'\n'* ]]
	[[ "$output" == *"WantedBy=multi-user.target"* ]]
}

@test "cgroup::render_unit skips user.slice when only memory is set" {
	run cgroup::render_unit "" "" 4G
	[ "$status" -eq 0 ]
	[[ "$output" != *"user.slice CPU"* ]]
	[[ "$output" != *"set-property --runtime user.slice"* ]]
	[[ "$output" == *"system.slice MemoryLow=4G"* ]]
}

@test "cgroup::render_unit prints nothing when all settings are empty" {
	run cgroup::render_unit "" "" ""
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}
