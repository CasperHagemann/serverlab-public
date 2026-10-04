#!/usr/bin/env bash
#
# cgroup.sh — cgroup weight and I/O scheduler helpers. Functions only.
[[ -n "${SERVERLAB_LIB_CGROUP:-}" ]] && return 0
readonly SERVERLAB_LIB_CGROUP=1

# cgroup::valid_weight <value>
# Returns 0 if <value> is a whole number from 1 to 10000 (the range of the
# systemd CPUWeight= and IOWeight= settings).
cgroup::valid_weight() {
	local value="$1"
	[[ "${value}" =~ ^[1-9][0-9]{0,4}$ ]] && ((value <= 10000))
}

# cgroup::valid_memory <value>
# Returns 0 if <value> is a whole number of bytes with an optional K, M, G
# or T suffix (powers of 1024), e.g. 4G.
cgroup::valid_memory() {
	[[ "$1" =~ ^[1-9][0-9]*[KMGT]?$ ]]
}

# cgroup::valid_scheduler <name>
# Returns 0 if <name> is a block I/O scheduler this project accepts.
cgroup::valid_scheduler() {
	[[ "$1" =~ ^(bfq|mq-deadline|kyber|none)$ ]]
}

# cgroup::memory_bytes <value>
# Prints <value> (see cgroup::valid_memory) in bytes.
cgroup::memory_bytes() {
	local value="$1"
	local number="${value%[KMGT]}"
	local suffix="${value#"${number}"}"

	case "${suffix}" in
	K) echo $((number * 1024)) ;;
	M) echo $((number * 1048576)) ;;
	G) echo $((number * 1073741824)) ;;
	T) echo $((number * 1099511627776)) ;;
	*) echo "${number}" ;;
	esac
}

# cgroup::bfq_weight <io-weight>
# Prints the io.bfq.weight value systemd writes for an IOWeight= value. BFQ
# weights run from 1 to 1000, IOWeight= from 1 to 10000; both default to 100.
# Values above the default are scaled linearly (1000 -> 181, 10000 -> 1000).
cgroup::bfq_weight() {
	local weight="$1"
	if ((weight >= 100)); then
		echo $((100 + 900 * (weight - 100) / 9900))
	else
		echo "${weight}"
	fi
}

# cgroup::render_dropin <cpu-weight> <io-weight> <memory-low>
# Prints a systemd slice drop-in with the non-empty settings. Prints nothing
# if all three are empty.
cgroup::render_dropin() {
	local cpu="$1"
	local io="$2"
	local memory="$3"

	if [[ -z "${cpu}${io}${memory}" ]]; then
		return 0
	fi

	echo "# Managed file - local changes may be overwritten."
	echo "[Slice]"
	if [[ -n "${cpu}" ]]; then
		echo "CPUWeight=${cpu}"
	fi
	if [[ -n "${io}" ]]; then
		echo "IOWeight=${io}"
	fi
	if [[ -n "${memory}" ]]; then
		echo "MemoryLow=${memory}"
	fi
}

# cgroup::render_udev_rule <disk-name> <scheduler>
# Prints a udev rule that sets the I/O scheduler of the whole disk <disk-name>
# (e.g. nvme0n1) whenever it appears or changes.
cgroup::render_udev_rule() {
	local disk="$1"
	local scheduler="$2"

	echo "# Managed file - local changes may be overwritten."
	printf 'ACTION=="add|change", KERNEL=="%s", ATTR{queue/scheduler}="%s"\n' \
		"${disk}" "${scheduler}"
}

# cgroup::active_scheduler <scheduler-file>
# Prints the active scheduler from a queue/scheduler file, e.g. "bfq" for
# "none mq-deadline [bfq]".
cgroup::active_scheduler() {
	sed -n 's/.*\[\([^]]*\)\].*/\1/p' "$1"
}

# cgroup::scheduler_listed <name> <scheduler-file>
# Returns 0 if <name> is one of the schedulers listed in the file.
cgroup::scheduler_listed() {
	tr -d '[]' <"$2" | tr -s ' ' '\n' | grep -qx -- "$1"
}

# cgroup::weight_value <cgroup-file>
# Prints the value in a cgroup weight or limit file: the last field of the
# first line ("default 181" -> 181, "1000" -> 1000).
cgroup::weight_value() {
	[[ -r "$1" ]] || return 1
	awk 'NR == 1 { print $NF }' "$1"
}

# cgroup::slice_properties <cpu-weight> <io-weight> <memory-low>
# Prints the non-empty settings as systemctl set-property arguments, e.g.
# "CPUWeight=1000 IOWeight=10000 MemoryLow=4G". Prints an empty line if all
# three are empty.
cgroup::slice_properties() {
	local cpu="$1"
	local io="$2"
	local memory="$3"
	local props=()

	[[ -n "${cpu}" ]] && props+=("CPUWeight=${cpu}")
	[[ -n "${io}" ]] && props+=("IOWeight=${io}")
	[[ -n "${memory}" ]] && props+=("MemoryLow=${memory}")
	echo "${props[*]:-}"
}

# cgroup::render_unit <cpu-weight> <io-weight> <memory-low>
# Prints a oneshot systemd unit that applies the settings to the running
# system.slice and user.slice at boot, after udev has set the I/O scheduler.
# systemd does not write io.bfq.weight to a slice created before the bfq
# module is loaded, so the drop-ins alone are not enough. MemoryLow applies
# to system.slice only. Prints nothing if all three are empty.
cgroup::render_unit() {
	local cpu="$1"
	local io="$2"
	local memory="$3"
	local control="/run/systemd/system.control"
	local sys_props
	local user_props

	if [[ -z "${cpu}${io}${memory}" ]]; then
		return 0
	fi
	sys_props="$(cgroup::slice_properties "${cpu}" "${io}" "${memory}")"
	user_props="$(cgroup::slice_properties "${cpu}" "${io}" "")"

	echo "# Managed file - local changes may be overwritten."
	echo "[Unit]"
	echo "Description=Node CPU, disk I/O and memory priority"
	echo "Wants=systemd-udev-settle.service"
	echo "After=systemd-udev-settle.service"
	echo
	echo "[Service]"
	echo "Type=oneshot"
	echo "RemainAfterExit=yes"
	echo "ExecStart=/usr/bin/systemctl set-property --runtime system.slice" \
		"${sys_props}"
	if [[ -n "${user_props}" ]]; then
		echo "ExecStart=/usr/bin/systemctl set-property --runtime user.slice" \
			"${user_props}"
	fi
	# The runtime drop-ins would override later changes to the files in
	# /etc/systemd/system; the kernel keeps the values.
	echo "ExecStartPost=/usr/bin/rm -rf ${control}/system.slice.d" \
		"${control}/user.slice.d"
	echo
	echo "[Install]"
	echo "WantedBy=multi-user.target"
}
