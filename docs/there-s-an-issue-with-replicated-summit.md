# Plan: `04-standards/` section + research mirror refactor

## Context

EposForge needs a top-level home for cross-cutting **adopted standards** (Agent Skills, MCP, naming conventions, vocabulary, canonical doc sources). Today these rules are scattered through `AGENTS.md` and `00-vision/01-glossary.md` with no single normative location.

Adding the new section exposed a deeper structural issue: `03-research/` previously used a flat per-component layout that did **not** mirror where the architecture content actually lives (`01-architecture/02-components/01-spec-input.md`). The research catalog and the thing it's research *for* had drifted out of structural alignment.

This plan makes three changes:

1. Introduce `04-standards/` as the source of truth for adopted standards.
2. Refactor `03-research/` so that every research path mirrors the source path of the thing it researches.
3. Adopt a new standard — the **research-mirror standard** — that protects the mirror against future refactors. Agent instructions point at it; the standard itself owns the rule.

Goal: standards adoption is auditable, research paths are predictable from source paths, and the structural invariant survives refactors because it is itself an adopted standard.

Constraint: GEA depends on EposForge, never the reverse. This change is entirely internal to EposForge.

## Locked decisions

- AGENTS.md normative sections move to `04-standards/`; AGENTS.md retains thin pointers.
- Adoption is recorded ADR-style in a **Status** block inside each standard file (date, supersedes, declined-options link). No separate ADR folder.
- All EposForge content must conform to adopted standards.
- `04-standards/` and `03-research/04-standards/` use **subfolder-per-standard** with identical folder names on both sides.
- Mirror is **need-based**: `03-research/` only contains paths that have actual research content. Empty mirror folders are not created speculatively.
- Cross-cutting root files (`03-research/README.md`, `03-research/landscape.md`) stay at the research root; they are not part of the mirror.
- The mirror invariant is owned by a new adopted standard (`04-standards/06-research-mirror/`); AGENTS.md only points at it.

## Mirror rule (the new invariant)

For any source file `<repo-root>/<path>/<file>.md`, its research lives at `03-research/<path>/<file>/...` (folder, may contain one or more descriptively-named .md files).

Examples:

- `01-architecture/02-components/01-spec-input.md` → research at `03-research/01-architecture/02-components/01-spec-input/`
- `04-standards/01-naming-conventions/naming-conventions.md` → research at `03-research/04-standards/01-naming-conventions/`
- `01-architecture/00-adapter-pattern.md` → research at `03-research/01-architecture/00-adapter-pattern/` (created only if/when research is added)

File names *inside* mirrored folders are content-descriptive — not pinned to match the source filename — matching the existing `03-research/01-architecture/02-components/03-dev-product/dev-products.md` convention.

## Target folder structure (after refactor)

```text
04-standards/
  README.md
  00-standards-meta/standards-meta.md
  01-naming-conventions/naming-conventions.md
  02-vocabulary/vocabulary.md
  03-agent-skills/agent-skills.md
  04-mcp/mcp.md
  05-canonical-doc-sources/canonical-doc-sources.md
  06-research-mirror/research-mirror.md

03-research/
  README.md                                          (cross-cutting, stays at root)
  landscape.md                                       (cross-cutting, stays at root)
  01-architecture/
    02-components/
      01-spec-input/spec-input.md                    (moved from prior flat component folders)
      02-living-spec/living-spec.md                  (moved)
      03-dev-product/dev-products.md                 (moved)
      04-router/router.md                            (moved)
      05-tool-transport/tool-transport.md            (moved)
      06-spec-graph/spec-graph.md                    (moved)
      06-spec-graph/graphrag-neo4j-integration.md    (moved)
      07-execution-sandbox/execution-sandbox.md      (moved)
      09-source-control-ci/source-control-ci.md      (moved)
      10-inference/inference.md                      (moved)
      11-audit-observability/audit-observability.md  (moved)
      12-secrets-key-management/secrets-key-management.md (moved)
  04-standards/
    01-naming-conventions/case-and-prefix-options.md
    (and one folder per populated standard)
```

Notes:

- Component 8 (Agent Policy) has no research today; no folder is created. The mirror is *need-based*.
- Component 9b (Release Rings) has no research today; same.

## Standard file template

Frontmatter: `doc_kind: standard`, `scope: eposforge-pattern`, `maturity: adopted | provisional | superseded`, `source_of_truth: yes`.

Required H2 sections, in order:

- **Status** — `adopted: YYYY-MM-DD`, `supersedes:` (path or `none`), `declined-options:` (relative link to the matching `03-research/04-standards/<n>-<slug>/` folder), external `spec-version:` if applicable.
- **Scope** — what this standard governs; what it does not.
- **Normative requirements** — numbered MUST/SHOULD/MAY clauses.
- **Conformance** — how to check (grep pattern, lint hook, validator).
- **Related** — links to components, other standards, external spec source.

## The `06-research-mirror` standard (preview of its normative content)

- MUST: every file under `03-research/<path>/` corresponds to a real source file at `<repo-root>/<path>.md`. Orphans are a conformance failure.
- MUST: when refactoring source paths (rename/move/delete), the matching `03-research/<path>/` folder moves with it in the same change.
- MAY: research folder remain empty-of-files (subfolders only) during a transition, but SHOULD be deleted if it stays empty.
- MAY: filenames inside a research folder be content-descriptive (need not match the source file name).
- Conformance check: a tree-diff script that lists `03-research/` paths and verifies each non-cross-cutting path resolves to a `.md` file at the corresponding source location.

## Files to create (scaffolding pass)

- `04-standards/README.md`
- `04-standards/00-standards-meta/standards-meta.md`
- `04-standards/01-naming-conventions/naming-conventions.md` (lift from `AGENTS.md` lines 191–215)
- `04-standards/06-research-mirror/research-mirror.md` (defines the mirror invariant)
- `03-research/04-standards/01-naming-conventions/case-and-prefix-options.md` (declined alternatives)
- `03-research/04-standards/06-research-mirror/structural-alternatives.md` (declined: flat per-component, sibling `standards/`, etc.)

## Files to move (research refactor)

All under `03-research/` get prefixed with `01-architecture/02-components/`:

- `01-spec-input/` → `01-architecture/02-components/01-spec-input/`
- `02-living-spec/` → `01-architecture/02-components/02-living-spec/`
- `03-dev-product/` → `01-architecture/02-components/03-dev-product/`
- `04-router/` → `01-architecture/02-components/04-router/`
- `05-tool-transport/` → `01-architecture/02-components/05-tool-transport/`
- `06-spec-graph/` → `01-architecture/02-components/06-spec-graph/`
- `07-execution-sandbox/` → `01-architecture/02-components/07-execution-sandbox/`
- `09-source-control-ci/` → `01-architecture/02-components/09-source-control-ci/`
- `10-inference/` → `01-architecture/02-components/10-inference/`
- `11-audit-observability/` → `01-architecture/02-components/11-audit-observability/`
- `12-secrets-key-management/` → `01-architecture/02-components/12-secrets-key-management/`

Use `git mv` to preserve history.

## Files to edit

- `AGENTS.md` — collapse §Vocabulary, §Authoritative-docs MCPs, §Conventions into a single `## Standards` H2 with bullet pointers to `04-standards/`. Add one line pointing at `04-standards/06-research-mirror/` under a refactoring-discipline note.
- `03-research/README.md` — rewrite the Organization section. Replace "Each subdirectory corresponds to a component" with the mirror rule: "Research paths mirror source paths. Research for `<path>.md` lives at `03-research/<path>/`. The mirror is need-based — folders exist only when populated. See `04-standards/06-research-mirror/` for the normative rule." Replace the per-component table with a generated/illustrative listing of currently-populated paths.
- `README.md` — add `04-standards/` row to the §How to read code block and to the §Repository Layers table.
- `00-vision/01-glossary.md` — add header note pointing at `04-standards/02-vocabulary/` when that standard lands.
- `01-architecture/00-adapter-pattern.md` — `invocation_surface` bullet gains "see `04-standards/04-mcp/` and `04-standards/03-agent-skills/`" once those land.
- `.github/workflows/doc-lint.yml` — extend glob from `03-research/**` to also cover `04-standards/**` and the new `03-research/01-architecture/**` deep paths.
- Update internal cross-references to moved research files. Search pattern: `03-research/<old-component-folder>` across the entire repo.

## Migration order

1. **PR 1 — Mirror standard + research refactor.** Create `04-standards/06-research-mirror/research-mirror.md`, its declined-alternatives counterpart, and the meta-standard (`00-standards-meta`). Move all 11 component research folders into `01-architecture/02-components/` via `git mv`. Update `03-research/README.md` and any internal links. Status: mirror is adopted and the existing research is already conformant.
2. **PR 2 — Naming conventions.** Create `04-standards/01-naming-conventions/`, lift from AGENTS.md, replace AGENTS.md §Conventions with a pointer.
3. **PR 3 — Vocabulary.** Same shape; dedupe against `00-vision/01-glossary.md`.
4. **PR 4 — Canonical doc sources.** Lift AGENTS.md §Authoritative-docs MCPs.
5. **PR 5 — MCP standard.** Needs research-side justification.
6. **PR 6 — Agent Skills standard.** Most external-spec citation work.

Within each PR: standard content moves before its source section becomes a pointer. Never leave both copies normative.

## Verification

After PR 1 (the structural change):

1. Directory check: `04-standards/` exists with `00-standards-meta/`, `06-research-mirror/`, `README.md`. `03-research/` no longer has top-level component folders; they live under `01-architecture/02-components/`.
2. Mirror conformance: for every `.md` file under `03-research/` (excluding the two cross-cutting root files), the path with `03-research/` stripped resolves to an existing `.md` at the repo root. Run a one-shot script that walks `03-research/` and stat-checks the corresponding source path.
3. `grep -r "03-research/<legacy-flat-component-folder>" .` returns no hits.
4. Rebuild the Spec Graph (`bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh`). Query Cognee: *"Which standards has EposForge adopted?"* — should return the mirror standard and the meta-standard. Verify research file entities now link under their new mirrored paths.
5. Open `AGENTS.md` and confirm any reference to refactoring-discipline points at `04-standards/06-research-mirror/`.

After each subsequent PR: confirm the lifted AGENTS.md / glossary section is now a pointer and no normative prose duplicate survives anywhere (`grep` the unique phrase).

## Out of scope

- GEA-side changes. GEA depends on EposForge; if GEA wants to consume these standards, that change happens in GEA.
- Lint tooling beyond extending the existing doc-lint glob and adding the mirror tree-diff script.
- Renumbering or restructuring `01-architecture/02-components/` itself.
- Promotion-lifecycle automation. Manual Status-block edits are sufficient at this stage.
