#!/usr/bin/env python3
"""sync-mcp.py — Generate .mcp.json and .vscode/mcp.json from mcp.servers.toml.

This script is the canonical generator for the MCP configuration files used
by Claude Code (.mcp.json) and VS Code / Copilot (.vscode/mcp.json).

The generated file never contains a secret. Stdio server launch commands are
wrapped with `epos-secrets --only <RUNTIME_NAMES> --` so secrets are injected
at runtime via the resolver.

Usage:
    python instance/installed/05-tool-transport/mcp-stdio-and-http/scripts/sync-mcp.py
    python instance/installed/05-tool-transport/mcp-stdio-and-http/scripts/sync-mcp.py --check

--check mode: regenerates to memory, diffs against on-disk, exits non-zero on drift.
"""

import difflib
import json
import os
import pathlib
import sys
import tempfile

if sys.version_info < (3, 11):
    print("ERROR: sync-mcp.py requires Python 3.11 or newer.", file=sys.stderr)
    sys.exit(1)

import tomllib  # stdlib since 3.11

# ---------------------------------------------------------------------------
# Repo root: four levels up from this script:
#   scripts/ -> mcp-stdio-and-http/ -> 05-tool-transport/ -> installed/ -> instance/ -> repo/
# Wait, it's actually:
#   scripts/ -> mcp-stdio-and-http/ -> 05-tool-transport/ -> installed/ -> instance/ -> repo
# Let's count: scripts is under mcp-stdio-and-http which is under 05-tool-transport
# which is under installed which is under instance which is under repo root.
# So: script.parent = scripts/, .parent = mcp-stdio-and-http/, .parent = 05-tool-transport/,
#     .parent = installed/, .parent = instance/, .parent = repo root
# ---------------------------------------------------------------------------
_SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
_MCP_ADAPTER_DIR = _SCRIPT_DIR.parent           # mcp-stdio-and-http/
_REPO_ROOT = _MCP_ADAPTER_DIR.parent.parent.parent.parent  # repo root

_TOML_SOURCE = _MCP_ADAPTER_DIR / "mcp.servers.toml"
_SECRETS_ROOT = _REPO_ROOT / "instance" / "installed" / "12-secrets-key-management"
_EPOS_SECRETS = _REPO_ROOT / "instance" / "installed" / "12-secrets-key-management" / "bin" / "epos-secrets"

_GENERATOR_NOTE = "sync-mcp.py — DO NOT EDIT, edit mcp.servers.toml instead"


# ---------------------------------------------------------------------------
# Load secrets manifest to build logical_name -> runtime_name map
# ---------------------------------------------------------------------------

def _build_runtime_name_map() -> dict[str, str]:
    """Map logical_name -> runtime_name from all secrets.toml files."""
    mapping: dict[str, str] = {}
    for toml_path in sorted(_SECRETS_ROOT.glob("*/secrets.toml")):
        with toml_path.open("rb") as fh:
            data = tomllib.load(fh)
        for secret in data.get("secret", []):
            logical = secret["logical_name"]
            runtime = secret["runtime_name"]
            mapping[logical] = runtime
    return mapping


# ---------------------------------------------------------------------------
# Variable substitution in non_secret_env values
# ---------------------------------------------------------------------------

def _substitute_env_vars(value: str) -> str:
    """
    Expand ${REPO_ROOT} to the absolute repo root path.
    Other ${VAR} patterns are left as-is (they are runtime env refs).
    Note: ${ANTHROPIC_API_KEY} etc. remain as literal strings in the env block —
    these are resolved by epos-secrets at runtime, not here.
    """
    repo_root_str = str(_REPO_ROOT).replace("\\", "/")
    return value.replace("${REPO_ROOT}", repo_root_str)


# ---------------------------------------------------------------------------
# Build the resolved env block for a server
# Secrets-backed env vars (from uses_secrets) are injected by epos-secrets
# at runtime, so we include them as ${RUNTIME_NAME} placeholders that the
# non_secret_env block may reference (e.g. LLM_API_KEY = "${ANTHROPIC_API_KEY}").
# But those placeholders should NOT appear in the generated JSON env block —
# they are handled by the epos-secrets wrapper command.
# ---------------------------------------------------------------------------

def _build_env_block(server: dict, runtime_map: dict[str, str]) -> dict[str, str]:
    """Return non-secret env vars with REPO_ROOT substituted."""
    non_secret = server.get("non_secret_env", {})
    result = {}
    secret_runtime_names = set()
    for logical in server.get("uses_secrets", []):
        runtime = runtime_map.get(logical)
        if runtime:
            secret_runtime_names.add(runtime)

    for key, value in non_secret.items():
        expanded = _substitute_env_vars(str(value))
        # Strip out any non_secret_env entries that are just references to secrets
        # (e.g. LLM_API_KEY = "${ANTHROPIC_API_KEY}" — epos-secrets sets ANTHROPIC_API_KEY
        # directly; we don't need a duplicate alias in the static env block).
        # We keep the entry only if it's not a bare ${SECRET_RUNTIME_NAME} reference.
        is_secret_alias = expanded.strip("${}") in secret_runtime_names and expanded.startswith("${")
        if not is_secret_alias:
            result[key] = expanded
    return result


# ---------------------------------------------------------------------------
# Build epos-secrets wrapper command for a stdio server
# ---------------------------------------------------------------------------

def _wrap_with_epos_secrets(server: dict, runtime_map: dict[str, str]) -> tuple[list[str], dict[str, str]]:
    """
    Returns (wrapped_command_argv, env_block) where wrapped_command_argv prepends
    `python <epos-secrets> --only <RUNTIME_NAMES> --` before the original command.
    """
    uses_secrets = server.get("uses_secrets", [])
    runtime_names = []
    missing = []
    for logical in uses_secrets:
        runtime = runtime_map.get(logical)
        if runtime is None:
            missing.append(logical)
        else:
            runtime_names.append(runtime)

    if missing:
        print(
            f"ERROR: server '{server['name']}' uses_secrets entries not found in any "
            f"secrets.toml: {missing}\n"
            f"  Add the missing entries to the appropriate adapter's secrets.toml.",
            file=sys.stderr,
        )
        sys.exit(1)

    original_cmd = [server["command"]] + server.get("args", [])
    epos_secrets_path = str(_EPOS_SECRETS).replace("\\", "/")

    if runtime_names:
        only_arg = ",".join(runtime_names)
        wrapped = ["python", epos_secrets_path, "--only", only_arg, "--"] + original_cmd
    else:
        wrapped = ["python", epos_secrets_path, "--"] + original_cmd

    env_block = _build_env_block(server, runtime_map)
    return wrapped, env_block


# ---------------------------------------------------------------------------
# Generate .mcp.json (Claude Code format: mcpServers)
# ---------------------------------------------------------------------------

def _generate_mcp_json(servers: list[dict], runtime_map: dict[str, str]) -> dict:
    mcp_servers = {}
    for server in servers:
        name = server["name"]
        transport = server["transport"]

        if transport == "http":
            mcp_servers[name] = {
                "type": "http",
                "url": server["url"],
            }
        elif transport == "stdio":
            wrapped_cmd, env_block = _wrap_with_epos_secrets(server, runtime_map)
            entry: dict = {
                "type": "stdio",
                "command": wrapped_cmd[0],
                "args": wrapped_cmd[1:],
            }
            if env_block:
                entry["env"] = env_block
            mcp_servers[name] = entry
        else:
            print(f"WARNING: unknown transport '{transport}' for server '{name}'; skipping.", file=sys.stderr)

    return {
        "_generator": _GENERATOR_NOTE,
        "mcpServers": mcp_servers,
    }


# ---------------------------------------------------------------------------
# Generate .vscode/mcp.json (VS Code / Copilot format: servers with type)
# ---------------------------------------------------------------------------

def _generate_vscode_mcp_json(servers: list[dict], runtime_map: dict[str, str]) -> dict:
    vscode_servers = {}
    for server in servers:
        name = server["name"]
        transport = server["transport"]

        if transport == "http":
            vscode_servers[name] = {
                "type": "http",
                "url": server["url"],
            }
        elif transport == "stdio":
            wrapped_cmd, env_block = _wrap_with_epos_secrets(server, runtime_map)
            entry: dict = {
                "type": "stdio",
                "command": wrapped_cmd[0],
                "args": wrapped_cmd[1:],
            }
            if env_block:
                entry["env"] = env_block
            vscode_servers[name] = entry
        else:
            print(f"WARNING: unknown transport '{transport}' for server '{name}'; skipping.", file=sys.stderr)

    return {
        "_generator": _GENERATOR_NOTE,
        "servers": vscode_servers,
    }


# ---------------------------------------------------------------------------
# Atomic write helper
# ---------------------------------------------------------------------------

def _atomic_write_json(path: pathlib.Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = json.dumps(data, indent=2) + "\n"
    # Write to temp file in same dir, then rename for atomicity
    fd, tmp_path = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(content)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    check_mode = "--check" in sys.argv

    if not _TOML_SOURCE.exists():
        print(f"ERROR: {_TOML_SOURCE} not found.", file=sys.stderr)
        return 1

    with _TOML_SOURCE.open("rb") as fh:
        config = tomllib.load(fh)

    servers = config.get("server", [])
    if not servers:
        print("WARNING: no [[server]] entries found in mcp.servers.toml.")

    runtime_map = _build_runtime_name_map()

    mcp_json_data = _generate_mcp_json(servers, runtime_map)
    vscode_mcp_json_data = _generate_vscode_mcp_json(servers, runtime_map)

    mcp_json_path = _REPO_ROOT / ".mcp.json"
    vscode_mcp_json_path = _REPO_ROOT / ".vscode" / "mcp.json"

    if check_mode:
        drift = False
        for path, data in [
            (mcp_json_path, mcp_json_data),
            (vscode_mcp_json_path, vscode_mcp_json_data),
        ]:
            generated = json.dumps(data, indent=2) + "\n"
            existing = path.read_text(encoding="utf-8") if path.exists() else ""
            if generated != existing:
                drift = True
                diff = difflib.unified_diff(
                    existing.splitlines(keepends=True),
                    generated.splitlines(keepends=True),
                    fromfile=f"{path} (on-disk)",
                    tofile=f"{path} (generated)",
                )
                print(f"\nDrift detected in {path}:")
                sys.stdout.writelines(diff)

        if drift:
            print(
                "\nRun: python instance/installed/05-tool-transport/mcp-stdio-and-http/scripts/sync-mcp.py",
                file=sys.stderr,
            )
            return 1
        else:
            print("OK — .mcp.json and .vscode/mcp.json are in sync with mcp.servers.toml.")
            return 0

    # Write mode
    _atomic_write_json(mcp_json_path, mcp_json_data)
    print(f"Written: {mcp_json_path}")

    _atomic_write_json(vscode_mcp_json_path, vscode_mcp_json_data)
    print(f"Written: {vscode_mcp_json_path}")

    print("\nReload your IDE / Claude Code session to pick up the updated MCP config.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
