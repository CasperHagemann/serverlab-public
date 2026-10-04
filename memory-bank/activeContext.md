# Active Context

## Current focus

Documentation is strict and factual: Configuration states what is live,
plans are in a separate Planned section, reasoning for decisions is in ADRs.
The repository is considered ready for public release.

## Proxmox node state (`pve.kiwik.org`)

Minisforum MS-A2, AMD Ryzen 9 9955HX, 29 GiB usable RAM, Kingston 1 TB NVMe.
Proxmox VE 9.2 (Debian 13 trixie).

- `vmbr0` on `nic0` (management, 192.168.88.101/24) from install.
- `vmbr1` on `nic1` (general VM) created by `scripts/proxmox-node/10-network.sh`.
- `local-data` (`nvme0n1p4`, btrfs, ~853 GiB) created by
  `scripts/proxmox-node/20-storage.sh`; `local` and `local-btrfs` disabled.
- Values: `inventory/`, `config/proxmox-nodes/pve.kiwik.org.env`.

## Next steps

1. Planned Proxmox-node work is listed in the Planned section of each
   `docs/design/` doc (post-install tasks in 02, I/O weighting in 04,
   security, backup, monitoring, HA).
2. Optional: GitHub Actions workflow running the same checks as a required
   PR status check.

## Preferences

**Documentation**

- Facts only: no advice, suggestions, conversation, or diary wording.
- Planned items go in their own clearly separated section, never mixed with
  implemented content.
- Rejected alternatives and their reasoning go in ADRs, not design docs.
- No "TBD", "stub", or "once hardware arrives" wording. Hardware is
  received and inventory is current.
- Inventory files hold concrete values only.
- Use "control node" (where development happens) and
  "Proxmox node". Never "workstation".
- Hidden folders (`.agents/`, `.cline/`, and `.clinerules/` except
  `.clinerules/custom/`) are kept as they are. `.clinerules/custom/` holds
  project rules written by hand, always active (no frontmatter).

**Scripts and workflow**

- Explicit, non-mutating pre-commit behaviour.
- No automatic rollback in Proxmox-node scripts; stop and report.
- No extra packages on the Proxmox node.
- Manual `remote-run.sh` verification (dry-run, decline, `--yes`, re-run) is
  sufficient; no automated Proxmox-node test runner.
- MCP server versions are not pinned.
- Show fetched web content collapsed; present only conclusions and relevant
  facts.
- Use absolute paths for file references.

## Learnings

- `git reset --hard` discards uncommitted changes; prefer `--soft`,
  `--mixed`, or `git revert` when uncommitted work exists.
- Verify state with separate commands rather than `&&` chains.
- `ec` checks untracked files, which can produce unexpected failures.
