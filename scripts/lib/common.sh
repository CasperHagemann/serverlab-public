#!/usr/bin/env bash
#
# common.sh — loader for serverlab host-script shared helpers.
#
# Usage: source this file near the top of a script, after `set -euo pipefail`:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
#
# This file itself defines nothing except sourcing the topic files below —
# see scripts/README.md for the conventions each of those files follows
# (functions only, `pkg::function` naming, include guards, `local` variables).

set -euo pipefail

_serverlab_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/log.sh
source "${_serverlab_lib_dir}/log.sh"
# shellcheck source=scripts/lib/guards.sh
source "${_serverlab_lib_dir}/guards.sh"
# shellcheck source=scripts/lib/prompt.sh
source "${_serverlab_lib_dir}/prompt.sh"
# shellcheck source=scripts/lib/files.sh
source "${_serverlab_lib_dir}/files.sh"
# shellcheck source=scripts/lib/config.sh
source "${_serverlab_lib_dir}/config.sh"
# shellcheck source=scripts/lib/pve.sh
source "${_serverlab_lib_dir}/pve.sh"
# shellcheck source=scripts/lib/net.sh
source "${_serverlab_lib_dir}/net.sh"
# shellcheck source=scripts/lib/disk.sh
source "${_serverlab_lib_dir}/disk.sh"

unset _serverlab_lib_dir
