# Installed Adapter: windows-acl-user → Execution Sandbox (Component 7)

> Living Spec for the Windows OS-user + NTFS-ACL Execution Sandbox
> Adapter installed in this repo. Per
> [../../00-adapter-pattern.md](../../00-adapter-pattern.md), all
> required universal and component-specific fields are declared here.

---

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `windows-acl-user` |
| `component` | `07-execution-sandbox` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `local` (filesystem isolation only; network egress intentionally unrestricted in v1) |
| `cost_hint` | `free` (OS-native; no additional tooling required) |
| `capabilities` | `filesystem-isolation`, `identity-separation` |
| `invocation_surface` | `OS-user-account` (`runas /user:gemini-runner`) |

### Execution Sandbox required fields

| Field | Value |
|---|---|
| `isolation_mechanism` | `os-user-account + ntfs-acl` |
| `network_policy_modes` | `none` — network egress is intentionally unrestricted in v1 (see Contract gaps) |
| `gpu_support` | `false` |
| `state_persistence` | `true` — per-session; workspace persists across invocations within a session |

### Repo-specific fields

| Field | Value |
|---|---|
| `workspace_root` | `D:\src\git\gh\eposforge\eposforge` |
| `runner_principal` | `gemini-runner` (local Windows standard account, non-admin) |
| `outbound_network` | open — required for Gemini inference, GitHub MCP, Microsoft Docs MCP, and loopback `eposforge-graph` MCP |
| `teardown` | manual (no per-sub-task teardown; ephemeral workspace not implemented in v1) |
| `bound_dev_product` | `gemini-cli` (see [../../03-dev-product/installed/gemini-cli.md](../../03-dev-product/installed/gemini-cli.md)) |

---

## Setup

Run `scripts/install-gemini-sandbox.ps1` as administrator. The script is
idempotent and performs:

1. Creates local standard user `gemini-runner` (non-admin, no interactive
   logon session required outside of `runas`).
2. Grants Modify on `workspace_root` to `gemini-runner` via NTFS ACL.
3. Denies read on the operator's profile directory (`C:\Users\<operator>`)
   to `gemini-runner` — defense-in-depth atop default cross-user denial.
4. Installs Gemini CLI under the `gemini-runner` profile.
5. Stages `.gemini/settings.json` from `.gemini/settings.json.example`.
6. Configures secrets in Windows Credential Manager for `gemini-runner`.
7. Verifies outbound connectivity to all required endpoints.
8. Prints the daily operator launch command.

---

## ACL summary

| Path | Permission | Principal |
|---|---|---|
| `D:\src\git\gh\eposforge\eposforge` | Modify (OI)(CI) | `gemini-runner` |
| `C:\Users\<operator>` | Read — DENY (OI)(CI) | `gemini-runner` |

---

## Contract gaps (v1)

This sandbox is a *coarse* implementation. It satisfies filesystem
isolation for human-driven sessions but does not meet the full
Execution Sandbox component contract
([../../07-execution-sandbox.md](../../07-execution-sandbox.md)):

| Contract requirement | Status | Notes |
|---|---|---|
| Fresh isolated workspace per sub-task | **Not met** | Single persistent workspace; no teardown between tasks |
| Resource limits (CPU, memory, wall clock, network egress) | **Not met** | No resource quotas applied; network is open |
| Enforce Dev Product's privacy posture at network level | **Partial** — filesystem only | Gemini inference is `vendor-no-training`; network not restricted |
| Tear down cleanly after sub-task | **Not met** | No teardown; operator manages session lifecycle |
| Emit audit events on creation, termination, policy violations | **Not met** | No audit events in v1 |

**Intended scope:** suitable for human-driven invocation of Gemini CLI on
this repo. Not suitable for autonomous Router dispatch.

**Upgrade path:** replace with a container or VM isolation mechanism that
provides per-sub-task workspace lifecycle and resource limits.

---

## Deltas from canonical contract

This adapter intentionally departs from the component contract in two
dimensions that are documented here rather than silently omitted:

1. **Per-session, not per-sub-task.** The canonical contract requires a
   fresh isolated workspace per dispatched sub-task. This adapter provides
   one persistent session-scoped workspace. This is sufficient while
   Gemini CLI is invoked interactively by the operator.

2. **Network egress unrestricted.** The canonical contract requires the
   sandbox to enforce the Dev Product's privacy posture at the network
   layer. This adapter relies on Gemini's API-level `vendor-no-training`
   guarantee and does not add network-layer enforcement. This is an
   intentional v1 scope boundary.
