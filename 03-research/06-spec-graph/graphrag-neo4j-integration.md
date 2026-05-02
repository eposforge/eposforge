---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# GraphRAG + Neo4j Integration Pattern

> **Snapshot date:** 2026-04. Verify current tool versions before
> adopting.

A pipeline that projects every Living Spec (and vision/architecture
doc) into a queryable Neo4j knowledge graph by running Microsoft
GraphRAG over all Markdown files and importing the output Parquet
tables into Neo4j. Any MCP-compatible Dev Product can then query the
graph via the Neo4j MCP Tool Transport extension.

---

## When to use this pattern

This pattern suits the Spec Graph slot when:

- The factory's spec corpus is primarily Markdown.
- The operator wants hierarchical community detection (multi-scale
  summaries) in addition to reuse/dependency queries.
- A local Neo4j instance is already available or is acceptable.
- The operator wants natural-language-driven graph queries from
  a Dev Product rather than writing raw Cypher.

---

## Architecture overview

```text
Markdown corpus (00-vision/, 01-architecture/, 02-roadmap/,
               03-research/, Living Specs in deliverable repos)
        │
        ▼
  Microsoft GraphRAG (Python pipeline)
  ├── Custom prompts (entity_types, relationship_types)
  └── Indexing output (Parquet files in output/)
        │
        ▼
  Neo4j import (spec-graph-import.sh)
  └── Nodes: Entity, Relationship, Community, TextUnit
  └── Vector indexes on entity + community embeddings
        │
        ▼
  Neo4j (local)
  └── Query surface: Cypher + vector similarity
        │
        ▼
  Tool Transport: Neo4j MCP extension
  └── graph-query capability for Dev Products
        │
        ▼
  Dev Product (Gemini CLI, Claude Code, Cursor, Goose, …)
  └── Natural-language queries, consistency checks,
      new ADR generation, spec authoring with full graph context
```

---

## Component roles

| Component (slot) | Filled by |
|---|---|
| Spec Graph (06) | Microsoft GraphRAG + Neo4j CE |
| Tool Transport (05) | MCP; Neo4j MCP extension |
| Inference (10) | Gemini API (indexing); any MCP-compatible model |
| Dev Product (03) | Vendor-agnostic; Gemini CLI as reference |
| Secrets & Key Mgmt (12) | Env vars or Vault; never committed |
| Audit & Observability (11) | Neo4j query logs + script exit codes |

---

## Extraction vocabulary

GraphRAG extracts entities and relationships from text using
configurable prompts. This pattern tunes those prompts to the
EposForge vocabulary.

**Entity types:**

| Type | Examples |
|---|---|
| `component` | Spec Input, Router, Spec Graph, Inference Layer |
| `adapter` | Claude Code, Neo4j CE, Gemini API |
| `phase` | Phase 0 Foundation, Phase A Adapter Foundation |
| `pillar` | Substrate-Agnostic Platform, AI Factory |
| `principle` | Everything-as-Code, AI-First Operations |
| `factory` | Platform Factory, Product Factory, Dark Factory |
| `deliverable` | OutreachApi, eposforge docs |
| `constraint` | privacy: local, rebuild_target: 15 min |

**Relationship types:**

| Relationship | Meaning |
|---|---|
| `FULFILLS_SLOT` | Adapter fills a component slot |
| `DEPENDS_ON` | Component or deliverable depends on another |
| `MATURES_TO` | One phase advances to the next |
| `GOVERNED_BY` | Component or action is constrained by a principle |
| `IMPLEMENTS` | Adapter implements a capability |
| `SUPERSEDES` | A newer spec or adapter replaces an older one |

These are declared in `instance/graphrag/prompts/entity_extraction.txt` and
can be extended by the operator.

---

## Setup

### Prerequisites

- Neo4j Community Edition with APOC and Graph Data Science plugins
  running on localhost (default: `bolt://localhost:7687`).
- A `GEMINI_API_KEY` environment variable set to a paid Gemini API
  key (free tier may train on data).
- Python 3.10–3.12.
- The eposforge repo cloned locally.

### One-time initialization

```bash
cd eposforge/instance/graphrag
python -m venv .venv
source .venv/bin/activate
pip install graphrag neo4j pandas pyarrow
graphrag init --root .   # generates default prompts; custom prompts
                         # in prompts/ override them afterward
```

### Indexing

```bash
bash instance/scripts/spec-graph-index.sh
```

This runs GraphRAG over all Markdown files in `00-vision/`,
`01-architecture/`, `02-roadmap/`, `03-research/`, and any Living
Spec files included via the `file_pattern` in `instance/graphrag/settings.yaml`.
Output Parquet files land in `instance/graphrag/output/`.

### Import into Neo4j

```bash
bash instance/scripts/spec-graph-import.sh
```

Reads the Parquet output and batch-imports all Entity, Relationship,
Community, and TextUnit records into Neo4j. Creates vector indexes
for hybrid graph + semantic search.

### Full rebuild (index + import)

```bash
bash instance/scripts/spec-graph-rebuild.sh
```

### Git post-commit hook (optional)

```bash
bash instance/scripts/hooks/install-hooks.sh
```

Sets a non-blocking `.needs-rebuild` flag when `*.md` files in the
vision/architecture directories change. Run
`instance/scripts/spec-graph-rebuild.sh` after significant doc batches.

---

## Querying the graph

Once imported, any Cypher-capable tool can query the graph directly.
Via the Neo4j MCP extension, any MCP-compatible Dev Product can issue
natural-language instructions that translate to Cypher automatically.

**Example queries:**

```cypher
-- All adapters and the components they fulfill
MATCH (a:Entity {type: 'adapter'})-[:RELATED {rel_type: 'FULFILLS_SLOT'}]->(c:Entity {type: 'component'})
RETURN a.name, c.name ORDER BY c.name;

-- Community summaries at level 1 (broad themes)
MATCH (c:Community {level: 1}) RETURN c.title, c.summary LIMIT 10;

-- Dependencies of the Spec Graph component
MATCH (sg:Entity {name: 'Spec Graph'})-[:RELATED {rel_type: 'DEPENDS_ON'}]->(dep)
RETURN dep.name, dep.type;
```

---

## Maintenance recommendations

- Re-run `spec-graph-rebuild.sh` whenever more than a handful of docs
  change. GraphRAG does not support incremental update; nuke-and-
  reproject is the rebuild contract per the Spec Graph component
  contract.
- Keep custom prompt files under `instance/graphrag/prompts/` in version
  control. They encode the extraction vocabulary for the factory.
- Keep Neo4j local. Scale to Neo4j Aura only if graph sharing
  across multiple operators is required; Aura introduces vendor
  dependency and data-residency considerations.
- Monitor `instance/graphrag/output/reports/` after each index run. GraphRAG
  emits per-document processing reports that surface extraction
  quality issues.

---

## Privacy posture

GraphRAG sends text chunks to the inference model for extraction.

| Scenario | Privacy posture |
|---|---|
| Indexing public docs (e.g., this repo) | `vendor-default` acceptable |
| Indexing private Living Specs | Require `vendor-no-training` key or local model |
| Neo4j graph itself | `local` — stays on the operator's machine |

For private instances, substitute the Gemini API key with an Ollama
local model endpoint in `instance/graphrag/settings.yaml` (set `api_base` to
the Ollama OpenAI-compatible endpoint and `api_key` to any string).

---

## Reference files

| File | Purpose |
|---|---|
| [`instance/graphrag/settings.yaml`](../../instance/graphrag/settings.yaml) | GraphRAG project config |
| [`instance/graphrag/prompts/`](../../instance/graphrag/prompts/) | Custom entity/relationship extraction prompts |
| [`instance/scripts/spec-graph-rebuild.sh`](../../instance/scripts/spec-graph-rebuild.sh) | Index + import in one command |
| [`instance/SPEC.md`](../../instance/SPEC.md) | Living Spec for this tooling (Component 2 contract) |
| [`instance/adrs/001-spec-graph-graphrag-neo4j.md`](../../instance/adrs/001-spec-graph-graphrag-neo4j.md) | ADR recording adapter decisions |

