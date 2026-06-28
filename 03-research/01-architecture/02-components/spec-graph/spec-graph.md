---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Spec Graph — Implementation Catalog

> **Snapshot date:** 2026-04. Verify current details before adopting.

Candidate Adapters for the Spec Graph slot
([../../01-architecture/02-components/spec-graph.md](../../01-architecture/02-components/spec-graph.md)).
A Spec Graph Adapter projects every Living Spec across the factory
into a queryable form, supporting reuse detection, dependency
mapping, and change-impact analysis.

This catalog is **not exhaustive** and **not an endorsement**.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — graph DB, vector store, code-graph product, hybrid.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Query languages** — Cypher, GraphQL, SQL, vector similarity, etc.
- **Capabilities** — what query shapes the Adapter handles well.
- **Notes** — anything notable for Adapter authors.

---

## Candidates

### Neo4j

- **Type:** native graph database.
- **Cost tier:** free OSS (Community Edition); commercial Enterprise
  / Aura tiers available.
- **Query languages:** Cypher; GraphQL via plugins.
- **Capabilities:** mature graph storage, rich Cypher pattern
  matching, well-suited to dependency / impact queries; vector
  index support for hybrid graph + similarity retrieval.
- **Notes:** common starting choice for instances that already use a
  graph DB elsewhere. Adapter projects each Living Spec into nodes
  (`:Deliverable`, `:Spec`, `:Capability`, `:Contract`,
  `:DevProduct`) with `DEPENDS_ON`, `IMPLEMENTS`, `PRODUCED_BY`,
  `SUPERSEDES`, `CONTRACT_WITH` edges; nuke-and-reproject is the
  rebuild contract.

### Code-Graph-RAG

- **Type:** open-source code-graph indexer with retrieval API.
- **Cost tier:** free OSS.
- **Query languages:** retrieval API + graph traversal.
- **Capabilities:** indexes a codebase into a graph projection
  optimized for RAG over code.
- **Notes:** primarily designed for code, not specs. Usable for the
  Spec Graph slot if the Adapter projects Living Specs into the
  index as additional node kinds. Worth evaluating in instances
  that already use Code-Graph-RAG for code retrieval.

### Blitzy GraphRAG

- **Type:** proprietary GraphRAG-backed memory layer (part of the
  Blitzy platform).
- **Cost tier:** commercial.
- **Query languages:** vendor-specific.
- **Capabilities:** integrated graph + RAG over specs and code in a
  hosted environment.
- **Notes:** higher lock-in than self-hosted alternatives; useful
  data point for instances evaluating a buy-vs-build trade-off on
  the Spec Graph slot.

### Microsoft GraphRAG

- **Type:** open-source graph extraction pipeline (Microsoft
  Research).
- **Cost tier:** free OSS; inference costs depend on the model
  backend (Gemini, OpenAI, or local via Ollama).
- **Query languages:** none natively — outputs Parquet files.
  Pair with the Neo4j import step to unlock Cypher queries and
  vector similarity search against the extracted graph.
- **Capabilities:** full-document entity and relationship
  extraction, hierarchical community detection at multiple
  resolution levels, embedding generation, community summary
  reports. Produces Entity, Relationship, Community, and
  TextUnit records.
- **Notes:** designed for unstructured text corpora; well-suited
  to Markdown architecture docs. Custom prompts in the
  `prompts/` directory let Adapter authors tune extraction to
  domain-specific vocabulary (e.g., Component, Adapter, Phase,
  Pillar). Rebuild is a full nuke-and-reproject; incremental
  update is not supported out of the box. See
  [graphrag-neo4j-integration.md](./graphrag-neo4j-integration.md)
  for the recommended pipeline that feeds GraphRAG output into
  Neo4j as the query layer.

### Hybrid vector + graph store

- **Type:** stack pattern (e.g., Neo4j + pgvector, Weaviate,
  Qdrant + a graph projection).
- **Cost tier:** free OSS to commercial depending on components.
- **Query languages:** mixed — vector similarity for retrieval,
  graph traversal for structure.
- **Capabilities:** combines structural reuse / dependency queries
  with similarity retrieval for spec text.
- **Notes:** valid choice when Living Specs benefit from semantic
  search alongside graph queries. Adapter must declare
  `projection_format` as hybrid.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
with declared rebuild target durations and explicit support for
incremental re-projection on a single spec change.

