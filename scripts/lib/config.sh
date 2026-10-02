#!/usr/bin/env bash
#
# config.sh — per-node config file loading/validation. Functions only.
[[ -n "${SERVERLAB_LIB_CONFIG:-}" ]] && return 0
readonly SERVERLAB_LIB_CONFIG=1

# config::load <path>
# Sources a KEY=value config file after checking it exists and contains
# only safe assignment lines (defence against a config file that isn't
# plain KEY=value, since it gets sourced as bash).
config::load() {
	local path="$1"

	if [[ ! -f "${path}" ]]; then
		log::die "Config file not found: ${path}"
	fi

	local blank_or_comment='^[[:space:]]*(#.*)?$'
	local key_value='^[A-Za-z_][A-Za-z0-9_]*="?[^;&|$()`]*"?[[:space:]]*(#.*)?$'
	if grep -qvE "${blank_or_comment}|${key_value}" "${path}"; then
		log::die "Config file '${path}' contains something other than" \
			"plain KEY=value lines or comments — refusing to load it."
	fi

	# shellcheck disable=SC1090
	source "${path}"
}

# config::require <variable-name> [variable-name...]
# Aborts if any of the named variables are unset or empty after loading
# config (and, in a script that prompts, after prompting too).
config::require() {
	local var
	for var in "$@"; do
		if [[ -z "${!var:-}" ]]; then
			log::die "Required value '${var}' is not set" \
				"(config file or prompt)."
		fi
	done
}
