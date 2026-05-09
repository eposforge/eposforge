# Phase 4 — Ontology Grounding Stability

## Status

| Phase | Commits | Summary |
|---|---|---|
| 0 | `803dca5` | Harness, CogneeClient (health/add\_file/delete\_dataset), smoke tests, secrets wired |
| 1 | `6166553` `7464737` | cognify/search/list\_documents; 4/4 integration tests pass |
| 2 | `2a0e01b` | delete\_document; accumulation confirmed — update = delete+add; data\_id must be persisted |
| 3 | `<pending>` | deletefile tests; delete synchronous; partial delete non-cascading; same data\_id on delete+readd of identical content |
| **4** | **<- this phase** | Prove ontology-anchored entity IDs are stable across document edits |

API behavioral findings from all phases are in
`instance/installed/06-spec-graph/cognee/cognee.md` §Observed API behavior.

## Phase 3 findings (summary for Phase 4 planning)

- **Delete is synchronous** — no polling needed by Phase 5.
- **Partial delete is non-cascading at the file level** — deleting doc A leaves
  doc B in `list_documents`.
- **Delete + re-add of identical content → same `data_id`** — content-hash dedup
  active even after delete. Phase 5: if a file reverts to a previous version,
  re-adding produces the same data\_id.
- **KG-level eviction after delete: unconfirmed.** CHUNKS search for UUID tokens
  is unreliable. Orphaned KG nodes after delete remain an open question.

## Goal

Same overall effort: git-commit-driven sync replacing full prune-and-reproject.
Phase 4 proves that Cognee's ontology-anchored entity extraction produces stable
entity IDs across document edits and re-adds. If entity IDs churn on every
update, downstream consumers (KG queries, cross-document references) break on
every sync cycle regardless of whether the sync tool's file-level operations
are correct.

Phase 4 is also the phase best positioned to probe KG-level eviction — by
tracking a known entity ID before and after delete, we can see whether the
entity disappears from the KG or persists as an orphan.

## What Phase 4 must prove

1. An ontology-anchored entity extracted from a document has a stable ID that
   survives an edit to that document (delete old data\_id + re-add updated content).
2. The same entity extracted from a re-added document maps to the same ontology
   node (not a duplicate). Phase 5 needs this to know whether downstream consumers
   accumulate duplicate entity nodes across sync cycles.
3. (Advisory) After `delete_document`, the entity extracted from that document
   disappears from the KG — confirming KG-level eviction, the question Phase 3
   could not answer with UUID token search.

**If #1 fails (entity IDs not stable):** the sync tool is correct at the file
level but incorrect at the KG level — every update churns entity IDs. Evaluate
whether Cognee's ontology key mechanism (`ontologyKey` param on cognify, per
swagger) stabilises IDs before proceeding to Phase 5.

**If #2 fails (duplicate entities on re-add):** downstream queries accumulate
noise nodes. Same evaluation as above.

## Scope

**In Phase 4:**

- No new `CogneeClient` methods unless Phase 4 discovers a needed endpoint
  (e.g. a KG graph inspection endpoint — `GET /api/v1/datasets/{id}/graph`
  exists per swagger and may be needed for entity ID extraction).
- A small fixture TTL under `sync/tests/fixtures/phase4.ttl` containing a
  single well-known class definition (e.g. `epos:TestEntity`) for the ontology
  anchor.
- New conftest fixture: `ontology_dataset` — loads a doc that references a
  known ontology term, returns `(dataset_id, data_id)`. The ontology key is
  passed to `add_file` or `cognify` via the `ontologyKey` swagger parameter
  (exact mechanism TBV from swagger before writing).
- New test file `tests/test_ontology.py`, three `integration`-marked tests.

**Critical pre-work before writing any code:**

- Fetch `GET /api/v1/datasets/{dataset_id}/graph` schema from the live swagger
  to understand how entity IDs are exposed (or determine an alternative path).
- Understand how `ontologyKey` is set on cognify: does it accept an inline TTL
  string, a file path in the container, or a separately uploaded artifact? Check
  swagger and/or the live API before writing the fixture.

**Design constraints (unchanged):** thin client, no test-mode flags.

**Out of scope:** the sync tool itself (Phase 5), cognee.md full rewrite (final).

## Files to create

```
instance/installed/06-spec-graph/cognee/sync/
  tests/
    fixtures/
      phase4.ttl          # minimal ontology fixture (single class definition)
    test_ontology.py      # three integration tests
```

## Files to modify

```
instance/installed/06-spec-graph/cognee/sync/tests/conftest.py
  + ontology_dataset fixture (function scope factory) — TBD once ontologyKey
    mechanism is confirmed from swagger

instance/installed/06-spec-graph/cognee/sync/src/cognee_sync/client.py
  + get_graph(dataset_id) — ONLY IF GET /api/v1/datasets/{dataset_id}/graph
    is needed for entity ID extraction and swagger confirms the schema
```

## Critical files — content notes

### `tests/fixtures/phase4.ttl`

Minimal OWL/RDF file. One class definition is sufficient — the goal is to give
Cognee an ontology anchor, not to model anything real:

```turtle
@prefix epos: <https://eposforge.example/ontology#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-type#> .

epos:PhaseTestEntity a owl:Class ;
    rdfs:label "Phase Test Entity" .
```

The label `"Phase Test Entity"` is what tests embed in document content to
trigger ontology-anchored extraction. The class IRI `epos:PhaseTestEntity`
is what tests check for stability.

### `tests/test_ontology.py` — three tests

All `@pytest.mark.integration`. All depend on the ontology mechanism being
understood from swagger before implementation.

1. **`test_entity_id_stable_across_edit`** — add a doc referencing
   `PhaseTestEntity`, capture the entity's graph ID, delete + re-add with
   minor edit (e.g. added sentence), capture the entity's graph ID again.
   Assert IDs match. Uses `get_graph` or equivalent.

2. **`test_entity_not_duplicated_on_readd`** — after delete + re-add, assert
   only one node with the ontology class IRI exists in the dataset graph
   (not two). Proves the sync tool won't accumulate duplicate nodes across
   update cycles.

3. **`test_delete_evicts_entity_from_graph`** (advisory) — add a doc, capture
   entity ID, delete doc, query graph, record whether entity persists or is
   gone. The finding resolves Phase 3's open KG-eviction question.

## Verification

```powershell
cd instance\installed\06-spec-graph\cognee\sync

python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run pytest -m smoke -v
python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run pytest -m integration -v -s
```

## Open questions Phase 4 must answer before writing code

1. **How is `ontologyKey` set?** The swagger shows `cognify` accepts
   `ontologyKey: list[str]`. Does this reference a pre-uploaded TTL artifact,
   an inline string, or a container-local path? Check the live swagger and/or
   the Cognee source before writing any fixture code.
2. **How are entity IDs exposed?** `GET /api/v1/datasets/{dataset_id}/graph`
   exists per swagger. Does its response include node IDs mapped to ontology
   class IRIs? Fetch and inspect before writing the tests.
3. **Does the `phase4.ttl` fixture need to be uploaded to Cognee before use,
   or can it be passed inline?** Determines whether a pre-test setup step
   (upload TTL) is needed in the fixture.

**If the ontology mechanism turns out to be too opaque to test reliably:**
record that finding and proceed to Phase 5 — ontology ID stability is a
nice-to-have characterisation, not a prerequisite for the basic sync tool.

## Future phases (record, not commitment)

**Phase 5 — the sync tool itself.** Confirmed design from Phases 1–3:
- Add: `add_file` (cognify implicit, synchronous)
- Update: `delete_document(old_data_id) + add_file` (must persist `data_id`
  per tracked file path — sidecar required)
- Delete: `delete_document(data_id)` (synchronous)
- State store: SQLite or similar mapping `file_path -> data_id`
- Trigger: git post-receive hook or Gitea Actions on push

**Final cleanup:** cognee.md full rewrite; optional epos-secrets.ps1 wrapper.
