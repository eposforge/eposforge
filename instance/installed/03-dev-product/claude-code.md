---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: claude-code → Dev Product (Component 3)

> Living Spec for the Claude Code Dev Product Adapter installed in this
> repo. Per [../../../01-architecture/00-adapter-pattern.md](../../../01-architecture/00-adapter-pattern.md),
> all required universal and component-specific fields are declared here.

---

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `claude-code` |
| `component` | `03-dev-product` |
| `version` | `unpinned` (latest release) |
| `status` | `approved` |
| `privacy_posture` | `vendor-no-training` (Claude Max / Pro with enterprise settings; consumer opt-out required) |
| `cost_hint` | `consumer-paid` |
| `capabilities` | `multi-file-edit`, `terminal-ops`, `browser-ops`, `agentic-autonomy`, `mcp-tool-use` |
| `invocation_surface` | `CLI` |

### Dev Product required fields

| Field | Value |
|---|---|
| `task_shapes` | `single-file-edit`, `multi-file-refactor`, `test-authoring`, `terminal-ops`, `browser-ops` |
| `context_window` | `200k tokens` (Claude 3.7 Sonnet) |
| `parallelism` | `false` (single interactive session) |
| `streaming` | `true` (streams to terminal; not to audit log in v1) |

### Repo-specific fields

| Field | Value |
|---|---|
| `mcp_wiring` | `.mcp.json` (gitignored; derive from `.mcp.json.example`) |
| `enforcement_surface` | `UserPromptSubmit hook (.claude/settings.json) + AGENTS.md` |
| `instruction_file` | `CLAUDE.md` |
| `execution_sandbox` | none declared (runs in operator's shell session; see Contract gaps) |

---

## MCP server set

All three Tool Transport servers are wired via `.mcp.json`:

| Server | Transport | Notes |
|---|---|---|
| `eposforge-graph` | stdio (`mcp-neo4j-cypher`) | read-only; loopback only |
| `github` | stdio (`@modelcontextprotocol/server-github`) | requires `GITHUB_PERSONAL_ACCESS_TOKEN` in env |
| `ms-docs` | http (`https://learn.microsoft.com/api/mcp`) | public; no auth required |

---

## MCP-first enforcement

Two layers:

1. **`AGENTS.md`** — tool-neutral policy inherited by all Dev Products.
2. **`.claude/settings.json` UserPromptSubmit hook** — injects an
   MCP-first reminder when the prompt contains architecture vocabulary.
   Pre-allows `mcp__eposforge-graph__*` tools to avoid deferred-tool
   friction.

---

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| No Execution Sandbox | Claude Code runs in operator's shell; a prompt injection or hallucinated command could affect the operator's filesystem | Install into a formal Execution Sandbox Adapter when one is declared for this product |
| `streaming: true` pipes to terminal only | Audit & Observability slot receives no structured events | Wire audit events when the factory's Audit Adapter is installed |
| `parallelism: false` | Router cannot dispatch concurrent Claude Code sub-tasks | Use multiple shell sessions or wait for headless API support |

---

## Secrets binding

Secrets are read from the operator environment at session start:

- `GITHUB_PERSONAL_ACCESS_TOKEN` — required for GitHub MCP server.
- Other model keys managed by Anthropic's own credential chain.

No secrets are committed to this repo. See
[../../../01-architecture/02-components/12-secrets-key-management.md](../../../01-architecture/02-components/12-secrets-key-management.md)
for the slot contract.

