# Win11 Setup for EposForge Spec Graph MCP

This runbook sets up `eposforge-graph` on a Windows 11 workstation
connecting to a shared Neo4j instance.

## Scope

- Use VS Code Copilot Chat with `eposforge-graph` MCP tools.
- Connect Neo4j via direct host/IP on your private network (Bolt is TCP,
  not HTTP).
- Avoid stdio startup timeout by running MCP as a persistent HTTP service.

## Prerequisites

- Windows 11 machine with network reachability to your Neo4j host.
- Docker Desktop running.
- VS Code with GitHub Copilot Chat enabled.
- Git installed.
- Python 3.11 to 3.13 installed with the `py` launcher available.

## 1. Clone the repo

```powershell
git clone https://github.com/eposforge/eposforge.git
cd eposforge
```

## 2. Create Python venv and install MCP server

```powershell
cd instance\installed\06-spec-graph\graphrag
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install mcp-neo4j-cypher
```

Optional, only if you also want to rebuild the graph on this machine:

```powershell
pip install graphrag==3.0.9 neo4j pandas pyarrow lancedb
```

If you plan to run the rebuild scripts from Windows, use Git Bash or WSL.
The repo's rebuild helpers in `instance/scripts/` are shell scripts.

## 3. Neo4j endpoint assumptions

A shared Neo4j instance should be reachable from this workstation with Bolt
exposed on port `7688`. No local Neo4j instance is needed.

> Caddy cannot proxy Bolt. `https://<neo4j-browser-host>` is useful for the Neo4j
> browser UI on port `7474`, but MCP must connect directly to Bolt over TCP.

Bolt connection: `bolt://<neo4j-host-or-ip>:7688`

Browser UI: `https://<neo4j-browser-host>`

## 4. Set Neo4j connection values

```powershell
$env:NEO4J_URI = "bolt://<neo4j-host-or-ip>:7688"
$env:NEO4J_USERNAME = "neo4j"
$env:NEO4J_PASSWORD = "<your-password>"
```

These values only live for the current PowerShell session. If you want them to
persist across terminal restarts, add them to your PowerShell profile or load
them from a local `.env` file before starting the MCP server.

## 5. Run MCP as a persistent HTTP process

Run this in a dedicated PowerShell terminal and keep it running:

```powershell
cd instance\installed\06-spec-graph\graphrag
.\.venv\Scripts\Activate.ps1
mcp-neo4j-cypher `
  --transport http `
  --server-host 127.0.0.1 `
  --server-port 7776 `
  --server-path /mcp/ `
  --read-only
```

Why this mode: it avoids the stdio cold-start timing issues seen with Python-
based MCP servers, and `mcp-neo4j-cypher` will read `NEO4J_URI`,
`NEO4J_USERNAME`, and `NEO4J_PASSWORD` directly from the environment.

## 6. Configure the VS Code MCP client

Create local file `.vscode/mcp.json` in the repo:

```json
{
  "servers": {
    "eposforge-graph": {
      "type": "http",
      "url": "http://127.0.0.1:7776/mcp/"
    }
  }
}
```

The repo already includes `.vscode/mcp.json.example` with the same shape as a
copyable template. `.vscode/mcp.json` is local-only and ignored by git.

## 7. Validate in Copilot Chat

- Open Copilot Chat.
- Open Tools and confirm `eposforge-graph` appears.
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
