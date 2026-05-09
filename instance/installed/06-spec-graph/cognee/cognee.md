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
