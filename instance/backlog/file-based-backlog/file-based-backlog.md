---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: file-based-backlog -> Backlog (Component 13)

> Living Spec for the Backlog Adapter installed in this repo.
> Slot contract: [../../../01-architecture/02-components/backlog.md](../../../01-architecture/02-components/backlog.md)

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `file-based-backlog` |
| `component` | `backlog` |
| `version` | `0.2.0` |
| `status` | `experimental` |
| `privacy_posture` | `local` |
| `cost_hint` | `free` |
| `capabilities` | `issue-tracking`, `dependency-linking`, `cross-repo-aggregation`, `archive-indexing`, `linting`, `ready-work-query`, `portfolio-views`, `version-sync` |
| `invocation_surface` | `bash scripts` |

### Backlog required fields

| Field | Value |
|---|---|
| `repo_prefix` | `EF` |
| `discovery_method` | `workspace-file` with `BACKLOG_ROOTS` env fallback |
| `archive_format` | `single-file-with-index` |

### Repo-specific fields

| Field | Value |
|---|---|
| `fix_surfaces` | `eposforge-pattern` \| `repo-instance` \| `infrastructure` \| `process` |
| `config_path` | `backlog/config.toml` |
| `active_path` | `backlog/backlog.md` |
| `slated_path` | `backlog/backlog-slated.md` |
| `archive_path` | `backlog/backlog-archive.md` |
| `archive_index_path` | `backlog/backlog-archive-index.md` |

## File layout

```text
backlog/
  config.toml
  backlog.md
  backlog-slated.md
  backlog-archive.md
  backlog-archive-index.md
```

## Schema reference

Canonical issue schema and status-dependent field requirements:
[docs/schema.md](docs/schema.md)

## Multi-repo pattern

The adapter supports aggregation across repos using discovery precedence:

1. `$VSCODE_WORKSPACE_FILE` or `$WORKSPACE_FILE`
2. `$BACKLOG_ROOTS` (colon-separated roots)
3. `aggregate.sh --roots <path...>`
4. Current repo fallback

### Repo roles: substrate vs product

In a multi-repo portfolio, each repo declares a `role` in its `config.toml`:

- `role = "product"` — the repo delivers business value to a human or customer.
  **Value-harvest milestone anchors live in product repos** (discovered via the
  milestone-elicitation skill, EF-043). These anchors are the destinations the
  portfolio's critical-path and triage tooling (EF-039/EF-040/EF-041) computes
  toward.
- `role = "substrate"` — the repo provides the operational/infrastructure
  substrate that products run on (hosts, networking, secrets, orchestration,
  CI, IaC). **Substrate repos do not originate harvest anchors**, because the
  value they create is only realized through a product. Substrate items earn
  priority by linking toward product-repo anchors via `Blocks: <repo>:<ID>`
  (directly or through a dependency chain).

The role is advisory metadata today (mirrored in each `backlog.md` header for
readers); making the elicitation and portfolio tooling refuse to place anchors in
`substrate` repos, and flag substrate items with no `Blocks:` path to any product
anchor, is a natural enforcement follow-up. Repos that are neither (e.g. the
framework/pattern repo itself) may omit the field.

## Operator commands

From repo root (preferred: run-from-clone via `BACKLOG_HOME`; these paths are the vendored-copy fallback):

- `bash instance/backlog/file-based-backlog/scripts/new-issue.sh`
- `bash instance/backlog/file-based-backlog/scripts/lint-backlog.sh`
- `bash instance/backlog/file-based-backlog/scripts/sweep-resolved.sh`
- `bash instance/backlog/file-based-backlog/scripts/aggregate.sh --plan`
- `bash instance/backlog/file-based-backlog/scripts/aggregate.sh --regressions <keyword>`
- `bash instance/backlog/file-based-backlog/scripts/aggregate.sh --graph`
- `bash instance/backlog/file-based-backlog/scripts/aggregate.sh --themes`
- `bash instance/backlog/file-based-backlog/scripts/aggregate.sh --critical-path <ID>`
- `bash instance/backlog/file-based-backlog/scripts/ready.sh`
- `bash instance/backlog/file-based-backlog/scripts/ready.sh --json`

### Tooling distribution

Preferred mode: run scripts directly from a framework clone, set `BACKLOG_HOME` to
`<framework-clone>/instance/backlog/file-based-backlog`.

Vendored-copy mode: copy the scripts directory into the adopter repo, then keep it
current with:

- `bash <framework-scripts>/sync-tooling.sh <adopter-repo-root>` — sync scripts and report changes
- `bash <framework-scripts>/sync-tooling.sh --check <adopter-repo-root>` — check for drift, exit non-zero if stale

## Cross-host portability

Scripts are written for `#!/usr/bin/env bash`, derive `REPO_ROOT` via
`git rev-parse --show-toplevel`, and run on Linux and Git Bash.

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| Single-file Markdown parser | Complex edge cases may require stricter parser in future | Add JSON projection cache while preserving Markdown source-of-truth |
| Discovery assumes local filesystem access | Remote repo federation not covered | Add optional fetch adapter for remote backlog mirrors |
| Manual field authoring | Typos possible before lint | Add interactive `new-issue` prompts and autofill helpers |