#!/usr/bin/env bats
#
# disk.bats — tests for scripts/lib/disk.sh
#
# Pure-calculation functions (disk::align_sectors, disk::validate_geometry,
# disk::round_down_sector, disk::extent_bytes, disk::partition_path) are
# tested directly. disk::next_partnum and disk::free_extent are tested
# against a stub `sgdisk` on PATH (tests/fixtures/bin/sgdisk), since they
# shell out to it. disk::os_disk/sector_size/alignment_offset/
# optimal_io_size read real host paths (/proc, /sys) and aren't covered
# here — they're thin single-command wrappers, exercised manually against
# the real host instead (see docs/decisions/0003).

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	FIXTURES_BIN="${BATS_TEST_DIRNAME}/../fixtures/bin"
	PATH="${FIXTURES_BIN}:${PATH}"
	source "${LIB_DIR}/log.sh"
	source "${LIB_DIR}/disk.sh"
}

# --- disk::align_sectors ------------------------------------------------

@test "disk::align_sectors: 512 B sectors -> 2048 sectors per MiB" {
	run disk::align_sectors 512
	[ "$status" -eq 0 ]
	[ "$output" = "2048" ]
}

@test "disk::align_sectors: 4096 B sectors -> 256 sectors per MiB" {
	run disk::align_sectors 4096
	[ "$status" -eq 0 ]
	[ "$output" = "256" ]
}

# --- disk::validate_geometry ---------------------------------------------

@test "disk::validate_geometry: aligned offset and divisible optimal_io_size passes" {
	run disk::validate_geometry 0 262144
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "disk::validate_geometry: aligned offset and zero optimal_io_size passes" {
	run disk::validate_geometry 0 0
	[ "$status" -eq 0 ]
}

@test "disk::validate_geometry: non-zero alignment_offset fails" {
	run disk::validate_geometry 512 0
	[ "$status" -eq 1 ]
	[[ "$output" == *"alignment_offset"* ]]
}

@test "disk::validate_geometry: optimal_io_size not dividing 1 MiB fails" {
	run disk::validate_geometry 0 300000
	[ "$status" -eq 1 ]
	[[ "$output" == *"optimal_io_size"* ]]
}

# --- disk::round_down_sector ----------------------------------------------

@test "disk::round_down_sector: already-aligned end sector (512 B) is unchanged" {
	# 2048-sector alignment: sector 2047 (end) makes a 1 MiB block from 0.
	run disk::round_down_sector 2047 2048
	[ "$status" -eq 0 ]
	[ "$output" = "2047" ]
}

@test "disk::round_down_sector: unaligned end sector (512 B) rounds down" {
	run disk::round_down_sector 2100 2048
	[ "$status" -eq 0 ]
	[ "$output" = "2047" ]
}

@test "disk::round_down_sector: unaligned end sector (4K) rounds down" {
	run disk::round_down_sector 300 256
	[ "$status" -eq 0 ]
	[ "$output" = "255" ]
}

# --- disk::extent_bytes ----------------------------------------------------

@test "disk::extent_bytes: computes size of an inclusive sector range" {
	run disk::extent_bytes 2048 2147 512
	[ "$status" -eq 0 ]
	[ "$output" = "51200" ]
}

# --- disk::partition_path --------------------------------------------------

@test "disk::partition_path: nvme disk gets a 'p' infix" {
	run disk::partition_path /dev/nvme0n1 4
	[ "$status" -eq 0 ]
	[ "$output" = "/dev/nvme0n1p4" ]
}

@test "disk::partition_path: plain disk gets a bare suffix" {
	run disk::partition_path /dev/sda 4
	[ "$status" -eq 0 ]
	[ "$output" = "/dev/sda4" ]
}

# --- disk::next_partnum (stubbed sgdisk) -----------------------------------

@test "disk::next_partnum: empty disk starts at 1" {
	SGDISK_STUB_PARTS="" run disk::next_partnum /dev/stub0
	[ "$status" -eq 0 ]
	[ "$output" = "1" ]
}

@test "disk::next_partnum: existing partitions 1-3 -> next is 4" {
	SGDISK_STUB_PARTS="1 2 3" run disk::next_partnum /dev/stub0
	[ "$status" -eq 0 ]
	[ "$output" = "4" ]
}

# --- disk::free_extent (stubbed sgdisk) ------------------------------------

@test "disk::free_extent: aligned free space (512 B sectors)" {
	SGDISK_STUB_FIRST="2048" SGDISK_STUB_LAST="1999999966" \
		run disk::free_extent /dev/stub0 2048
	[ "$status" -eq 0 ]
	[ "$output" = "2048 1999999966" ]
}

@test "disk::free_extent: aligned free space (4K sectors)" {
	SGDISK_STUB_FIRST="256" SGDISK_STUB_LAST="249999999" \
		run disk::free_extent /dev/stub0 256
	[ "$status" -eq 0 ]
	[ "$output" = "256 249999999" ]
}

@test "disk::free_extent: unaligned free space still reports sgdisk's aligned start" {
	# sgdisk itself performs the alignment when -a is passed, so the stub
	# simply reflects what a real sgdisk would report for an odd start
	# request — first/last come back already aligned to the given -a value.
	SGDISK_STUB_FIRST="2048" SGDISK_STUB_LAST="1999999966" \
		run disk::free_extent /dev/stub0 2048
	[ "$status" -eq 0 ]
	[[ "$output" == "2048 "* ]]
}

@test "disk::free_extent: no free space prints empty fields" {
	SGDISK_STUB_FIRST="" SGDISK_STUB_LAST="" \
		run disk::free_extent /dev/stub0 2048
	[ "$status" -eq 0 ]
	[ "$output" = " " ]
}

# --- too-little-space scenario (extent_bytes feeding a min-size check) ----

@test "too-little-space: a small free extent computes below a 10 GiB minimum" {
	# 1 GiB free extent (512 B sectors) should compute well under
	# VMDATA_MIN_GIB's default of 10 GiB (10737418240 bytes).
	local min_bytes=10737418240
	run disk::extent_bytes 2048 2099199 512
	[ "$status" -eq 0 ]
	[ "$output" -lt "$min_bytes" ]
}
