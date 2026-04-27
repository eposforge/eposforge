# SPEC.md — EposForge Documentation Maintenance Tooling

> Living Spec for Component 6 (Spec Graph) as implemented in this repo.
> Per the paired-change rule: any change to the tooling behavior in
> `graphrag/` or `scripts/` must update this file in the same commit.

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

---

## Component slot

This tooling implements **Component 6: Spec Graph** for the EposForge
repo itself. It is a concrete reference implementation of the pattern
documented in
[03-research/06-spec-graph/graphrag-neo4j-integration.md](03-research/06-spec-graph/graphrag-neo4j-integration.md).

---

## Adapter metadata

Per [01-architecture/00-adapter-pattern.md](01-architecture/00-adapter-pattern.md)
and [01-architecture/02-components/06-spec-graph.md](01-architecture/02-components/06-spec-graph.md):

| Field | Value |
|---|---|
| `name` | `graphrag-neo4j` |
| `component` | `06-spec-graph` |
| `version` | `0.1.0` |
| `privacy_posture` | `local` (Neo4j) / `vendor-default` (inference during indexing) |
| `cost_hint` | free (Neo4j CE) + metered (Gemini API for indexing) |
| `capabilities` | graph-query, community-detection, vector-similarity |
| `invocation_surface` | CLI scripts (`scripts/spec-graph-rebuild.sh`) |
| `status` | `experimental` |
| `query_languages` | Cypher (via Neo4j); natural language (via Neo4j MCP) |
| `projection_format` | hybrid (graph nodes/edges + embeddings) |
| `rebuild_target` | 15 minutes |
| `incremental_update` | false — full nuke-and-reproject |

---

## Observable behavior

1. **Trigger:** operator runs `bash scripts/spec-graph-rebuild.sh` (or
   CI job runs it on a schedule / after significant doc batches).

2. **Indexing:** GraphRAG reads all `*.md` files matching
   `^(00-vision|01-architecture|02-roadmap|03-research)/.*\.md$`
   from the repo root. Extracts Entity, Relationship, Community, and
   TextUnit records into Parquet files under `graphrag/output/`.

3. **Import:** The import script reads Parquet files and loads all
   records into the local Neo4j instance at `NEO4J_URI`. Clears
   prior graph data before import (full nuke-and-reproject).
   Creates constraints on `Entity.id` and `Community.id`, and
   indexes on `Entity.name` and `Entity.type`.

4. **Query surface:** After import, the Neo4j MCP extension exposes
   Cypher generation and graph-memory RAG to any connected Dev
   Product. Operators can issue instructions such as:
   - "Find all adapters that fulfill the Spec Graph slot."
   - "List all principles that govern the Router component."
   - "Generate a new ADR for adding a second Dev Product Adapter."

5. **Rebuild flag:** The `scripts/hooks/post-commit` hook writes
   `graphrag/.needs-rebuild` when doc files change. This is a
   non-blocking reminder; it does not trigger the rebuild itself.

---

## Inputs / outputs

### Inputs

| Input | Description | Bounds |
|---|---|---|
| Markdown files | `*.md` in 4 docs directories | Any valid Markdown |
| `GEMINI_API_KEY` | Gemini API key for GraphRAG inference | Must be set in env |
| `NEO4J_URI` | Neo4j bolt URI | Default: `bolt://localhost:7687` |
| `NEO4J_USERNAME` | Neo4j username | Default: `neo4j` |
| `NEO4J_PASSWORD` | Neo4j password | Must be set in env |

### Outputs

| Output | Description |
|---|---|
| `graphrag/output/*.parquet` | Entity, Relationship, Community, TextUnit tables |
| Neo4j graph | Fully imported knowledge graph |
| `graphrag/.needs-rebuild` | Flag file set by post-commit hook |

---

## Dependencies

| Dependency | Version | Role |
|---|---|---|
| Python | 3.10–3.12 | GraphRAG runtime |
| `graphrag` (pip) | 1.x | Indexing pipeline |
| `neo4j` (pip) | 5.x | Neo4j Python driver |
| `pandas`, `pyarrow` (pip) | current | Parquet reading |
| Neo4j Community Edition | 5.x | Graph store |
| APOC plugin | compatible | Neo4j stored procedures |
| Graph Data Science plugin | compatible | Vector indexes |
| Gemini API | current | Entity extraction inference |

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
| Missing API key | `GEMINI_API_KEY` unset | `spec-graph-index.sh` exits 1 with error message |
| Missing Neo4j vars | `NEO4J_PASSWORD` unset | `spec-graph-import.sh` exits 1 with error message |
| No output dir | `graphrag/output/` absent | `spec-graph-import.sh` exits 1 with error message |
| No venv | `graphrag/.venv/` absent | Index/import scripts exit 1 with setup instructions |
| Zero matching files | All docs dirs empty | GraphRAG produces empty Parquet; Neo4j graph has 0 entities |
| Large corpus | > 500 Markdown files | Completes within `rebuild_target` (15 min) |

---

## Paired-change rule

Changes to the following files require updating this `SPEC.md` in the
same commit:

- `graphrag/settings.yaml` (any key that changes observable behavior)
- `scripts/spec-graph-index.sh`
- `scripts/spec-graph-import.sh`
- `scripts/spec-graph-rebuild.sh`
- `scripts/hooks/post-commit`
