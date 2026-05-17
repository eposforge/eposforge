# Win11 Setup for Cognee Spec Graph MCP

This runbook sets up local `cognee` MCP on a Windows 11 workstation
connecting to a shared Neo4j instance.

## Scope

- Use VS Code Copilot Chat with `cognee` MCP tools.
- Connect Neo4j via direct host/IP on your private network (Bolt is TCP,
  not HTTP).
- Run Cognee MCP locally over stdio.

## Prerequisites

- Windows 11 machine with network reachability to your Neo4j host.
- Docker Desktop running.
- VS Code with GitHub Copilot Chat enabled.
- Git installed.
- Python 3.11 to 3.13 installed with the `py` launcher available.
- `uv` installed (`uvx` command available).

## 1. Clone the repo

```powershell
git clone https://github.com/eposforge/eposforge.git
cd eposforge
```

## 2. Install local Cognee MCP runtime

```powershell
uv --version
uvx --version
```

Optional, only if you also want to rebuild the graph on this machine:

```powershell
pip install graphrag==3.0.9 neo4j pandas pyarrow lancedb
```

If you plan to run the rebuild scripts from Windows, use Git Bash or WSL.
The repo's rebuild helpers live under `instance/installed/06-spec-graph/graphrag/scripts/` (GraphRAG fallback) — they are shell scripts.

## 3. Neo4j endpoint assumptions

A shared Neo4j instance should be reachable from this workstation with Bolt
exposed on port `7688`. No local Neo4j instance is needed.

> Caddy cannot proxy Bolt. `https://<neo4j-browser-host>` is useful for the Neo4j
> browser UI on port `7474`, but MCP must connect directly to Bolt over TCP.

Bolt connection: `bolt://<neo4j-host-or-ip>:7688`

Browser UI: `https://<neo4j-browser-host>`

## 4. Set Neo4j and inference API values

```powershell
$env:NEO4J_URI = "bolt://<neo4j-host-or-ip>:7688"
$env:NEO4J_USERNAME = "neo4j"
$env:NEO4J_PASSWORD = "<your-password>"
$env:ANTHROPIC_API_KEY = "<your-anthropic-api-key>"
$env:OPENAI_API_KEY = "<your-openai-api-key>"
```

These values only live for the current PowerShell session. If you want them to
persist across terminal restarts, add them to your PowerShell profile or load
them from a local `.env` file before starting the MCP server.

## 5. Run local Cognee MCP

Run this in a dedicated PowerShell terminal and keep it running:

```powershell
uvx cognee-mcp
```

This runs the MCP server locally. Inference still uses external APIs via
`ANTHROPIC_API_KEY` and `OPENAI_API_KEY`.

## 6. Configure the VS Code MCP client

Create local file `.vscode/mcp.json` in the repo:

```json
{
  "servers": {
    "cognee": {
      "type": "stdio",
      "command": "uvx",
      "args": ["cognee-mcp"]
    }
  }
}
```

The repo already includes `.vscode/mcp.json.example` with the same shape as a
copyable template. `.vscode/mcp.json` is local-only and ignored by git.

## 7. Validate in Copilot Chat

- Open Copilot Chat.
- Open Tools and confirm `cognee` appears.
- Start it if needed.
- Run a simple read query, for example:

```cypher
MATCH (e:Entity)
RETURN e.type AS type, count(*) AS count
ORDER BY count DESC
LIMIT 10
```

If the tool connects but returns no rows, verify the shared graph has been
imported recently and that your `NEO4J_*` values are set in the same terminal
where you started the MCP server.

## Security note

Do not commit real hostnames, internal DNS names, or private IP addresses to
repo docs. Keep environment-specific endpoint details in local notes or a
private runbook.
