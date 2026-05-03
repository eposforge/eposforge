"""
Windows event-loop wrapper for cognee-mcp.

Python 3.12 on Windows defaults to ProactorEventLoop, which deadlocks when
cognee's permanent-memory pipeline runs ONNX / embedding work.  Forcing
WindowsSelectorEventLoopPolicy resolves this without patching the installed
cognee-mcp package.

Usage (replaces `uvx cognee-mcp`):
    uv run --with "cognee[fastembed]" --with cognee-mcp python cognee-mcp-win-wrapper.py
"""
import asyncio
import sys

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

# Diagnostic: print effective LLM config to stderr so it appears in server logs
try:
    from cognee.infrastructure.llm.config import LLMConfig
    _llm = LLMConfig()
    print(
        f"[wrapper] LLM provider={_llm.llm_provider!r} model={_llm.llm_model!r} "
        f"api_key={'<set>' if _llm.llm_api_key else '<MISSING>'}",
        file=sys.stderr, flush=True,
    )
except Exception as _e:
    print(f"[wrapper] could not read LLMConfig: {_e}", file=sys.stderr, flush=True)

try:
    from src.server import main as _server_main
except ImportError:
    from server import main as _server_main

asyncio.run(_server_main())
