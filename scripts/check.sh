#!/usr/bin/env bash
#
# check.sh — bring the repo into compliance with .editorconfig and lint
# shell scripts.
#
# Two modes:
#   ./scripts/check.sh            fix mode  — formats the whole repo in place,
#                                  then runs the bats test suite
#   ./scripts/check.sh --check    check mode — staged files only, no mutation
#                                  (used by the pre-commit hook, see
#                                  .githooks/pre-commit) — does NOT run bats,
#                                  see note below
#
# Steps (fix mode):
#   1. shfmt      — formats/checks .sh files
#   2. prettier    — formats/checks .json/.md files
#   3. shellcheck  — lints .sh files for correctness (never mutates)
#   4. ec          — verifies against .editorconfig (never mutates)
#   5. bats        — runs tests/ (recursively), if the directory exists
#
# Requires: shfmt, prettier, shellcheck, ec (editorconfig-checker), bats —
# see docs/dev-environment.md for install instructions.

set -euo pipefail
set -o errtrace

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

# shellcheck source=scripts/lib/common.sh
source "scripts/lib/common.sh"

check_mode=false
if [[ "${1:-}" == "--check" ]]; then
	check_mode=true
fi

on_failure() {
	if [[ "${check_mode}" == true ]]; then
		log::error "Pre-commit checks failed — commit aborted. No files were modified."
		log::error "Run './scripts/check.sh' to auto-fix, then re-stage and commit."
		log::error "To bypass (not recommended): git commit --no-verify"
	else
		log::error "Check failed — see output above."
	fi
}
trap on_failure ERR

for tool in shfmt prettier shellcheck ec bats; do
	if ! command -v "${tool}" >/dev/null 2>&1; then
		log::error "${tool} not found — see docs/dev-environment.md for install instructions."
		exit 1
	fi
done

exclude_pattern='^\.clinerules/|^\.agents/'

if [[ "${check_mode}" == true ]]; then
	# Staged files only (added/copied/modified), excluding the same paths
	# .editorconfig checking skips repo-wide, and files that no longer exist
	# (e.g. staged deletions).
	mapfile -t staged_files < <(
		git diff --cached --name-only --diff-filter=ACM |
			grep -Ev "${exclude_pattern}" || true
	)

	if [[ ${#staged_files[@]} -eq 0 ]]; then
		log::info "No relevant staged files — nothing to check."
		exit 0
	fi

	staged_sh=()
	staged_fmt=() # .json/.md, for prettier
	for f in "${staged_files[@]}"; do
		[[ -f "${f}" ]] || continue
		case "${f}" in
		*.sh) staged_sh+=("${f}") ;;
		*.json | *.md) staged_fmt+=("${f}") ;;
		esac
	done

	if [[ ${#staged_sh[@]} -gt 0 ]]; then
		log::info "Checking shell formatting (shfmt -d)..."
		shfmt -d "${staged_sh[@]}"

		log::info "Linting shell scripts (shellcheck)..."
		shellcheck -S warning "${staged_sh[@]}"
	fi

	if [[ ${#staged_fmt[@]} -gt 0 ]]; then
		log::info "Checking JSON/Markdown formatting (prettier --check)..."
		prettier --check "${staged_fmt[@]}"
	fi

	log::info "Verifying staged files against .editorconfig (ec)..."
	ec "${staged_files[@]}"

	log::info "All staged files pass. No files were modified."
else
	log::info "Formatting shell scripts (shfmt)..."
	shfmt -w .

	log::info "Formatting JSON/Markdown (prettier)..."
	prettier --write .

	log::info "Linting shell scripts (shellcheck)..."
	# -S warning: suppress info-level notices (e.g. SC1091 on `source`),
	# which are not actionable failures for this script's purposes.
	find . -name '*.sh' -not -path './.git/*' -print0 |
		xargs -0 shellcheck -S warning

	log::info "Verifying against .editorconfig (ec)..."
	ec -exclude "${exclude_pattern}"

	if [[ -d tests ]]; then
		log::info "Running bats test suite (tests/)..."
		bats --recursive tests/
	fi

	log::info "Check complete."
fi
