---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# ADR 002 — Spec Graph: Cognee as Default Extraction Engine

| Field | Value |
|---|---|
| Status | Accepted (with implementation drift — see note below) |
| Date | 2026-05 |
| Supersedes | [ADR 001](001-spec-graph-graphrag-neo4j.md) |
| Components affected | spec-graph, tool-transport, dev-product, inference |

---

> **Implementation drift note (2026-05-20).** The *decision* of this
> ADR — cognee as the default Spec Graph extraction engine, GraphRAG
> shelved as fallback — remains valid. Several implementation details
> below have diverged and are kept here only as a historical record of
> the choice at the time it was made; the authoritative current state
> lives in [`.eposforge/SPEC.md`](../SPEC.md),
> [`.eposforge/spec-graph/cognee/cognee.md`](../installed/spec-graph/cognee/cognee.md),
> and [`.eposforge/spec-graph/cognee/sync/README.md`](../installed/spec-graph/cognee/sync/README.md).
> Differences from the description below:
>
> - **Storage backend:** cognee no longer writes to Neo4j. As of cognee
>   1.0.4+, the KG is stored entirely in cognee's embedded Kuzu graph
>   (`cognee_graph_ladybug`) + embedded LanceDB vector store. The
>   `NEO4J_*` env vars and Cypher query surface described here apply
>   only to the shelved GraphRAG fallback path.
> - **Deployment shape:** the active path is now a **two-container**
>   setup — `dkr-cgnee-api` (owns the KG) and `dkr-cgnee-mcp` (stateless
>   proxy via `API_URL=http://dkr-cgnee-api:8000`) — not a `uvx
>   cognee-mcp` single-process invocation.
> - **Embedding provider:** the current API container uses cognee's
>   default embedder (OpenAI `text-embedding-3-small`) configured via
>   `EMBEDDING_API_KEY`. Fastembed was the planned local default at the
>   time of this ADR but is not in use today.
> - **LLM model:** `claude-haiku-4-5-20251001`, not `claude-sonnet-4-5`.
> - **Cognee version pin:** the API container runs `cognee 1.0.7-local`
>   (built from `cognee/cognee:main`), not the `cognee==1.0.3` pin
>   suggested below.
> - **Cognify is no longer implicit on add:** cognee-sync now calls
>   `POST /api/v1/cognify` explicitly after every batch of file
>   operations. See cognee.md Pipeline behavior.
> - **Incremental update is validated and is the default.** The
>   "rebuild model: full nuke-and-reproject" line below has been
>   superseded by per-file incremental sync (cognee-sync Phases 0–5
>   complete).

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
  (`cognee-mcp`) that exposes both graph-query and semantic-search
  tools in one package, reducing operational surface. (Implementation
  note: today this is deployed as the `dkr-cgnee-mcp` container in
  proxy mode against `dkr-cgnee-api`; not a `uvx` invocation. The
  graph-query surface is the cognee HTTP API, not Cypher.)

**Cognee 1.0** (topoteretes/cognee) addresses these concerns:

- **Ontology-grounded extraction:** the `cognify` call accepts a TTL
  ontology file (`00-vision/01-ontology.ttl`). Entities are normalized
  against the EposForge vocabulary before they enter the graph, producing
  consistent relationship labels without prompt engineering.
- **Local embeddings:** Cognee supports a `fastembed` embedding provider
  (`BAAI/bge-small-en-v1.5`, 384 dims) that runs entirely local,
  requiring no external API key for the embedding stage. *(Today's
  deployment is actually configured with cognee's default OpenAI
  embedder via `EMBEDDING_API_KEY`; fastembed is supported but not
  selected. The OpenAI key is still required only when this provider
  is in use; switching back to fastembed remains an option.)*
- **Integrated MCP:** `cognee-mcp` bundles graph-query and semantic-search
  in one MCP server, replacing the Neo4j MCP extension. Tool count and
  configuration complexity are reduced.
- **Anthropic inference:** extraction uses Anthropic Claude via the
  Anthropic API for LLM-backed entity and relationship extraction, which
  is already present for Dev Product use. *(Today's deployment uses
  `claude-haiku-4-5-20251001`; the ADR-era target was
  `claude-sonnet-4-5`. The provider choice is unchanged.)*

---

## Decision: Spec Graph Adapter — Cognee (default) + GraphRAG (fallback)

**Chosen:** Cognee 1.0 as the default Spec Graph extraction engine;
Microsoft GraphRAG retained as an opt-in fallback via
`.eposforge/spec-graph/graphrag/scripts/rebuild.sh`.

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

**Rebuild model (as filed):** full nuke-and-reproject (same as GraphRAG).
Cognee's `prune()` wipes the vector and relational stores; Neo4j is
cleared separately. Incremental update is not yet validated.

> **Update (2026-05-20):** Incremental update is validated and is the
> default. `cognee-sync` Phases 0–5 are complete. The cognee storage
> backend is its own embedded Kuzu/LanceDB (no Neo4j) — `prune()` is
> not invoked on incremental syncs; update = `delete_document` +
> `add_file` + `cognify` per file.

**Sync command (Cognee default — incremental):**
```sh
# From.eposforge/spec-graph/cognee/sync:
epos-secrets uv run cognee-sync --added <new-files>
epos-secrets uv run cognee-sync --modified <changed-files>
epos-secrets uv run cognee-sync --deleted <removed-files>

# Full-corpus seed (all tracked .md files, Linux/macOS):
cd.eposforge/spec-graph/cognee/sync
epos-secrets uv run cognee-sync --added $(git -C ../../../.. ls-files '*.md')
```
See `.eposforge/spec-graph/cognee/sync/README.md` for setup and secrets.

**Rebuild command (GraphRAG fallback — full nuke-and-reproject):**
```sh
bash.eposforge/spec-graph/graphrag/scripts/rebuild.sh
```

**Required environment variables (never committed):**
| Variable | Required for |
|---|---|
| `ANTHROPIC_API_KEY` | Cognee LLM extraction (always; consumed by `dkr-cgnee-api`) |
| `COGNEE_API_URL` | Endpoint of `dkr-cgnee-api`, consumed by `cognee-sync` |
| `EMBEDDING_API_KEY` | Embedding provider key (today: OpenAI for cognee's default embedder; unset only if fastembed is configured) |
| `ENABLE_BACKEND_ACCESS_CONTROL` | Set `false` for single-user local deployment |
| `OPENAI_API_KEY` | GraphRAG fallback (`--graphrag`) only — the embedding provider key above plays the same role on the cognee path |
| `NEO4J_PASSWORD` / `NEO4J_URI` | GraphRAG fallback only; the cognee path uses its own embedded storage and does not connect to Neo4j |

---

## Decision: Tool Transport Adapter — Cognee MCP (`cognee-mcp`)

**Chosen:** `cognee-mcp` as the `graph-query` capability provider,
replacing the Neo4j MCP extension. *(Today this is deployed as the
`dkr-cgnee-mcp` container in proxy mode against `dkr-cgnee-api`. The
ADR-era plan was `uvx cognee-mcp` invocation; the container-based
deployment is the validated production shape.)*

**Rationale:**

- `cognee-mcp` is the first-party MCP server for Cognee, bundling
  graph-query and semantic-search in one package.
- Removing the Neo4j MCP extension reduces the number of MCP server
  processes required per Dev Product session.
- The AGENTS.md `cognee` MCP policy replaces the former `eposforge-graph`
  policy; agents query `cognee` for architecture knowledge.

**Configuration:** the MCP container reads `API_URL` (pointing at
`dkr-cgnee-api`) and forwards all tool calls over HTTP. The API
container itself reads `ANTHROPIC_API_KEY` and `EMBEDDING_API_KEY`.
Secrets are injected at runtime and never committed to the repo.

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
- **Negative:** Cognee 1.0 is experimental; API surface and storage
  schema may change across patch releases. *(Today's deployment runs
  `cognee 1.0.7-local` built from `cognee/cognee:main` rather than the
  ADR-era `cognee==1.0.3` pin. Patches to the upstream image are
  carried in `Dockerfile` / `Dockerfile.mcp` in the compose project.)*
- **Negative:** Windows long-path limit (260 chars) prevents venv
  installation in the repo's deep `.eposforge/spec-graph/cognee/.venv`
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
- **Note:** first successful rebuild must be validated to confirm
  Cognee's entity and relationship schema for this corpus. Subsequent
  AGENTS.md schema documentation updates should follow. *(Today: 83
  TextDocuments / 1186 entities / 226 entity types in the
  `eposforge-sync` dataset after the 2026-05-20 corpus sync.)*

---

## Review

Open a PR to supersede this ADR if:

- Cognee reaches a stable release with a frozen Neo4j schema.
- A new extraction engine better satisfies the ontology-grounding
  and local-embedding requirements.
- The Windows long-path limitation is resolved and the venv path
  workaround can be removed.
- Incremental update becomes validated and the rebuild model changes.
