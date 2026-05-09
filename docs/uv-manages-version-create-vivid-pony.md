# Phase 5 — The Sync Tool

## Status

| Phase | Commits | Summary |
|---|---|---|
| 0 | `803dca5` | Harness, CogneeClient, smoke tests, secrets wired |
| 1 | `6166553` `7464737` | cognify/search/list\_documents; cognify implicit on add; CHUNKS for assertions |
| 2 | `2a0e01b` | delete\_document; re-add accumulates; update = delete+add; data\_id must be persisted |
| 3 | `5f688d1` | deletefile tests; delete synchronous; partial delete non-cascading; same data\_id on delete+readd of identical content |
| 4 | `<pending>` | upload\_ontology/delete\_ontology/get\_graph; graph is global (not dataset-scoped); node IDs stable; ontology anchoring works; `.owl` extension required |
| **5** | **<- this phase** | The sync tool itself |

API behavioral findings from all phases are in
`instance/installed/06-spec-graph/cognee/cognee.md` §Observed API behavior.

## Phase 4 findings (summary for Phase 5 design)

- **Graph is global, not dataset-scoped.** `GET /api/v1/datasets/{id}/graph`
  returns the full instance graph regardless of dataset_id. 50 nodes / 105 edges
  from the pre-ingested EposForge corpus are always present.
- **Node IDs are stable** across delete+re-add of identical content. Phase 5
  downstream consumers will not see entity ID churn from sync cycles.
- **Ontology upload:** requires `.owl` filename extension (Turtle content accepted).
  Referenced by string key in `cognify(ontologyKey=[key])`.
- **Ontology-anchored extraction works** — `PhaseTestEntity`-referencing nodes
  appear after explicit cognify with ontologyKey. `ontology_valid` flag stays
  `False` regardless (Cognee version behavior; does not affect functionality).

## Confirmed sync tool design (from Phases 1–4)

| Operation | Mechanism | Notes |
|---|---|---|
| **Add file** | `add_file(dataset_name, content, filename)` | Cognify implicit, synchronous |
| **Update file** | `delete_document(dataset_id, old_data_id)` + `add_file(...)` | Must persist `data_id` per tracked path |
| **Delete file** | `delete_document(dataset_id, data_id)` | Synchronous; partial delete non-cascading |
| **State store** | `file_path -> data_id` mapping | Required for update path; SQLite sidecar or similar |
| **Dataset** | One dataset per sync scope (e.g. per repo or per directory) | All files in one dataset; dataset_id stable |

## What Phase 5 must deliver

1. A CLI command `cognee-sync [--diff <base-ref>]` that:
   - Computes the set of changed files since `base-ref` (or full re-sync if omitted)
   - Classifies each changed file as add / update / delete
   - Dispatches the correct Cognee API calls per the table above
   - Updates the state store on success; rolls back no-op on failure
2. A state store (SQLite at `sync/.cognee-state.db` or configurable path)
   with schema: `(file_path TEXT PRIMARY KEY, dataset_id TEXT, data_id TEXT,
   content_hash TEXT, synced_at TEXT)`
3. A Gitea Actions workflow (or post-receive hook) that invokes `cognee-sync`
   on push to trigger incremental updates automatically

## Scope

**In Phase 5:**

- New module `src/cognee_sync/sync.py` — the sync engine: diff computation,
  classify, dispatch, state store CRUD.
- New module `src/cognee_sync/state.py` — SQLite-backed state store with
  typed read/write/delete for the `file_path -> (dataset_id, data_id,
  content_hash)` mapping.
- New CLI entry point wired in `pyproject.toml` (`[project.scripts]`):
  `cognee-sync = "cognee_sync.cli:main"` — thin argument parser, calls
  `sync.py`.
- New test file `tests/test_sync.py` — integration tests for full add/update/
  delete round-trips via the CLI entry point against the live API.
- `sqlite3` (stdlib) for the state store — no new runtime dependencies unless
  Phase 5 implementation reveals a need.

**Design constraints:**

- The sync engine is idempotent: re-running on the same diff produces the same
  Cognee state. Identical content → `PipelineRunAlreadyCompleted` (dedup),
  same `data_id` — state store does not change.
- State store writes are committed only after the Cognee API call succeeds.
  Partial failure (API success, state write failure) is recoverable by re-running
  the sync.
- The CLI is invokable via `epos-secrets cognee-sync` for local use and via
  `uv run cognee-sync` inside CI.

**Out of scope for Phase 5:**

- Ontology-anchored sync (Phase 4 proved it works; integrate when the repo's
  glossary TTL is stable enough to use as an anchor)
- Cross-dataset entity dedup (single dataset for now)
- `cognee.md` full rewrite (last step, after Phase 5 ships)

## Files to create

```
instance/installed/06-spec-graph/cognee/sync/
  src/cognee_sync/
    sync.py           # diff computation, classify, dispatch, state store CRUD
    state.py          # SQLite-backed file_path -> (dataset_id, data_id, hash)
    cli.py            # thin argparse entry point
  tests/
    test_sync.py      # integration tests: add/update/delete round-trips
```

## Files to modify

```
instance/installed/06-spec-graph/cognee/sync/pyproject.toml
  + [project.scripts]: cognee-sync = "cognee_sync.cli:main"

instance/installed/06-spec-graph/cognee/sync/README.md
  + Phase 5 invocation section
```

## Critical files — content notes

### `state.py`

```python
# Schema: file_path (PK), dataset_id, data_id, content_hash, synced_at
# Operations: upsert(path, dataset_id, data_id, hash), get(path), delete(path), list_all()
# DB path: configurable via COGNEE_STATE_DB env var, default sync/.cognee-state.db
```

`content_hash` is the SHA-256 of the file content (hex). Used to detect
identical content on re-add so `data_id` can be reused without an API call.

### `sync.py`

Three entry-point functions called by `cli.py`:

- `sync_add(client, state, dataset_id, file_path, content)` — call `add_file`,
  write state. If state already has this path with the same hash, skip (idempotent).
- `sync_update(client, state, dataset_id, file_path, content)` — read old
  `data_id` from state, call `delete_document`, call `add_file`, write new state.
- `sync_delete(client, state, dataset_id, file_path)` — read `data_id` from
  state, call `delete_document`, delete state row.
- `sync_diff(client, state, config, base_ref)` — compute git diff, classify
  files, dispatch to the three functions above.

### `tests/test_sync.py`

Four `integration`-marked tests:

1. **`test_sync_add`** — `sync_add` a file; assert state row created with correct
   `data_id`; assert `list_documents` shows the file.
2. **`test_sync_update`** — `sync_add` then `sync_update` with new content; assert
   state row updated with new `data_id`; assert old `data_id` gone from
   `list_documents`.
3. **`test_sync_delete`** — `sync_add` then `sync_delete`; assert state row
   deleted; assert `list_documents` empty.
4. **`test_sync_idempotent`** — `sync_add` twice with identical content; assert
   second call is a no-op (same `data_id`, no duplicate API call).

## Verification

```powershell
cd instance\installed\06-spec-graph\cognee\sync

# Regression
python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run pytest -m smoke -v

# All integration tests
python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run pytest -m integration -v -s

# CLI smoke (once CLI is wired)
python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run cognee-sync --help
```

## Open questions Phase 5 must answer (and record)

1. **Dataset naming strategy.** One dataset per repo? One per directory subtree?
   One per file? Given accumulation behavior (Phase 2), a single dataset with
   per-file `data_id` tracking is simplest. Confirm before wiring the state store.
2. **What to do when state store has a `data_id` that no longer exists in Cognee**
   (e.g. after a manual `delete_dataset` or Cognee wipe)? Re-add? Error? Define
   the reconciliation path.
3. **Full re-sync path.** When `--diff` is omitted, walk the corpus roots and
   `sync_add` every file. If a file already exists in state with the same hash,
   skip. This covers the cold-start case.

## Final cleanup (after Phase 5 ships)

- **`cognee.md` full rewrite** — drop `(in transition)` markers, set
  `invocation_surface` to `cognee-sync`, set `incremental_update: true`,
  resolve v1 contract gaps.
- **`epos-secrets.ps1` wrapper** — optional; only if daily sync invocation
  friction justifies it.
