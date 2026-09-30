#!/usr/bin/env bash
#
# install-hooks.sh — one-time setup per clone: point git at the repo's
# tracked hooks directory (.githooks/) instead of the default, untracked
# .git/hooks/.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

# shellcheck source=scripts/lib/common.sh
source "scripts/lib/common.sh"

chmod +x .githooks/pre-commit
git config core.hooksPath .githooks

log_info "Git hooks installed (core.hooksPath = .githooks)."
log_info "pre-commit now runs './scripts/check.sh --check' on staged files."
