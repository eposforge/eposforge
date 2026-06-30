---
doc_kind: operator-runbook
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Cognee MCP Self-Consume Runbook (EF-010)

This runbook captures how this repo self-consumes `cognee-mcp` and how adopters
can apply the same pattern to their own corpus.

## Goal

- Connect an MCP-capable dev product to `cognee-mcp`.
- Verify the dev product can query the EposForge dataset.
- Document the same flow for adopters with substitution points.

## Shared-backend mode decision

For this repo, the default decision is **shared-backend single-graph mode**.

Set these values on the Cognee MCP server:

- `COGNEE_MCP_AGENT_SCOPED=false`
- `ENABLE_BACKEND_ACCESS_CONTROL=false`

Why this mode:

- Multiple MCP clients can query the same central graph.
- Cross-dataset traversal is available at the backend graph layer.

When to choose per-agent or isolated mode instead:

- You need strict tenant isolation by dataset or identity.
- You cannot allow broad read access across datasets.

## Transport options

- `stdio`: best for local dev-product processes.
- `sse`/`http`: best for remote or shared MCP endpoints.

Use placeholders in tracked config examples (do not commit private hostnames).

## Minimal client examples

### Claude Code (`.mcp.json`)

```json
{
  "mcpServers": {
    "cognee": {
      "command": "uvx",
      "args": ["cognee-mcp"],
      "env": {
        "COGNEE_MCP_AGENT_SCOPED": "false",
        "ENABLE_BACKEND_ACCESS_CONTROL": "false"
      }
    }
  }
}
```

### Copilot (`.vscode/mcp.json`)

```json
{
  "servers": {
    "cognee": {
      "type": "stdio",
      "command": "uvx",
      "args": ["cognee-mcp"],
      "env": {
        "COGNEE_MCP_AGENT_SCOPED": "false",
        "ENABLE_BACKEND_ACCESS_CONTROL": "false"
      }
    }
  }
}
```

### Cursor-style config (SSE)

```json
{
  "mcpServers": {
    "cognee": {
      "url": "https://<your-cognee-mcp-host>/sse"
    }
  }
}
```

## Verification (this repo)

1. Confirm MCP registration:
   - `claude mcp list`
2. Run a recall query from an MCP-capable dev product:
   - Example: `mcp__cognee__recall` for a known architecture term.
3. Confirm results include expected entities from the eposforge dataset.

### Adopter-safe recommendation view (EF-011 / EF-012)

For recommendation-style questions ("how does an adopter org do <pattern>"),
use the adopter-safe wrapper so responses do not leak EposForge-internal
`.eposforge/...` paths and each recommendation is maturity-tagged.

```bash
python.eposforge/spec-graph/cognee/scripts/adopter-recall.py \
  --query "how does an adopter org do secrets handling for CI"
```

Expected output behavior:

- Internal `.eposforge/...` references are rewritten to
  `<adopter-layout-path>` with a prerequisite note.
- Each line is tagged as `[maturity: shipped|partial|intent]`.

## TTL overlay flow

Overlay ontology updates are uploaded via `cognee-sync`, not by ad-hoc MCP
tool calls.

Use incremental sync only:

- `epos-secrets uv run cognee-sync --modified 00-vision/01-ontology.ttl <changed-docs>`

Important limitation:

- Cognee ontology upload requires the multipart filename extension `.owl`.
- This behavior is documented in
  `.eposforge/spec-graph/cognee/cognee.md`.
- Automation of the extension handling is tracked separately in `EF-004`.

## For adopters

Substitute these inputs for your environment:

- Your corpus paths (instead of this repo's docs).
- Your overlay TTL file and ontology key.
- Your own MCP endpoint or local `uvx cognee-mcp` process.
- Your own dataset naming and access-control policy.

Recommended rollout:

1. Start with `stdio` in one dev product.
2. Verify `mcp list` and one successful `recall` query.
3. Add SSE/HTTP transport only when shared endpoint access is needed.
4. Keep ontology updates incremental; avoid bulk re-cognify until budget and
   inference routing controls are in place.
