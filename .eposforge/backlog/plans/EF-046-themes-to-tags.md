# EF-046 — Convert `Theme:` (single-valued) → `Tags:` (multi-valued)

Status: plan (open) · Date: 2026-06-16 · Effort: M · Theme: backlog-tooling

## Problem

The backlog `Theme:` field (added by EF-037) is **single-valued**, which forces a
false either/or at classification time. Real items belong to several concerns at
once:

- EF-044 — `backlog-tooling` **and** `simplification`
- EF-027 — `agent-policy` **and** `content-safety`
- EF-030 / EF-031 — `skills` plus their domain (`spec-graph`, …)

Single-valued themes also make the `--themes` portfolio view lossy: an item is
filed under one cluster when it genuinely bridges two.

## Decision

Replace single-valued `Theme:` with multi-valued `Tags:` (comma-separated, same
inline-CSV style as `Depends on:` / `Blocks:`).

### Data model

| Construct | Edge type | Cardinality | Field |
|---|---|---|---|
| **Tags** | associative grouping (undirected) | many per item | `Tags: a, b, c` |
| **Dependencies** | directional (`A → B`) | many per item | `Depends on:` / `Blocks:` |
| **Anchors / role** | unchanged | — | `role` in `config.toml`; anchor = ordinary item |

Tags are *grouping* edges (item ↔ tag-node) and remain strictly distinct from the
*directional dependency* edges that drive critical-path ordering. This change does
**not** touch `Depends on:` / `Blocks:`.

## Scope (verified surface area, 2026-06-16)

- **Scripts (2):** `lint-backlog.sh` (parse + validate), `aggregate.sh`
  (`--themes` grouping, `--mermaid` subgraphs). `ready.sh`, `new-issue.sh`,
  `sweep-resolved.sh` do **not** reference themes.
- **Configs (6):** `themes = [...]` vocab in EF, the primary adopter, OAPI, OA, EXR; IAC empty.
- **Docs:** `docs/schema.md:33` (`Theme:` row); Living Spec command list
  (`--themes`); `portfolio-review` + `milestone-elicitation` skill text.
- **Data:** ~82 `Theme:` lines across 8 backlog files (active/slated/archive) in
  4 repos.

## Steps

1. **Config vocab rename** — `themes = [...]` → `tags = [...]` in all 6
   `config.toml`. Parsers read `tags`, falling back to `themes` (one-version grace
   alias).

2. **`aggregate.sh` parser**
   - `parse_config` (~L89–93): read `tags`, fall back to `themes`.
   - Issue extraction (~L289): replace scalar `"theme"` with
     `"tags": [t.strip() for t in fields.get("Tags", fields.get("Theme","")).split(",") if t.strip()]`.
   - `--themes` mode (~L332–426): add `--tags` (keep `--themes` as alias). Append
     each item under **every** tag it carries. "Unanchored" = **empty tags AND**
     no `Blocks:` path to an anchor. Non-vocab tags still report under
     "(not in vocab)".

3. **`lint-backlog.sh` validation** (~L300–303): split `Tags:` on commas; error
   per tag not in vocab. Emit a **deprecation warning** when a legacy `Theme:`
   line is found (until the alias is removed in a later version).

4. **`--mermaid` — Option A (ratified 2026-06-16)** (~L505–561). Mermaid
   `subgraph` requires each node in exactly one subgraph, so:
   - **Primary tag = first tag in the list** → subgraph membership.
   - Remaining tags rendered via node `classDef` styling (so multi-membership is
     still visible without breaking the nesting).
   - Regenerate `backlog/portfolio.md`.

5. **Migration (mechanical, git-reversible)**
   - Rewrite `^Theme: (.*)$` → `^Tags: \1$` across the 8 backlog files.
   - Rename `themes =` → `tags =` across the 6 configs.
   - Re-tag the first beneficiaries: EF-044 → `backlog-tooling, simplification`;
     EF-030 / EF-031 → `skills` (+ domain); EF-027 → `agent-policy, content-safety`.

6. **Docs + version**
   - `docs/schema.md:33`: `Theme:` row → `Tags:` (CSV, multi-valued, per-repo vocab).
   - Living Spec: bump `version` 0.2.0 → **0.3.0** (also reconcile with `VERSION`
     0.2.2), update command list to `--tags`.
   - Update `portfolio-review` + `milestone-elicitation` skill text
     (`Theme:` / `--themes` references).
   - `scripts/VERSION` → 0.3.0.

## Acceptance

- All configs use `tags = [...]`; `themes = [...]` still parses (alias).
- `Tags: a, b` parses to a list; legacy `Theme:` parses with a lint warning.
- Lint errors per invalid tag; passes across all roots after migration.
- `aggregate.sh --tags` (and `--themes` alias) lists multi-tagged items under
  every tag; unanchored set is empty-tags ∧ no-Blocks-path.
- `--mermaid` keeps subgraphs (primary tag) + classDef styling for extra tags;
  `portfolio.md` regenerates cleanly.

## Out of scope (sibling items)

- **Directional-leak lint** — enforce "public repo items never reference
  non-public IDs" (needs a `visibility`/public flag in `config.toml`). Separate EF
  item; see memory `project-public-backlog-no-private-refs`.
- **EF-032 `Blocks: the primary adopter-012, the primary adopter-015` leak fix** — 1-line delete (the the primary adopter-side
  `Depends on:` already carries it); do independently.

## Adjacency

EF-037 (added the `Theme:` field whose cardinality this evolves); EF-039 / EF-040 /
EF-041 (portfolio tooling consuming the groupings); EF-044 (first multi-tag
beneficiary).
