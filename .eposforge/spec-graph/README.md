---
component: spec-graph
status: filled
---

# Component 06 — Spec Graph (this instance)

This directory is the EposForge repo's concrete implementation of
Component 6 (Spec Graph). Two adapters are installed here; one is on the
active path, the other is a shelved opt-in fallback.

| Adapter | Status | Where | Backend | Notes |
|---|---|---|---|---|
| `cognee-ontology-preprocessor` | **active (default)** | [`./cognee/`](./cognee/) | Cognee's embedded Kuzu graph + LanceDB vector store inside `dkr-cgnee-api` | Ontology-grounded extraction; per-file incremental sync via `cognee-sync` |
| `graphrag` | shelved fallback | [`./graphrag/`](./graphrag/) | Microsoft GraphRAG → separate Neo4j Community Edition | Full nuke-and-reproject only; not on the active path |

Component slot contract: [`../../../01-architecture/02-components/spec-graph.md`](../../../01-architecture/02-components/spec-graph.md).
Repo-instance Living Spec: [`../../SPEC.md`](../../SPEC.md).

---

## Default path (cognee)

Active ingestion runs through `cognee-sync` against the
`dkr-cgnee-api` container. The MCP surface (`dkr-cgnee-mcp`) runs in
proxy mode so Claude Code / Gemini CLI / any MCP-compatible Dev
Product reads and writes the same KG.

- Living Spec: [`./cognee/cognee.md`](./cognee/cognee.md)
- CLI: [`./cognee/sync/`](./cognee/sync/) — `cognee-sync --added / --modified / --deleted <files>`
- Quickstart and invocation: [`./cognee/sync/README.md`](./cognee/sync/README.md)
- Deployment topology (two containers, proxy mode): see the
  "Deployment topology" section in `cognee.md`.

Typical workflow: edit Markdown, commit; the
`scripts/hooks/post-commit` fragment flags
`./.needs-rebuild`; operator runs `cognee-sync` with the git diff;
cognee-sync uploads changed files and triggers cognify; the KG is
queryable immediately via the MCP `recall` tool.

---

## Shelved fallback (graphrag)

Full-rebuild path retained for one-off bulk re-extractions or for
cross-checking the cognee output against a different extractor.
Requires its own Neo4j instance and OpenAI embeddings.

- Living Spec: [`./graphrag/graphrag.md`](./graphrag/graphrag.md)
- Setup & Cypher query patterns: [`./graphrag/README.md`](./graphrag/README.md)
- Invocation: `bash ./graphrag/scripts/rebuild.sh`

The fallback writes into a **separate** Neo4j store. It does not touch
the cognee KG.

---

## Shared bits

- `./scripts/hooks/post-commit` — non-blocking flag-setter; touches
  `./.needs-rebuild` when tracked `*.md` files change. Composed into
  `.git/hooks/post-commit` by `.eposforge/source-control-ci/github-and-actions/scripts/install-hooks.sh`.
- `./.needs-rebuild` — the flag file. Cleared the next time the
  operator (or CI) successfully runs cognee-sync against the diff.
