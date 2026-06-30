# EF-047 — Restore + enforce the public/private backlog boundary

Status: plan (open) · Date: 2026-06-16 · Effort: M · Theme: backlog-tooling

## Problem

The publishable framework repo (`/mnt/raid-storage/src/git/gh/eposforge`) is the
open-source product, but its backlog currently embeds adopter-internal references.
Found 2026-06-16 during portfolio-review:

| # | Leak | Where | Kind |
|---|------|-------|------|
| 1 | `Blocks:` line pointing at two <adopter> adopter IDs | EF-032 | **structural edge** (worst — shows up in `--graph`, ingested as a relationship) |
| 2 | absolute private host path `/mnt/raid-storage/src/git/local/dark-factory-reference-architecture.mmd` | EF-026, EF-029 notes | prose |
| 3 | "<adopter> LAN" in title + verify-with | EF-023, EF-024 | prose / scope |
| 4 | named adopter example "<AdopterName> … <AdopterShort> copy" | EF-022 notes | prose |

## Rule (ratified by architect 2026-06-16)

Public/publishable repos using the eposforge backlog **must never reference
non-public backlog items**. Cross-repo edges are **directional**: the
private/adopter item declares `Depends on: <public-repo>:<ID>`; the public item
never names a private ID. (See memory `project-public-backlog-no-private-refs`,
and EF-011 — this is the backlog-layer face of the framework-vs-adopter boundary.)

This work has two separable halves: **restore** (clean the current leaks) and
**enforce** (a lint rule so it can't regress).

---

## Phase 1 — Restore (concrete cleanup, git-reversible)

1. **EF-032 structural edge** — delete the `Blocks: <adopter>-…` line. Lossless: the
   adopter side already carries `Depends on: eposforge:EF-032` (and `…:EF-031`),
   so the relationship survives where it belongs.
2. **EF-026 / EF-029 host path** — replace the absolute
   `/mnt/raid-storage/...dark-factory-reference-architecture.mmd` with a generic
   reference ("an adopter's reference-architecture diagram"), or relocate the
   diagram into the framework repo if it is meant to ship. Default: genericize.
3. **EF-022 prose** — "<AdopterName> single-vault migration" / "the duplicated
   <AdopterShort> copy" → "an adopter's single-vault migration" / "the duplicated adopter
   copy."
4. **EF-023 / EF-024 — DECISION PENDING (do not execute blind):** these are scoped
   to "<adopter> LAN" in their *titles*, which may mean they are adopter work
   misfiled in the framework backlog rather than framework items needing a wording
   pass. Resolve first:
   - **sanitize-in-place** — keep as a framework observability/memory pattern;
     "<adopter> LAN" → "the adopter's LAN" / "LAN-local"; **or**
   - **relocate** — move EF-023/EF-024 into the adopter backlog as `<adopter>-` items.
   Phase 1 sanitizes #1–#3 immediately; #4 waits on this call.

**Phase 1 verify:** `grep -nE '<adopter-name-patterns>|/mnt/raid-storage|\.lan'  # (see check-sensitive-literals.sh for current patterns)
.eposforge/backlog/backlog.md` returns only intentional matches (e.g. operational
header notes), and no `^Blocks:`/`^Depends on:` field in a public-repo item names
a private ID.

---

## Phase 2 — Enforce (lint rule)

### 2a. Visibility metadata
Add `visibility = "public" | "private"` to each `config.toml`:
- `eposforge` (framework) → `public`
- primary adopter, IAC, and other adopters (adopters) → `private`
- **Unset → treated as `private`** (fail-safe; only an explicit `public` opts a
  repo into outbound-reference scrutiny).

### 2b. Lint check (`lint-backlog.sh`)
- `parse_config`: read `visibility`.
- With multi-root context (`BACKLOG_ROOTS`), build a `{prefix: visibility}` map
  across all roots.
- For each item in a **public** repo, extract every cross-repo `<prefix>:<ID>`
  reference from `Depends on:` / `Blocks:`. If the referenced prefix resolves to
  `private` (or is unknown) → **ERROR**:
  `"<id> (public) references non-public <ref>; declare the edge on the private side."`
- **Single-root degradation:** when foreign visibility can't be resolved (lint run
  against one root), a public repo carrying *any* foreign-prefix edge is flagged —
  the framework is the only public repo here, so any outbound cross-repo edge from
  it is suspect. Document this in the lint help.

### 2c. Prose heuristic (optional, WARNING not ERROR)
Scan public-repo item text for private markers — absolute host paths (`/mnt/...`),
`*.lan`, private IPv4, known adopter names — and emit warnings. Lower confidence;
never blocks. Catches the #2–#4 class before it ships.

**Phase 2 verify:** with the visibility flags set, re-introducing a
`Blocks: <private>:<ID>` to any framework item makes `lint-backlog.sh` exit
non-zero with the boundary error; after Phase 1 the lint passes clean across all
roots.

---

## Acceptance (whole item)

- All leaks in the table are gone (Phase 1), EF-023/024 decision recorded.
- `visibility` declared in all 6 configs; `eposforge = public`.
- Lint errors on a public→private edge and passes post-cleanup across all roots.
- Lint help documents the rule + the single-root degradation.

## Out of scope / siblings

- **Wider repo audit** — the same public→private scan likely belongs across the
  whole `eposforge` repo (specs, `AGENTS.md`, runbooks), not just the backlog.
  Separate effort; this item is backlog-scoped.
- **EF-046** (Theme→Tags) — independent; sequence either order.

## Adjacency

EF-011 / EF-012 (framework-vs-adopter conflation — same boundary, spec-graph
layer); EF-046 (sibling backlog-tooling change); EF-032 (the structural-edge
leak this removes).
