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
| `Fix surface:` | Per-repo enum from `backlog/config.toml` | Comma-separated when a change genuinely lands on more than one surface (multi-valued, same form as `Tags:`); each element is validated against the vocabulary. Parenthetical qualifiers are not vocabulary — put that detail in `Notes:` |
| `Verify with:` | One-line observable signal | |

## Conditional fields

| Field | Required when | Notes |
|---|---|---|
| `Depends on:` | Dependencies exist | Comma-separated IDs |
| `Blocks:` | Dependents exist | Comma-separated IDs |
| `Tags:` | Item belongs to one or more tags | Comma-separated per-repo vocabulary from `backlog/config.toml` (multi-valued); `Theme:` accepted as legacy alias with deprecation warning in lint. Omit if none. |
| `Supersedes:` | Item replaces an older one | Comma-separated IDs; the superseded item should add `Blocks: <this-id>` for bidirectional traceability |
| `Bundle hint:` | Co-scheduling intent exists | Omit if none |
| `Validation:` | `Status: resolved` | Summary of confirmation |
| `Resolved:` | `Status: resolved` | `YYYY-MM-DD` |
| `Slated:` | `Status: slated` | `YYYY-MM-DD` |
| `Re-evaluate by:` | `Status: slated` | `YYYY-MM-DD` (mandatory) |
| `Migration:` | Item is the owner/anchor of a named migration | Kebab-case slug (e.g. `numbered-to-named-components`). Declares the slug exists; other items reference it via `LegacyShapeOf:` / `TargetShapeOf:`. |
| `LegacyShapeOf:` | Item's work sits on the legacy side of an in-flight migration | Comma-separated migration slugs, same comma-separated style as `Blocks:`. Each slug must be declared by some item's `Migration:`. |
| `TargetShapeOf:` | Item's work sits on the target side of an in-flight migration | Comma-separated migration slugs, same comma-separated style as `Blocks:`. Each slug must be declared by some item's `Migration:`. |

## File-level rules

- `backlog.md` stores active work: `open`, `in-progress`, `blocked`.
- `backlog-slated.md` stores deferred work: `slated` only.
- `backlog-archive.md` stores resolved work under `## YYYY-MM` sections.
- `backlog-archive-index.md` is generated and should not be edited
  manually.

## Dependency-link rules

- IDs in `Depends on:`, `Blocks:`, and `Supersedes:` must resolve to an existing issue in
  active, slated, or archive files across the discovery set.
- IDs remain stable; links must never be rewritten to prose references.
- `Status: blocked` requires at least one `Depends on:` ID that is still `open`,
  `in-progress`, `blocked`, or `slated`. A blocked item with no open dependency is a
  lint error (use a blocker record — see below).

## Blocker records (EF-042)

Non-work constraints (budget, vendor dependency, hardware availability, waiting on
an external party) are tracked as ordinary backlog items with `Fix surface: external`
and a re-check cadence in `Notes:` or `Re-evaluate by:`. Items stalled by the
constraint declare `Depends on: <blocker-id>`. Resolution is recorded via the normal
`Validation:`/`Resolved:` flow.

`fix_surfaces` in `config.toml` must include `"external"` for blocker records to
pass lint.

## Migration tracking (EF-066)

`Migration:`, `LegacyShapeOf:`, and `TargetShapeOf:` make an in-flight strangler-fig
migration (see `02-roadmap/adoption-strategy.md`) legible to agents, independent of
free-text `Notes:`. Exactly one item declares a migration slug via `Migration:`; any
number of other items then declare which side of that migration they sit on via
`LegacyShapeOf:` (do not invest further here — it is being replaced) or
`TargetShapeOf:` (this is the destination shape). These are associative
migration-membership edges, **not** `Depends on:` / `Blocks:`, which continue to
drive critical-path ordering. `aggregate.sh --strangler` renders one section per
migration slug, its legacy-shape and target-shape items, and a hint for items whose
text looks migration-shaped but carry none of the three fields yet. Adopter-specific
migration IDs stay in the adopter's own backlog (EF-047 public/private boundary).

**Completeness is asymmetric.** Lint errors if a declared `Migration:` has no
`TargetShapeOf:` item — a migration must show where it is going. It only warns if
one has no `LegacyShapeOf:` item, because a migration's legacy side is sometimes
diffuse corpus state (scattered across files, not a single ticket) rather than a
real candidate item — forcing target-side work into `LegacyShapeOf:` just to
satisfy a hard rule produces a wrong "do not invest" advisory on work that should
be invested in. Do not add `LegacyShapeOf:` to an item unless its own work is
genuinely still building or extending the legacy shape.

## Validation and sweep rules

- `Status: resolved` entries must include both `Validation:` and
  `Resolved:` before sweep.
- `sweep-resolved.sh` is the only mechanism that moves resolved entries
  from active to archive and regenerates the archive index.