#!/usr/bin/env bats
#
# args.bats — tests for scripts/lib/args.sh

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	source "${LIB_DIR}/args.sh"
}

@test "args::usage names the script in the first line" {
	run args::usage "storage.sh"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "Usage: storage.sh [--config <file>] [--dry-run] [--yes] [--help]" ]
}

@test "args::usage lists every option and the exit codes" {
	run args::usage "x.sh"
	[[ "$output" == *"--config <file>"* ]]
	[[ "$output" == *"--dry-run"* ]]
	[[ "$output" == *"--yes"* ]]
	[[ "$output" == *"-h, --help"* ]]
	[[ "$output" == *"3  Declined"* ]]
}

@test "args::usage prints the literal \$(hostname -f), not its value" {
	run args::usage "x.sh"
	[[ "$output" == *'$(hostname -f).env'* ]]
}
