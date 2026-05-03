# cognee-mcp storage alignment — list_data empty / recall broken

## Problem statement

The Cognee MCP server (`list_data`, `recall`) returns empty results even though
the spec graph was successfully rebuilt into Neo4j. Two independent
misconfigurations cause this:

### Mismatch 1 — `SYSTEM_ROOT_DIRECTORY`

Cognee maintains a local state root (dataset registry, LanceDB vectors, SQLite
metadata). The rebuild script and the MCP server currently point at different
directories:

| Context | `SYSTEM_ROOT_DIRECTORY` |
|---|---|
| `spec-graph-rebuild.sh` / `spec-graph-cognee.py` | `<repo>/instance/installed/06-spec-graph/cognee/.cognee` |
| MCP server (`.mcp.json`, no override set) | `D:\venv\cognee\Lib\site-packages\cognee\.cognee_system` |

`list_data` reads Cognee's dataset registry from `SYSTEM_ROOT_DIRECTORY`.
Because the MCP server uses a different root, it sees no datasets.

### Mismatch 2 — embedding provider / dimensions

The rebuild script was previously configured with `fastembed` /
`BAAI/bge-small-en-v1.5` (384 dims). The MCP server is configured with
`openai` / `text-embedding-3-small` (1536 dims).

`fastembed` was abandoned for the MCP server context due to a known deadlock
between ONNX Runtime's thread pool and Python's `asyncio.ProactorEventLoop` on
Windows (partially mitigated by `cognee-mcp-win-wrapper.py`, but not fully
resolved for the embedding path). LanceDB stores vectors at a fixed dimension
per table; mixed-dimension reads silently fail or return garbage results.

**Result:** `recall` / semantic search fails even when the directories are
aligned, because the stored vectors were generated with a different model than
the query encoder.

---

## Fix plan

### Step 1 — Align rebuild script to OpenAI embeddings

Update `instance/scripts/spec-graph-cognee.py` and its installed mirror at
`instance/installed/06-spec-graph/cognee/scripts/cognee.py`:

Replace:
```python
cognee.config.set_embedding_provider("fastembed")
cognee.config.set_embedding_model("BAAI/bge-small-en-v1.5")
cognee.config.set_embedding_dimensions(384)
```

With:
```python
cognee.config.set_embedding_provider("openai")
cognee.config.set_embedding_model("text-embedding-3-small")
cognee.config.set_embedding_dimensions(1536)
cognee.config.set_embedding_api_key(os.environ.get("OPENAI_API_KEY"))
```

Requires `OPENAI_API_KEY` in the rebuild environment (same key already in
`.mcp.json`).

### Step 2 — Add `SYSTEM_ROOT_DIRECTORY` to `.mcp.json`

Add to the `cognee` server's `env` block:

```json
"SYSTEM_ROOT_DIRECTORY": "D:\\src\\git\\gh\\eposforge\\eposforge\\instance\\installed\\06-spec-graph\\cognee\\.cognee"
```

Remove the now-redundant OpenAI embedding vars that duplicate what's already
implied by `EMBEDDING_PROVIDER`/`EMBEDDING_MODEL` (they are already correct in
`.mcp.json` and need no change after Step 1 aligns the rebuild).

### Step 3 — Rebuild the spec graph

Run a full nuke-and-reproject so LanceDB vectors are regenerated with the
OpenAI embedding model:

```powershell
$env:NEO4J_URI = "bolt://<neo4j-host-or-ip>:7688"
$env:COGNEE_VENV = "D:\venv\cognee"
$env:COGNEE_SKIP_CONNECTION_TEST = "true"
$env:ENABLE_BACKEND_ACCESS_CONTROL = "false"
$env:OPENAI_API_KEY = "<your-key>"
& "C:\Program Files\Git\bin\bash.exe" instance/scripts/spec-graph-rebuild.sh
```

### Step 4 — Restart MCP server and verify

Restart the VS Code MCP server, then call `list_data` — it should now return
the 46 ingested spec files. Call `recall` with a query such as
`"Which adapters fulfill the Spec Graph slot?"` to confirm semantic search
works.

---

## Affected files

| File | Change required |
|---|---|
| `instance/scripts/spec-graph-cognee.py` | Switch to OpenAI embeddings (Step 1) |
| `instance/installed/06-spec-graph/cognee/scripts/cognee.py` | Same (Step 1) |
| `.mcp.json` | Add `SYSTEM_ROOT_DIRECTORY` (Step 2) — **not committed; contains secrets** |

---

## Notes

- `.mcp.json` is gitignored and contains live API keys. Keep it that way.
- The `D:\venv\cognee` venv patches (kwargs filter, `max_tokens` inject,
  `http2=False`) apply only to the rebuild context. The MCP server runs via
  `uv run` in a separate venv and has its own copy of `adapter.py`.
- The fastembed deadlock on Windows is documented in
  `docs/runbooks/cognee-mcp-troubleshooting.md`.
