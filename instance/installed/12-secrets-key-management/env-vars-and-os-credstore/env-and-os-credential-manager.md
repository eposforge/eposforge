---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: env-vars-and-os-credstore -> Secrets & Key Management (Component 12)

> Living Spec for this repo's current secrets binding strategy.
> Slot contract: [../../../../01-architecture/02-components/12-secrets-key-management.md](../../../../01-architecture/02-components/12-secrets-key-management.md)

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `env-vars-and-os-credstore` |
| `component` | `12-secrets-key-management` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `local` |
| `cost_hint` | `free` |
| `capabilities` | `runtime-secret-injection`, `credential-isolation`, `gitignore-protected-config` |
| `invocation_surface` | process environment + OS credential manager |

### Secrets / Key Management required fields

| Field | Value |
|---|---|
| `storage_modes` | process environment, OS credential manager |
| `rotation_model` | operator-managed manual rotation |
| `exposure_boundaries` | secrets excluded from git; scoped to shell/user context |
| `audit_surface` | minimal (provider-side logs + local history) |

### Repo-specific fields

| Field | Value |
|---|---|
| `env_bindings` | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `NEO4J_PASSWORD`, `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `os_credential_binding` | Gemini CLI credentials via Windows Credential Manager for `gemini-runner` |
| `mcp_config_file` | `.mcp.json` is gitignored |
| `sandbox_reference` | [../../07-execution-sandbox/windows-acl-user/windows-acl-user.md](../../07-execution-sandbox/windows-acl-user/windows-acl-user.md) |

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| No formal vault adapter | Single-operator trust and process discipline required | Add dedicated vault-backed Secrets adapter |
| No automated rotation enforcement | Drift risk for long-lived tokens | Add rotation runbook + CI policy checks |
