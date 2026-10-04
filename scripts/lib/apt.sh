#!/usr/bin/env bash
#
# apt.sh — APT deb822 (.sources) helpers. Functions only; they print to
# stdout and never touch the filesystem.
[[ -n "${SERVERLAB_LIB_APT:-}" ]] && return 0
readonly SERVERLAB_LIB_APT=1

# apt::field <sources-path> <field>
# Prints the value of <field> (e.g. Suites) from the first stanza of a
# deb822 file. Prints nothing if the field is missing.
apt::field() {
	local path="$1"
	local field="$2"
	awk -v field="${field}" '
		/^[[:space:]]*$/ { if (started) exit; next }
		/^[[:space:]]*#/ { next }
		{ started = 1 }
		index($0, field ":") == 1 {
			sub(/^[^:]*:[[:space:]]*/, "")
			sub(/[[:space:]]+$/, "")
			print
			exit
		}
	' "${path}"
}

# apt::render_source <uri> <suite> <component> <keyring>
# Prints a deb822 file with one `deb` stanza and a header comment.
apt::render_source() {
	local uri="$1"
	local suite="$2"
	local component="$3"
	local keyring="$4"
	printf '# Managed file - local changes may be overwritten.\n'
	printf 'Types: deb\n'
	printf 'URIs: %s\n' "${uri}"
	printf 'Suites: %s\n' "${suite}"
	printf 'Components: %s\n' "${component}"
	printf 'Signed-By: %s\n' "${keyring}"
}

# apt::disable_source <sources-path>
# Prints the deb822 file with every stanza that has a `Types:` line
# disabled: any existing `Enabled:` line is replaced by `Enabled: no`
# placed at the end of the stanza.
apt::disable_source() {
	local path="$1"
	awk '
		function flush(   i) {
			for (i = 1; i <= n; i++) print buf[i]
			if (n > 0 && has_types) print "Enabled: no"
			n = 0
			has_types = 0
		}
		/^[[:space:]]*$/ { flush(); print; next }
		/^Enabled:/ { next }
		/^Types:/ { has_types = 1 }
		{ buf[++n] = $0 }
		END { flush() }
	' "${path}"
}

# apt::is_disabled <sources-path>
# Returns 0 if the first stanza of the deb822 file has `Enabled: no`.
apt::is_disabled() {
	[[ "$(apt::field "$1" Enabled)" =~ ^[Nn][Oo]$ ]]
}

# apt::error_lines
# Reads `apt-get update` output on stdin and prints only the error lines
# (`E:` and `Err:`).
apt::error_lines() {
	grep -E '^(E|Err):' || true
}

# apt::ceph_nosub_uri <enterprise-uri>
# Prints the no-subscription URI that matches a Proxmox Ceph enterprise URI
# (https://enterprise.proxmox.com/debian/ceph-<release>). Fails for any
# other URI.
apt::ceph_nosub_uri() {
	local uri="$1"
	local prefix='https://enterprise.proxmox.com/debian/ceph-'

	[[ "${uri}" == "${prefix}"* ]] || return 1
	printf 'http://download.proxmox.com/debian/ceph-%s\n' "${uri#"${prefix}"}"
}
