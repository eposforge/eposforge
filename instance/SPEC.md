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
queryable knowledge graph. Microsoft GraphRAG extracts entities,
relationships, and hierarchical community summaries from all Markdown
files in the docs directories. The resulting Parquet tables are
imported into a local Neo4j instance. Any MCP-compatible Dev Product
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
| `name` | `graphrag-neo4j` |
| `component` | `06-spec-graph` |
| `version` | `0.1.0` |
| `privacy_posture` | `local` (Neo4j) / `vendor-default` (inference during indexing) |
| `cost_hint` | free (Neo4j CE) + metered (Anthropic/OpenAI APIs for indexing) |
| `capabilities` | graph-query, community-detection, [vector-similarity](./installed/06-spec-graph/graphrag/README.md#hybrid-graph--vector-queries) |
| `invocation_surface` | CLI scripts (`instance/scripts/spec-graph-rebuild.sh`) |
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
| `microsoft-graphrag` | `SPEC_GRAPH` | implemented, default, experimental | `bash instance/scripts/spec-graph-rebuild.sh` | Default extraction/indexing path |
| `neo4j-ce` | `SPEC_GRAPH` | implemented, active, experimental | `instance/scripts/spec-graph-import.sh` + Neo4j MCP | Query store and Cypher/vector surface |
| `cognee-ontology-preprocessor` | `SPEC_GRAPH` | implemented, optional, experimental | `bash instance/scripts/spec-graph-rebuild.sh --cognee` | Ontology-grounded extraction path |

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

## Observable behavior

1. **Trigger:** operator runs `bash instance/scripts/spec-graph-rebuild.sh` (or
  `bash instance/scripts/spec-graph-rebuild.sh --cognee`) or CI runs it on a
   schedule / after significant doc batches.

2. **Indexing / extraction:**
   - Default path: GraphRAG reads all `*.md` files matching
     `^(00-vision|01-architecture|02-roadmap|03-research|instance/installed|instance/adrs)/.*\.md$`
     from the repo root. It extracts Entity, Relationship, Community,
     and TextUnit records into Parquet files under `instance/installed/06-spec-graph/graphrag/output/`.
   - Optional Cognee path (`--cognee`): Cognee performs ontology-grounded
     extraction (seeded by `00-vision/01-glossary.ttl`) and exports
     GraphRAG-compatible Parquet output.

3. **Import / projection to query store:**
   - Default path: the import script reads Parquet files and loads all
     records into the local Neo4j instance at `NEO4J_URI`.
   - Optional Cognee path: the Cognee script writes to Neo4j directly and
     also exports Parquet artifacts.
   Both paths follow full nuke-and-reproject semantics.

4. **Query surface:** After import, the Neo4j MCP extension exposes
   Cypher generation and graph-memory RAG to any connected Dev
   Product. Operators can issue instructions such as:
   - "Find all adapters that fulfill the Spec Graph slot."
   - "List all principles that govern the Router component."
   - "Generate a new ADR for adding a second Dev Product Adapter."

5. **Rebuild flag:** The `instance/scripts/hooks/post-commit` hook writes
  `instance/installed/06-spec-graph/.needs-rebuild` when doc files change. This is a
   non-blocking reminder; it does not trigger the rebuild itself.

---

## Inputs / outputs

### Inputs

| Input | Description | Bounds |
|---|---|---|
| Markdown files | `*.md` in 4 docs directories | Any valid Markdown |
| `ANTHROPIC_API_KEY` | Anthropic API key for extraction | Required for default GraphRAG path and current Cognee script |
| `OPENAI_API_KEY` | OpenAI API key for embeddings | Required for default GraphRAG path and current Cognee script |
| `NEO4J_URI` | Neo4j bolt URI | Default: `bolt://localhost:7687` |
| `NEO4J_USERNAME` | Neo4j username | Default: `neo4j` |
| `NEO4J_PASSWORD` | Neo4j password | Must be set in env |
| `--cognee` | Rebuild flag selecting Cognee extraction path | Optional |

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
- `instance/scripts/spec-graph-index.sh`
- `instance/scripts/spec-graph-import.sh`
- `instance/scripts/spec-graph-rebuild.sh`
- `instance/scripts/spec-graph-cognee.py`
- `instance/scripts/check-doc-classification.py` (regulated directories, exempt patterns, or required fields)
- `.github/workflows/doc-lint.yml` (trigger paths or job behaviour)
- `instance/scripts/hooks/post-commit`

