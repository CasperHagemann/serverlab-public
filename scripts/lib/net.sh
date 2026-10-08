#!/bin/bash
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

# net::bridge_vlan_aware <bridge>
# True if the bridge currently has VLAN awareness (vlan_filtering) enabled.
net::bridge_vlan_aware() {
  local bridge="$1"
  local base="${SERVERLAB_SYS_NET:-/sys/class/net}"
  local path="${base}/${bridge}/bridge/vlan_filtering"
  [[ -r "${path}" ]] && [[ "$(<"${path}")" == "1" ]]
}

# net::ifupdown_option <interfaces-file> <iface> <option>
# Prints the value of an option (e.g. bridge-vids) in the "iface <iface>"
# stanza of an ifupdown file, or nothing if the stanza or option is absent.
net::ifupdown_option() {
  local file="$1" iface="$2" option="$3"
  [[ -r "${file}" ]] || return 0
  awk -v iface="${iface}" -v opt="${option}" '
    $1 ~ /^(iface|auto|allow-[a-z]+|source|source-directory|mapping)$/ {
      in_stanza = ($1 == "iface" && $2 == iface)
      next
    }
    in_stanza && $1 == opt {
      sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+/, "")
      print
      exit
    }
  ' "${file}"
}

# net::vlan_leftovers <bridge> <nic> <interfaces-file>
# Prints the per-VLAN interfaces Proxmox creates for tagged guests on a
# bridge that is not VLAN aware: <bridge>v<N> (bridge) and <nic>.<N>
# (VLAN sub-interface), one per line, bridges first. Interfaces defined in
# the interfaces file are not leftovers and are skipped.
net::vlan_leftovers() {
  local bridge="$1" nic="$2" file="$3"
  local base="${SERVERLAB_SYS_NET:-/sys/class/net}" path name
  for path in "${base}/${bridge}"v[0-9]* "${base}/${nic}".[0-9]*; do
    [[ -e "${path}" ]] || continue
    name="$(basename "${path}")"
    [[ "${name}" =~ ^${bridge}v[0-9]+$ ||
      "${name}" =~ ^${nic}\.[0-9]+$ ]] || continue
    if [[ -r "${file}" ]] &&
      grep -qE "^[[:space:]]*iface[[:space:]]+${name}[[:space:]]" \
        "${file}"; then
      continue
    fi
    printf '%s\n' "${name}"
  done
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
