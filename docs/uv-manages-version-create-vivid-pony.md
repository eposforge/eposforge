# Final cleanup — cognee.md rewrite + Gitea Actions wiring

## Status

| Phase | Commits | Summary |
|---|---|---|
| 0 | `803dca5` | Harness, CogneeClient, smoke tests, secrets wired |
| 1 | `6166553` `7464737` | cognify/search/list\_documents; cognify implicit + synchronous |
| 2 | `2a0e01b` | delete\_document; update = delete+add; data\_id must be persisted |
| 3 | `5f688d1` | deletefile tests; delete synchronous and non-cascading |
| 4 | `f3d5f90` | graph/ontology; node IDs stable; .owl extension required |
| 5 | `<pending>` | sync tool: state.py, sync.py, cli.py; 18/18 integration tests pass |
| **cleanup** | **<- this phase** | cognee.md full rewrite + Gitea Actions workflow |

The `cognee-sync` CLI ships. Invoke via:

```powershell
epos-secrets uv run cognee-sync --added path/new.md --modified path/changed.md --deleted path/old.md
```

API behavioral findings from all phases are in
`.eposforge/spec-graph/cognee/cognee.md` §Observed API behavior.

## What remains

### 1. `cognee.md` full rewrite

Drop the `(in transition)` markers, replace the `invocation_surface` with
the `cognee-sync` CLI, set `incremental_update: true`, update the
`Repo-specific fields` table, and resolve the v1 contract gaps. The Phase 0
surgical harm-reduction edits (status banner, deleted sections) did enough to
prevent harm; the full rewrite closes the loop.

Specific table entries to update:

| Field | Current (stub) | Final value |
|---|---|---|
| `invocation_surface` | `in revision (see ./sync/)` | `cognee-sync CLI (see ./sync/README.md)` |
| `incremental_update` | `false (in transition)` | `true (delete\_document + add\_file; data\_id persisted in .cognee-state.db)` |
| `script` | `in revision` | `cognee-sync` (see `./sync/pyproject.toml` entry point) |

Also: remove the `(in revision)` status banner from the top of the file,
and update the "Contract gaps (v1)" table — the incremental-update gap is
now closed.

### 2. Gitea Actions workflow

Create `.gitea/workflows/cognee-sync.yml` that:

1. Triggers on push to `main`
2. Computes `--added`, `--modified`, `--deleted` from `git diff --name-only
   --diff-filter=A/M/D ${{ gitea.event.before }}..${{ gitea.sha }} -- '*.md'`
3. Invokes `epos-secrets uv run cognee-sync` with those lists

The workflow must run on a self-hosted runner that has:
- `uv` installed
- The age key present (for `epos-secrets` to decrypt `secrets.enc.yaml`)
- Network access to `cognee.grace.lan`

### 3. `COGNEE_STATE_DB` persistence between runs — **decided**

State DB lives at `.eposforge/spec-graph/cognee/sync/.cognee-state.db`,
committed to source. Default is hardcoded in `cli.py` relative to `__file__`
so it resolves correctly regardless of working directory. Override with
`COGNEE_STATE_DB` if needed.

Committing a SQLite binary to git is acceptable: single-operator repo,
single Cognee instance, no concurrent writers. DB is small and grows
incrementally (one row per tracked file).

### 4. `--full-sync` command (optional enhancement)

Walk configured corpus roots (`*.md` files), `sync_add` each one (idempotent
— identical content skips the API call). Useful after a runner wipe or to
bootstrap a fresh Cognee instance. Not required for the daily diff-based sync.

## Verification

```powershell
# CLI help
epos-secrets uv run cognee-sync --help

# Dry-run against a real file
epos-secrets uv run cognee-sync --dry-run --added .eposforge/SPEC.md

# Full integration suite
epos-secrets uv run pytest -m integration -v -s   # 18 pass, 1 xfail expected

# Smoke only
epos-secrets uv run pytest -m smoke -v
```
