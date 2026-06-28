---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Tool Transport — Implementation Catalog

> **Snapshot date:** 2026-04. Verify current details before adopting.

Candidate Adapters for the Tool Transport slot
([../../01-architecture/02-components/tool-transport.md](../../01-architecture/02-components/tool-transport.md)).
A Tool Transport Adapter exposes capabilities (git, fs, shell,
graph-query, browser, http) to Dev Products through a defined
protocol. One Transport serves all Dev Products in the factory;
swapping the Transport does not require changing Dev Products.

This catalog is **not exhaustive** and **not an endorsement**.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — protocol standard, hosted service, embedded library.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Transport protocol** — wire-level protocol (MCP, gRPC,
  HTTP+JSON, library call, etc.).
- **Capabilities exposed** — which of the required minimum
  capability categories the Adapter covers.
- **Notes** — anything notable for Adapter authors.

---

## Candidates

### MCP (Model Context Protocol)

- **Type:** open protocol standard (Anthropic, open-source
  community).
- **Cost tier:** free OSS.
- **Transport protocol:** JSON-RPC 2.0 over stdio or SSE.
- **Capabilities exposed:** git, fs, shell, graph-query, browser,
  http — via composable MCP server extensions (one per capability
  category or bundled).
- **Notes:** de-facto standard for agentic tool access as of
  2025-2026. Supported natively by Gemini CLI, Claude Code,
  Cursor, Goose, OpenCode, and most other Dev Product candidates.
  The factory installs one MCP server per capability; Dev Products
  discover the capability set from the server manifest. Strong
  Adapter target: the protocol is stable, the ecosystem is large,
  and swapping an MCP server implementation requires no Dev
  Product changes.

### Neo4j MCP Extension

- **Type:** MCP server extension (community + official support).
- **Cost tier:** free OSS.
- **Transport protocol:** MCP (JSON-RPC 2.0 over stdio).
- **Capabilities exposed:** `graph-query` — Cypher generation,
  graph memory/RAG, schema inspection, visualization.
- **Notes:** installs alongside a Neo4j instance. Provides the
  `graph-query` capability required by the Spec Graph Adapter
  contract. Dev Products issue natural-language requests; the
  extension generates and executes Cypher against the configured
  Neo4j database. Required configuration: `NEO4J_URI`,
  `NEO4J_USERNAME`, `NEO4J_PASSWORD` as environment variables or
  MCP config block. See
  [spec-graph/graphrag-neo4j-integration.md](../spec-graph/graphrag-neo4j-integration.md)
  for the recommended setup. Privacy posture: `local` when the
  Neo4j instance is on the operator's machine.

### OpenAI Swarm / Assistant Tool Calls

- **Type:** vendor API protocol (OpenAI).
- **Cost tier:** consumer-paid / commercial.
- **Transport protocol:** HTTP+JSON (OpenAI function-calling
  schema).
- **Capabilities exposed:** tool calls defined by the operator as
  JSON schema functions; real capability set depends on what
  functions are registered.
- **Notes:** tightly coupled to OpenAI models. Usable as a
  Transport if all Dev Products are OpenAI-backed, but creates
  vendor lock-in at the transport layer. Prefer MCP for
  vendor-agnostic instances.

### Golem Tool Broker (experimental)

- **Type:** open-source tool broker.
- **Cost tier:** free OSS.
- **Transport protocol:** HTTP+JSON (custom).
- **Capabilities exposed:** pluggable via broker registry; can
  front MCP servers.
- **Notes:** experimental as of 2026; worth evaluating for
  instances that need a central policy enforcement layer above
  the transport protocol level. Adapter would front an MCP
  server and add audit / rate-limit middleware.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
that support the full required minimum capability set (git, fs,
shell, graph-query, browser, http) or clearly declare which
categories they cover and which require a complementary Adapter.

