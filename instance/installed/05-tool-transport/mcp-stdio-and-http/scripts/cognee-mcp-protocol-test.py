"""
Cognee MCP protocol smoke test — connects to cognee-mcp via MCP stdio transport,
calls tools exactly as VS Code would, and enforces per-call timeouts.

This tests the real stdio JSON-RPC path without tying up the VS Code MCP
connection.  Run it any time to validate the server without agent intervention.

Usage:
    uv run --with "cognee[fastembed]" --with cognee-mcp --with mcp --with openai --with anthropic --with neo4j \
        python instance/scripts/cognee-mcp-protocol-test.py
"""
import asyncio
import json
import os
import pathlib
import sys
import time

# ---------------------------------------------------------------------------
# Load env from .mcp.json so the spawned server gets identical settings
# ---------------------------------------------------------------------------
REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
MCP_JSON = REPO_ROOT / ".mcp.json"

def load_env_from_mcp_json():
    if not MCP_JSON.exists():
        print(f"[WARN] {MCP_JSON} not found — relying on process env")
        return
    cfg = json.loads(MCP_JSON.read_text())
    env_block = cfg.get("mcpServers", {}).get("cognee", {}).get("env", {})
    for k, v in env_block.items():
        if v is not None:
            os.environ[k] = str(v)

load_env_from_mcp_json()

# Force SelectorEventLoop on Windows before importing any asyncio-heavy libs
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

from mcp import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

WRAPPER = str(
    REPO_ROOT
    / "instance"
    / "installed"
    / "05-tool-transport"
    / "mcp-stdio-and-http"
    / "scripts"
    / "cognee-mcp-win-wrapper.py"
)

DATASET   = "mcp_proto_smoke_20260503"
SESSION_ID = "proto-smoke-session"
TOOL_TIMEOUT = int(os.environ.get("COGNEE_TEST_STEP_TIMEOUT", "75"))

# Isolated storage dirs for the test subprocess — avoids SQLite/LanceDB write-lock
# contention with any VS Code-managed cognee-mcp server running concurrently.
TEST_STORAGE_ROOT = str(REPO_ROOT / "scratchpad" / ".cognee-proto-test")

PASS = "[PASS]"
FAIL = "[FAIL]"
results: dict[str, str] = {}


async def call_tool(session: ClientSession, tool: str, args: dict, label: str, timeout: int = TOOL_TIMEOUT):
    print(f"  -> {label}  (tool={tool}, timeout={timeout}s)")
    t0 = time.perf_counter()
    result = await asyncio.wait_for(session.call_tool(tool, arguments=args), timeout=timeout)
    elapsed = time.perf_counter() - t0
    # result.content is a list of TextContent / ImageContent etc.
    text = " | ".join(
        getattr(c, "text", repr(c)) for c in (result.content or [])
    )
    print(f"     completed in {elapsed:.2f}s")
    print(f"     response: {text[:200]}")
    return text


async def run_tests(session: ClientSession):
    # ---- Test 1 — permanent remember + recall ----------------------------
    print("\n[TEST 1] Permanent remember + recall")
    try:
        await call_tool(session, "remember", {
            "data": "Smoke-test permanent token: MCP_PROTO_SMOKE_PERM_20260503",
            "dataset_name": DATASET,
        }, "remember(permanent)", timeout=120)

        txt = await call_tool(session, "recall", {
            "query": "MCP_PROTO_SMOKE_PERM_20260503",
            "datasets": DATASET,
            "top_k": 3,
        }, "recall(permanent)", timeout=TOOL_TIMEOUT)

        results["test1"] = PASS if "smoke" in txt.lower() or "proto" in txt.lower() or "perm" in txt.lower() else f"{FAIL} (unexpected response: {txt[:80]})"
    except asyncio.TimeoutError:
        results["test1"] = f"{FAIL} (TimeoutError after {TOOL_TIMEOUT}s)"
    except Exception as e:
        results["test1"] = f"{FAIL} ({type(e).__name__}: {e})"

    # ---- Test 2 — session remember + improve bridge ----------------------
    print("\n[TEST 2] Session -> permanent bridge")
    try:
        await call_tool(session, "remember", {
            "data": "Smoke-test bridge token: MCP_PROTO_SMOKE_BRIDGE_20260503",
            "dataset_name": DATASET,
            "session_id": SESSION_ID,
        }, "remember(session)", timeout=30)

        await call_tool(session, "improve", {
            "dataset_name": DATASET,
            "session_ids": SESSION_ID,
        }, "improve(bridge)", timeout=TOOL_TIMEOUT)

        txt = await call_tool(session, "recall", {
            "query": "MCP_PROTO_SMOKE_BRIDGE_20260503",
            "datasets": DATASET,
            "top_k": 3,
        }, "recall(bridge)", timeout=120)

        results["test2"] = PASS if "smoke" in txt.lower() or "bridge" in txt.lower() or "proto" in txt.lower() else f"{FAIL} (unexpected response: {txt[:80]})"
    except asyncio.TimeoutError:
        results["test2"] = f"{FAIL} (TimeoutError after {TOOL_TIMEOUT}s)"
    except Exception as e:
        results["test2"] = f"{FAIL} ({type(e).__name__}: {e})"

    # ---- Test 3 — cleanup ------------------------------------------------
    print("\n[TEST 3] Cleanup")
    try:
        await call_tool(session, "forget_memory", {
            "dataset": DATASET,
            "everything": False,
        }, "forget_memory(dataset)", timeout=60)
        results["test3"] = PASS
    except asyncio.TimeoutError:
        results["test3"] = f"{FAIL} (TimeoutError after 60s)"
    except Exception as e:
        results["test3"] = f"{FAIL} ({type(e).__name__}: {e})"


async def main():
    print("=" * 60)
    print("Cognee MCP protocol smoke test  (stdio JSON-RPC)")
    print("=" * 60)
    print(f"Wrapper: {WRAPPER}")
    print(f"Dataset: {DATASET}")
    print(f"Tool timeout: {TOOL_TIMEOUT}s")

    server_params = StdioServerParameters(
        command=sys.executable,  # reuse the already-loaded uv env — avoids uv-within-uv nesting
        args=[WRAPPER],
        env={
            **dict(os.environ),  # includes all .mcp.json values loaded above
            # Give this server its own isolated storage to avoid write-lock
            # contention with the VS Code-managed cognee-mcp server.
            "SYSTEM_ROOT_DIRECTORY": TEST_STORAGE_ROOT,
            "DATA_ROOT_DIRECTORY": TEST_STORAGE_ROOT + "/data",
            # NOTE: do NOT set LITELLM_LOG=DEBUG here — litellm prints to stdout
            # which corrupts the MCP JSON-RPC stream.
        },
    )

    print("\n[SETUP] Spawning cognee-mcp server via stdio...")
    print("  (first run may take 30-60s while uv resolves packages)")
    t_start = time.perf_counter()
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await asyncio.wait_for(session.initialize(), timeout=180)
            elapsed = time.perf_counter() - t_start
            print(f"  Server initialized in {elapsed:.2f}s")

            # List available tools for diagnostic output
            tools = await asyncio.wait_for(session.list_tools(), timeout=10)
            tool_names = [t.name for t in tools.tools]
            print(f"  Available tools: {tool_names}")

            await run_tests(session)

    print("\n" + "=" * 60)
    print("RESULTS")
    print("=" * 60)
    all_pass = True
    for name, result in results.items():
        print(f"  {name}: {result}")
        if FAIL in result:
            all_pass = False
    print()
    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    asyncio.run(main())
