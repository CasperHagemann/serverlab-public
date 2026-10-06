# Design: High Availability & Clustering

## Scope

Phase 2: second physical machine, clustering, hardware-level failover (homelab scale).

## Configuration

None.

---

## Decision records

None.

## Planned

> Not implemented.

| Item                    | Description                                                          | Depends on       |
| ----------------------- | -------------------------------------------------------------------- | ---------------- |
| Second node             | Second physical machine                                              | Phase 1 complete |
| Clustering              | Proxmox cluster of the nodes                                         | Second node      |
| Hardware-level failover | Failover between nodes                                               | Clustering       |
| Shared storage          | Required because btrfs has no `pvesr` replication (see `storage.md`) | Second node      |
