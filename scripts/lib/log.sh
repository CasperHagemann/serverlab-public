#!/usr/bin/env bash
#
# log.sh — logging helpers. Functions only; sourcing this file has no side
# effects other than defining functions below.
[[ -n "${SERVERLAB_LIB_LOG:-}" ]] && return 0
readonly SERVERLAB_LIB_LOG=1

# log::info <message...>
# Prints an informational message to stderr.
log::info() {
	printf '[INFO]  %s\n' "$*" >&2
}

# log::warn <message...>
# Prints a warning message to stderr.
log::warn() {
	printf '[WARN]  %s\n' "$*" >&2
}

# log::error <message...>
# Prints an error message to stderr.
log::error() {
	printf '[ERROR] %s\n' "$*" >&2
}

# log::die <message...>
# Prints an error message and exits with status 1.
log::die() {
	log::error "$*"
	exit 1
}
