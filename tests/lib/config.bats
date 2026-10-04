#!/usr/bin/env bats
#
# config.bats — tests for scripts/lib/config.sh

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	source "${LIB_DIR}/log.sh"
	source "${LIB_DIR}/config.sh"
}

@test "config::load dies if the file doesn't exist" {
	run config::load "${BATS_TEST_TMPDIR}/does-not-exist.env"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Config file not found"* ]]
}

@test "config::load sources plain KEY=value lines" {
	local config_file="${BATS_TEST_TMPDIR}/host.env"
	cat >"${config_file}" <<-'EOF'
		# a comment
		MGMT_BRIDGE="vmbr0"
		VM_IFACE=nic1
	EOF

	config::load "${config_file}"
	[ "${MGMT_BRIDGE}" == "vmbr0" ]
	[ "${VM_IFACE}" == "nic1" ]
}

@test "config::load refuses a file containing command substitution" {
	local config_file="${BATS_TEST_TMPDIR}/malicious.env"
	echo 'EVIL=$(echo pwned)' >"${config_file}"

	run config::load "${config_file}"
	[ "$status" -eq 1 ]
	[[ "$output" == *"refusing to load"* ]]
}

@test "config::load refuses a file containing a semicolon-chained command" {
	local config_file="${BATS_TEST_TMPDIR}/malicious.env"
	echo 'FOO=bar; rm -rf /tmp/whatever' >"${config_file}"

	run config::load "${config_file}"
	[ "$status" -eq 1 ]
	[[ "$output" == *"refusing to load"* ]]
}

@test "config::require passes when all named variables are set" {
	FOO="x"
	BAR="y"
	run config::require FOO BAR
	[ "$status" -eq 0 ]
}

@test "config::require dies when a named variable is unset" {
	unset MISSING_VAR
	run config::require MISSING_VAR
	[ "$status" -eq 1 ]
	[[ "$output" == *"MISSING_VAR"* ]]
}

@test "config::require dies when a named variable is set but empty" {
	EMPTY_VAR=""
	run config::require EMPTY_VAR
	[ "$status" -eq 1 ]
}

@test "config::load sources single-line arrays, including an empty one" {
	local config_file="${BATS_TEST_TMPDIR}/host.env"
	cat >"${config_file}" <<-'EOT'
		SERVERS=("a.example" "b.example") # trailing comment
		NONE=()
	EOT

	config::load "${config_file}"
	[ "${#SERVERS[@]}" -eq 2 ]
	[ "${SERVERS[1]}" == "b.example" ]
	[ "${#NONE[@]}" -eq 0 ]
}

@test "config::load refuses an array containing command substitution" {
	local config_file="${BATS_TEST_TMPDIR}/malicious.env"
	echo 'EVIL=("$(echo pwned)")' >"${config_file}"

	run config::load "${config_file}"
	[ "$status" -eq 1 ]
	[[ "$output" == *"refusing to load"* ]]
}

@test "config::require_array passes for an empty array" {
	EMPTY=()
	run config::require_array EMPTY
	[ "$status" -eq 0 ]
}

@test "config::require_array dies for a scalar or unset variable" {
	SCALAR="x"
	run config::require_array SCALAR
	[ "$status" -eq 1 ]
	unset MISSING_ARR
	run config::require_array MISSING_ARR
	[ "$status" -eq 1 ]
	[[ "$output" == *"MISSING_ARR"* ]]
}
