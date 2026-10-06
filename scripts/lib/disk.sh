#!/bin/bash
#
# disk.sh — disk/partition inspection helpers for storage Proxmox-node scripts.
# Functions only; these only read state or do pure calculations, never
# change anything.
[[ -n "${SERVERLAB_LIB_DISK:-}" ]] && return 0
readonly SERVERLAB_LIB_DISK=1

# disk::os_disk
# Prints the whole-disk device (e.g. /dev/nvme0n1) backing the root
# filesystem's mountpoint, via `findmnt` + `lsblk PKNAME`.
disk::os_disk() {
  local root_src root_pkname
  root_src="$(findmnt -no SOURCE /)"
  root_pkname="$(lsblk -no PKNAME "${root_src}")"
  if [[ -z "${root_pkname}" ]]; then
    log::die "Could not determine the parent disk of root filesystem" \
      "source '${root_src}'."
  fi
  printf '/dev/%s\n' "${root_pkname}"
}

# disk::sector_size <disk>
# Prints the device's logical block size in bytes (e.g. 512 or 4096).
disk::sector_size() {
  local disk="$1"
  cat "/sys/block/$(basename "${disk}")/queue/logical_block_size"
}

# disk::alignment_offset <disk>
# Prints the device's reported alignment offset in bytes (0 if aligned).
disk::alignment_offset() {
  local disk="$1"
  cat "/sys/block/$(basename "${disk}")/alignment_offset"
}

# disk::optimal_io_size <disk>
# Prints the device's optimal I/O size in bytes (0 if not reported).
disk::optimal_io_size() {
  local disk="$1"
  cat "/sys/block/$(basename "${disk}")/queue/optimal_io_size"
}

# disk::align_sectors <sector-size>
# Prints the number of sectors making up a 1 MiB alignment boundary for a
# device with this logical sector size (2048 at 512 B, 256 at 4096 B).
disk::align_sectors() {
  local sector_size="$1"
  echo $((1048576 / sector_size))
}

# disk::validate_geometry <alignment-offset> <optimal-io-size>
# Prints nothing and returns 0 if this disk's reported geometry is safe to
# align on plain 1 MiB boundaries: alignment_offset must be 0, and
# optimal_io_size (if the device reports one, i.e. > 0) must evenly divide
# 1 MiB. Otherwise prints a reason to stdout and returns 1.
disk::validate_geometry() {
  local alignment_offset="$1"
  local optimal_io_size="$2"

  if [[ "${alignment_offset}" -ne 0 ]]; then
    echo "alignment_offset is ${alignment_offset}, not 0 —" \
      "1 MiB alignment is not guaranteed safe on this disk"
    return 1
  fi

  if [[ "${optimal_io_size}" -gt 0 ]] &&
    ((1048576 % optimal_io_size != 0)); then
    echo "optimal_io_size (${optimal_io_size}) does not evenly divide 1 MiB"
    return 1
  fi

  return 0
}

# disk::partition_path <disk> <part-num>
# Prints the device path of a partition on <disk> — handles the nvme/mmcblk
# "p" infix (e.g. /dev/nvme0n1 + 4 -> /dev/nvme0n1p4), vs a plain suffix
# (e.g. /dev/sda + 4 -> /dev/sda4).
disk::partition_path() {
  local disk="$1"
  local num="$2"
  if [[ "$(basename "${disk}")" =~ [0-9]$ ]]; then
    printf '%sp%s\n' "${disk}" "${num}"
  else
    printf '%s%s\n' "${disk}" "${num}"
  fi
}

# disk::next_partnum <disk>
# Prints the next unused partition number on <disk> (1 if it has none),
# based on `sgdisk -p` output.
disk::next_partnum() {
  local disk="$1"
  local max
  max="$(sgdisk -p "${disk}" |
    awk '/^ *[0-9]+ / { print $1 }' |
    sort -n | tail -n1)"
  echo $((${max:-0} + 1))
}

# disk::free_extent <disk> <align-sectors>
# Prints "<first-sector> <last-sector>" of the largest free block on
# <disk>, with the start aligned to <align-sectors> (via `sgdisk -a`).
# Both fields are empty if there's no free space on the disk.
disk::free_extent() {
  local disk="$1"
  local align="$2"
  local first last
  first="$(sgdisk -a "${align}" -F "${disk}")"
  last="$(sgdisk -a "${align}" -E "${disk}")"
  printf '%s %s\n' "${first}" "${last}"
}

# disk::round_down_sector <sector> <align-sectors>
# Rounds a sector number down so that (result + 1) is a multiple of
# <align-sectors> — used to round a free extent's end sector down to a
# 1 MiB boundary (sgdisk -E does not align the end of a free block).
disk::round_down_sector() {
  local sector="$1"
  local align="$2"
  echo $((((sector + 1) / align) * align - 1))
}

# disk::extent_bytes <first-sector> <last-sector> <sector-size>
# Prints the size in bytes of the inclusive sector range
# [<first-sector>, <last-sector>].
disk::extent_bytes() {
  local first="$1"
  local last="$2"
  local sector_size="$3"
  echo $(((last - first + 1) * sector_size))
}
