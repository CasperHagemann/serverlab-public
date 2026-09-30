#!/usr/bin/env bash
#
# prompt.sh — interactive input helpers. Functions only.
[[ -n "${SERVERLAB_LIB_PROMPT:-}" ]] && return 0
readonly SERVERLAB_LIB_PROMPT=1

# prompt::confirm <message> [--yes]
# Asks the user to confirm an action. Returns 0 (success) if confirmed.
# If "--yes" is passed (typically because the script was invoked with a
# --yes/-y flag), skips the prompt and returns 0 immediately.
prompt::confirm() {
	local message="$1"
	local auto_yes="${2:-}"
	local reply

	if [[ "${auto_yes}" == "--yes" ]]; then
		log::info "${message} (auto-confirmed: --yes)"
		return 0
	fi

	read -r -p "${message} [y/N] " reply
	[[ "${reply}" =~ ^[Yy]$ ]]
}

# prompt::value <variable-name> <prompt-text> [default]
# Prompts for a value only if the named variable is currently unset/empty,
# and assigns the answer (or default) into it. Used so config-file values
# take precedence and prompting only happens for what's missing.
prompt::value() {
	local -n _prompt_out="$1"
	local prompt_text="$2"
	local default_value="${3:-}"
	local reply

	if [[ -n "${_prompt_out:-}" ]]; then
		return 0
	fi

	if [[ -n "${default_value}" ]]; then
		read -r -p "${prompt_text} [${default_value}]: " reply
		_prompt_out="${reply:-${default_value}}"
	else
		read -r -p "${prompt_text}: " reply
		_prompt_out="${reply}"
	fi
}
