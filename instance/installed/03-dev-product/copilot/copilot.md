---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---
# Installed Adapter: copilot → Dev Product (Component 3)

> Living Spec for the GitHub Copilot Dev Product Adapter installed in
| `status` | `approved` |
> this repo. Per [../../../../01-architecture/00-adapter-pattern.md](../../../../01-architecture/00-adapter-pattern.md),
> all required universal and component-specific fields are declared here.

---

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `copilot` |
| `component` | `03-dev-product` |
| `version` | `unpinned` (latest VS Code extension release) |
| `status` | `approved` |
| `privacy_posture` | `vendor-no-training` (business / enterprise plan; consumer plans require opt-out) |
| `cost_hint` | `consumer-paid` |
| `capabilities` | `inline-autocomplete`, `chat`, `agent-mode`, `multi-file-edit`, `mcp-tool-use` |
| `invocation_surface` | `IDE-extension` (VS Code) |

### Dev Product required fields

| Field | Value |
|---|---|
| `task_shapes` | `single-file-edit`, `multi-file-refactor`, `test-authoring` |
| `context_window` | `varies` (depends on active model backend; typically 128k–200k tokens) |
| `parallelism` | `false` (single agent session) |
| `streaming` | `true` (streams to VS Code chat panel; not to audit log in v1) |
| `autonomy_tos_posture` | `subscription-only; supervised-max` (see [../../../../01-architecture/03-autonomy-modes.md](../../../../01-architecture/03-autonomy-modes.md)) |

### Repo-specific fields

| Field | Value |
|---|---|
| `mcp_wiring` | `.vscode/mcp.json` (gitignored; derive from `.vscode/mcp.json.example`) |
| `enforcement_surface` | `AGENTS.md only` |
| `instruction_file` | `.github/copilot-instructions.md` |
| `orchestration_role` | `delegated-worker` |
| `execution_sandbox` | none declared (runs in VS Code host process; see Contract gaps) |

---

## MCP server set

All three Tool Transport servers are wired via `.vscode/mcp.json`:

| Server | Transport | Notes |
|---|---|---|
| `cognee` | stdio (`uvx cognee-mcp`) | local-hosted MCP; graph and memory operations |
| `github` | stdio (`@modelcontextprotocol/server-github`) | requires `GITHUB_PERSONAL_ACCESS_TOKEN` in env |
| `ms-docs` | http (`https://learn.microsoft.com/api/mcp`) | public; no auth required |

---

## MCP-first enforcement

One layer:

1. **`AGENTS.md`** — tool-neutral policy inherited by all Dev Products.
   No tool-specific hook is available on this surface in v1.

---

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| No Execution Sandbox | Copilot runs in VS Code host process | Formal sandbox support pending IDE integration support |
| Single enforcement layer | No hook-level MCP-first reminder | Copilot relies on instruction compliance; add `.github/instructions/` file if further reinforcement is needed |
| `streaming: true` pipes to VS Code panel only | Audit & Observability slot receives no structured events | Wire audit events when the factory's Audit Adapter is installed |

---

## Secrets binding

Secrets are read from VS Code's environment or secret storage:

- `GITHUB_PERSONAL_ACCESS_TOKEN` — required for GitHub MCP server.

Copilot authenticates via a per-seat subscription with no BYOK / API-key
path, and its `IDE-extension` invocation surface has no sanctioned
headless mode. It therefore caps at `supervised` mode and cannot be
promoted to `autonomous` regardless of auth rebind; see the ToS threshold
in [../../../../01-architecture/03-autonomy-modes.md](../../../../01-architecture/03-autonomy-modes.md).

No secrets are committed to this repo. See
[../../../../01-architecture/02-components/12-secrets-key-management.md](../../../../01-architecture/02-components/12-secrets-key-management.md)
for the slot contract.

