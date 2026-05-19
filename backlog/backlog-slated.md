# Backlog Slated

Deferred issues (`slated`) with mandatory re-evaluation dates.

## Issue EF-002 — Git-based authoritative sync from server-side post-receive or CI workflow
ID: EF-002
Title: Git-based authoritative sync from server-side post-receive or CI workflow
Date: 2026-05-17
Status: slated
Slated: 2026-05-18
Re-evaluate by: 2026-07-18
Effort: L
Fix surface: infrastructure
Depends on: EF-001
Verify with: post-receive or CI trigger updates graph on merge to default branch

## Issue EF-003 — Add --reconcile-from-disk mode on cognee-sync CLI
ID: EF-003
Title: Add --reconcile-from-disk mode on cognee-sync CLI
Date: 2026-05-17
Status: slated
Slated: 2026-05-18
Re-evaluate by: 2026-07-18
Effort: M
Fix surface: repo-instance
Depends on: EF-001
Verify with: reconcile mode removes stale graph entities not present in source docs

## Issue EF-004 — Automate ontology re-upload path for .owl extension requirement
ID: EF-004
Title: Automate ontology re-upload path for .owl extension requirement
Date: 2026-05-17
Status: slated
Slated: 2026-05-18
Re-evaluate by: 2026-06-18
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-001
Notes: client.py `upload_ontology` already renames `.ttl` → `.owl` in the multipart form, but the CLI routes all files (including TTL) through `add_file`. The grounding ontology upload path (`/api/v1/ontologies`) is never called during normal sync; only used in test fixtures. Fix: CLI should detect `.ttl`/`.owl` files and dispatch to `upload_ontology` + `cognify` with `ontologyKey`.
Verify with: ontology upload step runs from CLI without manual extension workaround

