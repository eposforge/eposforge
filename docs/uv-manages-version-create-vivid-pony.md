# Phase 3 — `deletefile` Behavior

## Status

| Phase | Commits | Summary |
|---|---|---|
| 0 | `803dca5` | Harness: uv project, `CogneeClient` (health/add_file/delete_dataset), smoke tests, secrets wired |
| 1 | `6166553` `7464737` | cognify/search/list_documents; 4/4 integration tests pass |
| 2 | `<pending>` | delete_document; updatefile tests; accumulation confirmed — update = delete+add |
| **3** | **← this phase** | Prove deletions evict content and characterise shared-entity behavior |

API behavioral findings from all phases are in
`instance/installed/06-spec-graph/cognee/cognee.md` §Observed API behavior.

## Phase 2 findings (summary for Phase 3 planning)

- **Re-add accumulates.** Same filename + new content → 2 docs in `list_documents`.
  Update = `delete_document(data_id) + add_file`. Phase 5 must persist `data_id`
  per tracked file path.
- **`data_id` changes on content change.** Different UUID per content version.
- **`delete_document` works.** After delete, `list_documents` returns 0 items for
  that `data_id`. Re-add after delete gives a fresh entry.
- **`list_documents` schema:** `{id, name, createdAt, updatedAt, extension, mimeType,
  rawDataLocation, datasetId}`. `id` = `data_id` from `add_file`. Extension stored
  as `txt` regardless of original.

## Goal

Same overall effort: git-commit-driven sync replacing full prune-and-reproject.
Phase 3 proves that deleting a file's data_id evicts its content from the KG,
characterises whether deleting one doc removes shared KG entities (or correctly
retains them), and confirms delete + re-add is a clean round-trip (no tombstones).

## What Phase 3 must prove

1. After `delete_document(data_id)`, content unique to that document is no longer
   returned by search. (Eviction is real, not just a storage delete.)
2. When two documents share an extracted entity and one is deleted, the shared
   entity persists. (Delete is non-cascading for shared graph nodes.)
3. Delete + re-add restores the content to the KG — no tombstones or orphaned
   nodes block re-ingestion.
4. Deletes are reflected synchronously in `list_documents`. (No async gap that
   Phase 5 would need to poll around.)

**If #1 fails:** the KG and the stored files diverge — `delete_document` removes
the file but leaves KG nodes. Stop and evaluate; the sync tool's delete path
would need a different mechanism (e.g. `delete_dataset` + recreate).

**If #2 fails (shared entity also deleted):** Phase 5 must avoid deleting documents
whose entities are referenced by other documents still in the corpus. This
complicates the sync tool significantly — stop and evaluate before Phase 5.

## Scope

**In Phase 3:**

- No new `CogneeClient` methods. `delete_document` and `search` (CHUNKS) from
  Phases 1–2 are sufficient. (`delete_dataset` from Phase 0 is reused for
  cleanup.)
- New conftest fixture: `two_doc_dataset` factory — adds two documents to the
  same dataset and returns their data_ids. Cleanup via `dataset_lifecycle`.
- New test file `tests/test_deletefile.py`, four `integration`-marked tests.
- Search assertions use `CHUNKS` `text` field (verbatim, deterministic), not
  `GRAPH_COMPLETION`. Use `dataset_ids=[dataset_id]` (UUID-based) for scoping,
  not `datasets=[name]`, since Phase 2 confirmed `datasets=` scoping is
  unreliable for vector search.

**Note on search scoping (Phase 2 lesson):** CHUNKS semantic search for a
UUID-like token does not reliably match the document containing that token.
Phase 3 asserts eviction via `list_documents` (file-level) rather than via CHUNKS
search wherever possible, falling back to search only for KG-level eviction
checks (assertion #1 above requires a KG query, not just a file listing).

**Design constraints (unchanged):** thin client, no test-mode flags, fixtures
compose, client calls HTTP.

**Out of scope:** ontology id stability (Phase 4), sync tool code (Phase 5).

## Files to create

```
instance/installed/06-spec-graph/cognee/sync/
  tests/
    test_deletefile.py
```

## Files to modify

```
instance/installed/06-spec-graph/cognee/sync/tests/conftest.py
  + two_doc_dataset fixture (function scope factory)
    # adds two documents with different content to the same dataset
    # returns (dataset_id, data_id_a, data_id_b)
    # cleanup via dataset_lifecycle
```

No client.py changes expected. No edits outside `cognee/sync/`.

## Critical files — content notes

### `conftest.py` — `two_doc_dataset`

```python
@pytest.fixture()
def two_doc_dataset(
    client: CogneeClient,
    dataset_lifecycle: Callable[..., dict[str, Any]],
) -> Generator[Callable[..., tuple[str, str, str]], None, None]:
    def _factory(
        name: str,
        token_a: str,
        token_b: str,
    ) -> tuple[str, str, str]:
        resp_a = dataset_lifecycle(name, f"# doc a\n\n{token_a}\n", "doc-a.md")
        dataset_id: str = resp_a["dataset_id"]
        data_id_a: str = resp_a["data_ingestion_info"][0]["data_id"]

        resp_b = client.add_file(
            dataset_name=name,
            content=f"# doc b\n\n{token_b}\n",
            filename="doc-b.md",
        )
        data_id_b: str = resp_b["data_ingestion_info"][0]["data_id"]

        return dataset_id, data_id_a, data_id_b
    yield _factory
```

### `tests/test_deletefile.py` — four tests

All `@pytest.mark.integration`. Tokens generated inline (`phase3-*`).

1. **`test_delete_removes_document_from_list`** — add a doc, delete it via
   `delete_document`, assert `list_documents` returns 0 items (synchronous
   eviction). This is the file-level proof; fast, no search needed.

2. **`test_delete_and_readd_is_clean_roundtrip`** — add doc with token A, delete,
   re-add same filename with token A again. Assert `list_documents` shows 1 item
   and the new `data_id` differs from the deleted one (no tombstone blocking
   re-ingestion). Optional: attempt search for token A after re-add if CHUNKS
   scoping can be made to work (use `dataset_ids=`).

3. **`test_shared_entity_persists_after_partial_delete`** — add two docs (A and B)
   with a SHARED phrase in both. Delete doc A's `data_id`. Assert doc B still
   appears in `list_documents`. Attempt CHUNKS search for the shared phrase —
   record whether it still returns a hit (shared entity retained) or misses
   (shared entity deleted with doc A). This test characterises; it does NOT assert
   a specific outcome — both behaviors are recorded. The finding determines whether
   Phase 5 needs shared-entity tracking.

4. **`test_delete_is_synchronous`** — add a doc, immediately call
   `list_documents`, delete, immediately call `list_documents` again. Assert the
   second call shows the item gone without any polling. Proves Phase 5 does not
   need to add a sleep or poll loop after delete.

## Verification

```powershell
cd instance\installed\06-spec-graph\cognee\sync

# Regression check
python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run pytest -m smoke -v

# All integration tests including Phase 3
python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run pytest -m integration -v -s
```

Expected outcomes:

1. Smoke tests pass — no regressions.
2. `test_delete_removes_document_from_list` passes — delete is reflected in
   `list_documents` immediately.
3. `test_delete_and_readd_is_clean_roundtrip` passes — re-add after delete works.
4. `test_shared_entity_persists_after_partial_delete` passes (characterisation);
   output records whether shared entity survives partial delete.
5. `test_delete_is_synchronous` passes — no async gap.
6. All test datasets cleaned up by teardown.

## Open questions Phase 3 must answer (and record)

1. **Does deleting a data_id evict its KG entities, or only the stored file?**
   If KG entities persist after delete, the sync tool's delete path is broken at
   the KG level even if the file listing looks clean.
2. **Are shared entities (nodes referenced by multiple documents) retained when
   one referencing document is deleted?** Determines whether Phase 5 needs
   shared-entity tracking.
3. **Is delete synchronous in `list_documents`?** (Expected yes, given add is
   synchronous. Confirm.)

## Future phases (record, not commitment)

**Phase 4 — Ontology grounding stability.** Prove ontology-anchored entity ids
are stable across edits and re-adds. Needs a fixture `.ttl` under
`sync/tests/fixtures/`. Open: stable ids? `.ttl` per-dataset or per-instance?

**Phase 5 — the sync tool itself.** Update mechanism confirmed (Phase 2):
`delete_document + add_file`, persist `data_id` per path. Phase 3 confirms
whether shared-entity tracking is also required. CLI vs. daemon decided by
Phase 1–4 latency/idempotency findings.

**Final cleanup:** cognee.md full rewrite; optional epos-secrets.ps1 wrapper.
