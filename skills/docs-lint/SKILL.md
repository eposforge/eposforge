---
name: docs-lint
description: periodic semantic health check for the Markdown corpus (Karpathy LLM-Wiki lint)
---

# docs-lint

Runs a semantic health check over the spec layer (`00-vision/` through `04-standards/`), `AGENTS.md`, and `.eposforge/backlog/` to find contradictions, stale claims, orphan pages, missing cross-references, and broken pointers.

## Operations
- This is a report-only skill. Do NOT auto-edit content in the corpus.
- When run, search the target scope for semantic issues.
- Produce a findings report in `.scratchpad/docs-lint-report.md`.
- Classify each finding as one of: `contradiction`, `stale-claim`, `orphan-page`, `missing-cross-reference`, `broken-pointer`, `boundary-leak`, `component-ref`.
- For `component-ref`: flag prose that names a component (from the [Component Catalog](../../01-architecture/02-components/README.md)) as a **bare, unbracketed** word where it denotes the component and should be a shortcut reference link (`[Orchestrator]`) per [Naming Conventions](../../04-standards/01-naming-conventions/naming-conventions.md#component-references). This is the semantic half that needs concept-vs-component judgment. *Division of labor*: the deterministic, zero-false-positive classes — numeric identifiers (`C4`, `Component 14`), the deprecated `Router` name, and undefined/broken component links — live in the blocking `check-component-links.py --check` floor (wired into `doc-lint.yml`); do not re-report those here.
- For `boundary-leak`: In a `visibility = "public"` repository, flag contextual references to private repos, private backlogs, or adopter-internal work that the deterministic lint floor cannot detect (e.g., naming a private repo in prose, an adopter org/repo name, or oblique paraphrases of private work). Use the visibility map (`config.toml`) to know what is private. Genuine private-repo references (flag) are distinguished from sanctioned generic framing like "an adopter" (no flag).
  - *Division of labor*: Deterministic, zero-false-positive classes (private item-ID references via the visibility map, host paths, `*.lan`, private IPs) stay in the blocking `lint-backlog.sh` floor. Semantic/contextual detection lives here.
- Append a parseable entry to `skills/docs-lint/run-log.md` with the format `## [YYYY-MM-DD] lint | <summary>`, where `<summary>` summarizes the run.

## Target Scope
- Spec layer: `00-vision/`, `01-architecture/`, `02-roadmap/`, `03-research/`, `04-standards/`
- `AGENTS.md`
- `.eposforge/backlog/`
- OUT OF SCOPE: `.eposforge/` adapter internals, graph-side answer-quality.

## Known Seed Findings to verify
- (a) AGENTS.md §Standards points at `04-standards/04-mcp/` and `04-standards/05-canonical-doc-sources/`, neither of which exists on disk.
- (b) backlog cross-references to EF IDs that have moved to `backlog-archive.md` should be flagged with their new location.
