---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# ADR 002 — Spec Graph: Cognee as Default Extraction Engine

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-05 |
| Supersedes | [ADR 001](001-spec-graph-graphrag-neo4j.md) |
| Components affected | 06-spec-graph, 05-tool-transport, 03-dev-product, 10-inference |

---

## Context

ADR 001 chose Microsoft GraphRAG as the Spec Graph extraction engine.
After operational experience and ecosystem evaluation, several issues
emerged:

- **Vocabulary drift:** GraphRAG extracts entities via LLM prompts that
  require explicit per-corpus vocabulary tuning. The EposForge vocabulary
  (Component, Adapter, Phase, Pillar, FULFILLS_SLOT, etc.) was encoded in
  custom prompts but still produced inconsistent entity normalization across
  corpus versions.
- **OpenAI embedding dependency:** GraphRAG v3.x requires OpenAI
  `text-embedding-3-small` for the embedding pipeline, binding the local
  rebuild to a paid external service even for non-inference work.
- **Monolithic rebuild:** GraphRAG's full nuke-and-reproject model and
  multi-stage pipeline (chunk → embed → graph → community → report) is
  slow and opaque. The 15-minute target was optimistic for medium corpora.
- **MCP transport mismatch:** ADR 001's tool transport was the Neo4j MCP
  extension. As of 2025-2026, Cognee ships its own MCP server
  (`cognee-mcp` via `uvx`) that exposes both graph-query (Cypher) and
  semantic-search tools in one package, reducing operational surface.

**Cognee 1.0** (topoteretes/cognee) addresses these concerns:

- **Ontology-grounded extraction:** the `cognify` call accepts a TTL
  ontology file (`00-vision/01-ontology.ttl`). Entities are normalized
  against the EposForge vocabulary before they enter the graph, producing
  consistent relationship labels without prompt engineering.
- **Local embeddings:** Cognee supports `fastembed` as the embedding
  provider. `BAAI/bge-small-en-v1.5` (384 dims) runs entirely local,
  requiring no external API key for the embedding stage.
- **Integrated MCP:** `cognee-mcp` bundles graph-query and semantic-search
  in one MCP server, replacing the Neo4j MCP extension. Tool count and
  configuration complexity are reduced.
- **Anthropic inference:** extraction uses `claude-sonnet-4-5` via the
  Anthropic API for LLM-backed entity and relationship extraction, which
  is already present for Dev Product use. OpenAI dependency is eliminated.

---

## Decision: Spec Graph Adapter — Cognee (default) + GraphRAG (fallback)

**Chosen:** Cognee 1.0 as the default Spec Graph extraction engine;
Microsoft GraphRAG retained as an opt-in fallback via
`instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh`.

**Rationale:**

- Cognee's ontology-grounded extraction produces entity normalization
  consistent with EposForge's defined vocabulary without custom prompt
  maintenance.
- Local embeddings (fastembed) eliminate the OpenAI API key requirement
  for rebuild operations, lowering the barrier for offline or
  air-gapped contributors.
- The integrated `cognee-mcp` MCP server reduces tool-transport
  configuration to a single `uvx cognee-mcp` entry, with fewer moving
  parts than the GraphRAG + Neo4j MCP extension stack.
- GraphRAG's community detection (Leiden algorithm) remains available
  as a fallback for corpus-level thematic analysis when hierarchical
  community summaries are required.

**Rebuild model:** full nuke-and-reproject (same as GraphRAG). Cognee's
`prune()` wipes the vector and relational stores; Neo4j is cleared
separately. Incremental update is not yet validated.

**Sync command (Cognee default — incremental):**
```sh
# From instance/installed/06-spec-graph/cognee/sync:
epos-secrets uv run cognee-sync --added <new-files>
epos-secrets uv run cognee-sync --modified <changed-files>
epos-secrets uv run cognee-sync --deleted <removed-files>

# Full-corpus seed (all tracked .md files, Linux/macOS):
cd instance/installed/06-spec-graph/cognee/sync
epos-secrets uv run cognee-sync --added $(git -C ../../../.. ls-files '*.md')
```
See `instance/installed/06-spec-graph/cognee/sync/README.md` for setup and secrets.

**Rebuild command (GraphRAG fallback — full nuke-and-reproject):**
```sh
bash instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh
```

**Required environment variables (never committed):**
| Variable | Required for |
|---|---|
| `ANTHROPIC_API_KEY` | Cognee LLM extraction (always) |
| `NEO4J_PASSWORD` | Neo4j connection (always) |
| `NEO4J_URI` | Neo4j connection if non-default |
| `COGNEE_VENV` | Override venv path (Windows long-path workaround) |
| `COGNEE_SKIP_CONNECTION_TEST` | Skip Cognee pre-flight LLM test |
| `ENABLE_BACKEND_ACCESS_CONTROL` | Set `false` for single-user local rebuild |
| `OPENAI_API_KEY` | GraphRAG fallback (`--graphrag`) only |

---

## Decision: Tool Transport Adapter — Cognee MCP (`cognee-mcp`)

**Chosen:** `cognee-mcp` (via `uvx cognee-mcp`) as the `graph-query`
capability provider, replacing the Neo4j MCP extension.

**Rationale:**

- `cognee-mcp` is the first-party MCP server for Cognee, bundling
  graph-query (Cypher against Neo4j) and semantic-search (fastembed
  vectors) in one package.
- Removing the Neo4j MCP extension reduces the number of MCP server
  processes required per Dev Product session.
- The AGENTS.md `cognee` MCP policy replaces the former `eposforge-graph`
  policy; agents query `cognee` for architecture knowledge.

**Configuration:** `ANTHROPIC_API_KEY`, `NEO4J_URI`, `NEO4J_USERNAME`,
`NEO4J_PASSWORD` are read from the MCP config block or environment
variables. They are never committed to the repo.

---

## Alternatives considered

### Retain GraphRAG as default, adopt Cognee as fallback

GraphRAG's operational issues (OpenAI dependency, prompt maintenance,
rebuild time) are ongoing. Cognee's ontology-grounded approach is a
better fit for the EposForge vocabulary-first philosophy. GraphRAG is
retained as a fallback for its community detection capability, not as
the primary engine.

### LlamaIndex property graph

LlamaIndex 0.10+ offers property graph extraction with ontology
grounding. Evaluated but not adopted: fewer production deployments
on Neo4j CE, less mature MCP tooling, and additional Python dependency
surface compared to Cognee.

### Pure vector store (no graph)

Addressed and ruled out in ADR 001. The structural query requirement
(dependency/impact traversal) remains.

---

## Consequences

- **Positive:** ontology-grounded extraction produces consistent entity
  normalization aligned with EposForge vocabulary — without custom
  prompt files.
- **Positive:** no OpenAI API key required for rebuild. Anthropic key
  is already required for Dev Product use.
- **Positive:** single MCP server (`cognee-mcp`) provides both graph
  and semantic search, reducing operational complexity.
- **Negative:** Cognee 1.0 is experimental; API surface and Neo4j
  schema may change across patch releases. Pin `cognee==1.0.3` in the
  venv until a stable release is declared.
- **Negative:** Windows long-path limit (260 chars) prevents venv
  installation in the repo's deep `instance/installed/06-spec-graph/cognee/.venv`
  path. Use `COGNEE_VENV=D:\venv\cognee` as a workaround until the
  repo is relocated to a shorter path or Windows long-path support is
  enabled system-wide.
- **Negative:** `COGNEE_SKIP_CONNECTION_TEST=true` and
  `ENABLE_BACKEND_ACCESS_CONTROL=false` are required for the local
  single-user rebuild profile. These are operational env vars, not
  committed configuration.
- **Trade-off:** GraphRAG community detection (hierarchical thematic
  summaries) is no longer produced by the default rebuild. The
  `--graphrag` flag preserves access for corpus-level analysis.
- **Note:** first successful rebuild must be validated against Neo4j
  to confirm Cognee's entity and relationship schema for this corpus.
  Subsequent AGENTS.md schema documentation updates should follow.

---

## Review

Open a PR to supersede this ADR if:

- Cognee reaches a stable release with a frozen Neo4j schema.
- A new extraction engine better satisfies the ontology-grounding
  and local-embedding requirements.
- The Windows long-path limitation is resolved and the venv path
  workaround can be removed.
- Incremental update becomes validated and the rebuild model changes.
