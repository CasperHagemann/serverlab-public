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

@test "net::bridge_vlan_aware reflects vlan_filtering" {
	export SERVERLAB_SYS_NET="${BATS_TEST_TMPDIR}/net"
	mkdir -p "${SERVERLAB_SYS_NET}/br-on/bridge" "${SERVERLAB_SYS_NET}/br-off/bridge"
	printf '1\n' >"${SERVERLAB_SYS_NET}/br-on/bridge/vlan_filtering"
	printf '0\n' >"${SERVERLAB_SYS_NET}/br-off/bridge/vlan_filtering"
	run net::bridge_vlan_aware br-on
	[ "$status" -eq 0 ]
	run net::bridge_vlan_aware br-off
	[ "$status" -eq 1 ]
	run net::bridge_vlan_aware missing
	[ "$status" -eq 1 ]
}

@test "net::ifupdown_option reads an option from the right stanza" {
	file="${BATS_TEST_TMPDIR}/interfaces"
	cat >"${file}" <<-'EOF'
		auto vmbr0
		iface vmbr0 inet static
			bridge-ports nic0
			bridge-vids 10

		auto vmbr1
		iface vmbr1 inet manual
			bridge-ports nic1
			bridge-vids 2-4094 4000
		#General VM network

		source /etc/network/interfaces.d/*
	EOF
	run net::ifupdown_option "${file}" vmbr1 bridge-vids
	[ "$status" -eq 0 ]
	[ "${output}" == "2-4094 4000" ]
	run net::ifupdown_option "${file}" vmbr0 bridge-vids
	[ "${output}" == "10" ]
	run net::ifupdown_option "${file}" vmbr1 bridge-vlan-aware
	[ -z "${output}" ]
	run net::ifupdown_option "${file}" vmbr9 bridge-vids
	[ -z "${output}" ]
}

@test "net::vlan_leftovers lists per-VLAN interfaces not in the file" {
	export SERVERLAB_SYS_NET="${BATS_TEST_TMPDIR}/net2"
	mkdir -p "${SERVERLAB_SYS_NET}"/{vmbr1,vmbr1v100,vmbr1v101,nic1,nic1.100,nic1.7,vmbr0,vmbr0v5}
	file="${BATS_TEST_TMPDIR}/interfaces2"
	cat >"${file}" <<-'IFACES'
		auto vmbr1
		iface vmbr1 inet manual
		bridge-ports nic1

		auto nic1.7
		iface nic1.7 inet manual
	IFACES
	run net::vlan_leftovers vmbr1 nic1 "${file}"
	[ "$status" -eq 0 ]
	[ "${output}" == $'vmbr1v100\nvmbr1v101\nnic1.100' ]
}

@test "net::vlan_leftovers prints nothing when there are none" {
	export SERVERLAB_SYS_NET="${BATS_TEST_TMPDIR}/net3"
	mkdir -p "${SERVERLAB_SYS_NET}"/{vmbr1,nic1}
	run net::vlan_leftovers vmbr1 nic1 /nonexistent
	[ "$status" -eq 0 ]
	[ -z "${output}" ]
}
