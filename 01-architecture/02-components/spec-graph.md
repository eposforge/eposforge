---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 6: Spec Graph

## Purpose

A queryable projection of every Living Spec across the factory. The
Spec Graph enables factory-scale reasoning: reuse detection, dependency
mapping, change-impact analysis, and retrieval-augmented generation
over all specs.

The Spec Graph is a **projection**. The Living Specs are the source of
truth; the graph is rebuilt from them. If the graph and the specs ever
disagree, the specs win and the graph is re-projected.

## Contract

Any Adapter for this slot must:

- Index every Living Spec in the factory. Indexing is post-merge,
  triggered by Source Control + CI.
- Provide a query surface that supports at minimum: reuse detection
  ("does anything already do X?"), dependency mapping ("what depends on
  Y?"), change-impact analysis ("if Z changes, what is affected?").
- Be **rebuildable** from the Living Specs in bounded time. The Adapter
  must publish a target rebuild duration; instances may set their own
  ceiling. If the graph is wrong, nuke and re-project.
- Support tier-gated writes: read access is broad; write access (e.g.,
  enriching the graph with derived facts) is restricted by Agent Policy.
- Emit audit events for every write.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `query_languages` — what query interfaces the Adapter exposes (e.g.,
  Cypher, GraphQL, SQL).
- `projection_format` — what shape Living Specs project into (graph
  nodes / edges, embeddings + metadata, hybrid).
- `rebuild_target` — declared target rebuild time for the full factory.
- `incremental_update` — whether the Adapter supports incremental
  re-projection on a single spec change.

## Boundaries

- **Is:** a projection of Living Specs, queryable by the Router and by
  operators.
- **Is not:** a source of truth. Never edit the graph directly to
  change behavior; edit the Living Spec.
- **Is not:** required to be a graph database specifically. Vector
  stores, relational projections, or hybrid stores are acceptable as
  long as the contract is met.

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog (Neo4j,
Code-Graph-RAG, Blitzy GraphRAG, hybrid vector + graph stores, etc.).

