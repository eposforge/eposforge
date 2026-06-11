---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: env-vars -> Secrets & Key Management (Component 12)

> Living Spec for the process-environment secrets adapter.
> Slot contract: [../../../../01-architecture/02-components/12-secrets-key-management.md](../../../../01-architecture/02-components/12-secrets-key-management.md)
> Candidate catalog: [../../../../03-research/01-architecture/02-components/12-secrets-key-management/secrets-key-management.md](../../../../03-research/01-architecture/02-components/12-secrets-key-management/secrets-key-management.md)

This adapter fulfills the Component 12 (Secrets & Key Management) slot using process
environment variables as the store backend. It is the lowest-common-denominator bootstrap
layer: it carries non-secret env-driven config (`LLM_MODEL`, `EPOS_ENV`) that are not
sensitive but are referenced by the manifest schema, and serves as fallback for any secret
that does not yet have a higher-fidelity adapter configured.

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `env-vars` |
| `component` | `12-secrets-key-management` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `local` |
| `cost_hint` | `free` |
| `capabilities` | `runtime-config-injection`, `bootstrap-passthrough` |
| `invocation_surface` | process environment |

### Secrets / Key Management required fields

| Field | Value |
|---|---|
| `store_backends` | process environment |
| `rotation_supported` | `false` |
| `injection_modes` | `env` |

### Repo-specific fields

| Field | Value |
|---|---|
| `env_bindings` | `LLM_MODEL`, `EMBEDDING_MODEL`, `INFERENCE_PROVIDER`, `COGNEE_REQUIRE_AZURE_ROUTING`, `AZURE_API_BASE`, `AZURE_API_VERSION`, `EPOS_ENV` |
| `manifest_file` | `secrets.toml` (this directory) |
| `resolver_note` | `epos-secrets` resolver reads this manifest; env-var entries are passthrough from the calling process environment |

## Purpose

This adapter declares env-var-backed configuration that is:
- Not sensitive (e.g., `LLM_MODEL`, `INFERENCE_PROVIDER`, `AZURE_API_BASE`, `EPOS_ENV`) — but is tracked in the manifest so the
  resolver has a canonical record of every named entry.
- Used as a bootstrap fallback when the `sops-age` adapter cannot be initialized (e.g.,
  on a fresh developer machine before age keys are distributed).

Sensitive secrets (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `AZURE_API_KEY`, `NEO4J_PASSWORD`, etc.) belong
in the `sops-age` adapter. This adapter does NOT own those entries; any attempt to declare
them here conflicts with `sops-age` and will cause the resolver to fail loudly on collision.

## Observable behavior

- The `epos-secrets` resolver reads `secrets.toml` and, for entries with `adapter = "env-vars"`,
  looks up the `runtime_name` in the calling process's environment.
- If the env var is already set, it is passed through to the child process unchanged.
- If the env var is missing and the entry is `required_environments = ["dev"]` and the
  current env is `dev`, the resolver emits a warning but does not fail (env-vars entries
  are advisory unless `required = true` is set in the manifest).
- No decryption step; no external process.

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| No rotation support | Env vars live in shell rc files; rotation is manual re-export | Operator updates shell rc and restarts terminal; no tooling yet |
| No audit emission for env passthrough | `secret.accessed` events not emitted for plain env vars | Wire resolver to emit event on every env lookup |
| No expiry tracking | Env-var entries have no rotation timestamp | Add `rotation_log.toml` per-adapter in follow-up |
