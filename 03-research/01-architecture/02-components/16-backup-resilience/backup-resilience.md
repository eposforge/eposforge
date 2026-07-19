---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Component 16: Backup / Data Resilience — Implementation Catalog

Candidate Adapters for the Backup / Data Resilience slot.

## Candidates

### Restic
- **Type**: CLI backup program.
- **Notes**: Fast, secure, efficient backup program.

### autorestic
- **Type**: Restic wrapper.
- **Notes**: YAML-based config for Restic.

### BorgBackup
- **Type**: Deduplicating backup program.
- **Notes**: Supports compression and authenticated encryption.

### Kopia
- **Type**: Backup tool.
- **Notes**: Fast and secure open-source backup tool.

### Snapshot-based options
- **ZFS/btrfs snapshots**
- **cloud-native volume snapshots**
- **Velero for k8s**
