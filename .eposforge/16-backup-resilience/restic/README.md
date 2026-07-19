---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Restic Adapter

This adapter implements Component 16 (Backup / Data Resilience) using `restic`.

## Adapter Metadata

| Field | Value |
|---|---|
| `name` | `restic-backup` |
| `component` | `backup-resilience` |
| `version` | `0.1.0` |
| `privacy_posture` | `private` |
| `cost_hint` | Low (depends on storage backend) |
| `capabilities` | incremental-backup, encrypted-backup, offsite-replication |
| `invocation_surface` | CLI / cron invoked on the host machine |
| `status` | `experimental` |
| `targets` | `.eposforge/spec-graph/cognee/data/`, `.eposforge/secrets-key-management/` |
| `replication` | Off-host replication to an append-only object store |

## Backup Strategy & Targets

The adapter defines the following backup targets:
- Knowledge Graph Data: `.eposforge/spec-graph/cognee/data/cognee_system`
- Vault State: `.eposforge/secrets-key-management/`

## Schedule & Cadence

- **Incremental Backups**: Run automatically every hour via cron to capture recent changes.
- **Full Backups / Snapshots**: Tagged snapshots taken daily. Restic naturally handles deduplication.

## Security & Resilience

- **Off-host / Offsite Replication**: Data is synced to an external, offsite target (e.g., S3 or Backblaze B2) to protect against local host failure.
- **Append-only / Immutable Target**: The remote storage bucket is configured with append-only access. Malicious actors or compromised agents cannot delete or overwrite historical backups.
- **Backup-Credential Isolation**: Credentials for the Restic repository (passwords, AWS keys) are stored purely on the host environment and are strictly isolated from the agent-reachable runtime. Agents have zero access to backup credentials.

## Validation & Observability

- **Tested-Restore Hook**: A weekly automated hook `restic restore` verifies backup integrity and alerts on failure.
- **C11 Audit Emission**: Every successful snapshot, restore test, or failure emits a log event to Component 11 (Audit & Observability).
