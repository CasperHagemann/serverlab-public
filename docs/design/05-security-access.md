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
