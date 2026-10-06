#!/usr/bin/env bash
#
# pve.sh — pvesh wrappers. Functions only.
[[ -n "${SERVERLAB_LIB_PVE:-}" ]] && return 0
readonly SERVERLAB_LIB_PVE=1

# pve::get <api-path>
# Runs `pvesh get` and prints its (text-formatted) output.
pve::get() {
  local path="$1"
  pvesh get "${path}"
}

# pve::node
# Prints the local node name, as Proxmox knows it.
pve::node() {
  hostname
}

# pve::create <api-path> [pvesh-args...]
# Runs `pvesh create` with the given arguments (e.g. to stage a new network
# interface into /etc/network/interfaces.new).
pve::create() {
  local path="$1"
  shift
  pvesh create "${path}" "$@"
}

# pve::set <api-path> [pvesh-args...]
# Runs `pvesh set` with the given arguments (e.g. to apply the staged
# network configuration: `pve::set "/nodes/$(pve::node)/network"`).
pve::set() {
  local path="$1"
  shift
  pvesh set "${path}" "$@"
}

# pve::revert <api-path>
# Runs `pvesh delete` against a network endpoint, which discards the
# pending /etc/network/interfaces.new staged changes without touching the
# running config (e.g. `pve::revert "/nodes/$(pve::node)/network"`).
pve::revert() {
  local path="$1"
  pvesh delete "${path}"
}

# pve::wait_task <upid> [timeout-seconds]
# Polls /nodes/<node>/tasks/<upid>/status (requesting JSON just for this
# one call, parsed with grep — no jq needed for a single flat object) once
# a second until the task is no longer running, or the timeout (default
# 60s) elapses. Returns 0 if the task finished with exitstatus "OK", 1
# otherwise (failed, timed out, or its status couldn't be parsed).
pve::wait_task() {
  local upid="$1"
  local timeout="${2:-60}"
  local waited=0
  local raw status exitstatus

  while ((waited < timeout)); do
    raw="$(pvesh get "/nodes/$(pve::node)/tasks/${upid}/status" \
      --output-format json 2>/dev/null)" || return 1
    status="$(grep -oP '"status"\s*:\s*"\K[^"]+' <<<"${raw}")"
    if [[ "${status}" == "stopped" ]]; then
      exitstatus="$(grep -oP '"exitstatus"\s*:\s*"\K[^"]+' <<<"${raw}")"
      [[ "${exitstatus}" == "OK" ]]
      return $?
    fi
    sleep 1
    waited=$((waited + 1))
  done

  return 1
}

# pve::storage_disabled <storage-id>
# True if the named storage exists and is currently disabled. False if it's
# active, or if the storage doesn't exist / pvesm status fails.
pve::storage_disabled() {
  local id="$1"
  local status
  status="$(pvesm status --storage "${id}" 2>/dev/null |
    awk 'NR==2{print $3}')"
  [[ "${status}" == "disabled" ]]
}
