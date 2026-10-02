#!/usr/bin/env bash
#
# check.sh — bring the repo into compliance with .editorconfig and lint
# shell scripts.
#
# Two modes:
#   ./scripts/control-node/check.sh
#       fix mode — formats the whole repo in place, then runs the bats
#       test suite
#   ./scripts/control-node/check.sh --check
#       check mode — staged files only, no mutation (used by the
#       pre-commit hook, see .githooks/pre-commit) — does NOT run bats
#
# Steps (fix mode):
#   1. shfmt       — formats/checks .sh files
#   2. prettier    — formats/checks .json/.md files
#   3. shellcheck  — lints .sh files for correctness (never mutates)
#   4. line length — .sh files stay within 80 columns (never mutates)
#   5. ADRs        — docs/decisions/ structure and index (never mutates)
#   6. ec          — verifies against .editorconfig (never mutates)
#   7. bats        — runs tests/ (recursively), if the directory exists
#
# Runs on the control node. The 80-column limit comes from the Google Shell
# Style Guide, which neither shfmt nor shellcheck enforces; a tab counts as
# 4 columns (see .editorconfig).
#
# Requires: shfmt, prettier, shellcheck, ec (editorconfig-checker), bats —
# see docs/control-node.md for install instructions.

set -euo pipefail
set -o errtrace

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

# shellcheck source=scripts/lib/common.sh
source "scripts/lib/common.sh"

check_mode=false
if [[ "${1:-}" == "--check" ]]; then
	check_mode=true
fi

on_failure() {
	if [[ "${check_mode}" == true ]]; then
		log::error "Pre-commit checks failed — commit aborted." \
			"No files were modified."
		log::error "Run './scripts/control-node/check.sh' to auto-fix," \
			"then re-stage and commit."
		log::error "To bypass (not recommended): git commit --no-verify"
	else
		log::error "Check failed — see output above."
	fi
}
trap on_failure ERR

# check_line_length <file...>
# Prints "<file>:<line>: <n> columns (max 80)" for every line over 80
# columns, counting a tab as 4 columns. Returns 1 if any line is too long.
check_line_length() {
	local file
	local failed=false
	local awk_prog='length($0) > 80 {
		printf "%s:%d: %d columns (max 80)\n", f, NR, length($0)
		bad = 1
	}
	END { exit bad }'

	for file in "$@"; do
		if ! expand -t4 "${file}" | awk -v f="${file}" "${awk_prog}"; then
			failed=true
		fi
	done

	[[ "${failed}" == false ]]
}

# check_adrs [dir]
# Validates the ADR files in <dir> (default docs/decisions) against
# .clinerules/custom/adr-decisions.md: file name, title number, status,
# date, section order, non-empty sections, and index links in both
# directions. Prints one line per problem. Returns 1 if any problem is
# found.
check_adrs() {
	local dir="${1:-docs/decisions}"
	local failed=false
	local file base num sections empty index link

	problem() {
		log::error "ADR: $*"
		failed=true
	}

	index="${dir}/README.md"
	[[ -f "${index}" ]] || problem "${index} is missing"

	for file in "${dir}"/[0-9]*.md; do
		[[ -f "${file}" ]] || continue
		base="$(basename "${file}")"
		num="${base%%-*}"

		[[ "${base}" =~ ^[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*\.md$ ]] ||
			problem "${base}: file name must be NNNN-kebab-case-title.md"
		head -n 1 "${file}" | grep -qE "^# ${num}\. .+" ||
			problem "${base}: first line must be '# ${num}. Title'"
		grep -qE '^Status: (Proposed|Accepted)$' "${file}" ||
			problem "${base}: needs 'Status: Proposed' or 'Status: Accepted'"
		grep -qE '^Date: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "${file}" ||
			problem "${base}: needs 'Date: YYYY-MM-DD'"

		sections="$(grep -E '^## ' "${file}" | tr '\n' '|')"
		[[ "${sections}" == "## Context|## Decision|## Consequences|" ]] ||
			problem "${base}: sections must be exactly Context, Decision," \
				"Consequences, in that order"

		empty="$(awk '
			function flush() { if (sec != "" && !text) print sec }
			/^## / { flush(); sec = $0; text = 0; next }
			sec != "" && /[^[:space:]]/ { text = 1 }
			END { flush() }
		' "${file}" | tr '\n' ' ')"
		[[ -z "${empty}" ]] ||
			problem "${base}: empty section(s): ${empty}" \
				"(write 'Not applicable: <reason>.')"

		if [[ -f "${index}" ]] && ! grep -qF "](${base})" "${index}"; then
			problem "${base}: no link in ${index}"
		fi
	done

	if [[ -f "${index}" ]]; then
		while IFS= read -r link; do
			[[ -f "${dir}/${link}" ]] ||
				problem "${index}: link to missing file ${link}"
		done < <(grep -oE '\]\([0-9]{4}-[^)]*\.md\)' "${index}" |
			sed -E 's/^\]\(//; s/\)$//')
	fi

	[[ "${failed}" == false ]]
}

for tool in shfmt prettier shellcheck ec bats; do
	if ! command -v "${tool}" >/dev/null 2>&1; then
		log::error "${tool} not found —" \
			"see docs/control-node.md for install instructions."
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

		log::info "Checking line length (max 80 columns)..."
		check_line_length "${staged_sh[@]}"
	fi

	if [[ ${#staged_fmt[@]} -gt 0 ]]; then
		log::info "Checking JSON/Markdown formatting (prettier --check)..."
		prettier --check "${staged_fmt[@]}"
	fi

	if printf '%s\n' "${staged_files[@]}" | grep -q '^docs/decisions/'; then
		log::info "Checking ADR structure and index..."
		check_adrs
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

	log::info "Checking line length (max 80 columns)..."
	mapfile -t all_sh < <(find . -name '*.sh' -not -path './.git/*')
	check_line_length "${all_sh[@]}"

	log::info "Checking ADR structure and index..."
	check_adrs

	log::info "Verifying against .editorconfig (ec)..."
	ec -exclude "${exclude_pattern}"

	if [[ -d tests ]]; then
		log::info "Running bats test suite (tests/)..."
		bats --recursive tests/
	fi

	log::info "Check complete."
fi
