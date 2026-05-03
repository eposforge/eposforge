# cognee-mcp troubleshooting — permanent-memory hang

## Problem statement

The `remember(permanent)` and `recall(bridge)` MCP tool calls always time out
(75–120 s) when invoked through the MCP stdio JSON-RPC protocol test, even
though:

- The correct LLM config is confirmed in server startup output:
  `provider='anthropic'  model='claude-haiku-4-5-20251001'  api_key=<set>`
- LanceDB storage is now isolated per test run — no lock contention with the
  VS Code task server.
- The **standalone Python API test** runs the identical permanent-remember flow
  in ~14 s and passes all three tests.

### Key evidence

Server log shows `extract_graph_and_summarize` started at `04:16:19`; the next
log entry is at `04:18:18` — a **2-minute silence** inside that pipeline step.
Session-path operations (`remember(session)`, `improve`) complete in < 0.1 s,
so the hang is specific to the permanent graph-extraction path when the server
is run as a subprocess of the protocol test.

### Current hypothesis

The protocol test spawns the server using `sys.executable` (the same Python
already running the `uv run` outer process). Cognee's `@lru_cache` singletons
(`LLMConfig`, `create_embedding_engine`, database adapters) may be inherited in
a partially-initialised state, causing a deadlock or infinite retry inside the
graph-extraction step that does not surface in an isolated fresh process.

### What has already been ruled out

| Candidate cause | Ruled out because |
|---|---|
| Windows ProactorEventLoop deadlock | Fixed via `cognee-mcp-win-wrapper.py`; wrapper confirmed in logs |
| Wrong LLM / embedding keys | Confirmed correct by wrapper diagnostic print |
| Shared LanceDB storage contention | Fixed by `SYSTEM_ROOT_DIRECTORY` isolation |
| `uv`-within-`uv` trampoline crash | Fixed by switching subprocess to `sys.executable` |
| `LITELLM_LOG=DEBUG` corrupting MCP stdout | Removed after identifying it breaks JSON-RPC stream |

---

## Files

### Troubleshooting scripts

| Script | Purpose |
|---|---|
| `instance/scripts/cognee-mcp-protocol-test.py` | MCP stdio JSON-RPC protocol test — spawns cognee-mcp as subprocess, calls tools with per-call timeouts, reports PASS/FAIL |
| `instance/scripts/cognee-mcp-test.py` | Standalone Python API test — calls cognee directly (no MCP), all 3 flows PASS in ~70 s total |

### Server and config

| File | Purpose |
|---|---|
| `instance/installed/05-tool-transport/mcp-stdio-and-http/scripts/cognee-mcp-win-wrapper.py` | Server entry point — forces `WindowsSelectorEventLoopPolicy` before `asyncio.run`, prints LLM config diagnostic to stderr |
| `.mcp.json` | VS Code MCP server config — contains full env block (`LLM_PROVIDER`, `LLM_MODEL`, `LLM_API_KEY`, `EMBEDDING_*`, `NEO4J_*`, etc.) |
| `instance/scripts/run-eposforge-mcp-http.ps1` | VS Code task launch script for the MCP server |

### Logs (local only, not committed)

| Path | Contents |
|---|---|
| `instance/scripts/proto-test-server.log` | stderr from the cognee-mcp subprocess spawned by the protocol test |
| `instance/scripts/.cognee-proto-test/` | Isolated LanceDB + system storage root used by protocol test runs |

---

## How to run the tests

### Standalone API test (all 3 flows expected PASS, ~70 s)

```powershell
$env:COGNEE_TEST_STEP_TIMEOUT='75'
uv run --with "cognee[fastembed]" --with cognee-mcp --with openai --with anthropic --with neo4j `
    python instance/scripts/cognee-mcp-test.py
```

### MCP protocol test (test1 + test2 currently FAIL due to permanent-memory hang)

```powershell
$env:COGNEE_TEST_STEP_TIMEOUT='75'
uv run --with "cognee[fastembed]" --with cognee-mcp --with mcp --with openai --with anthropic --with neo4j `
    python instance/scripts/cognee-mcp-protocol-test.py 2>instance/scripts/proto-test-server.log
```

---

## Next steps

1. Switch the protocol test subprocess from `sys.executable` back to a fresh
   `uv run` invocation, but avoid the trampoline error by setting
   `UV_NO_MANAGED_PYTHON=1` or by using a pre-built venv path.  A fresh
   process guarantees no inherited singleton state.
2. Alternatively, instrument `extract_graph_and_summarize` directly (add a
   watchdog thread that writes a heartbeat line to a side-channel file) to
   pinpoint which internal call blocks.
3. Check whether the hang reproduces when Neo4j is unreachable (i.e., is the
   graph-write to Neo4j the blocking call?).  If so, the fix is a
   per-operation timeout on the Neo4j driver.
