---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 6: Spec Graph

## Purpose

A queryable projection of Living Specs so the factory can reason at
scale: reuse detection, dependency mapping, change-impact analysis, and
retrieval-augmented generation over intent docs.

Every Spec Graph is a **projection**. Living Specs on disk are the
source of truth; graphs are rebuilt from them. If a graph and the specs
ever disagree, the specs win and the graph is re-projected.

### Scope Spec Graph vs Factory Spec Graph

"Spec Graph" is overloaded unless these two levels are named:

| Term | Meaning |
| --- | --- |
| **Scope Spec Graph** | Projection of the Living Specs (or declared Living Spec corpus) **in one scope** — e.g. the EposForge pattern repo, an Adopter Platform Spec, IAC/substrate docs, or a single product repo. One ownership boundary, one rebuildable store (dataset, instance, or equivalent). |
| **Factory Spec Graph** | The **collective** factory-wide Spec Graph: the set of Scope Spec Graphs for that factory instance, plus the shared ontology, explicit cross-scope mappings, and agent/tool orchestration that answers questions over **every** Living Spec in the factory. It is a **logical** system, not a requirement for one physical graph containing every scope's corpus. |

Component 6's factory-scale obligations apply to the **Factory Spec
Graph**. Multi-graph deployment
([`ef:MultiGraphArchitecture`](../../00-vision/01-ontology.ttl)) is the
usual way to implement that collective: one Scope Spec Graph per scope,
connected by ontology and deliberate synthesis — not automatic merge of
all markdown into one bag.

Examples:

- The Cognee graph built from the EposForge framework repo is a **Scope
  Spec Graph** (pattern + references scope). It is **not** the Factory
  Spec Graph by itself.
- A product repo (e.g. OutreachAssistant) may run its own **Scope Spec
  Graph** over its Living Specs. That does not put product intent into
  the pattern scope graph.
- "Does anything in the factory already do X?" is a **Factory Spec
  Graph** question: query the relevant Scope Spec Graph(s) and
  synthesize using shared ontology relations.

When prose says "the Spec Graph" without qualifier, prefer the more
specific term. Prefer **pattern-scope Spec Graph** (or the scope name)
over "main Spec Graph" for the EposForge framework projection.

## Contract

Any Adapter for this slot must:

- Project Living Specs for the **scope(s)** it serves into a queryable
  form. A factory instance's adapters, taken together, must cover
  **every** Living Spec in that factory (the Factory Spec Graph
  obligation). A single adapter may implement one Scope Spec Graph or
  host multiple scopes (e.g. multiple datasets in one process).
- Index post-merge, triggered by Source Control + CI for the corpus it
  owns.
- Provide a query surface that supports at minimum: reuse detection
  ("does anything already do X?"), dependency mapping ("what depends on
  Y?"), change-impact analysis ("if Z changes, what is affected?").
  Factory-wide answers may require multi-scope query + synthesis when
  scopes are separate stores.
- Be **rebuildable** from the Living Specs in bounded time. The Adapter
  must publish a target rebuild duration per scope it serves; instances
  may set their own ceiling. If a graph is wrong, nuke and re-project
  that scope.
- Support tier-gated writes: read access is broad; write access (e.g.,
  enriching the graph with derived facts) is restricted by Agent Policy.
- Emit audit events for every write.
- When participating in multi-graph: declare **scope identity** (what
  corpus it projects) and how clients select that scope (dataset name,
  MCP endpoint, etc.). Cross-scope links use the shared ontology and
  explicit mappings; federation is deliberate, not implicit.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `query_languages` — what query interfaces the Adapter exposes (e.g.,
  Cypher, GraphQL, SQL).
- `projection_format` — what shape Living Specs project into (graph
  nodes / edges, embeddings + metadata, hybrid).
- `rebuild_target` — declared target rebuild time for the corpus (per
  scope when multi-scope).
- `incremental_update` — whether the Adapter supports incremental
  re-projection on a single spec change.
- `scope_id` (multi-graph) — stable identifier for the scope this
  projection serves (e.g. `eposforge-pattern`, product repo name).
- `factory_participation` (multi-graph) — how this Scope Spec Graph is
  discovered and composed into the Factory Spec Graph (datasets, MCP
  routes, recall wrappers).

## Boundaries

- **Is:** a projection of Living Specs (per scope and, collectively,
  factory-wide), queryable by the Orchestrator and by operators.
- **Is not:** a source of truth. Never edit the graph directly to
  change behavior; edit the Living Spec.
- **Is not:** required to be a single physical store for the whole
  factory. Scope Spec Graphs may be separate; the Factory Spec Graph is
  the composed capability.
- **Is not:** required to be a graph database specifically. Vector
  stores, relational projections, or hybrid stores are acceptable as
  long as the contract is met.
- **Is not:** a code graph (AST/call-graph of implementation). Code
  intelligence is a different shape; see landscape research. Spec Graph
  projects **intent docs** (Living Specs), not source structure.
- **Is not:** the independent backlog-items graph. Backlog *mechanics*
  may project into a Scope Spec Graph; raw work items live in the
  file-based backlog graph (`ef:IndependentBacklogGraph`).

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog (Neo4j,
Code-Graph-RAG, Blitzy GraphRAG, hybrid vector + graph stores, etc.).
Multi-graph deployment notes:
[../../docs/adopter-architecture-discussion-capture.md](../../docs/adopter-architecture-discussion-capture.md).
