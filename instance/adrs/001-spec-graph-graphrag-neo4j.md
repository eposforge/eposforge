---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# ADR 001 — Spec Graph: GraphRAG + Neo4j

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-04 |
| Components affected | 06-spec-graph, 05-tool-transport, 03-dev-product, 10-inference |

---

## Context

documents. Its corpus of vision and architecture Markdown files is the
primary artifact the factory maintains. As the corpus grows, keeping
it consistent — detecting contradictions, tracing dependencies between
align with the established vocabulary — becomes a non-trivial cognitive
task for any maintainer or contributing Dev Product.

Component 6 (Spec Graph) addresses this by projecting all Living Specs
into a queryable knowledge graph that Dev Products can consult during
the EposForge repo's own Spec Graph implementation.
The goal is a local, reproducible, version-controlled setup that:
- Requires no external hosted services beyond the inference API
  used during indexing.
  changes.
  section in `instance/SPEC.md` and choose accordingly.

---

## Decision: Spec Graph Adapter — Microsoft GraphRAG + Neo4j CE

**Chosen:** Microsoft GraphRAG (indexing pipeline) + Neo4j Community
Edition (graph store).

**Rationale:**

- GraphRAG's hierarchical community detection provides multi-scale
  understanding of the EposForge corpus, surfacing both fine-grained
  entity relationships and broad thematic clusters.
- GraphRAG produces standard Parquet output that can be imported into
  any graph store; it does not lock the factory to any particular
  query backend.
- Neo4j CE is free OSS, runs locally, and provides mature Cypher
  pattern matching well-suited to the dependency/impact query shapes
  required by the Spec Graph contract.
- Custom extraction prompts in `instance/graphrag/prompts/` encode the
  EposForge vocabulary (Component, Adapter, Phase, Pillar,
  FULFILLS_SLOT, MATURES_TO, etc.) and travel with the repo,
  so extraction quality is consistent across rebuilds.

**Rebuild model:** full nuke-and-reproject per the Spec Graph component
contract. Incremental update is not supported by GraphRAG v3.x.
Rebuild target: 15 minutes for the current corpus.

**Privacy posture:** Neo4j is local (`local`). Inference during
indexing is `vendor-default` for this public repo. Private instances
should use a `vendor-no-training` Gemini key or substitute Ollama.

---

## Decision: Tool Transport Adapter — MCP + Neo4j MCP Extension

**Chosen:** MCP (Model Context Protocol) as the transport protocol;
Neo4j MCP extension as the `graph-query` capability provider.

**Rationale:**

- MCP is the de-facto standard for agentic tool access as of 2025-2026
  and is supported by all major Dev Product candidates (Gemini CLI,
  Claude Code, Cursor, Goose, OpenCode, OpenClaw).
- The Neo4j MCP extension exposes Cypher generation and graph-memory
  RAG to any connected Dev Product without requiring Dev Product-
  specific integration work. Swapping the Dev Product does not
  require changing the Neo4j MCP configuration.
- The `graph-query` capability exposed via Neo4j MCP satisfies the
  Tool Transport minimum capability set required by the Spec Graph
  Adapter contract.

**Configuration:** `NEO4J_URI`, `NEO4J_USERNAME`, `NEO4J_PASSWORD`
are read from the MCP config block or environment variables. They
are never committed to the repo (Secrets & Key Management contract).

---

## Decision: Dev Product Adapter — Vendor-agnostic; Gemini CLI as reference

**Chosen:** no single vendor locked in; Gemini CLI is the reference
implementation for documentation and examples.

**Rationale:**

- EposForge's core principle is vendor-agnostic. Hard-wiring a single
  Dev Product would contradict the pattern this repo defines.
- Because the Tool Transport layer is MCP and Neo4j MCP works with all
  major MCP-compatible Dev Products, swapping Gemini CLI for Claude
  Code, Cursor, Goose, or any other MCP-compatible agent requires only
  a config change — no code or script changes.
- Gemini CLI is documented as the reference because its large context
  window suits full-corpus ingestion tasks and its free + paid tiers
  lower the barrier to entry for contributors.
- Instances with privacy requirements should substitute a local Dev
  Product (e.g., Goose + Ollama) and update the inference backend in
  `instance/graphrag/settings.yaml` accordingly.

---

## Decision: Automation — Non-blocking post-commit flag + manual rebuild

**Chosen:** post-commit hook writes `instance/graphrag/.needs-rebuild` flag;
operator runs `instance/scripts/spec-graph-rebuild.sh` after significant batches.

**Rationale:**

- GraphRAG indexing takes ~10 minutes. A blocking commit hook would
  make commits unacceptably slow.
- A CI-triggered rebuild (optional extension) adds complexity that is
  not yet warranted for a single-operator repo. It can be added by
  adding a scheduled workflow job that runs
  `instance/scripts/spec-graph-rebuild.sh` on the CI host.
- The non-blocking flag preserves the reminder without blocking
  developer flow. The post-commit hook is installed manually via
  `instance/scripts/hooks/install-hooks.sh` rather than forced on all
  contributors; this respects the DCO-based contribution model.

---

## Alternatives considered

### Pure vector store (e.g., Chroma, pgvector, Qdrant)

Provides similarity search but not graph-structured relationship
traversal. Would satisfy a simplified Spec Graph contract but not
the dependency-mapping and change-impact-analysis requirements.
Ruled out: insufficient structural expressiveness.

### Code-Graph-RAG

Designed for code, not prose Markdown. Graph schema is optimized
for function/class/module relationships, not component/adapter/phase
concepts. Usable but requires heavier Adapter shaping work.
Ruled out: not the right fit for a docs-first corpus.

### Blitzy GraphRAG (commercial)

Provides an integrated GraphRAG-backed memory layer. Higher lock-in
and vendor dependency than the self-hosted stack. Does not fit the
vendor-agnostic principle.
Ruled out: commercial lock-in inconsistent with EposForge principles.

### Neo4j Aura (hosted)

The same Neo4j query layer but hosted by Neo4j Inc. Removes the
local install requirement but introduces vendor dependency and
data-residency considerations for private instances.
Deferred: acceptable for a future scale-out option; see
`graphrag-neo4j-integration.md` maintenance recommendations.

---

## Consequences

- **Positive:** full graph of EposForge architecture available to any
  MCP-compatible Dev Product with a single config line. Consistency
  checks, cross-component reasoning, and new-content generation are
  grounded in the actual documented structure.
- **Positive:** native Neo4j vector indexes (three: `entity_embedding`,
  `text_unit_embedding`, `community_report_embedding`) are created by
  `instance/scripts/spec-graph-import.sh` using embeddings sourced from LanceDB
  (`instance/graphrag/output/lancedb`). Hybrid Cypher queries that combine
  structural traversal with semantic similarity are supported without
  any MCP-layer changes. See `instance/graphrag/README.md` for example queries.
- **Positive:** all configuration, prompts, and scripts are in the
  repo; the graph is fully reproducible from source.
- **Negative:** rebuild requires a Gemini API key and a running Neo4j
  instance. First-time setup is non-trivial (~5 steps).
- **Negative:** nuke-and-reproject means the graph is stale between
  rebuild runs. Large batches of uncommitted doc changes are not
  reflected in the graph until a rebuild.
- **Trade-off:** Gemini free tier is documented but carries a training-
  data risk for private content. Operators must read the privacy posture
  section in `SPEC.md` and choose accordingly.
- **Note:** Incremental update is not supported by GraphRAG v3.x.
  Rebuild target: 15 minutes for the current corpus.

---

## Review

Open a PR to supersede this ADR if:

- The corpus outgrows the 15-minute rebuild target and incremental
  update becomes necessary.
- A new Tool Transport replaces MCP as the factory standard.
- The operator chooses to lock in a specific Dev Product Adapter.

