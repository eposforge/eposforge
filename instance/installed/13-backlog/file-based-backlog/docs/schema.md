# Backlog Schema Reference

Canonical schema for the `file-based-backlog` adapter.

## Header format

Every issue in active, slated, and archive files uses:

`## Issue <ID> — <Title>`

Example:

`## Issue EF-001 — Initial corpus seed via cognee-sync`

## Required fields

| Field | Values | Notes |
|---|---|---|
| `ID:` | `<PREFIX>-<NNN>` | Auto-assigned, immutable |
| `Title:` | One-line string | Should match issue header title |
| `Date:` | `YYYY-MM-DD` | Discovery date |
| `Status:` | `open` \| `in-progress` \| `blocked` \| `slated` \| `resolved` | |
| `Effort:` | `S` \| `M` \| `L` \| `XL` | |
| `Fix surface:` | Per-repo enum from `backlog/config.toml` | |
| `Verify with:` | One-line observable signal | |

## Conditional fields

| Field | Required when | Notes |
|---|---|---|
| `Depends on:` | Dependencies exist | Comma-separated IDs |
| `Blocks:` | Dependents exist | Comma-separated IDs |
| `Bundle hint:` | Co-scheduling intent exists | Omit if none |
| `Validation:` | `Status: resolved` | Summary of confirmation |
| `Resolved:` | `Status: resolved` | `YYYY-MM-DD` |
| `Slated:` | `Status: slated` | `YYYY-MM-DD` |
| `Re-evaluate by:` | `Status: slated` | `YYYY-MM-DD` (mandatory) |

## File-level rules

- `backlog.md` stores active work: `open`, `in-progress`, `blocked`.
- `backlog-slated.md` stores deferred work: `slated` only.
- `backlog-archive.md` stores resolved work under `## YYYY-MM` sections.
- `backlog-archive-index.md` is generated and should not be edited
  manually.

## Dependency-link rules

- IDs in `Depends on:` and `Blocks:` must resolve to an existing issue in
  active, slated, or archive files across the discovery set.
- IDs remain stable; links must never be rewritten to prose references.

## Validation and sweep rules

- `Status: resolved` entries must include both `Validation:` and
  `Resolved:` before sweep.
- `sweep-resolved.sh` is the only mechanism that moves resolved entries
  from active to archive and regenerates the archive index.