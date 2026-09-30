#!/usr/bin/env bats
#
# net.bats — tests for scripts/lib/net.sh
#
# These read real interface state on the machine running the tests (only
# assuming "lo" exists, which is true on any Linux box), so they only make
# sense run in a development environment, not asserted against a specific Proxmox
# host's interfaces.
#
# Only functions with real parsing logic (net::iface_addrs --global's
# scope filtering, net::default_gateway's route-table parsing) are
# covered. The other functions are thin wrappers around a single
# /sys/class/net check and aren't worth testing separately.

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	source "${LIB_DIR}/net.sh"
}

@test "net::iface_addrs --global excludes loopback's host-scoped address" {
	# 127.0.0.1/8 on lo has scope "host", not "global" — --global should
	# filter it out, same as it would a link-local address.
	run net::iface_addrs --global lo
	[ "$status" -eq 0 ]
	[[ "${output}" != *"127.0.0.1"* ]]
}

@test "net::default_gateway prints an IPv4 address or nothing" {
	run net::default_gateway
	[ "$status" -eq 0 ]
	if [[ -n "${output}" ]]; then
		[[ "${output}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
	fi
}
