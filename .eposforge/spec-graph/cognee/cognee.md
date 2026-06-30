---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

> **STATUS:** Active. `cognee-sync` (Phases 0–5 complete) is the
> sole ingestion path. See `./sync/README.md` for invocation,
> environment, and tests.
> For Cognee MCP self-consumption and adopter substitution guidance,
> see `.eposforge/tool-transport/mcp-stdio-and-http/cognee-mcp-self-consume-runbook.md`.

# Installed Adapter: cognee-ontology-preprocessor → Spec Graph (Component 6)

---

## Deployment topology (read this first)

**Two containers, single KG.** Both live in the docker-compose project at
`/mnt/raid-storage/docker-volume-mounts/cognee/`.

| Container | Role | Storage | Build context |
|---|---|---|---|
| `dkr-cgnee-api` | Cognee FastAPI backend — **owns** the KG | `./data/cognee_system` (host volume) | `Dockerfile` (extends `cognee/cognee:main`) |
| `dkr-cgnee-mcp` | MCP server — **stateless proxy** to the API | none (proxy mode) | `Dockerfile.mcp` (extends `cognee/cognee-mcp:main`) |

The MCP container runs with `API_URL=http://dkr-cgnee-api:8000` so every
`remember` / `recall` / `forget` MCP tool call is forwarded over HTTP to the
backend. There is one KG on one volume; both surfaces (MCP and HTTP) read and
write to it. Do not bring up a second KG on the MCP container.

```
Claude Code ──MCP/SSE──▶ dkr-cgnee-mcp ──HTTP──▶ dkr-cgnee-api ──▶ ./data/cognee_system
cognee-sync CLI ─────────────────HTTP──────────▶ dkr-cgnee-api ─────────────┘
```

**Where to ingest:** always against `dkr-cgnee-api`. `cognee-sync` (see
`./sync/`) targets `https://cognee-api.grace.lan`. Do **not** target the MCP
container — in proxy mode it has no local store; in direct mode it would create
a second, divergent KG.

**Where to query:**
- From Claude Code: the cognee MCP tools (`mcp__cognee__recall` etc.) — they
  hit the MCP container at `https://cognee-mcp.grace.lan/sse`, which proxies
  to the API.
- From scripts / HTTP: `https://cognee-api.grace.lan/api/v1/*` directly.

For adopter-facing recommendation queries, use
`.eposforge/spec-graph/cognee/scripts/adopter-recall.py` instead of
raw `recall`/`search` output. The wrapper enforces two answering rules:
- EF-011 boundary: rewrite EposForge-internal `.eposforge/...` paths to
  adopter-layer placeholders.
- EF-012 clarity: add `[maturity: shipped|partial|intent]` tags per
  recommendation line.

### Why this layout, not a single container

The MCP server is `cognee/cognee-mcp:main` (the published MCP-protocol bridge),
the API is `cognee/cognee:main` (the FastAPI backend). They are separate
upstream images. The MCP image's `cognee_client.py` is built for either
direct-mode (own embedded store) or API/proxy mode — we use proxy mode so
there's a single source of truth.

### Switching modes

| Mode | `API_URL` env on MCP | MCP volumes | Notes |
|---|---|---|---|
| Proxy (current) | `http://dkr-cgnee-api:8000` | none | shared KG |
| Direct (don't use) | unset | local volume mounted | divergent KG, was the source of recent confusion |

### Upstream image quirks we patched

`Dockerfile.mcp` patches three bugs in `cognee/cognee-mcp:main` that only
matter in **direct** mode (they're inert in proxy mode since the LLM calls and
graph access happen inside the API container). Kept in place as a safety net in
case proxy mode is ever disabled:

1. `anthropic` Python SDK is missing from the upstream image despite
   `LLM_PROVIDER=anthropic` being the intended config. Patched: `pip install anthropic`.
2. `cognee.infrastructure.llm.structured_output_framework.litellm_instructor.llm.anthropic.adapter.AnthropicAdapter.acreate_structured_output` does not pass `max_tokens` to the Anthropic
   messages API. Patched to set `max_tokens=self.max_completion_tokens`.
3. `cognee.api.v1.recall.recall()` (cognee 1.0.4) never resolves the default
   user when `user=None`, so it crashes with `AttributeError: 'NoneType' object has no attribute 'id'`. Patched to call `get_default_user()` — the same pattern `remember()` already uses.

The API container (`cognee/cognee:main`, currently `cognee 1.0.7-local` with
`instructor 1.15.1`, `anthropic 0.86.0`) does not need these patches in
practice — 82 cognify runs / 0 errors over 48h confirmed.

### Confusing-error decoder

| Symptom | Real cause |
|---|---|
| `Failed to initialize Ladybug database: Could not map version_code to proper Ladybug version` | **File-lock contention**, not a real version mismatch. Some second process is trying to open `cognee_graph_ladybug` while the container holds the exclusive lock. Cognee's migration-fallback path masks the real `RuntimeError: Could not set lock on file` and reports the version-code lookup that fails because Ladybug 0.16.0 writes version_code 40, but cognee's migration table only knows 34–39. Don't try to "migrate" — find the second process. If no external second process is visible, the prior container run left a stale lock in `./data/cognee_system/databases/`. Recovery: **wipe and restart** — see **Recovery procedures** below. This destroys the KG; follow with a full corpus rebuild. |
| `database is locked` or `no such table: data` during bulk cognify | Cognee internal SQLite worker-concurrency. A large (80+ doc) batch spawns concurrent writer tasks; if any task holds a lock past the batch, subsequent re-runs hit it. Recovery: re-run the same `cognee-sync --added` command — the second pass picks up all missed docs cleanly. If the second pass also fails, restart `dkr-cgnee-api` to clear stale in-process locks, then re-run. |
| `Recall failed: 'NoneType' object has no attribute 'id'` | cognee 1.0.4 in the MCP image only. Already patched in `Dockerfile.mcp`. Won't appear in proxy mode. |
| `HTTP 404 Could not find session` after a restart | Expected — SSE sessions don't survive container recreation. Reconnect via Claude Code's `/mcp`. |

### Recovery procedures

#### KG wipe and restart (Ladybug stale-lock recovery)

Only use this when the Ladybug error appears at container startup and no
external process is holding the lock. **This destroys the entire KG.** Must be
followed by a full corpus rebuild.

```bash
COMPOSE_FILE=/mnt/raid-storage/docker-volume-mounts/cognee/docker-compose.yml
docker compose -f "$COMPOSE_FILE" stop dkr-cgnee-api
sudo rm -rf /mnt/raid-storage/docker-volume-mounts/cognee/data/cognee_system
sudo mkdir -p /mnt/raid-storage/docker-volume-mounts/cognee/data/cognee_system
sudo chown -R cdfadmin: /mnt/raid-storage/docker-volume-mounts/cognee/data/cognee_system
docker compose -f "$COMPOSE_FILE" start dkr-cgnee-api
# Wait ~10s for the health check, then run a full rebuild:
bash.eposforge/spec-graph/cognee/scripts/bulk-rebuild.sh
```

Also reset the cognee-sync state DB so it re-stages all files:

```bash
rm -f.eposforge/spec-graph/cognee/sync/.cognee-state.db
```

---

> Living Spec for the Cognee ontology-grounded extraction adapter installed
> in this repo. Per [../../../01-architecture/00-adapter-pattern/adapter-pattern.md](../../../01-architecture/00-adapter-pattern/adapter-pattern.md),
> all required universal and component-specific fields are declared here.

---

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `cognee-ontology-preprocessor` |
| `component` | `spec-graph` |
| `version` | `unpinned` (latest `cognee` release) |
| `status` | `experimental` |
| `privacy_posture` | `vendor-default` (Anthropic for LLM; OpenAI for embeddings during indexing) |
| `cost_hint` | metered (Anthropic + OpenAI APIs for indexing) |
| `capabilities` | `ontology-grounded-extraction`, `entity-normalization`, `synonym-collapse`, `embedded-graph-write` |
| `invocation_surface` | `cognee-sync` CLI (`./sync/`); per-file `--added` / `--modified` / `--deleted` over HTTP to `dkr-cgnee-api` |

### Spec Graph required fields

| Field | Value |
|---|---|
| `query_languages` | cognee HTTP API (`/api/v1/recall`, `/api/v1/search`); natural language via cognee MCP |
| `projection_format` | graph nodes/edges in embedded Kuzu + embeddings in embedded LanceDB |
| `rebuild_target` | per-file via cognee-sync (incremental); bulk cognify over the whole dataset typically completes in a few minutes |
| `incremental_update` | true — `cognee-sync` provides git-diff-driven incremental updates (Phases 0–5 complete) |

### Repo-specific fields

| Field | Value |
|---|---|
| `script` | `cognee-sync` CLI at `./sync/src/cognee_sync/cli.py` |
| `ontology_file` | `00-vision/01-ontology.ttl` |
| `llm_provider` | `anthropic` → `claude-haiku-4-5-20251001` (pinned in `.env` on the cognee compose project) |
| `embedding_provider` | cognee default (OpenAI `text-embedding-3-small` via `EMBEDDING_API_KEY`; runs on `dkr-cgnee-api`) |
| `graph_database` | embedded Kuzu (`cognee_graph_ladybug`) + embedded LanceDB (`cognee.lancedb/`), both on the `dkr-cgnee-api` volume at `./data/cognee_system/databases/` |
| `cognee_root` | `dkr-cgnee-api`'s `/app/cognee/.cognee_system/` (host-mounted at `/mnt/raid-storage/docker-volume-mounts/cognee/data/cognee_system/`) |

---

## Role in the Runtime Pipeline

This adapter is the active extraction path. The flow is:

1. `cognee-sync` (the CLI under `./sync/`) computes per-file diffs and
   issues `POST /api/v1/add` for new/modified files and `DELETE
   /api/v1/datasets/{id}/data/{data_id}` for removed files, all against
   `dkr-cgnee-api`.
2. After the batch of add/update operations, `cognee-sync` issues a
   single `POST /api/v1/cognify` against the affected dataset (default:
   `eposforge-sync`). Cognify drives `classify_documents`,
   `extract_chunks_from_documents`, and `extract_graph_and_summarize`
   to populate the KG. When `--ontology-key` (or `$COGNEE_ONTOLOGY_KEY`)
   is set, cognify is called with `ontologyKey=[key]` so extracted
   entities are anchored to the uploaded ontology — see
   §Ontology grounding below.
3. Cognee writes graph nodes/edges into `cognee_graph_ladybug` (embedded
   Kuzu) and embeddings into `cognee.lancedb/` (embedded LanceDB) on
   the `dkr-cgnee-api` volume.

The MCP surface (`dkr-cgnee-mcp`) runs in proxy mode (`API_URL=http://dkr-cgnee-api:8000`),
so `recall` / `remember` / `forget` over MCP read and write the same KG.

---

## Ontology grounding

Cognee anchors extraction to an ontology only when cognify is called with an
`ontologyKey` naming a previously-uploaded ontology. Anchoring is applied at
cognify time, per run, and is **not retroactive** — nodes from earlier
unanchored runs keep their LLM-improvised `EntityType` taxonomy.

**Build paths** (both via `cognee-sync`; ontology key defaults to `eposforge`):

- **Full rebuild** — `scripts/bulk-rebuild.sh`. Uploads `00-vision/01-ontology.ttl`
  as the `eposforge` anchor (`--upload-ontology`), stages every tracked `*.md`/`*.ttl`
  **except** the ontology TTL itself **and raw backlog items** (`backlog/`, `.eposforge/backlog/`, `plans/` — see EF-057), and cognifies with `ontologyKey=[eposforge]`.
  The ontology is the anchor, not a corpus document — ingesting it as a document
  produced an isolated `rdf_type`/`fulfillsSlot` island and is no longer done.
  Raw backlog item content stays out of the main Spec Graph (independent file-based backlog graph instead); mechanics are still referenceable via ontology (ef:BacklogComponent etc.).
- **Incremental** — on push, `cognee-sync --ontology-key eposforge --added/--modified/--deleted ...`.
  Assumes the ontology is already uploaded; just threads the key into the per-run
  cognify so new/changed docs anchor against the current ontology.
  Raw backlog paths are filtered at the caller (see update-spec-graph skill and bulk-rebuild).

**The uploaded ontology must be RDF/XML, not Turtle (cognee 1.0.7-local quirk).**
`RDFLibOntologyResolver`'s file-object load path (the one the upload endpoint
uses) parses with a hardcoded `format="xml"`, so a Turtle file uploaded as
`eposforge.owl` fails to parse, the graph falls back to `None`, and the
class/individual lookup is empty. Symptom: cognify "succeeds" with `ontologyKey`
set, but the API log shows `OntologyAdapter: No close match found for '<x>' in
category 'classes'/'individuals'` for *everything* and every node carries
`ontology_valid: false` — i.e. nothing anchored. `cognee-sync`'s
`upload_ontology` therefore converts Turtle → RDF/XML (via `rdflib`) before
upload; the on-disk source of truth stays `00-vision/01-ontology.ttl`. Verified
fix: the resolver then reports `Lookup built: 46 classes, 60 individuals` and
matches `concept`/`component`/`adapter`/`darkfactory`/`pillar`.

**Ontology changes require a full rebuild with a KG wipe — not an incremental run.**
Two compounding reasons: (1) no retroactive re-anchoring, so a changed ontology
only affects docs cognified after the change; (2) content-hash dedup
(`PipelineRunAlreadyCompleted`) skips re-extraction of unchanged docs, so simply
re-running over the same corpus will silently *not* re-anchor. After editing the
ontology, perform the KG wipe (§Recovery procedures) and then run `bulk-rebuild.sh`.
Document-only changes are safe incrementally.

> Open question: whether passing a *new* `ontologyKey` over content-hash-dedup'd
> documents forces re-resolution (it might, if the cache keys on content+ontology).
> If confirmed, ontology changes could skip the KG wipe. Untested — verify before
> relying on it.

---

## Active ingestion path

`cognee-sync` is the active ingestion path. Invocation, environment, and
state-store details live in [`./sync/README.md`](./sync/README.md).
Phases 0–5 of the strangler-fig migration are complete. The legacy
`ingest_dual_container.sh` artifact is removed.

---

## Observed API behavior (Phases 0–1 findings)

Behavioral observations from Phase 0 smoke tests and Phase 1 integration tests
against the running `dkr-cgnee-api` container. Observations against the live
deployment — not the upstream Cognee spec — and may change with container updates.

### Confirmed endpoints

| Method | Path | Notes |
|---|---|---|
| `POST` | `/api/v1/add` | Add files to a dataset; creates dataset if absent |
| `POST` | `/api/v1/cognify` | Explicit KG extraction (normally implicit — see below) |
| `POST` | `/api/v1/search` | Query the KG; `search_type` required |
| `GET` | `/api/v1/datasets` | List all datasets |
| `GET` | `/api/v1/datasets/{dataset_id}/data` | List data items in a dataset |
| `DELETE` | `/api/v1/datasets/{dataset_id}` | Delete a dataset |
| `DELETE` | `/api/v1/datasets/{dataset_id}/data/{data_id}` | Delete one data item |

### `POST /api/v1/add` — response shape

```json
{
  "status": "PipelineRunCompleted",
  "pipeline_run_id": "<uuid>",
  "dataset_id": "<uuid>",
  "dataset_name": "<name>",
  "payload": null,
  "data_ingestion_info": [
    {
      "run_info": { "status": "...", "pipeline_run_id": "...", "..." : "..." },
      "data_id": "<uuid>"
    }
  ]
}
```

`data_ingestion_info[0]["data_id"]` is the per-document UUID. Required for
`DELETE /api/v1/datasets/{dataset_id}/data/{data_id}` in update and delete flows.

### Pipeline behavior

- **Cognify is NOT implicit on `add_file` (cognee 1.0.7+).** Prior Phase 1
  observation said cognify ran synchronously during `POST /api/v1/add`. That
  was true in earlier cognee versions; in 1.0.7-local only the
  `resolve_data_directories` + `ingest_data` tasks fire — the graph-extraction
  tasks (`classify_documents`, `extract_graph_and_summarize`) do NOT run.
  Files land in raw storage and become listable via `list_documents`, but no
  DocumentChunk / Entity nodes are created. **`POST /api/v1/cognify` is
  required** to populate the KG. `cognee-sync` calls it automatically at the
  end of each CLI invocation (unless `--no-cognify` is passed). Direct
  callers must do the same.
  - **Symptom to recognize:** `recall` returns "context does not contain
    information about X" for content you know was just added. Before suspecting
    embeddings or search bugs, check `TextDocument` node count in the graph vs
    `list_documents` count — if they diverge, cognify never ran.
  - **Bulk cognify is concurrency-fragile.** Re-running cognify after a fresh
    `add_file` of 80+ docs produced ~10 SQLite errors (`no such table: data`,
    `database is locked`) from worker contention. Failed docs leave no
    graph nodes but no permanent damage. **Re-run cognify once more on the
    same dataset** and the missing docs are picked up cleanly; the contention
    burst doesn't repeat because the prior workers have released their locks.
    Plan for a two-pass cognify when bulk-ingesting from scratch. If the
    second pass also fails with lock errors, restart `dkr-cgnee-api` to
    clear stale in-process worker locks, then re-run. A third pass has not
    been needed in practice.
- **No async / polling.** Neither `add` nor explicit `cognify` returns a job id
  to poll. No `wait_for_cognify` is needed.
- **Re-add deduplicates on identical content.** Same content re-added to the same
  dataset returns `status: "PipelineRunAlreadyCompleted"` and the same `data_id`.
  `list_documents` shows 1 doc. Safe to retry adds on the same content.

### `POST /api/v1/cognify` — response shape

Keyed by dataset UUID, not a flat status dict:

```json
{
  "<dataset_uuid>": {
    "status": "PipelineRunCompleted",
    "pipeline_run_id": "<uuid>",
    "dataset_id": "<uuid>",
    "dataset_name": "<name>",
    "payload": null,
    "data_ingestion_info": [{ "..." : "..." }]
  }
}
```

### `POST /api/v1/search` — response shapes by `search_type`

| `search_type` | Response type | `text` field | Use for |
|---|---|---|---|
| `GRAPH_COMPLETION` | `list[str]` | LLM-generated completion (non-verbatim) | Exploratory queries only |
| `SUMMARIES` | `list[IndexSchema]` | LLM-generated summary | — |
| `CHUNKS` | `list[IndexSchema]` | Verbatim document text chunk | Content-presence assertions |

**Use `CHUNKS` for deterministic content assertions in tests.** `GRAPH_COMPLETION`
may echo a token name in LLM prose even when the token is not present in the KG.

`IndexSchema` dict keys: `id`, `text`, `type` (`"IndexSchema"`), `created_at`
(epoch ms), `updated_at`, `ontology_valid`, `version`, `topological_rank`,
`belongs_to_set`, `source_pipeline`, `source_task`, `source_node_set`,
`source_user`, `source_content_hash`, `feedback_weight`, `importance_weight`.

### `GET /api/v1/datasets/{dataset_id}/data` — response shape

Returns a list of data item objects. Confirmed schema:

```json
[
  {
    "id": "<uuid>",
    "name": "<filename-without-extension>",
    "createdAt": "2026-05-09T20:02:04.461122",
    "updatedAt": "2026-05-09T20:02:05.063778",
    "extension": "txt",
    "mimeType": "text/plain",
    "rawDataLocation": "file:///app/cognee/.data_storage/text_<hash>.txt",
    "datasetId": "<dataset-uuid>"
  }
]
```

`id` matches `data_ingestion_info[0]["data_id"]` from `add_file`. Files are stored
as `txt` regardless of the original extension (`.md` → stored as `txt`). `name`
is the filename without extension.

### Re-add with new content — accumulation behavior (Phase 2 finding)

Re-adding a file with the **same filename but different content** to an existing
dataset **accumulates** — both the old and new entries persist. `list_documents`
returns 2 items with the same `name` but different `id` values.

Consequence for the sync tool (Phase 5): **update = `delete_document` + `add_file`**.
The sync tool must persist `data_id` per tracked file path so it can issue the
explicit delete before re-adding updated content.

`delete_document` confirmed to work: after `DELETE /api/v1/datasets/{dataset_id}/data/{data_id}`,
`list_documents` shows 0 items for that data_id. Re-add then adds fresh content with a new `id`.

### Phase 3 findings — delete behavior

All file-level assertions confirmed via `list_documents`:

- **`delete_document` is synchronous.** `list_documents` reflects the removal
  immediately after the call returns. Phase 5 does not need to poll after delete.
- **Partial delete in a two-document dataset is non-cascading at the file level.**
  Deleting doc A leaves doc B in `list_documents`. Phase 5 can safely issue
  per-document deletes without affecting sibling documents in the same dataset.
- **Delete + re-add of identical content assigns the same `data_id`.** Content-hash
  dedup is active even when the document was previously deleted — the pipeline
  reruns (`status: "PipelineRunCompleted"`, not `"PipelineRunAlreadyCompleted"`)
  but the same UUID is assigned. Implication for Phase 5: if a tracked file is
  deleted and then its content is restored unchanged, the sync tool will re-issue
  the same `data_id` and may not need to update its sidecar.
- **KG-level eviction after delete: unconfirmed.** CHUNKS semantic search for
  UUID-like tokens is unreliable (all advisory probes returned `found=False`
  regardless of whether content should have been present). The file-level behavior
  is correct; whether deleted documents leave orphaned KG nodes is an open
  question. Phase 4 or a dedicated KG-inspection approach is needed to answer it.

### Phase 4 findings — graph structure and ontology anchoring

**`GET /api/v1/datasets/{dataset_id}/graph` returns the global instance graph.**
The `dataset_id` path parameter does not scope the result to a single dataset —
all nodes and edges from the entire Cognee instance are returned. Node schema:
`{id, label, properties, type}`. Node types observed: `TextSummary`, `Entity`,
`EntityType`, `DocumentChunk`. Properties include `source_content_hash`,
`source_pipeline`, `source_task`, `ontology_valid`, `text`.

**Graph node IDs are stable across delete + re-add of identical content.**
The full set of 50 instance node UUIDs was identical before and after a
delete + re-add cycle. Phase 5 downstream KG consumers will not see entity ID
churn from sync operations on unchanged content.

**Ontology upload requires `.owl` file extension.** The endpoint
`POST /api/v1/ontologies` validates the filename extension and rejects anything
that is not `.owl`. Turtle/N-Triples content is accepted if the filename ends
in `.owl`. The `ontology_key` field is the user-defined identifier referenced
via the `ontologyKey` parameter on `POST /api/v1/cognify`.

**Ontology-anchored cognify produces `PhaseTestEntity`-referencing nodes.**
After `cognify(datasets=[name], ontologyKey=[key])`, nodes referencing the
ontology label appear in the graph: a `TextSummary` node with summarised text
mentioning the entity, and a `DocumentChunk` node with the raw document text.
`ontology_valid: False` on all observed nodes — the ontology influences
extraction but the `ontology_valid` flag is not set to `True` for matched
entities (possibly a Cognee version behaviour).

### Phase 5 — sync tool design (confirmed)

The incremental sync tool (`cognee-sync` CLI) ships as part of this package.
Invocation requires `epos-secrets` for secret injection:

```powershell
# On push, compute diff and sync:
epos-secrets uv run cognee-sync `
    --added   path/new.md `
    --modified path/changed.md `
    --deleted  path/removed.md

# Inspect tracked state:
epos-secrets uv run cognee-sync --status

# Dry-run (no API calls):
epos-secrets uv run cognee-sync --dry-run --added path/new.md
```

| Env var | Default | Purpose |
|---|---|---|
| `COGNEE_DATASET_NAME` | `eposforge-sync` | Cognee dataset that all tracked files go into |
| `COGNEE_STATE_DB` | `.cognee-state.db` | SQLite state store path (`file_path -> data_id`) |

**Update mechanism confirmed (Phase 2):** update = `delete_document(old_data_id)` + `add_file`.
The state store persists the `data_id` per tracked file path so the correct entry
can be deleted before re-add. Identical content is a no-op (content-hash check
skips the API call).

### Windows encoding note

`GRAPH_COMPLETION` results and string print statements may contain non-ASCII
Unicode (e.g. `→` U+2192). Use `ascii(result)` not `repr(result)`, and avoid
Unicode literals in print strings in test files, when targeting a cp1252 terminal.

---

## Environment variables

| Variable | Required | Notes |
|---|---|---|
| `LLM_API_KEY` or `ANTHROPIC_API_KEY` | yes (dual-container ingestion) | LLM extraction key for backend add/cognify |
| `OPENAI_API_KEY` | optional (dual-container ingestion) | depends on embedding/provider configuration |

---

---

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| Unpinned `cognee` version | Breaking API changes may silently change graph schema or ontology resolution | Pin version in `requirements.txt` once the adapter is promoted from experimental |
| No audit events | Indexing runs are not logged to the Audit & Observability slot | Wire structured events when a factory Audit Adapter is installed |
| Ontology change forces full KG wipe + rebuild | Content-hash dedup skips re-extraction; anchoring is not retroactive | Verify whether a new `ontologyKey` defeats dedup; if so, incremental re-anchor is possible |
