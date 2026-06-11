---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: gemini-cli → Dev Product (Component 3)

> Living Spec for the Gemini CLI Dev Product Adapter installed in this
> repo. Per [../../../../01-architecture/00-adapter-pattern.md](../../../../01-architecture/00-adapter-pattern.md),
> all required universal and component-specific fields are declared here.

---

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `gemini-cli` |
| `component` | `03-dev-product` |
| `version` | `unpinned` (latest `@google/gemini-cli` release) |
| `status` | `experimental` |
| `privacy_posture` | `vendor-default` (free tier permitted — this is an OSS project; training on repo content is acceptable) |
| `cost_hint` | `free` |
| `capabilities` | `very-large-context`, `multi-file-edit`, `terminal-ops`, `mcp-extensible` |
| `invocation_surface` | `CLI` |

### Dev Product required fields

| Field | Value |
|---|---|
| `task_shapes` | `single-file-edit`, `multi-file-refactor`, `test-authoring`, `terminal-ops` |
| `context_window` | `1M tokens` (Gemini 2.5 Pro) |
| `parallelism` | `false` (single interactive session) |
| `streaming` | `true` (streams to terminal; not to audit log in v1) |
| `autonomy_tos_posture` | `subscription-ok-through-supervised; api-key-required-for-autonomous` (see [../../../../01-architecture/03-autonomy-modes.md](../../../../01-architecture/03-autonomy-modes.md)) |

### Repo-specific fields

| Field | Value |
|---|---|
| `mcp_wiring` | `.gemini/settings.json` (gitignored; derive from `.gemini/settings.json.example`) |
| `enforcement_surface` | `AGENTS.md only` |
| `instruction_file` | `GEMINI.md` |
| `orchestration_role` | `delegated-worker` |
| `execution_sandbox` | `windows-acl-user` (see [../../../07-execution-sandbox/windows-acl-user/windows-acl-user.md](../../../07-execution-sandbox/windows-acl-user/windows-acl-user.md)) |

---

## MCP server set

All three Tool Transport servers are wired via `.gemini/settings.json`:

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

## Sandbox

Gemini CLI runs under the `windows-acl-user` Execution Sandbox (v1):
coarse per-session OS-user isolation via a dedicated `gemini-runner` local
Windows account. See the sandbox Living Spec for full isolation details.

Daily operator launch:
```powershell
runas /user:gemini-runner /savecred "gemini chat --workspace D:\src\git\gh\eposforge\eposforge"
```

Setup: run `instance/installed/07-execution-sandbox/windows-acl-user/scripts/install-gemini-sandbox.ps1` as administrator.

---

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| Coarse per-session sandbox | Not per-sub-task; no ephemeral workspace teardown between tasks | Upgrade sandbox Adapter to container or VM isolation |
| No network egress restriction | Filesystem isolation only; Gemini could exfiltrate workspace contents over network | Add network egress controls to sandbox Adapter |
| Single enforcement layer | No hook-level MCP-first reminder | Gemini CLI does not currently support UserPromptSubmit-equivalent hooks |
| `streaming: true` pipes to terminal only | Audit & Observability slot receives no structured events | Wire audit events when factory's Audit Adapter is installed |

---

## Secrets binding

Secrets for the `gemini-runner` account are stored in Windows Credential
Manager (never in env files or committed configs):

- `GEMINI_API_KEY` — optional; only required if using a paid Gemini API
  key. Free tier uses Google account auth and does not require this key.
- `GITHUB_PERSONAL_ACCESS_TOKEN` — required for GitHub MCP server.

Free-tier Google account auth (OAuth) is valid through `supervised` mode.
Google enforces against OAuth use in automated / unattended patterns, so
promotion to `autonomous` mode requires setting `GEMINI_API_KEY` (direct
API key); see the ToS threshold in
[../../../../01-architecture/03-autonomy-modes.md](../../../../01-architecture/03-autonomy-modes.md).

No secrets are committed to this repo. See
[../../../../01-architecture/02-components/12-secrets-key-management.md](../../../../01-architecture/02-components/12-secrets-key-management.md)
for the slot contract.

