#!/bin/bash
#
# ntp.sh — chrony configuration rendering helpers. Functions only; they
# print to stdout and never touch the filesystem.
[[ -n "${SERVERLAB_LIB_NTP:-}" ]] && return 0
readonly SERVERLAB_LIB_NTP=1

# ntp::render_sources <server> [server...]
# Prints the contents of a chrony `sources.d/*.sources` file: a header
# comment followed by one `server <name> iburst` line per server.
ntp::render_sources() {
  local server
  printf '# Managed file - local changes may be overwritten.\n'
  for server in "$@"; do
    printf 'server %s iburst\n' "${server}"
  done
}

# ntp::disable_default_sources <chrony.conf-path>
# Prints the given chrony.conf with every active `pool` and `server` line,
# and the DHCP `sourcedir /run/chrony-dhcp` line, commented out, so only
# sources from sources.d are used.
ntp::disable_default_sources() {
  local path="$1"
  awk '
    /^[[:space:]]*(pool|server)[[:space:]]/ { print "# " $0; next }
    /^[[:space:]]*sourcedir[[:space:]]+\/run\/chrony-dhcp[[:space:]]*$/ {
      print "# " $0
      next
    }
    { print }
  ' "${path}"
}

# ntp::count_sources
# Prints the number of time sources chrony currently knows about.
ntp::count_sources() {
  chronyc -n -c sources | grep -c . || true
}

# ntp::has_sourcedir <chrony.conf-path> <directory>
# Returns 0 if the config has an active `sourcedir <directory>` line.
ntp::has_sourcedir() {
  local path="$1"
  local dir="$2"
  grep -qE "^[[:space:]]*sourcedir[[:space:]]+${dir}[[:space:]]*$" "${path}"
}
