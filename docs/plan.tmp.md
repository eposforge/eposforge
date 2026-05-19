# Plan: Stand up cognee-mcp as the eposforge spec-graph backend

**Status:** working draft, to be picked up from `srv-docker-hp`. Not for commit; replace or delete after the work lands.

## Goal

Run a single cognee process (cognee-mcp in Direct Mode, containerised, with
persistent volumes) that:

1. Uses cognee's internal DB tooling (embedded Kuzu + LanceDB + SQLite).
   No Neo4j.
2. Exposes the full 12-tool MCP surface to agents (`cognify`, `search`,
   `recall`, `remember`, `list_data`, `delete_dataset`, `delete`, `prune`,
   `forget_memory`, `improve`, `cognify_status`, `save_interaction`).
3. Persists the KG across container restarts (mounted volumes).
4. Is the only writer to its embedded DBs (single-writer constraint).

This is the architecture that makes EF-010 (self-consumption + adopter
onboarding runbook) actually work end-to-end.

## Host affinity

| Host | Role |
|---|---|
| `srv-docker-hp` | runs the cognee-mcp container; **all docker/compose work** |
| `ws-dev-w` | MCP client (Claude Code, Cursor, etc.) talking SSE/HTTP to srv-docker-hp |

The current `.mcp.json` runs cognee-mcp as a *host process on ws-dev-w*
via `uv run --with cognee-mcp ...`. That can never be persistent — the
DB lands in the uv cache. The whole point of moving to a container on
srv-docker-hp is to fix this.

## What we learned from troubleshooting (2026-05-18)

- The cognee MCP server is healthy. Direct stdio probe returned 12 tools
  on `tools/list`. The "no tools in this session" symptom was a
  Claude Code session-start race — cosmetic, fixed by restarting the
  client.
- cognee-mcp in the current host-process config is in Direct Mode with
  DB at
   `<abs-path-to-repo-root>/.../.cognee_system/databases`
  — transient and disconnected from `dkr-cgnee-api`'s embedded DBs
  (where cognee-sync writes). MCP queries therefore see an empty KG
  regardless of how much cognee-sync has ingested.
- `instance/installed/05-tool-transport/mcp-stdio-and-http/mcp.servers.toml`
  declares cognee as `transport = "sse"` at
  `https://cognee-mcp.grace.lan/sse`. The generated `.mcp.json` does NOT
  match — it has the old stdio-+-wrapper config. `sync-mcp.py` has no
  `sse` branch; running it today would drop cognee from `.mcp.json`
  entirely. The TOML reflects the *intended* architecture.

## Why dkr-cgnee-api has to go

cognee-mcp Direct Mode and dkr-cgnee-api are two cognee processes. They
cannot share embedded Kuzu/LanceDB safely (single-writer). To get the
full 12-tool MCP surface, cognee-mcp must own the DB. That means
dkr-cgnee-api retires.

cognee-sync currently posts to dkr-cgnee-api's REST endpoints
(`/api/v1/add`, `/api/v1/cognify`, `/api/v1/search`, etc.). cognee-mcp
exposes MCP JSON-RPC, not REST. So when dkr-cgnee-api retires,
cognee-sync must move to MCP-tool ingestion. That's a separate piece of
work — call it EF-012 — and it's why we can't do this in one shot.

Sequencing: stand up cognee-mcp container first, leave dkr-cgnee-api
running (read-only, deprecated) until cognee-sync is reworked, then
retire dkr-cgnee-api and re-ingest into the cognee-mcp container.

## Proposed backlog items

| ID | Title | Effort |
|---|---|---|
| EF-011 (open) | Stand up cognee-mcp container on srv-docker-hp; persistent volumes; SSE/HTTP transport; teach `sync-mcp.py` to emit SSE; regenerate `.mcp.json` | M |
| EF-012 (open, depends on EF-011) | Rewrite cognee-sync to ingest via MCP `cognify`/`remember` tools; retire dkr-cgnee-api; re-ingest corpus | M-L |
| EF-010 (open, blocked by EF-011) | Self-consumption / adopter-onboarding runbook | S |

(IDs are placeholders — confirm next sequential after creating.)

## EF-011 — concrete work plan

Done on srv-docker-hp unless noted.

1. **Pick storage layout.** Decide where the persistent volumes live on
   srv-docker-hp. Suggest something like:
   - `/srv/cognee-mcp/.cognee_system/` (graph + metadata DBs)
   - `/srv/cognee-mcp/.data_storage/` (raw file blobs)
   Confirm path/owner conventions with how dkr-cgnee-api volumes are
   laid out today.

2. **docker-compose service.** Use the upstream image
   `cognee/cognee-mcp:main` (or pin a digest). Environment:
   ```yaml
   environment:
     TRANSPORT_MODE: sse                       # or http
     LLM_PROVIDER: anthropic
     LLM_MODEL: claude-haiku-4-5-20251001       # or whatever's current
     LLM_API_KEY: ${ANTHROPIC_API_KEY}
     EMBEDDING_PROVIDER: openai
     EMBEDDING_MODEL: openai/text-embedding-3-small
     EMBEDDING_DIMENSIONS: 1536
     VECTOR_DB_PROVIDER: lancedb
     # No NEO4J_* — cognee uses its embedded graph DB by default
     ENABLE_BACKEND_ACCESS_CONTROL: "false"     # single-graph mode
     COGNEE_MCP_AGENT_SCOPED: "false"           # all clients see the shared eposforge dataset
     DATA_ROOT_DIRECTORY: /app/.data_storage
     SYSTEM_ROOT_DIRECTORY: /app/.cognee_system
   volumes:
     - /srv/cognee-mcp/.cognee_system:/app/.cognee_system
     - /srv/cognee-mcp/.data_storage:/app/.data_storage
   ports:
     - "8000:8000"
   ```
   Open: secrets injection mechanism on srv-docker-hp. Today the
   wrapper on ws-dev-w uses `epos-secrets`. Decide if the container
   reads from a `.env` file, host env, or a secrets sidecar — pick one
   that matches existing dkr-cgnee-api practice.

3. **Front with TLS reverse proxy.** Caddy or whatever's already in
   place for `cognee-mcp.grace.lan`. SSE works through HTTP reverse
   proxies fine (unlike Bolt).

4. **Verify the container.** From ws-dev-w:
   ```powershell
   claude mcp add cognee-sse -t sse https://cognee-mcp.grace.lan/sse
   claude mcp list                  # expect ✓ Connected
   ```
   Or run the probe script analog directly against the SSE endpoint
   and confirm `tools/list` returns the same 12 tools as the local
   probe did.

5. **Teach `sync-mcp.py` to emit SSE.** Add an `sse` transport branch
   in both `_generate_mcp_json` and `_generate_vscode_mcp_json` that
   emits `{ "type": "sse", "url": ... }`. Mirror the existing `http`
   branch. (`.vscode/mcp.json` may need a slightly different shape —
   check VS Code Copilot's MCP schema for SSE.)

6. **Regenerate config.** Run `sync-mcp.py` on ws-dev-w. `.mcp.json`
   and `.vscode/mcp.json` should now contain the SSE entry matching
   `mcp.servers.toml`. The `--check` mode should be clean after.

7. **Remove the stale stdio path.** Delete or archive
   `instance/installed/05-tool-transport/mcp-stdio-and-http/scripts/cognee-mcp-win-wrapper.py`
   once nothing references it. Drop the NEO4J_* allowlist entries from
   the cognee server config (they'll be gone from the generated JSON
   automatically once TOML is the only source).

8. **Restart Claude Code on ws-dev-w.** Verify the 12 tools surface as
   `mcp__cognee__*` and a sanity `recall` against an empty KG returns
   the empty-result shape rather than an error.

## EF-012 — cognee-sync rewrite (sketch, not the active work)

- Replace `cognee_sync.client.CogneeClient` REST calls with MCP
  JSON-RPC client calls against the same SSE endpoint.
- `add_file` → MCP `cognify` (text content) or `remember` (without
  `session_id`, into the eposforge dataset).
- `delete_document` → MCP `delete`.
- State store schema stays roughly the same; `data_id` may change shape
  depending on the MCP tool response.
- Re-ingest the 82 doc corpus from EF-001 into the new container.

## Open questions to resolve before/during EF-011

1. Is `cognee-mcp.grace.lan` already provisioned (DNS + TLS), or do we
   need to set it up?
2. Does srv-docker-hp already have the cognee/cognee-mcp image pulled?
   If so, which tag — `main`, a pinned digest, or a custom build?
3. How are LLM/embedding API keys delivered to dkr-cgnee-api today?
   Same mechanism for cognee-mcp.
4. Is there value in keeping dkr-cgnee-api around as a REST shim during
   the EF-012 transition (so existing automation isn't disrupted), or
   do we cut over hard?
5. Re-ingest strategy after cutover: full corpus via cognee-sync, or
   manual `cognify_file` calls, or a `cognify --reindex` style helper?

## Pickup checklist when resuming on srv-docker-hp

- [ ] Confirm host: `hostname` returns `srv-docker-hp`.
- [ ] Read this file end-to-end.
- [ ] Decide volume layout (question 2 above).
- [ ] Inspect existing dkr-cgnee-api compose/run config for env/secrets
      pattern to mirror.
- [ ] Stand up cognee-mcp container.
- [ ] Probe `tools/list` from inside srv-docker-hp before exposing
      externally.
- [ ] Confirm TLS / Caddy routing for cognee-mcp.grace.lan.
- [ ] Verify from ws-dev-w with `claude mcp list`.
- [ ] On ws-dev-w: teach sync-mcp.py to emit SSE, regenerate
      `.mcp.json` + `.vscode/mcp.json`, run `sync-mcp.py --check`.
- [ ] File EF-011 and EF-012 with the resolved details before merging
      changes.
