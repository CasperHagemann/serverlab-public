#!/usr/bin/env bash
#
# net.sh — local network-state inspection helpers, using only tools present
# on a base Proxmox VE install (/sys/class/net, `ip`, `awk`) — no `jq`.
# Functions only; these only read state, never change it.
[[ -n "${SERVERLAB_LIB_NET:-}" ]] && return 0
readonly SERVERLAB_LIB_NET=1

# net::iface_exists <iface>
# True if a network interface with this name currently exists.
net::iface_exists() {
	local iface="$1"
	[[ -d "/sys/class/net/${iface}" ]]
}

# net::iface_master <iface>
# Prints the name of the bridge/bond this interface is a member of, or
# nothing if it isn't a member of one.
net::iface_master() {
	local iface="$1"
	local master_path="/sys/class/net/${iface}/master"
	if [[ -e "${master_path}" ]]; then
		basename "$(readlink -f "${master_path}")"
	fi
}

# net::iface_addrs [--global] <iface>
# Prints the interface's IPv4/IPv6 addresses in CIDR form, one per line
# (empty output if the interface has none, e.g. an unaddressed bridge, or
# doesn't exist). With --global, skips link-local addresses (e.g. the
# automatic fe80::/10 address every up interface gets) — use this when
# checking whether an interface has been assigned a "real" address.
net::iface_addrs() {
	local scope_args=()
	if [[ "${1:-}" == "--global" ]]; then
		scope_args=(scope global)
		shift
	fi
	local iface="$1"
	ip -o addr show dev "${iface}" "${scope_args[@]}" 2>/dev/null |
		awk '$3 == "inet" || $3 == "inet6" { print $4 }'
}

# net::iface_is_up <iface>
# True if the interface's operational state is up.
net::iface_is_up() {
	local iface="$1"
	local state_path="/sys/class/net/${iface}/operstate"
	[[ -e "${state_path}" ]] && [[ "$(<"${state_path}")" == "up" ]]
}

# net::default_gateway
# Prints the current IPv4 default gateway address, or nothing if none.
net::default_gateway() {
	ip route show default 2>/dev/null |
		awk '/^default/ {
			for (i = 1; i <= NF; i++)
				if ($i == "via") print $(i + 1)
		}' |
		head -n1
}
