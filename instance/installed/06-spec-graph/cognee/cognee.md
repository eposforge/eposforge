---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

> **STATUS: in revision.** Incremental-sync development is underway in
> `./sync/`. Sections below that describe `ingest_dual_container.sh`
> refer to a deleted artifact and should not be followed; treat
> `./sync/README.md` as the current authority for invocation.

# Installed Adapter: cognee-ontology-preprocessor → Spec Graph (Component 6)

> Living Spec for the Cognee ontology-grounded extraction adapter installed
> in this repo. Per [../../../../01-architecture/00-adapter-pattern.md](../../../../01-architecture/00-adapter-pattern.md),
> all required universal and component-specific fields are declared here.

---

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `cognee-ontology-preprocessor` |
| `component` | `06-spec-graph` |
| `version` | `unpinned` (latest `cognee` release) |
| `status` | `implemented, default, experimental` |
| `privacy_posture` | `vendor-default` (Anthropic for LLM; OpenAI for embeddings during indexing) |
| `cost_hint` | metered (Anthropic + OpenAI APIs for indexing) |
| `capabilities` | `ontology-grounded-extraction`, `entity-normalization`, `synonym-collapse`, `embedded-graph-write` |
| `invocation_surface` | `in revision (see ./sync/ for in-flight implementation)` |

### Spec Graph required fields

| Field | Value |
|---|---|
| `query_languages` | Backend API |
| `projection_format` | graph nodes/edges in embedded store |
| `rebuild_target` | varies by corpus size; runs before GraphRAG community detection pass |
| `incremental_update` | `false (in transition — see ./sync/)` — full prune-and-reproject while sync is in development |

### Repo-specific fields

| Field | Value |
|---|---|
| `script` | `in revision (see ./sync/ for in-flight implementation)` |
| `ontology_file` | `00-vision/01-glossary.ttl` |
| `llm_provider` | `anthropic` → `claude-sonnet-4-5` |
| `embedding_provider` | `fastembed` (local; `BAAI/bge-small-en-v1.5`; no API key required) |
| `graph_database` | embedded Kuzu/LanceDB |
| `cognee_root` | `instance/installed/06-spec-graph/cognee/.cognee/` (gitignored) |

---

## Role in the Runtime Pipeline

This adapter is the active extraction path for the running dual-container
deployment. The flow is:

1. Build a filtered corpus snapshot (`*.md` + `*.ttl`) from repo source roots.
2. Copy that snapshot into `dkr-cgnee-api`.
3. Run `cognee.add()` and `cognee.cognify()` in the backend container.

The resulting graph is stored in Cognee's embedded runtime data store.

---

## Active ingestion path

Active ingestion is being rewritten under `./sync/`. Until Phase 5 lands,
manual ingestion is performed by the operator outside this adapter spec.
See `./sync/README.md` for the current bootstrapping and test instructions.

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

- **Cognify is implicit on `add_file`.** The full KG-extraction pipeline runs
  synchronously during `POST /api/v1/add`. Content is queryable immediately after
  the call returns. `POST /api/v1/cognify` is accepted but re-runs extraction;
  it is not required.
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

### Windows encoding note

`GRAPH_COMPLETION` results may contain non-ASCII Unicode (e.g. `→` U+2192).
Use `ascii(result)` not `repr(result)` when printing to a cp1252 terminal.

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
| Full prune on every run | `cognee.prune()` clears all Cognee state before each rebuild; no incremental update | Explore Cognee's diff/update APIs once the corpus stabilizes |
