# Phase 2 — `updatefile` Behavior

## Status

| Phase | Commits | Summary |
|---|---|---|
| 0 | `803dca5` | Harness: uv project, `CogneeClient` (health/add_file/delete_dataset), smoke tests, secrets wired |
| 1 | `6166553` `7464737` | cognify/search/list_documents added; 4/4 integration tests pass |
| **2** | **← this phase** | Prove content edits update the KG — the GraphRAG-burn test |

API behavioral findings from Phases 0–1 are in
`instance/installed/06-spec-graph/cognee/cognee.md` §Observed API behavior.

## Goal

Build a git-commit-driven sync tool that updates the Cognee KG in place when
EposForge `*.md` files change, replacing full prune-and-reproject. Harness at
`instance/installed/06-spec-graph/cognee/sync/`.

Phase 2 is the GraphRAG-burn test — GraphRAG's incremental update failed exactly
here because content edits were silently ignored and only filenames were tracked.
If Cognee fails this test, the incremental-sync premise is invalid.

## What Phase 2 must prove

1. Content updated in a same-named file is queryable via `CHUNKS` search after
   re-add. (New content is visible.)
2. The old content is NOT returned by `CHUNKS` search after re-add with new
   content. (Old content is evicted — the GraphRAG-burn assertion.)
3. Explicit `delete_document(data_id) + add_file` evicts old content, whether
   or not re-add alone does. (Proves the guaranteed update path.)
4. Whether `data_id` is stable across a content change — in-place semantics
   (same id) vs. delete+add semantics (new id). Phase 5 needs this to decide
   whether to persist `data_id` per tracked file path.

**If #1 fails:** stop and evaluate — add itself may be broken for this content
type.

**If #2 fails but #3 passes:** update mechanism for Phase 5 is
`delete_document + add_file`. Phase 5 must persist `data_id` per tracked path.
Continue to Phase 3.

**If #2 AND #3 fail:** stop and evaluate — Cognee may be accumulation-only,
invalidating the incremental-sync approach entirely.

## Scope

**In Phase 2:**

- One new `CogneeClient` method: `delete_document(dataset_id, data_id)` →
  `DELETE /api/v1/datasets/{dataset_id}/data/{data_id}`. Confirmed from swagger.
  Phase 3 reuses this method for delete-eviction tests.
- New conftest fixture: `updated_dataset` factory — adds ALPHA content, re-adds
  BETA (same dataset, same filename), returns `(dataset_id, alpha_data_id,
  beta_data_id)`. Cleanup inherited from `dataset_lifecycle`.
- New test file `tests/test_updatefile.py`, four `integration`-marked tests.
- `CHUNKS` search used for all assertions (verbatim `text` field, deterministic).
  `GRAPH_COMPLETION` not used — confirmed noise by Phase 1.

**Design constraints (unchanged):**

- `delete_document` returns `None` on success, suppresses 404, raises on other
  non-2xx. Same pattern as `delete_dataset`.
- No test-mode parameters on client. Fixture composes, client calls HTTP.

**Out of scope:**

- Shared-entity behavior on delete (Phase 3)
- Ontology id stability (Phase 4)
- Any sync tool code (Phase 5)
- Decision on Phase 5's update mechanism — that's a Phase 2 finding, not Phase 2 code

## Files to create

```
instance/installed/06-spec-graph/cognee/sync/
  tests/
    test_updatefile.py
```

## Files to modify

```
instance/installed/06-spec-graph/cognee/sync/src/cognee_sync/client.py
  + delete_document(dataset_id, data_id) → None
    # DELETE /api/v1/datasets/{dataset_id}/data/{data_id}
    # 404 suppressed; Phase 2 section header

instance/installed/06-spec-graph/cognee/sync/tests/conftest.py
  + updated_dataset fixture (function scope factory)
    # adds ALPHA, re-adds BETA same filename
    # returns (dataset_id, alpha_data_id, beta_data_id)
```

No edits outside `cognee/sync/` for Phase 2.

## Critical files — content notes

### `client.py` — `delete_document`

```python
def delete_document(self, dataset_id: str, data_id: str) -> None:
    """DELETE /api/v1/datasets/{dataset_id}/data/{data_id}."""
    response = self._client.delete(
        f"/api/v1/datasets/{dataset_id}/data/{data_id}"
    )
    if response.status_code == 404:
        return
    response.raise_for_status()
```

### `conftest.py` — `updated_dataset`

```python
@pytest.fixture()
def updated_dataset(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
) -> Generator[Callable[..., tuple[str, str, str]], None, None]:
    def _factory(
        name: str,
        alpha_token: str,
        beta_token: str,
        filename: str = "update-test.md",
    ) -> tuple[str, str, str]:
        alpha_response = dataset_lifecycle(
            name, f"# update test\n\n{alpha_token}\n", filename
        )
        dataset_id: str = alpha_response["dataset_id"]
        alpha_data_id: str = alpha_response["data_ingestion_info"][0]["data_id"]

        beta_response = client.add_file(
            dataset_name=name,
            content=f"# update test\n\n{beta_token}\n",
            filename=filename,
        )
        beta_data_id: str = beta_response["data_ingestion_info"][0]["data_id"]

        return dataset_id, alpha_data_id, beta_data_id
    yield _factory
```

`alpha_data_id` and `beta_data_id` may or may not differ — Phase 2 finding #4.
The fixture records both without asserting.

### `tests/test_updatefile.py` — four tests

All `@pytest.mark.integration`. Alpha/beta tokens are generated inline per test
(`f"phase2-alpha-{uuid.uuid4().hex[:8]}"`) — no fixture needed for tokens.

1. **`test_updated_content_is_queryable`** — add ALPHA, re-add BETA (same
   dataset, same filename), `CHUNKS` search → at least one result with
   `beta_token` in `result["text"]`. Strict field check, not substring of
   `str(results)`.

2. **`test_updated_content_evicts_old_content`** — THE GraphRAG-burn test.
   After re-add with BETA, `CHUNKS` search → assert zero results have
   `alpha_token` in `result["text"]`. Field-level assertion, iterate results.
   Pass = re-add evicts. Fail = follow the failure rule above.

3. **`test_explicit_delete_and_readd_evicts_old_content`** — add ALPHA,
   `delete_document(dataset_id, alpha_data_id)`, re-add BETA, `CHUNKS` search
   for `alpha_token` → zero hits. Proves the guaranteed update path. This test
   must pass regardless of test #2's outcome.

4. **`test_data_id_behavior_on_content_change`** — after `updated_dataset`,
   compare `alpha_data_id` and `beta_data_id`. No assertion — records the finding:
   same id = in-place semantics; different id = delete+add semantics (Phase 5
   must persist `data_id` per tracked path).

## Verification

```powershell
cd instance\installed\06-spec-graph\cognee\sync

# Regression check
python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run pytest -m smoke -v

# Phase 2
python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run pytest -m integration -v -s
```

Expected outcomes:

1. Smoke tests pass — no regressions from `delete_document`.
2. `test_updated_content_is_queryable` passes — BETA is findable.
3. `test_updated_content_evicts_old_content` — outcome determines Phase 5 update
   mechanism. Apply the failure rule before deciding to continue.
4. `test_explicit_delete_and_readd_evicts_old_content` passes.
5. `test_data_id_behavior_on_content_change` passes and prints its finding.
6. All test-prefixed datasets deleted by teardown.

If CHUNKS search returns unexpected results, verify the second `add_file`
response `status` — `PipelineRunCompleted` means cognify fired (expected for new
content); `PipelineRunAlreadyCompleted` means the content was considered identical
(content hash match — check that alpha and beta tokens are actually distinct).

## Open questions Phase 2 must answer (and record)

1. **Does re-add with new content evict old content?** Determines Phase 5's update
   mechanism: simple re-add vs. explicit delete+add.
2. **Is `data_id` stable across content changes?** Same id = in-place; new id =
   Phase 5 must persist `data_id` per tracked file path.
3. **Does cognify still fire implicitly on re-add with new content?** The second
   `add_file` response `status` answers this. Phase 1 confirmed dedup on identical
   content; different content should re-run, but confirm.

## Future phases (record, not commitment)

**Phase 3 — `deletefile` behavior.** Confirm `delete_document` (added in Phase 2)
evicts unique content. Two-doc setup with shared entity: delete one, shared entity
persists. Delete + re-add restores content (no tombstones). Confirm deletes are
synchronous in `list_documents`. Uses `DELETE /api/v1/datasets/{dataset_id}/data/{data_id}`.

**Phase 4 — Ontology grounding stability.** Prove ontology-anchored entity ids
are stable across edits and re-adds. Needs a fixture `.ttl` under
`sync/tests/fixtures/`. Open: does cognee expose stable ontology ids? Is the
`.ttl` per-dataset or per-instance?

**Phase 5 — the sync tool itself.** Git-driven: diff changed files, classify as
add/update/delete, dispatch cognee API calls. Update mechanism (re-add vs.
delete+add) and whether to persist `data_id` per path is decided by Phase 2.
CLI-vs-daemon is informed by Phase 1–4 findings on latency and idempotency.

**Final cleanup:**

- **`cognee.md` full rewrite** — drop `(in transition)` markers, point invocation
  surface at Phase 5's output, update metadata table, resolve v1 contract gaps.
- **`epos-secrets.ps1` wrapper** — optional follow-up if daily Phase 5 usage
  makes the Python-script invocation worth wrapping.
