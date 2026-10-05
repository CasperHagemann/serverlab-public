#!/usr/bin/env bats
#
# tz.bats — tests for scripts/lib/tz.sh

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	source "${LIB_DIR}/tz.sh"
	ZONEINFO="${BATS_TEST_TMPDIR}/zoneinfo"
	mkdir -p "${ZONEINFO}/Europe" "${ZONEINFO}/Etc"
	touch "${ZONEINFO}/Europe/Copenhagen" "${ZONEINFO}/Etc/GMT+1"
	touch "${ZONEINFO}/UTC"
}

@test "tz::valid accepts an existing area/city zone" {
	run tz::valid Europe/Copenhagen "${ZONEINFO}"
	[ "$status" -eq 0 ]
}

@test "tz::valid accepts a top-level zone and a zone with +" {
	run tz::valid UTC "${ZONEINFO}"
	[ "$status" -eq 0 ]
	run tz::valid Etc/GMT+1 "${ZONEINFO}"
	[ "$status" -eq 0 ]
}

@test "tz::valid rejects a zone that does not exist" {
	run tz::valid Europe/Atlantis "${ZONEINFO}"
	[ "$status" -ne 0 ]
}

@test "tz::valid rejects an empty name and a directory" {
	run tz::valid "" "${ZONEINFO}"
	[ "$status" -ne 0 ]
	run tz::valid Europe "${ZONEINFO}"
	[ "$status" -ne 0 ]
}

@test "tz::valid rejects path traversal and odd characters" {
	run tz::valid "../zoneinfo/UTC" "${ZONEINFO}"
	[ "$status" -ne 0 ]
	run tz::valid "Europe/Copenhagen;ls" "${ZONEINFO}"
	[ "$status" -ne 0 ]
}
