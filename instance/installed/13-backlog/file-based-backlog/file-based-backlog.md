---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: file-based-backlog -> Backlog (Component 13)

> Living Spec for the Backlog Adapter installed in this repo.
> Slot contract: [../../../../01-architecture/02-components/13-backlog.md](../../../../01-architecture/02-components/13-backlog.md)

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `file-based-backlog` |
| `component` | `13-backlog` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `local` |
| `cost_hint` | `free` |
| `capabilities` | `issue-tracking`, `dependency-linking`, `cross-repo-aggregation`, `archive-indexing`, `linting` |
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

## Operator commands

From repo root:

- `bash instance/installed/13-backlog/file-based-backlog/scripts/new-issue.sh`
- `bash instance/installed/13-backlog/file-based-backlog/scripts/lint-backlog.sh`
- `bash instance/installed/13-backlog/file-based-backlog/scripts/sweep-resolved.sh`
- `bash instance/installed/13-backlog/file-based-backlog/scripts/aggregate.sh --plan`
- `bash instance/installed/13-backlog/file-based-backlog/scripts/aggregate.sh --regressions <keyword>`
- `bash instance/installed/13-backlog/file-based-backlog/scripts/aggregate.sh --graph`

## Cross-host portability

Scripts are written for `#!/usr/bin/env bash`, derive `REPO_ROOT` via
`git rev-parse --show-toplevel`, and run on Linux and Git Bash.

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| Single-file Markdown parser | Complex edge cases may require stricter parser in future | Add JSON projection cache while preserving Markdown source-of-truth |
| Discovery assumes local filesystem access | Remote repo federation not covered | Add optional fetch adapter for remote backlog mirrors |
| Manual field authoring | Typos possible before lint | Add interactive `new-issue` prompts and autofill helpers |