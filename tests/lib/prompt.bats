#!/usr/bin/env bats
#
# prompt.bats — tests for scripts/lib/prompt.sh

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	source "${LIB_DIR}/log.sh"
	source "${LIB_DIR}/prompt.sh"
}

@test "prompt::confirm returns success immediately with --yes, without reading input" {
	run prompt::confirm "Proceed?" "--yes" </dev/null
	[ "$status" -eq 0 ]
	[[ "$output" == *"auto-confirmed: --yes"* ]]
}

@test "prompt::confirm returns success when the user answers y" {
	run prompt::confirm "Proceed?" <<<"y"
	[ "$status" -eq 0 ]
}

@test "prompt::confirm returns failure when the user answers n" {
	run prompt::confirm "Proceed?" <<<"n"
	[ "$status" -eq 1 ]
}

@test "prompt::confirm returns failure on an empty answer (default is No)" {
	run prompt::confirm "Proceed?" <<<""
	[ "$status" -eq 1 ]
}

@test "prompt::value keeps a pre-set variable without prompting" {
	local existing="already set"
	prompt::value existing "Enter value" </dev/null
	[ "${existing}" == "already set" ]
}

@test "prompt::value prompts and assigns the reply when unset" {
	local answer=""
	prompt::value answer "Enter value" <<<"typed-value"
	[ "${answer}" == "typed-value" ]
}

@test "prompt::value falls back to the default on an empty reply" {
	local answer=""
	prompt::value answer "Enter value" "default-value" <<<""
	[ "${answer}" == "default-value" ]
}
