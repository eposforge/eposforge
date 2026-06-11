---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---
# Installed Adapter: mcp-stdio-and-http -> Tool Transport (Component 5)

> Living Spec for the Tool Transport Adapter installed in this repo.
| `status` | `approved` |
> Slot contract: [../../../../01-architecture/02-components/05-tool-transport.md](../../../../01-architecture/02-components/05-tool-transport.md)

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `mcp-stdio-and-http` |
| `component` | `05-tool-transport` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `mixed` (`local` for Cognee MCP process, `vendor-default` for external inference APIs) |
| `cost_hint` | `free + metered` (server-dependent) |
| `capabilities` | `graph-query`, `repo-query`, `docs-query`, `memory` |
| `invocation_surface` | `MCP` (`stdio` and `http`) |

### Tool Transport required fields

| Field | Value |
|---|---|
| `transport_protocol` | `mcp` |
| `request_modes` | `sync`, `streaming` |
| `authn_modes` | `none`, `token` |
| `capability_declaration` | explicit per MCP server declaration |

### Repo-specific fields

| Field | Value |
|---|---|
| `mcp_config_source` | `.mcp.json` (gitignored; starts from `.mcp.json.example`) |
| `policy_anchor` | [../../../../AGENTS.md](../../../../AGENTS.md) MCP-first policy |
| `scope_note` | this is this repo's Tool Transport choice, not a normative requirement for other instances |

## Installed server set

Self-consumption and adopter onboarding steps for Cognee MCP are documented in
[cognee-mcp-self-consume-runbook.md](./cognee-mcp-self-consume-runbook.md).

| Server | Transport | Capability set | Notes |
|---|---|---|---|
| `cognee` | `stdio` (loopback) | `graph-query`, `memory` | Local Cognee MCP service; external LLM API calls via env keys |
| `github` | `stdio` | `repo-query` | Requires `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `microsoft.docs` | `http` | `docs-query` | Public endpoint |

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| No unified capability registry schema in repo | Capability discovery depends on MCP config conventions | Add a machine-validated capability manifest |
| Per-server auth configuration drift risk | Server onboarding can be error-prone | Add validation tooling over `.mcp.json` schema |
