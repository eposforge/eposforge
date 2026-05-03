"""
Cognee MCP smoke test — runs directly via Python, no MCP server needed.
Usage: uv run --with "cognee[fastembed]" --with openai python instance/scripts/cognee-mcp-test.py

Tests:
  1. Permanent ingest + graph recall (LLM + embedding path)
  2. Session -> permanent bridge (improve)
  3. Cleanup (forget dataset)
"""
import asyncio
import os
import sys
import json
import pathlib
import time

# ---------------------------------------------------------------------------
# Load config from .mcp.json so tests use the exact same settings as the server
# ---------------------------------------------------------------------------
REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
MCP_JSON = REPO_ROOT / ".mcp.json"

def load_env_from_mcp_json():
    if not MCP_JSON.exists():
        print(f"[WARN] {MCP_JSON} not found, relying on process env")
        return
    cfg = json.loads(MCP_JSON.read_text())
    env = cfg.get("mcpServers", {}).get("cognee", {}).get("env", {})
    for k, v in env.items():
        if v is not None:
            os.environ[k] = str(v)

load_env_from_mcp_json()

import cognee  # noqa: E402  — must come after env is set

DATASET = "mcp_smoke_test_standalone"
TOKEN_PERM   = "COGNEE_STANDALONE_PERM_20260502"
TOKEN_BRIDGE = "COGNEE_STANDALONE_BRIDGE_20260502"
SESSION_ID   = "standalone-bridge-session"

PASS = "[PASS]"
FAIL = "[FAIL]"
results = {}
STEP_TIMEOUT_SECONDS = int(os.environ.get("COGNEE_TEST_STEP_TIMEOUT", "180"))


async def run_step(label, coro, timeout=STEP_TIMEOUT_SECONDS):
    print(f"  -> {label} (timeout={timeout}s)")
    started = time.perf_counter()
    result = await asyncio.wait_for(coro, timeout=timeout)
    elapsed = time.perf_counter() - started
    print(f"     completed in {elapsed:.2f}s")
    return result

# ---------------------------------------------------------------------------
# Configure cognee identically to spec-graph-cognee.py
# ---------------------------------------------------------------------------
async def configure():
    cognee_root = REPO_ROOT / "instance" / "installed" / "06-spec-graph" / "cognee" / ".cognee"
    cognee_root.mkdir(parents=True, exist_ok=True)
    cognee.config.system_root_directory = str(cognee_root)

    llm_api_key = os.environ.get("LLM_API_KEY") or os.environ.get("ANTHROPIC_API_KEY")
    if not llm_api_key:
        raise RuntimeError("Missing LLM API key. Set LLM_API_KEY or ANTHROPIC_API_KEY.")

    cognee.config.set_llm_provider("anthropic")
    cognee.config.set_llm_model(os.environ.get("LLM_MODEL", "claude-haiku-4-5-20251001"))
    cognee.config.set_llm_api_key(llm_api_key)
    cognee.config.set_llm_config({"llm_args": {"max_tokens": 4096}})
    os.environ["COGNEE_SKIP_CONNECTION_TEST"] = "true"
    os.environ["ENABLE_BACKEND_ACCESS_CONTROL"] = "false"

    embedding_provider = os.environ.get("EMBEDDING_PROVIDER", "openai")
    embedding_model    = os.environ.get("EMBEDDING_MODEL", "text-embedding-3-small")
    cognee.config.set_embedding_provider(embedding_provider)
    cognee.config.set_embedding_model(embedding_model)
    if embedding_provider == "openai":
        embedding_api_key = os.environ.get("EMBEDDING_API_KEY") or os.environ.get("OPENAI_API_KEY")
        if not embedding_api_key:
            raise RuntimeError("Missing EMBEDDING_API_KEY / OPENAI_API_KEY for EMBEDDING_PROVIDER=openai.")
        cognee.config.set_embedding_api_key(embedding_api_key)
        cognee.config.set_embedding_dimensions(int(os.environ.get("EMBEDDING_DIMENSIONS", "1536")))
    else:
        cognee.config.set_embedding_dimensions(384)

    neo4j_url  = os.environ.get("NEO4J_URI", "bolt://localhost:7688")
    neo4j_user = os.environ.get("NEO4J_USERNAME", "neo4j")
    neo4j_pw   = os.environ.get("NEO4J_PASSWORD", "")
    cognee.config.set_graph_database_provider("neo4j")
    cognee.config.set_graph_db_config({
        "graph_database_url": neo4j_url,
        "graph_database_username": neo4j_user,
        "graph_database_password": neo4j_pw,
    })

    print(f"  LLM:       anthropic / claude-haiku-4-5-20251001")
    print(f"  Embedding: {embedding_provider} / {embedding_model}")
    print(f"  Graph DB:  {neo4j_url}")

# ---------------------------------------------------------------------------
# Test 1 — Permanent ingest + recall
# ---------------------------------------------------------------------------
async def test_permanent_ingest():
    print("\n[TEST 1] Permanent ingest + graph recall")
    try:
        remember_result = await run_step(
            "remember(permanent)",
            cognee.remember(TOKEN_PERM, dataset_name=DATASET, self_improvement=False),
        )
        print(f"  remember status: {remember_result.status}")

        results_list = await run_step(
            "recall(permanent)",
            cognee.recall(TOKEN_PERM, datasets=[DATASET], top_k=5),
            timeout=90,
        )
        if results_list:
            print(f"  recall returned {len(results_list)} result(s): {results_list[0]}")
            results["test1"] = PASS
        else:
            print("  recall returned no results")
            results["test1"] = FAIL
    except TimeoutError:
        print("  ERROR: step timed out")
        results["test1"] = f"{FAIL} (TimeoutError)"
    except Exception as e:
        print(f"  ERROR: {e}")
        results["test1"] = f"{FAIL} ({type(e).__name__}: {e})"

# ---------------------------------------------------------------------------
# Test 2 — Session -> permanent bridge (improve)
# ---------------------------------------------------------------------------
async def test_bridge():
    print("\n[TEST 2] Session -> permanent bridge")
    try:
        # Write to session cache only
        await run_step(
            "remember(session)",
            cognee.remember(
                TOKEN_BRIDGE,
                dataset_name=DATASET,
                session_id=SESSION_ID,
                self_improvement=False,
            ),
            timeout=60,
        )
        print(f"  session write done (session_id={SESSION_ID})")

        # Bridge session into permanent graph
        await run_step(
            "improve(session->permanent)",
            cognee.improve(dataset=DATASET, session_ids=[SESSION_ID]),
        )
        print("  improve bridge complete")

        # Recall from permanent
        results_list = await run_step(
            "recall(bridge token)",
            cognee.recall(TOKEN_BRIDGE, datasets=[DATASET], top_k=5),
            timeout=90,
        )
        if results_list:
            print(f"  recall returned {len(results_list)} result(s): {results_list[0]}")
            results["test2"] = PASS
        else:
            print("  recall returned no results after bridge")
            results["test2"] = FAIL
    except TimeoutError:
        print("  ERROR: step timed out")
        results["test2"] = f"{FAIL} (TimeoutError)"
    except Exception as e:
        print(f"  ERROR: {e}")
        results["test2"] = f"{FAIL} ({type(e).__name__}: {e})"

# ---------------------------------------------------------------------------
# Test 3 — Cleanup
# ---------------------------------------------------------------------------
async def test_cleanup():
    print("\n[TEST 3] Cleanup")
    try:
        await run_step("forget(dataset)", cognee.forget(dataset=DATASET), timeout=60)
        print(f"  dataset '{DATASET}' deleted")
        results["test3"] = PASS
    except TimeoutError:
        print("  ERROR: step timed out")
        results["test3"] = f"{FAIL} (TimeoutError)"
    except Exception as e:
        try:
            await run_step("forget(everything)", cognee.forget(everything=True), timeout=90)
            print("  full forget done (dataset-scoped forget not available)")
            results["test3"] = PASS
        except Exception as e2:
            print(f"  ERROR: {e2}")
            results["test3"] = f"{FAIL} ({type(e2).__name__}: {e2})"

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
async def main():
    print("=" * 60)
    print("Cognee MCP standalone smoke test")
    print("=" * 60)

    print("\n[SETUP] Configuring cognee...")
    await configure()

    await test_permanent_ingest()
    await test_bridge()
    await test_cleanup()

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
    # cognee's embedding engine (ONNX/openai) deadlocks on Windows with the default
    # ProactorEventLoop in Python 3.12. SelectorEventLoop fixes this.
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(main())
