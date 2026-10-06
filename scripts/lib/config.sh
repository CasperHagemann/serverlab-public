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
  # Single-line array of quoted plain words, e.g. KEY=("a.b" "c"); () is OK.
  local word='[[:space:]]*"[A-Za-z0-9._:-]+"'
  local array_open='^[A-Za-z_][A-Za-z0-9_]*=\(('
  local array_close=')*[[:space:]]*\)[[:space:]]*(#.*)?$'
  local array_value="${array_open}${word}${array_close}"
  local allowed="${blank_or_comment}|${key_value}|${array_value}"
  if grep -qvE "${allowed}" "${path}"; then
    log::die "Config file '${path}' contains something other than" \
      "plain KEY=value lines, single-line arrays, or comments —" \
      "refusing to load it."
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

# config::require_array <variable-name> [variable-name...]
# Aborts if any of the named variables is not declared as an array. An
# empty array is allowed (scripts give it a meaning, e.g. "use OS defaults").
config::require_array() {
  local var decl
  for var in "$@"; do
    decl="$(declare -p "${var}" 2>/dev/null || true)"
    if [[ "${decl}" != "declare -"*a*" "* ]]; then
      log::die "Required value '${var}' is not set as an array" \
        "(config file)."
    fi
  done
}

# config::require_declared <variable-name> [variable-name...]
# Aborts if any of the named variables is not declared at all. Unlike
# config::require, an empty value is allowed (scripts give it a meaning,
# e.g. "revert to the saved original"), so a missing line is still caught.
config::require_declared() {
  local var
  for var in "$@"; do
    if ! declare -p "${var}" >/dev/null 2>&1; then
      log::die "Required value '${var}' is not set (config file)."
    fi
  done
}
