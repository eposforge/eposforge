---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Backup / Data Resilience

## Purpose

Provides a centralized, tamper-resistant backup and restore capability for the agentic factory. Ensures that the system can recover from data loss, corruption, or adversarial actions (including by a privileged agent) within a defined RPO/RTO.

## Contract

Any Adapter for this slot must:

- **Enumerate backup targets** across the substrate:
  - config-as-code
  - secrets/key material (requires offline escrow)
  - source-control data
  - spec-graph + vector stores
  - stateful service volumes
  - orchestrator/work-ledger state
  - IaC state
- Implement **scheduling with incremental/full cadence**.
- Perform **off-host / offsite replication**.
- Implement **tested restore** with verification + checksum validation on a defined cadence.
- Declare the **RPO/RTO** (Recovery Point Objective / Recovery Time Objective).
- Enforce a **retention policy**.
- Provide **tamper-resistance for the privileged-agent threat model**:
  - append-only / immutable backup target
  - backup credentials isolated from any agent-reachable runtime
- Provide **consistency hooks for stateful stores** (DB snapshot/quiesce, not a hot mid-write file copy).
- Declare **audit emission into C11** on backup, restore, and restore-test events.

## Relationships

- Cross-references from Component 9 (Source Control + CI), Component 11 (Audit & Observability), and Component 12 (Secrets & Key Management).

## Reference implementations

Recommended candidate tools for this component include **Restic**, **autorestic**,
**BorgBackup**, **Kopia**, **Velero** (for Kubernetes), and filesystem snapshots
(**ZFS/btrfs**). See
`../../03-research/01-architecture/02-components/16-backup-resilience/backup-resilience.md`
for the full catalog and trade-offs.
