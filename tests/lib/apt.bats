#!/usr/bin/env bats
#
# apt.bats — tests for scripts/lib/apt.sh

setup() {
	LIB_DIR="${BATS_TEST_DIRNAME}/../../scripts/lib"
	source "${LIB_DIR}/apt.sh"
	SRC="${BATS_TEST_TMPDIR}/pve-enterprise.sources"
	cat >"${SRC}" <<-'EOF'
		Types: deb
		URIs: https://enterprise.proxmox.com/debian/pve
		Suites: trixie
		Components: pve-enterprise
		Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
	EOF
}

@test "apt::field prints the value of a field" {
	run apt::field "${SRC}" Suites
	[ "$status" -eq 0 ]
	[ "$output" == "trixie" ]
	run apt::field "${SRC}" URIs
	[ "$output" == "https://enterprise.proxmox.com/debian/pve" ]
}

@test "apt::field prints nothing for a missing field" {
	run apt::field "${SRC}" Architectures
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "apt::field reads only the first stanza and skips leading comments" {
	local f="${BATS_TEST_TMPDIR}/two.sources"
	cat >"${f}" <<-'EOF'
		# comment

		Types: deb
		Suites: trixie trixie-updates

		Types: deb
		Suites: trixie-security
		Components: main
	EOF
	run apt::field "${f}" Suites
	[ "$output" == "trixie trixie-updates" ]
	run apt::field "${f}" Components
	[ -z "$output" ]
}

@test "apt::render_source prints a header and one deb stanza" {
	run apt::render_source http://example/pve trixie pve-no-subscription /k.gpg
	[ "$status" -eq 0 ]
	[ "${lines[0]}" == "# Managed file - local changes may be overwritten." ]
	[ "${lines[1]}" == "Types: deb" ]
	[ "${lines[2]}" == "URIs: http://example/pve" ]
	[ "${lines[3]}" == "Suites: trixie" ]
	[ "${lines[4]}" == "Components: pve-no-subscription" ]
	[ "${lines[5]}" == "Signed-By: /k.gpg" ]
	[ "${#lines[@]}" -eq 6 ]
}

@test "apt::disable_source appends Enabled: no to the stanza" {
	run apt::disable_source "${SRC}"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" == "Types: deb" ]
	[ "${lines[4]}" == "Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg" ]
	[ "${lines[5]}" == "Enabled: no" ]
	[ "${#lines[@]}" -eq 6 ]
}

@test "apt::disable_source replaces an existing Enabled line" {
	printf 'Enabled: yes\n' >>"${SRC}"
	run apt::disable_source "${SRC}"
	[ "${#lines[@]}" -eq 6 ]
	[ "${lines[5]}" == "Enabled: no" ]
}

@test "apt::disable_source is idempotent" {
	apt::disable_source "${SRC}" >"${BATS_TEST_TMPDIR}/once"
	apt::disable_source "${BATS_TEST_TMPDIR}/once" >"${BATS_TEST_TMPDIR}/twice"
	cmp "${BATS_TEST_TMPDIR}/once" "${BATS_TEST_TMPDIR}/twice"
}

@test "apt::disable_source handles several stanzas and skips non-stanzas" {
	local f="${BATS_TEST_TMPDIR}/multi.sources"
	cat >"${f}" <<-'EOF'
		Types: deb
		Suites: a

		# just a comment

		Types: deb
		Suites: b
	EOF
	local expected="${BATS_TEST_TMPDIR}/expected"
	cat >"${expected}" <<-'EOF'
		Types: deb
		Suites: a
		Enabled: no

		# just a comment

		Types: deb
		Suites: b
		Enabled: no
	EOF
	# Compared as a whole file: bats' `lines` drops blank lines.
	apt::disable_source "${f}" >"${BATS_TEST_TMPDIR}/actual"
	cmp "${expected}" "${BATS_TEST_TMPDIR}/actual"
}

@test "apt::is_disabled succeeds only when Enabled: no is set" {
	run apt::is_disabled "${SRC}"
	[ "$status" -ne 0 ]
	apt::disable_source "${SRC}" >"${BATS_TEST_TMPDIR}/off"
	run apt::is_disabled "${BATS_TEST_TMPDIR}/off"
	[ "$status" -eq 0 ]
	printf 'Enabled: yes\n' >>"${SRC}"
	run apt::is_disabled "${SRC}"
	[ "$status" -ne 0 ]
}

@test "apt::error_lines keeps only E: and Err: lines" {
	run apt::error_lines <<-'EOF'
		Hit:1 http://deb.debian.org/debian trixie InRelease
		Err:2 https://enterprise.proxmox.com/debian/pve trixie InRelease
		  401  Unauthorized [IP: 1.2.3.4 443]
		W: some warning
		E: Failed to fetch https://enterprise.proxmox.com/debian/pve
	EOF
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -eq 2 ]
	[ "${lines[0]}" == "Err:2 https://enterprise.proxmox.com/debian/pve trixie InRelease" ]
	[ "${lines[1]}" == "E: Failed to fetch https://enterprise.proxmox.com/debian/pve" ]
}

@test "apt::error_lines prints nothing and succeeds for clean output" {
	run apt::error_lines <<-'EOF'
		Hit:1 http://deb.debian.org/debian trixie InRelease
	EOF
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "apt::ceph_nosub_uri maps the enterprise URI to the no-subscription one" {
	run apt::ceph_nosub_uri https://enterprise.proxmox.com/debian/ceph-squid
	[ "$status" -eq 0 ]
	[ "$output" == "http://download.proxmox.com/debian/ceph-squid" ]
}

@test "apt::ceph_nosub_uri rejects other URIs" {
	run apt::ceph_nosub_uri https://enterprise.proxmox.com/debian/pve
	[ "$status" -ne 0 ]
	run apt::ceph_nosub_uri http://example.com/ceph-squid
	[ "$status" -ne 0 ]
	run apt::ceph_nosub_uri ""
	[ "$status" -ne 0 ]
}
