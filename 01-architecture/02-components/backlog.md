---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 13: Backlog

## Purpose

A structured, load-rule-aware work-item tracker optimized for
AI-augmented workflows. This slot lets operators and agents keep durable,
uniquely identified issues, aggregate work across multiple repositories,
and perform regression research by traversing archived history.

## Contract

Any Adapter for this slot must:

- Provide durable, uniquely identified work items with stable cross-repo
  IDs in `<PREFIX>-<NNN>` format, with `repo_prefix` declared per repo.
- Support at least these states: active (`open`, `in-progress`,
  `blocked`), deferred (`slated`), and resolved (`resolved`).
- Enforce a machine-readable schema containing effort sizing,
  fix-surface classification, dependency links, and verification
  criteria.
- Implement load-rule-based file split so AI context windows only load
  required state (`active`, `slated`, and `archive` split into distinct
  files with documented load rules).
- Provide cross-repo aggregation so one invocation can return a unified
  queue when multiple repos implement this slot.
- Support dependency graph traversal where `Depends on` and `Blocks`
  links use stable IDs resolvable at aggregate time.
- Provide local lint/validate suitable for pre-commit and CI without
  requiring hosted services.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `repo_prefix` — short uppercase ID prefix for this repo (for example,
  `EF`, `OA`).
- `discovery_method` — how peers are discovered:
  `workspace-file` | `env-var` | `explicit-roots`.
- `archive_format` — archive storage mode. Default:
  `single-file-with-index`.

## Observable Behavior

1. Operator or agent creates a new issue and receives the next immutable
   ID for the repository prefix.
2. Lint validates schema fields, state-dependent requirements, and
   dependency-link resolvability.
3. Sweeping moves resolved entries from active storage into archive and
   refreshes a searchable archive index.
4. Aggregation discovers participating repos and renders a unified plan
   view over active and deferred work.

## Inputs / outputs

### Inputs

| Input | Description |
|---|---|
| Active backlog file | Open, in-progress, blocked entries |
| Slated backlog file | Deferred entries with re-evaluation dates |
| Archive backlog file | Resolved entries |
| Adapter config | Prefix, fix-surface enum, discovery behavior |
| Discovery roots | Workspace file, environment variable, or explicit roots |

### Outputs

| Output | Description |
|---|---|
| New issue entry | Appended issue template with next stable ID |
| Lint report | Field-level pass/fail validation for backlog files |
| Unified planning view | Aggregated active and slated queues across repos |
| Archive index | Searchable summary table of resolved issues |

## Dependencies

| Dependency | Role |
|---|---|
| Local filesystem | Durable issue storage |
| Git | Staged-file lint checks and repo-root resolution |
| Shell runtime | Script execution in local dev and CI |
| Optional Python runtime | Workspace-file JSON parsing and richer validation |

## Non-functional bounds

| Bound | Value |
|---|---|
| Durability | Issue IDs are immutable once assigned |
| Portability | Runs on Linux and Git Bash without hosted services |
| Auditability | Plain-text files with deterministic validation and indexing |
| AI context fit | Split files reduce token load by state |

## Versioning policy

- `0.x` is experimental.
- Backward-incompatible schema or command changes increment the minor
  version and update the Adapter Living Spec in the same commit.
- Transition to `1.0` requires successful multi-repo aggregation,
  dependency-resolution validation, and documented operator runbook.

## Boundaries

- **Is:** structured work-item tracking for AI-assisted planning and
  regression analysis.
- **Is not:** sprint planning, velocity estimation, or project finance.
- **Is not:** a replacement for public issue trackers such as GitHub
  Issues.

## Graph Projection

The backlog data lives in its own independent file-based graph (separate from the main Spec Graph in Component 6; see EF-056 / EF-057). Structured Markdown provides an explicit graph skeleton: issues are nodes (with `Status`, `Effort`, `Tags`, `Fix surface`, etc. attributes); `Depends on:`, `Blocks:`, and `Supersedes:` are directed edges; `Tags:` supply associative groupings/communities.

GraphRAG-style capabilities (dependency traversal, impact/critical-path analysis, thematic summarization, semantic search over items) are supplied by separate tooling and skills (`aggregate.sh --tags/--critical-path/--mermaid`, `portfolio-review`, `ready.sh`, and future dedicated processors) that read the files. The capability lives in the tooling layer, not the Markdown — keeping the data format pure, portable, and free of heavy runtime dependencies (e.g. no Cognee requirement for core backlog use).

Agents obtain graph-augmented answers by calling the appropriate tools/skills rather than performing broad raw file RAG. The shared ontology supplies cross-scope mapping when needed. Disk (the Markdown) is canonical; the graph is a projection for reasoning.

See `instance/backlog/file-based-backlog/file-based-backlog.md` (Living Spec), the architecture discussion capture docs, and EF-046/047/056–058.

Adopters designate one primary repo (the Adopter Platform Spec) that documents their overall eposforge implementation for product and platform factories and contains the `eposforge/` slice. Portfolio reviews are performed from that primary repo using the aggregate tooling (with appropriate BACKLOG_ROOTS).

## Reference implementations

See repo-instance adapter docs under
`instance/backlog/` for concrete implementations of this
slot.