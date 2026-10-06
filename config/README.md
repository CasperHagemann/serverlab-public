# Config

Per-node configuration files read by the scripts in
[`scripts/proxmox-node/`](../scripts/proxmox-node/), so the same script works
unchanged on every Proxmox node. How scripts use them:
[`scripts/README.md`](../scripts/README.md#configuration-pattern).

## Layout

```text
config/
  proxmox-nodes/
    <hostname>.env   one file per Proxmox node, named after its hostname
```

Scripts default to `config/proxmox-nodes/$(hostname -f).env` and accept
`--config <file>` to override.

## Format and keys

The format, the rules for keys and secrets are in
[ADR-0009](../docs/decisions/0009-node-configuration.md). Each key is
described in the design doc of its area:

| Area                | Design doc                                                        |
| ------------------- | ----------------------------------------------------------------- |
| Base system         | [`base-system.md`](../docs/design/base-system.md)                 |
| Networking          | [`networking.md`](../docs/design/networking.md)                   |
| Storage             | [`storage.md`](../docs/design/storage.md)                         |
| Resource management | [`resource-management.md`](../docs/design/resource-management.md) |

## Relationship to `inventory/`

`config/` holds the values a script applies. [`inventory/`](../inventory/)
holds the facts no script sets: the hardware and the site network plan. A value
lives in one of them, not both.
