---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Working Memory — Implementation Catalog

Candidate Adapters for the [Working Memory] slot
([../../../../01-architecture/02-components/working-memory.md](../../../../01-architecture/02-components/working-memory.md)).

This slot is the shared **replacement** for each Dev Product's native
memory system. Candidates must offer a semantic layer and a store that
every CLI can use through [Tool Transport]. A product that also
fulfills [Spec Graph] is a *different* Adapter: same vendor is allowed;
same dataset is not.

This catalog is **not exhaustive** and **not an endorsement**.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — memory platform, MCP server, agent framework module.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Semantic layer** — how writes become structure.
- **CLI reach** — whether one store can be consumed by many Dev
  Products.
- **Notes** — Adapter-author concerns, especially isolation from
  Spec Graph.

A product is a strong Working Memory candidate if it:

- Accepts remember / recall / forget (or equivalent) from multiple
  clients.
- Extracts structure (entities, relations, or a declared schema)
  rather than appending a flat note.
- Can be isolated from any Spec Graph or code-structure store of
  the same product.
- Can be pointed at by MCP or another Tool Transport.

---

## Candidates

### Cognee (distinct-dataset Adapter)

- **Type:** ontology-grounded knowledge graph + MCP (`recall`,
  `remember`, search).
- **Cost tier:** free OSS + inference / embedding keys.
- **Semantic layer:** `ontology-grounded` (TTL) + hybrid vector
  search. Strongest existing semantic write path in the EposForge
  research set.
- **CLI reach:** one MCP server, many MCP-speaking Dev Products
  (Claude Code, Cursor, Codex, Gemini CLI, Goose, and others).
- **Notes:** Cognee already **fulfills** the [Spec Graph] slot in
  instances that adopted it as the default extraction engine. That
  Adapter is **not** this slot. A Working Memory Adapter that
  **implements** Cognee MUST declare `store_isolation` as a
  **separate dataset** (and a distinct Tool Transport route /
  default query scope). Putting operational memories into the
  Living Spec dataset, or answering architecture questions from
  the memory dataset, is a contract violation. Candidate because
  the product already has remember/recall and a semantic layer;
  isolation and native-memory displacement are instance work.

### Mem0

- **Type:** managed / self-hosted memory layer for agents.
- **Cost tier:** free OSS core + hosted tiers.
- **Semantic layer:** extraction into a memory graph; embeddings
  for recall.
- **CLI reach:** API / MCP wrappers; not native to every coding
  CLI. Adapter must sit on Tool Transport.
- **Notes:** Built as agent memory, not as a spec projection.
  Weaker ontology-grounding than Cognee. Evaluate if the instance
  wants a memory-only product with no Spec Graph overlap.

### Zep

- **Type:** temporal knowledge-graph memory for agents.
- **Cost tier:** commercial + OSS components.
- **Semantic layer:** temporal KG (facts with validity windows).
- **CLI reach:** API; Adapter required.
- **Notes:** Strong on "what was true when." Does not replace Spec
  Graph. Good comparison point for retention metadata.

### LangMem

- **Type:** LangChain/LangGraph memory utilities.
- **Cost tier:** free OSS + model keys.
- **Semantic layer:** configurable; often embeddings + collections.
- **CLI reach:** library, not a factory-wide MCP. Would need a
  Tool Transport wrap.
- **Notes:** Fine inside a LangGraph Orchestrator; a weak
  standalone factory memory unless wrapped.

### Letta (formerly MemGPT)

- **Type:** agent runtime with tiered memory (core / recall /
  archival).
- **Cost tier:** free OSS + hosted.
- **Semantic layer:** archival store + optional embeddings; not
  ontology-grounded by default.
- **CLI reach:** its own agent runtime. Using it as Working Memory
  for *other* Dev Products requires extracting the store from the
  runtime.
- **Notes:** Closer to an Orchestrator + Dev Product than to a
  shared memory backend. Evaluate the store, not the full runtime.

---

## Declined as the slot fill

These were already parked against the wrong slots; they stay
declined *here* for the reasons named.

- **Native Dev Product memory** (Claude Code `MEMORY.md` /
  auto-memory, Codex memory, Cursor memories, and equivalents).
  This is the fragmentation the slot exists to replace. An Adapter
  may *ingest* a one-time export as a backfill; it must not remain
  the live store.
- **Spec Graph datasets** (including a Cognee dataset that
  projects Living Specs). Architecture guidance is a different
  authority. Do not remember operator facts into that graph.
- **Tool Transport code-structure** (codebase-memory-mcp,
  Code-Graph-RAG). As-built code, not operational memory.
- **[Interaction Capture] stores.** Immutable transcripts. Working
  Memory may distill from them later; the raw corpus is not the
  memory the CLIs consult.
- **[Audit & Observability] backends.** They record that a write
  happened; they do not answer "what do we remember?"

The Interaction Capture catalog continues to decline Mem0, Zep,
LangMem, and Letta as fills of *that* slot — they belong here.

<!-- component-links (generated by check-component-links.py --write-defs) -->
[Working Memory]: ../../../../01-architecture/02-components/working-memory.md
[Tool Transport]: ../../../../01-architecture/02-components/tool-transport.md
[Spec Graph]: ../../../../01-architecture/02-components/spec-graph.md
[Interaction Capture]: ../../../../01-architecture/02-components/interaction-capture.md
[Audit & Observability]: ../../../../01-architecture/02-components/audit-observability.md
