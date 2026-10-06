#!/usr/bin/env bash
#
# tz.sh — time zone helpers. Functions only.
[[ -n "${SERVERLAB_LIB_TZ:-}" ]] && return 0
readonly SERVERLAB_LIB_TZ=1

# tz::valid <zone-name> [zoneinfo-dir]
# Returns 0 if <zone-name> is a plain IANA zone name (e.g. Europe/Copenhagen)
# that exists as a file under the zoneinfo directory (default
# /usr/share/zoneinfo). Rejects empty names, `..`, and odd characters.
tz::valid() {
  local name="$1"
  local dir="${2:-/usr/share/zoneinfo}"
  local pattern='^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$'

  [[ "${name}" =~ ${pattern} ]] || return 1
  [[ -f "${dir}/${name}" ]]
}
