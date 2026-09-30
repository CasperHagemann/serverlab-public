# Design: High Availability & Clustering

> Reference: [`docs/inspiration/proxmox-guide.md`](../inspiration/proxmox-guide.md#11-high-availability-optional) (unvetted).

## Scope

Phase 2: second physical machine, clustering, hardware-level failover (homelab scale).

## Configuration

None.

---

## Planned

> Not implemented.

| Item                    | Description                                                             | Depends on       |
| ----------------------- | ----------------------------------------------------------------------- | ---------------- |
| Second node             | Second physical machine                                                 | Phase 1 complete |
| Clustering              | Proxmox cluster of the nodes                                            | Second node      |
| Hardware-level failover | Failover between nodes                                                  | Clustering       |
| Shared storage          | Required because btrfs has no `pvesr` replication (see `04-storage.md`) | Second node      |
