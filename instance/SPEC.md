---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# SPEC.md — EposForge Documentation Maintenance Tooling

> Living Spec for Component 6 (Spec Graph) as implemented in this repo.
> Per the paired-change rule: any change to the tooling behavior in
> `instance/installed/06-spec-graph/` or `instance/scripts/` must update this file in the same commit.

---

## Purpose

Maintain the EposForge vision and architecture Markdown corpus as a
queryable knowledge graph. Cognee performs ontology-grounded extraction
from all Markdown files in the docs directories and writes normalized
entities and relationships into Neo4j. GraphRAG remains installed as an
opt-in fallback path for extraction and community detection. Any
MCP-compatible Dev Product
(Gemini CLI, Claude Code, Cursor, Goose, or equivalent) connects to
Neo4j via the Neo4j MCP extension and gains structured, graph-augmented
memory of the full EposForge architecture for natural-language-driven
consistency checks, spec generation, and ADR authoring.

This spec also defines conventions that clarify which docs are
architecture contracts versus repo-instance implementations.

---

## Component slot

This tooling implements **Component 6: Spec Graph** for the EposForge
repo itself. This is one of many possible Spec Graph implementations;
the slot contract is defined in
[../01-architecture/02-components/06-spec-graph.md](../01-architecture/02-components/06-spec-graph.md).
It is a concrete reference implementation of the pattern documented in
[../03-research/06-spec-graph/graphrag-neo4j-integration.md](../03-research/06-spec-graph/graphrag-neo4j-integration.md).

---

## Adapter metadata

Per [../01-architecture/00-adapter-pattern.md](../01-architecture/00-adapter-pattern.md)
and [../01-architecture/02-components/06-spec-graph.md](../01-architecture/02-components/06-spec-graph.md):

| Field | Value |
|---|---|
| `name` | `cognee-neo4j` |
| `component` | `06-spec-graph` |
| `version` | `0.1.1` |
| `privacy_posture` | `local` (Neo4j) / `vendor-default` (inference during indexing) |
| `cost_hint` | free (Neo4j CE) + metered (Anthropic/OpenAI APIs for indexing) |
| `capabilities` | ontology-grounded-extraction, entity-normalization, graph-query |
| `invocation_surface` | CLI scripts (`instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh`) |
| `status` | `experimental` |
| `query_languages` | Cypher (via Neo4j); natural language (via Neo4j MCP) |
| `projection_format` | hybrid (graph nodes/edges + embeddings) |
| `rebuild_target` | 15 minutes |
| `incremental_update` | false — full nuke-and-reproject |

---

## Adapter registry (repo instance)

Single source of truth for Component 6 adapter status in this repository.

| Adapter | FULFILLS_SLOT | Status | Invocation surface | Notes |
|---|---|---|---|---|
| `cognee-ontology-preprocessor` | `SPEC_GRAPH` | implemented, default, experimental | `bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh` | Default ontology-grounded extraction path (dual-container HTTP API) |
| `neo4j-ce` | `SPEC_GRAPH` | implemented, active, experimental | `instance/installed/06-spec-graph/graphrag/scripts/import.sh` + Neo4j MCP | Query store and Cypher/vector surface |
| `microsoft-graphrag` | `SPEC_GRAPH` | implemented, installed-fallback, experimental | `bash instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh` | Opt-in GraphRAG extraction and import path |

Candidate adapters remain cataloged in
`../03-research/06-spec-graph/spec-graph.md` and are non-normative until listed
here as implemented.
These adapters fill Component 6 for THIS repo only. Other instances will pick
differently; see `../03-research/06-spec-graph/spec-graph.md` for the candidate catalog.

---

## Document classification convention

All architecture, implementation, and research documents should declare a
machine-readable classification block near the top.

Required fields:

- `doc_kind`: `architecture-contract` | `reference-implementation` | `candidate-research` | `operator-runbook`
- `scope`: `eposforge-pattern` | `repo-instance`
- `maturity`: `draft` | `experimental` | `approved` | `deprecated`
- `source_of_truth`: `yes` | `no`

Recommended placement:

- YAML frontmatter at file start, or
- a compact metadata table in the first major section.

Example (YAML frontmatter):

```yaml
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
```

---

## Script placement convention

Adapter implementation scripts must be colocated with the adapter they
implement under:

`instance/installed/<component>/<adapter>/scripts/`

`instance/scripts/` is a legacy compatibility area for repo-level orchestration
entrypoints and git hook helpers only. Do not add new adapter-specific
implementation scripts there.

This convention is enforced in CI by
`instance/installed/09-source-control-ci/github-and-actions/scripts/check-doc-classification.py`.

---

## Observable behavior

1. **Trigger:** operator runs `bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh` (or
  `bash instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh` for the GraphRAG fallback) or CI runs it on a
   schedule / after significant doc batches.

2. **Wipe stage:**
   - The rebuild script clears Neo4j graph projection state, prunes Cognee
     state, and removes generated GraphRAG `output/` and `cache/` artifacts.
   - Wipe stage executes before either extraction path.

3. **Indexing / extraction:**
   - Default path: Cognee performs ontology-grounded extraction (seeded by
     `00-vision/01-glossary.ttl`) and writes normalized entities and
     relationships to Neo4j.
   - Opt-in fallback path (`--graphrag`): GraphRAG reads all `*.md` files
     matching
     `^(00-vision|01-architecture|02-roadmap|03-research|instance/installed|instance/adrs)/.*\.md$`
     from the repo root and produces Parquet outputs under
     `instance/installed/06-spec-graph/graphrag/output/`.

4. **Import / projection to query store:**
   - Default path: Cognee writes directly into Neo4j.
   - Opt-in GraphRAG path: the import script reads Parquet files and loads
     all records into the local Neo4j instance at `NEO4J_URI`.
   Both paths follow full nuke-and-reproject semantics.

5. **Query surface:** After import, the Neo4j MCP extension exposes
   Cypher generation and graph-memory RAG to any connected Dev
   Product. Operators can issue instructions such as:
   - "Find all adapters that fulfill the Spec Graph slot."
   - "List all principles that govern the Router component."
   - "Generate a new ADR for adding a second Dev Product Adapter."

6. **Rebuild flag:** The `instance/scripts/hooks/post-commit` hook writes
  `instance/installed/06-spec-graph/.needs-rebuild` when doc files change. This is a
   non-blocking reminder; it does not trigger the rebuild itself.

7. **Layout/policy enforcement in CI:**
   - The doc lint checker validates adapter folder layout under
     `instance/installed/`.
   - The checker enforces script placement so adapter implementation scripts
     live in adapter-local `scripts/` folders.

---

## Inputs / outputs

### Inputs

| Input | Description | Bounds |
|---|---|---|
| Markdown files | `*.md` in 4 docs directories | Any valid Markdown |
| `LLM_API_KEY` | Generic LLM API key used by Cognee MCP/runtime | Required for Cognee MCP retrieval and accepted by local Cognee scripts |
| `ANTHROPIC_API_KEY` | Anthropic API key for extraction | Required for default Cognee path and GraphRAG fallback when `LLM_API_KEY` is not set |
| `OPENAI_API_KEY` | OpenAI API key for embeddings | Required for GraphRAG fallback (`--graphrag`) only |
| `NEO4J_URI` | Neo4j bolt URI | Default: `bolt://localhost:7688` |
| `NEO4J_USERNAME` | Neo4j username | Default: `neo4j` |
| `NEO4J_PASSWORD` | Neo4j password | Must be set in env |
| `--graphrag` | Rebuild flag selecting GraphRAG fallback extraction path | Optional |

### Outputs

| Output | Description |
|---|---|
| `instance/installed/06-spec-graph/graphrag/output/*.parquet` | Entity, Relationship, Community, TextUnit tables |
| Neo4j graph | Fully imported knowledge graph |
| `instance/installed/06-spec-graph/.needs-rebuild` | Flag file set by post-commit hook |

---

## Dependencies

| Dependency | Version | Role |
|---|---|---|
| Python | 3.10–3.12 | GraphRAG runtime |
| `graphrag` (pip) | 3.0.9 | Indexing pipeline |
| `cognee` (pip) | current | Optional ontology-grounded extraction path |
| `neo4j` (pip) | 5.x | Neo4j Python driver |
| `lancedb` (pip) | 0.24.3 | Vector store reader (transitively installed via graphrag) |
| `pandas`, `pyarrow` (pip) | current | Parquet reading |
| Neo4j Community Edition | ≥ 5.11 | Graph store + native vector indexes |
| APOC plugin | compatible | Neo4j stored procedures |
| Anthropic API | current | Text extraction inference |
| OpenAI API | current | Embedding generation |

---

## Non-functional bounds

| Bound | Value |
|---|---|
| Rebuild target | < 15 minutes for the current EposForge corpus |
| Privacy (graph) | `local` — Neo4j data never leaves the operator's machine |
| Privacy (inference) | `vendor-default` for public docs; use Ollama for private |
| Incremental update | Not supported; full rebuild required |
| Concurrent operators | Not designed for concurrent rebuild; serialize manually |

---

## Versioning policy

- `0.x` versions are experimental. Breaking changes (schema changes,
  script renames, settings.yaml key changes) increment the minor
  version and update this spec in the same commit.
- Moving to `1.0` requires successful end-to-end validation on a
  non-trivial corpus and a passing CI job.

---

## Test partitions (black-box)

The following equivalence classes and boundary values can be derived
from this spec without reading implementation code:

| Partition | Input | Expected outcome |
|---|---|---|
| Happy path | All env vars set, Neo4j running, valid Markdown | Graph imported; exit 0 |
| Missing extraction key | `ANTHROPIC_API_KEY` unset | `spec-graph-index.sh` exits 1 with error message |
| Missing embeddings key | `OPENAI_API_KEY` unset | `spec-graph-index.sh` exits 1 with error message |
| Missing Neo4j vars | `NEO4J_PASSWORD` unset | `spec-graph-import.sh` exits 1 with error message |
| No output dir | `instance/installed/06-spec-graph/graphrag/output/` absent | `spec-graph-import.sh` exits 1 with error message |
| No venv | `instance/installed/06-spec-graph/graphrag/.venv/` absent | Index/import scripts exit 1 with setup instructions |
| Zero matching files | All docs dirs empty | GraphRAG produces empty Parquet; Neo4j graph has 0 entities |
| Large corpus | > 500 Markdown files | Completes within `rebuild_target` (15 min) |

---

## Paired-change rule

Changes to the following files require updating this `SPEC.md` in the
same commit:

- `instance/installed/06-spec-graph/graphrag/settings.yaml` (any key that changes observable behavior)
- `instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh`
- `instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh`
- `instance/installed/06-spec-graph/graphrag/scripts/index.sh`
- `instance/installed/06-spec-graph/graphrag/scripts/import.sh`
- `instance/installed/06-spec-graph/cognee/scripts/cognee.py`
- `instance/installed/09-source-control-ci/github-and-actions/scripts/check-doc-classification.py` (regulated directories, exempt patterns, or required fields)
- `instance/installed/09-source-control-ci/github-and-actions/scripts/generate-installed-index.py` (adapter crawl logic or index schema)
- `.github/workflows/doc-lint.yml` (trigger paths or job behaviour)
- `instance/scripts/hooks/post-commit`

