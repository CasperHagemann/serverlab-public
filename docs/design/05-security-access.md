# Design: Security & Access

> Reference: [`docs/inspiration/proxmox-guide.md`](../inspiration/proxmox-guide.md#5-security-baseline) (unvetted).

## Scope

SSH/access control, node firewall, MFA for administrators, API token scoping for scripts.

## Configuration

None.

---

## Planned

> Not implemented.

| Item                | Description                                                                | Depends on |
| ------------------- | -------------------------------------------------------------------------- | ---------- |
| SSH/access control  | Access control for the Proxmox node                                        | -          |
| Node firewall       | Firewall for the Proxmox node                                              | -          |
| Administrator MFA   | MFA for administrators                                                     | -          |
| API token scoping   | Scoped API tokens for scripts                                              | -          |
| Administrator users | Named administrator users with least-privilege roles instead of `root@pam` | -          |
| TLS certificate     | Trusted certificate for the web UI and API (ACME or custom)                | -          |

### SSH login options

No method has been chosen. Possibilities for administrator login over SSH,
alone or combined:

- Password.
- Key with a passphrase, optionally held in `ssh-agent` with confirmation
  on each use (`ssh-add -c`) or a time limit (`ssh-add -t`).
- FIDO2 hardware key (`ed25519-sk`): needs a touch, and optionally the key's
  PIN (`-O verify-required`). Needs a backup key or console access if the
  key is lost.
- MFA, for example a one-time code.
- SSH certificates.

Whatever is chosen should need one input per deployment run, see
[Design for later: full deployment in one connection](../control-node.md#design-for-later-full-deployment-in-one-connection).
