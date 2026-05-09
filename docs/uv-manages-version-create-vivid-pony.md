# Phase 1 — `addfile` Behavior

## Context

Goal (overall effort): a git-commit-driven sync tool that updates the cognee
knowledge graph in place when EposForge `*.md` files change, replacing the
current full prune-and-reproject ingestion. Cognee assigns each document a
stable id and exposes file-level CRUD via its HTTP API
(swagger at https://cognee.grace.lan/docs); the sync tool will translate file
changes into add / update / delete calls.

**Phase 0 — done.** The test harness lives at
`instance/installed/06-spec-graph/cognee/sync/`:

- `cognee-sync` `uv` project, Python 3.13 pinned, `httpx` runtime dep,
  `pytest` + `pytest-randomly` dev deps
- `CogneeClient` with `health()`, `add_file()`, `delete_dataset()` —
  context-manager, bearer-auth, lenient JSON return
- `Config` reads `COGNEE_API_URL`, `COGNEE_API_TOKEN` (optional → anonymous),
  and `COGNEE_TLS_VERIFY` from the env injected by `epos-secrets`
- Session-scoped `client` fixture; function-scoped `dataset_name` and
  `dataset_lifecycle` factory; cleanup proven by `test_dataset_lifecycle_roundtrip`
- Two pytest markers registered: `smoke`, `integration`
- Secrets wired in the central manifest: `cognee_api_url`, `cognee_tls_verify`
  (plus `cognee_api_token` reserved); stale `cognee/scripts/` consumers pruned
- `instance/SPEC.md` lists `cognee-sync` as in-progress; `cognee.md` carries
  the in-revision banner and surgical edits

**Phase 0 discovery — resolved.** Re-ran smoke before starting Phase 1.
The `POST /api/v1/add` response field is **`dataset_id`**. Full response
shape observed:
```
{
  "status": "PipelineRunCompleted",
  "pipeline_run_id": "<uuid>",
  "dataset_id": "<uuid>",
  "dataset_name": "<name>",
  "payload": null,
  "data_ingestion_info": [{"run_info": {...}, "data_id": "<uuid>"}]
}
```
`status: "PipelineRunCompleted"` on the add response strongly suggests
cognify is implicit on add — Phase 1's load-bearing test confirms or
refutes this. The three-candidate fallback in `dataset_lifecycle` has been
collapsed to `response["dataset_id"]`. Phase 0 changes are committed as
`803dca5`.

**This is Phase 1.** It proves the load-bearing premise that an added file's
content is actually extracted into the KG and queryable. Until Phase 1
passes, every later phase is built on a guess. Phase 2 (update), Phase 3
(delete), Phase 4 (ontology stability), and Phase 5 (the sync tool itself)
are summarized in **Future phases** below — kept for planning continuity,
not committed to in detail until Phase 1's findings inform them.

**If Phase 1's load-bearing test fails, stop and evaluate.** Do not
proceed to Phase 2 on the hope that update will somehow fix what add
couldn't do. Pause, capture observations, and reassess the approach
(different cognee version, different search type, different ingestion
shape, or revisit whether incremental sync is the right strategy at all)
before any further code changes.

**Preconditions for starting Phase 1:**

- Phase 0's working-tree changes are committed to `main`. As of writing,
  `git status` still shows pending edits on `instance/SPEC.md`,
  `instance/installed/06-spec-graph/cognee/cognee.md`,
  `instance/installed/12-secrets-key-management/sops-age/secrets.toml`,
  `secrets.enc.yaml`, `.sops.yaml`, and untracked `sync/`. Commit before
  Phase 1.
- The Phase 0 smoke re-run from open question #4 has been executed and
  the dataset-id field name captured. The conftest fallback chain is
  collapsed in the same commit (or as the first Phase 1 commit) — Phase 1
  does not start with the fallback still in place.

## What Phase 1 must prove

1. A file added via `POST /api/v1/add` becomes part of the dataset's KG
   such that a query for content unique to that file returns a hit.
2. The mechanism by which extraction happens is understood and codified —
   either cognify is implicit on add, or it is an explicit follow-up call,
   or it is a job that must be polled to completion. We pick one model and
   document it; we do not paper over uncertainty.
3. Re-adding the same file (same dataset, same filename, identical content)
   has a known, documented behavior — dedup, replace, or duplicate. Phase 5
   needs this answer to decide whether the sync tool can safely re-emit
   adds on retry.
4. The dataset id field name from `add_file`'s response is finalized, and
   the conftest fallback removed.

These are the only assertions Phase 1 carries. Behavioral edges around
*update* and *delete* are explicitly out of scope — they belong to Phases 2
and 3 and conflating them here costs us focus.

## Scope

**In Phase 1:**

- Three new methods on `CogneeClient` (extending, not replacing, the Phase 0
  surface): `cognify`, `search`, `list_documents`. Endpoint paths and
  payload shapes sourced from the live swagger at
  https://cognee.grace.lan/docs — never assumed.
- A `wait_for_cognify` helper (client-level, not test-only) **iff** cognify
  proves to be asynchronous. If cognify is synchronous, this helper is not
  added; we do not write speculative code.
- New conftest fixtures: `unique_token` (function scope, generates a
  collision-free canary string for query assertions) and
  `cognified_dataset` (function scope factory, layers add → cognify →
  ready-wait on top of the existing `dataset_lifecycle` factory so tests
  read as one call).
- New test file `tests/test_addfile.py` with three `integration`-marked
  tests covering the three assertions above, plus a fourth
  `Phase 1 discovery` test that records the search response shape so
  Phase 2/3 can write strict assertions against it.
- Pin down the dataset-id field in `add_file`'s response; collapse the
  three-candidate fallback in `dataset_lifecycle` to the real key.

**Forward-looking design constraints** (carry-overs from Phase 0, restated
because every new method is an opportunity to violate them):

- `CogneeClient` stays thin. New methods return parsed JSON dicts. No
  pydantic models, no response wrappers, no typed envelopes — Phase 4
  decides if/when typing pays for itself.
- No `_for_test` parameters. If a test needs different behavior, the
  fixture composes it; the client does not branch on caller identity.
- `wait_for_cognify` (if added) takes timeout + poll-interval as parameters
  with sane defaults — not pulled from a test config singleton. Production
  daemon callers will pass their own values.
- `search` accepts a `search_type` parameter even if Phase 1 only exercises
  one type, because cognee's swagger exposes a search-type taxonomy and
  Phase 4 will need others. One parameter now, no refactor later.

**Out of scope for Phase 1** (deferred):

- Update/edit semantics (Phase 2)
- Delete and shared-entity behavior (Phase 3)
- Ontology-anchored id stability (Phase 4)
- Any file-watching, git-diffing, or daemon code (Phase 5)
- Strict response-shape typing — Phases 1–3 record actual shapes; Phase 4
  may introduce typed models if churn justifies it
- Concurrency / parallel-test execution. Phase 1 stays serial; the lifecycle
  factory's per-test UUID prefix already lets us parallelize later if needed

## Files to create

```
instance/installed/06-spec-graph/cognee/sync/
  tests/
    test_addfile.py          # four integration tests (see §Critical files below)
```

That is the entire create list. Phase 0 already built the project skeleton;
Phase 1 adds tests and extends existing modules. New files are the smell
to avoid here — every Phase 1 capability fits inside the harness already in
place.

## Files to modify

```
instance/installed/06-spec-graph/cognee/sync/src/cognee_sync/client.py
  + cognify(dataset_name_or_id) → dict          # POST /api/v1/cognify (path TBV from swagger)
  + search(query, search_type, dataset_ids=None) → dict
                                                # POST /api/v1/search (path TBV from swagger)
  + list_documents(dataset_id) → list[dict]     # GET path TBV from swagger
  + wait_for_cognify(...)  ONLY IF cognify is async
                                                # poll list_documents or job status until ready

  No changes to existing methods. No reorganization. New methods grouped
  in a "# Phase 1 methods" section header below the Phase 0 block.

instance/installed/06-spec-graph/cognee/sync/tests/conftest.py
  + unique_token fixture (function scope) — short hex token guaranteed
    not to appear in canonical EposForge content; used as the canary
    string in add+search assertions.
  + cognified_dataset fixture (function scope) — composes
    dataset_lifecycle + cognify + readiness wait into a single factory.
    Returns (dataset_id, response_from_add) so tests don't have to
    re-derive the id. Cleanup is inherited from dataset_lifecycle.
  ~ Collapse the three-candidate id-extraction in dataset_lifecycle
    (lines 100–104) to the actual field name observed in Phase 0.

instance/installed/06-spec-graph/cognee/sync/pyproject.toml
  No changes expected. If swagger reveals cognee uses a non-standard
  payload encoding (e.g., msgpack) we'd add a dep here, but JSON is the
  expected case.

instance/installed/06-spec-graph/cognee/sync/README.md
  + one-line update under the Phase 0 invocation note:
    "Phase 1 integration tests: `epos-secrets uv run pytest -m integration -v`"
```

No edits expected outside `cognee/sync/` for Phase 1. The cognee.md
surgical edits and SPEC.md registration happened in Phase 0; the *full*
cognee.md rewrite still waits for Phase 5.

## Critical files — content notes

### `client.py` — new methods

**`cognify(dataset_name_or_id, *, run_in_background=False)`**

- Path **confirmed** from swagger: `POST /api/v1/cognify`. Body shape
  (field name `datasets` vs `dataset_ids`, etc.) — confirm against the
  live spec before writing; swagger summary suggests both are accepted on
  related endpoints.
- Accept either the dataset *name* or the *id*. Cognee's `add` accepts
  both via separate fields (`datasetName` / `datasetId`); cognify likely
  does too. Pick whichever the swagger documents as canonical; do not
  silently overload our parameter — if both are needed, expose two
  arguments.
- Returns the parsed response dict. If cognify is async and returns a
  job id / pipeline run id, return the dict as-is; the *caller* (or
  `wait_for_cognify`) decides what to do with it. Do not hide async
  behavior behind a synchronous-looking method.

**`search(query, *, search_type, dataset_ids=None, datasets=None, top_k=None)`**

- Path **confirmed** from swagger: `POST /api/v1/search`. Body accepts
  `datasets` (list of names) **or** `dataset_ids` (list of UUIDs) for
  scoping — confirmed via swagger. Expose both parameters; pick whichever
  is more natural at the call site.
- `search_type` is required (no default). Cognee exposes multiple search
  types (graph completion, summaries, chunks, code, etc.); Phase 1 picks
  one — most likely `GRAPH_COMPLETION` or `CHUNKS` depending on what
  reliably surfaces a unique token from a freshly-added doc. Document the
  choice in a one-line code comment when we know which works.
- Returns the parsed JSON dict. The Phase 1 test that asserts a hit reads
  this dict by stringifying and substring-matching on the unique token —
  not by indexing into a hypothesized field shape. Phase 2+ tighten the
  assertion once the shape is observed.
- Note: `GET /api/v1/search` exists too (search history). Out of scope
  for Phase 1; flag for Phase 5 if the sync tool ever needs it.

**`list_documents(dataset_id)`**

- **Swagger has no per-dataset documents endpoint** in the surface we
  inspected — only `GET /api/v1/datasets` (list datasets, top-level).
  Phase 1's first task on this method is to recheck the live swagger for
  a `/api/v1/datasets/{id}/data` or similar; if absent, decide between
  (a) skipping `list_documents` for Phase 1 and using the `search`
  round-trip alone as the readiness signal, or (b) inferring document
  presence from a different endpoint cognee exposes. Do **not** invent a
  path that returns 404 just to satisfy the plan.
- If a path is found: returns the parsed response (list or dict containing
  a list). Used by `wait_for_cognify` (if async) and by Phase 3
  delete-eviction tests.
- If no path is found: drop `list_documents` from Phase 1 entirely; the
  search-token round-trip is sufficient evidence that the doc is in the
  KG, and Phase 3 can solve its own visibility problem when it gets
  there.

**`wait_for_cognify(dataset_name_or_id, *, timeout=180.0, interval=2.0)`**
*(only if Phase 1 finds cognify is async)*

- Polls whatever endpoint cognee exposes for pipeline status. If cognee
  has no status endpoint, polls `list_documents` and waits for an
  observable readiness signal (`status == "ready"` or similar — TBV).
- Raises `TimeoutError` (stdlib) on timeout, with the last-observed
  status in the message so failures are diagnosable.
- Default 180s timeout matches the Phase 0 client default and the
  existing `COGNEE_TEST_STEP_TIMEOUT` convention.

### `conftest.py` — new fixtures

**`unique_token`**
```python
@pytest.fixture()
def unique_token() -> str:
    """A short hex string vanishingly unlikely to appear in real corpus content."""
    return f"phase1-canary-{uuid.uuid4().hex[:12]}"
```
Tests embed this token in canary content and assert that searching for it
returns a hit. The `phase1-canary-` prefix makes test pollution easy to
spot if cleanup ever fails.

**`cognified_dataset`**

Factory fixture. Wraps `dataset_lifecycle` so the common path
(add → cognify → wait) is one call, and so the Phase 1 readiness model is
codified in *one* place — not duplicated across tests:

```python
@pytest.fixture()
def cognified_dataset(client, dataset_lifecycle):
    def _factory(name, content, filename="canary.md"):
        add_response = dataset_lifecycle(name, content, filename)
        dataset_id = add_response[<the-real-key>]
        cognify_response = client.cognify(name)  # or dataset_id, per swagger
        if <cognify-is-async>:
            client.wait_for_cognify(name)
        return dataset_id, add_response
    return _factory
```
Both branches of the `<cognify-is-async>` decision are wired by Phase 1's
first test; once the answer is in, the placeholder collapses to the
chosen path. We do not ship the conditional.

### `tests/test_addfile.py` — four integration tests

All marked `@pytest.mark.integration`. Run with
`epos-secrets uv run pytest -m integration -v`.

1. **`test_added_file_is_queryable_via_search`** — the load-bearing one.
   Add a doc whose body contains `unique_token`; cognify; search for the
   token; assert the token appears in the stringified response. Failure
   here invalidates the entire incremental-sync premise; passing
   establishes the baseline every later phase builds on.

2. **`test_cognify_completes_within_timeout`** — calls `cognify` directly
   on a freshly added doc and asserts it returns successfully (sync) or
   `wait_for_cognify` returns within `timeout=180s` (async). This test's
   *real* job is to lock in which model cognee uses; the assertion is the
   excuse to exercise the path. Add an `xfail`-strict marker if cognee's
   behavior changes between versions, so a regression surfaces loudly.

3. **`test_re_add_identical_content_is_idempotent_or_documented`** — add
   the same file twice (same dataset name, same filename, same content);
   capture both responses; assert that the second call does not raise and
   that `list_documents(dataset_id)` returns a count consistent with the
   observed behavior (1 = dedup, 2 = duplicate). The assertion records
   what cognee *actually* does so Phase 5 can pick a strategy. Includes
   a one-line print recording the observed dedup behavior for the
   Phase 1 changelog.

4. **`test_search_response_shape_discovery`** *(diagnostic, not
   load-bearing)* — issues one search and prints the top-level keys and
   nested structure of the response, the way Phase 0's lifecycle test
   prints `add_file` response keys. Phase 2/3 use this to write strict
   assertions; Phase 1 uses it to confirm we understood the shape before
   moving on. May be removed in Phase 4 once the shape is encoded in
   typed models.

### Existing automation reused, not re-implemented

- `epos-secrets` resolver shim — already injects `COGNEE_API_URL` /
  `COGNEE_API_TOKEN` / `COGNEE_TLS_VERIFY`. Phase 1 needs nothing new.
- `dataset_lifecycle` factory — Phase 1's `cognified_dataset` *wraps*
  it, inheriting the proven cleanup machinery. Cleanup is therefore
  unchanged: every dataset created in Phase 1 is deleted by the same
  teardown loop that proved itself in Phase 0.

## Verification

```powershell
cd instance\installed\06-spec-graph\cognee\sync

# Sanity: Phase 0 smoke still passes (regressions show up first here)
python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run pytest -m smoke -v

# Phase 1 itself
python ..\..\..\12-secrets-key-management\bin\epos-secrets uv run pytest -m integration -v
```

Linux equivalent — same invocation with forward slashes; no behavioral
difference.

Expected outcomes:

1. Phase 0 smoke tests still pass — no regressions from extending the
   client.
2. `test_added_file_is_queryable_via_search` passes: the canary token
   round-trips through add → cognify → search.
3. `test_cognify_completes_within_timeout` passes; the test source code
   reflects the observed sync/async model (one path, not a conditional).
4. `test_re_add_identical_content_is_idempotent_or_documented` passes
   and prints the observed re-add behavior. Whatever cognee does is
   acceptable — the test exists to *characterize*, not to enforce.
5. `test_search_response_shape_discovery` passes and prints the response
   structure. Output is captured in the run log and used to write Phase
   2's strict assertions.
6. After every test, listing datasets via the cognee API shows zero
   entries with the `eposforge-sync-tests-` prefix — confirming Phase 1
   inherits Phase 0's clean teardown unchanged.
7. `dataset_lifecycle`'s id-extraction in `conftest.py:100` is a single
   field access, not a fallback chain — the Phase 0 discovery has been
   acted on.
8. `git status` after a clean run shows no untracked artifacts inside
   `sync/` (no debug dumps, no swagger snapshots committed by accident).

If any of `cognify`, `search`, or `list_documents` fails because the
swagger-derived endpoint shape doesn't match the running container,
adjust against the live swagger at https://cognee.grace.lan/docs.
Discovering the actual surface is part of Phase 1's value, exactly as it
was in Phase 0.

## Phase 1 findings (answers recorded from test run)

All four integration tests passed. Answers to the open questions, for
Phases 2–5 to build on:

1. **Cognify is implicit on add — confirmed.** `add_file` returns
   `status: "PipelineRunCompleted"` and the content is immediately
   queryable without calling `cognify` explicitly. The explicit
   `POST /api/v1/cognify` endpoint also accepts calls successfully (returns
   `PipelineRunCompleted`) but appears to re-run extraction rather than
   being required. `wait_for_cognify` is not needed — neither add nor
   explicit cognify is async. Phase 5 does not need back-pressure on
   per-commit dispatches for the add path.

2. **Search response shapes confirmed:**
   - `GRAPH_COMPLETION` → `list[str]` (LLM-generated completions drawing
     on the KG). Length 1 per query.
   - `SUMMARIES` and `CHUNKS` → `list[dict]` — each item is an
     `IndexSchema` object with keys: `id`, `text`, `type`, `created_at`,
     `updated_at`, `ontology_valid`, `version`, `topological_rank`,
     `belongs_to_set`, `source_pipeline`, `source_task`, `source_node_set`,
     `source_user`, `source_content_hash`, `feedback_weight`,
     `importance_weight`. `CHUNKS` returns raw document text in `text`;
     `SUMMARIES` returns LLM-generated summaries.
   - **Phase 2 strict assertions should key on `CHUNKS` `text` fields** —
     they contain verbatim document content, not LLM interpretation, making
     ALPHA-gone / BETA-present checks deterministic. `GRAPH_COMPLETION`
     passes the unique-token check only because the LLM echoes the token
     name in its response, which is semantically noise.

3. **Re-add is dedup — confirmed, safe to retry adds.** Second add with
   identical content returns `status: "PipelineRunAlreadyCompleted"` and
   `list_documents` shows 1 doc. Phase 5 can re-emit adds on retry without
   risking duplicate KG entries.

4. ~~**dataset_id field**~~ **Resolved pre-Phase 1.** Field is `dataset_id`.
   Also: `data_ingestion_info[0]["data_id"]` is the per-document id
   (stable UUID); Phase 3 delete tests will use
   `DELETE /api/v1/datasets/{dataset_id}/data/{data_id}`.

5. **Per-dataset documents endpoint confirmed.** `GET /api/v1/datasets/{dataset_id}/data`
   works; `list_documents` ships in Phase 1.

6. **`cognify` response shape is a dict keyed by dataset_id**, not a flat
   status dict: `{<dataset_uuid>: {status, pipeline_run_id, dataset_id, …}}`.
   Phase 2 must not assume a flat response when calling `cognify` after
   an update.

7. **Windows cp1252 terminal encoding caveat.** LLM-generated search
   results can contain non-ASCII characters (e.g. `→` U+2192). Print
   statements that render search results must use `ascii()` not `!r`/`str`.
   Fixed in `test_addfile.py` — applies to any future test that prints
   `GRAPH_COMPLETION` results.

## Future phases (record, not commitment)

These are out of scope for Phase 1 and remain notional. Each phase adds
tests and client methods on top of the same harness; no harness redesign
expected.

**Phase 2 — `updatefile` behavior (the GraphRAG-burn test).** Prove edits
to a same-named file actually update the KG, rather than no-op-ing on
filename or content hash. Add file with token ALPHA, update same path to
BETA, assert BETA queryable AND ALPHA gone. Capture whether `document_id`
survives updates (in-place vs. delete+add semantics) — Phase 5 needs the
answer. Open question: does cognee have an explicit update endpoint, or is
update = delete + add?

**Phase 3 — `deletefile` behavior.** Prove deletes evict KG content and
characterize shared-entity behavior. Single-doc delete = unique-content
gone. Two-doc setup with shared entity, delete one = shared entity
persists. Delete + re-add restores content (no tombstones). Open
questions: does delete cascade, or correctly retain shared entities? Are
deletes synchronous in the doc list?

**Phase 4 — Ontology grounding stability.** Prove ontology-anchored
entities keep canonical ids across edits to documents that reference them.
Load a known ontology term into a doc, capture its id, edit the doc,
capture the id again, assert match. Stricter variant: same but with
delete + re-add. Likely needs a small fixture `.ttl` under
`sync/tests/fixtures/`. Open questions: does cognee expose stable
ontology-anchored ids? Is the `.ttl` per-dataset or per-instance?

**Phase 5 — the sync tool itself.** A git-driven process that, on commit
(or Gitea pre-receive hook), diffs changed files, classifies each as
add/update/delete, and dispatches the corresponding cognee API calls.
CLI-invoked-by-Gitea-Actions vs. long-running watcher is a design choice
informed by Phase 1–4 findings on update latency and idempotency.

**Final cleanup steps (last in the overall plan):**

- **Cognee.md full rewrite** at
  [instance/installed/06-spec-graph/cognee/cognee.md](mnt/raid-storage/src/git/gh/eposforge/instance/installed/06-spec-graph/cognee/cognee.md).
  Phase 0 did the surgical harm-reduction edits. The final rewrite drops
  the `(in transition)` markers, points the invocation surface at whatever
  Phase 5 ships, updates the metadata table to reflect actual
  incremental-update behavior verified by Phases 1–4, and resolves the v1
  contract gaps that closed along the way.
- **`epos-secrets.ps1` wrapper.** The sops-age adapter ships
  `epos-secrets` as a Python script only — unlike its sibling
  `epos-authorize.ps1` and `epos-machine-request.ps1` shims. Adding a
  `.ps1` wrapper is a small follow-up against the sops-age adapter if
  daily Windows usage of the Phase 5 sync tool makes the friction worth
  fixing. Not Phase 1.
