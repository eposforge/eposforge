---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

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
| `status` | `implemented, optional, experimental` |
| `privacy_posture` | `vendor-default` (Anthropic for LLM; OpenAI for embeddings during indexing) |
| `cost_hint` | metered (Anthropic + OpenAI APIs for indexing) |
| `capabilities` | `ontology-grounded-extraction`, `entity-normalization`, `synonym-collapse`, `neo4j-write` |
| `invocation_surface` | `CLI script (instance/scripts/spec-graph-rebuild.sh --cognee)` |

### Spec Graph required fields

| Field | Value |
|---|---|
| `query_languages` | Cypher (shared Neo4j instance with `graphrag-neo4j` adapter) |
| `projection_format` | graph nodes/edges (written directly to Neo4j) |
| `rebuild_target` | varies by corpus size; runs before GraphRAG community detection pass |
| `incremental_update` | `false` — full prune-and-reproject (`cognee.prune()` before each run) |

### Repo-specific fields

| Field | Value |
|---|---|
| `script` | `instance/scripts/spec-graph-cognee.py` |
| `ontology_file` | `00-vision/01-glossary.ttl` |
| `llm_provider` | `litellm` → `anthropic/claude-3-5-sonnet-20240620` |
| `embedding_provider` | `openai` → `text-embedding-3-small` (1536 dims) |
| `graph_database` | `neo4j` (shared instance; same `NEO4J_URI` / `NEO4J_USERNAME` / `NEO4J_PASSWORD` env vars) |
| `cognee_root` | `instance/installed/06-spec-graph/cognee/.cognee/` (gitignored) |

---

## Role in the rebuild pipeline

This adapter is the **optional first stage** of the Spec Graph rebuild. When
`--cognee` is passed to `spec-graph-rebuild.sh`, the pipeline runs in this order:

1. **`spec-graph-cognee.py`** — Cognee reads the corpus Markdown files, grounds
   entity extraction against `00-vision/01-glossary.ttl`, normalizes synonyms,
   and writes a clean entity/relationship graph directly into Neo4j. It then
   exports entities and relationships as Parquet files into
   `instance/installed/06-spec-graph/graphrag/output/` for the next stage.
2. **GraphRAG community detection** — `spec-graph-index.sh` runs
   `graphrag index` using the Cognee-produced Parquet as its starting graph,
   producing higher-quality Leiden communities because the input entities are
   already normalized.
3. **`spec-graph-import.sh`** — imports the final Parquet tables back into
   Neo4j, attaching vector embeddings and community reports.

Without `--cognee`, step 1 is skipped and GraphRAG performs extraction
from scratch with no ontology grounding.

---

## Environment variables

| Variable | Required | Notes |
|---|---|---|
| `ANTHROPIC_API_KEY` | yes | LLM extraction (Claude 3.5 Sonnet via LiteLLM) |
| `OPENAI_API_KEY` | yes | Embeddings (`text-embedding-3-small`) |
| `NEO4J_URI` | yes | e.g. `bolt://<neo4j-host-or-ip>:7688` |
| `NEO4J_USERNAME` | yes | default `neo4j` |
| `NEO4J_PASSWORD` | yes | |

---

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| Unpinned `cognee` version | Breaking API changes may silently change graph schema or ontology resolution | Pin version in `requirements.txt` once the adapter is promoted from experimental |
| Shared Neo4j namespace | Cognee and GraphRAG both write `Entity` nodes; schema conflicts possible if field names diverge | Namespace Cognee nodes (e.g. `CogneeEntity`) or add a schema validation step in the import script |
| No audit events | Indexing runs are not logged to the Audit & Observability slot | Wire structured events when a factory Audit Adapter is installed |
| Full prune on every run | `cognee.prune()` clears all Cognee state before each rebuild; no incremental update | Explore Cognee's diff/update APIs once the corpus stabilizes |
