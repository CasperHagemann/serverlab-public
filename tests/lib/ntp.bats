#!/usr/bin/env bats
#
# ntp.bats — tests for scripts/lib/ntp.sh

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	source "${LIB_DIR}/log.sh"
	source "${LIB_DIR}/ntp.sh"
}

@test "ntp::render_sources prints a header and one server line each" {
	run ntp::render_sources a.example b.example
	[ "$status" -eq 0 ]
	[ "${lines[0]}" == "# Managed file - local changes may be overwritten." ]
	[ "${lines[1]}" == "server a.example iburst" ]
	[ "${lines[2]}" == "server b.example iburst" ]
	[ "${#lines[@]}" -eq 3 ]
}

@test "ntp::disable_default_sources comments out pool and server lines only" {
	local conf="${BATS_TEST_TMPDIR}/chrony.conf"
	cat >"${conf}" <<-'EOF'
		sourcedir /etc/chrony/sources.d
		pool 2.debian.pool.ntp.org iburst
		server 10.0.0.1 iburst
		# pool already.commented iburst
		rtcsync
	EOF

	run ntp::disable_default_sources "${conf}"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" == "sourcedir /etc/chrony/sources.d" ]
	[ "${lines[1]}" == "# pool 2.debian.pool.ntp.org iburst" ]
	[ "${lines[2]}" == "# server 10.0.0.1 iburst" ]
	[ "${lines[3]}" == "# pool already.commented iburst" ]
	[ "${lines[4]}" == "rtcsync" ]
}

@test "ntp::disable_default_sources comments out the DHCP sourcedir only" {
	local conf="${BATS_TEST_TMPDIR}/chrony.conf"
	cat >"${conf}" <<-'EOF'
		sourcedir /run/chrony-dhcp
		sourcedir /etc/chrony/sources.d
	EOF

	run ntp::disable_default_sources "${conf}"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" == "# sourcedir /run/chrony-dhcp" ]
	[ "${lines[1]}" == "sourcedir /etc/chrony/sources.d" ]
}

@test "ntp::has_sourcedir succeeds when the sourcedir line is active" {
	local conf="${BATS_TEST_TMPDIR}/chrony.conf"
	printf 'sourcedir /etc/chrony/sources.d\n' >"${conf}"
	run ntp::has_sourcedir "${conf}" /etc/chrony/sources.d
	[ "$status" -eq 0 ]
}

@test "ntp::has_sourcedir fails when the line is missing or commented" {
	local conf="${BATS_TEST_TMPDIR}/chrony.conf"
	printf '# sourcedir /etc/chrony/sources.d\n' >"${conf}"
	run ntp::has_sourcedir "${conf}" /etc/chrony/sources.d
	[ "$status" -ne 0 ]
}
