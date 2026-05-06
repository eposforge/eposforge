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
| `status` | `implemented, default, experimental` |
| `privacy_posture` | `vendor-default` (Anthropic for LLM; OpenAI for embeddings during indexing) |
| `cost_hint` | metered (Anthropic + OpenAI APIs for indexing) |
| `capabilities` | `ontology-grounded-extraction`, `entity-normalization`, `synonym-collapse`, `embedded-graph-write` |
| `invocation_surface` | `CLI script (instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh)` |

### Spec Graph required fields

| Field | Value |
|---|---|
| `query_languages` | Backend API |
| `projection_format` | graph nodes/edges in embedded store |
| `rebuild_target` | varies by corpus size; runs before GraphRAG community detection pass |
| `incremental_update` | `false` — full prune-and-reproject (`cognee.prune()` before each run) |

### Repo-specific fields

| Field | Value |
|---|---|
| `script` | `instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh` |
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

## Dual-container ingestion (production stack)

For the running Docker deployment (`dkr-cgnee-api` + `dkr-cgnee-mcp`), use the
adapter-local ingestion script instead of ad-hoc API calls.

Canonical command:

```bash
bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh
```

Recommended low-cost smoke command first:

```bash
bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh --smoke
```

What this does:

1. Builds a corpus snapshot from the Spec Graph source roots (`00-vision`,
   `01-architecture`, `02-roadmap`, `03-research`, `instance/installed`,
   `instance/adrs`) including `*.md` and `*.ttl`.
2. Copies that snapshot into `dkr-cgnee-api`.
3. Runs `cognee.add()` and `cognee.cognify()` inside the backend container.

Important behavior in this mode:

1. The official dual-container backend defaults to embedded storage
   (Kuzu/LanceDB under the container data path).

Options:

```bash
# Keep prior Cognee state (no prune)
bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh --skip-prune

# Smoke mode: small corpus sample, skip prune by default
bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh --smoke

# Smoke mode with explicit sample size
bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh --smoke --max-files 8
```

Execution location:

Run ingestion on the Docker host (`srv-docker-hp`), where `dkr-cgnee-api`
and `dkr-neo4j-01` are running. Use workstation-triggered SSH only as a remote
control path.

Post-run checks:

```bash
curl -fsS https://cognee-mcp.grace.lan/health
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'dkr-cgnee-api|dkr-cgnee-mcp|dkr-neo4j-01'
```

---

## Environment variables

| Variable | Required | Notes |
|---|---|---|
| `LLM_API_KEY` or `ANTHROPIC_API_KEY` | yes (dual-container ingestion) | LLM extraction key for backend add/cognify |
| `OPENAI_API_KEY` | optional (dual-container ingestion) | depends on embedding/provider configuration |

---

## Windows setup note

Windows limits file paths to 260 characters by default. The repo-relative
venv path (`instance/installed/06-spec-graph/cognee/.venv`) may exceed this
limit during `pip install`. Use a short path instead:

```powershell
python -m venv D:\venv\cognee
D:\venv\cognee\Scripts\pip install cognee fastembed neo4j pandas pyarrow
```

Then set `COGNEE_VENV=D:\venv\cognee` when running the rebuild script, or
enable long paths via Group Policy / registry (`LongPathsEnabled = 1`).

---

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| Unpinned `cognee` version | Breaking API changes may silently change graph schema or ontology resolution | Pin version in `requirements.txt` once the adapter is promoted from experimental |
| No audit events | Indexing runs are not logged to the Audit & Observability slot | Wire structured events when a factory Audit Adapter is installed |
| Full prune on every run | `cognee.prune()` clears all Cognee state before each rebuild; no incremental update | Explore Cognee's diff/update APIs once the corpus stabilizes |
