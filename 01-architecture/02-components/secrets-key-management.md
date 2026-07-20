---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Secrets & Key Management

## Purpose

The slot for resolving, rotating, and redacting every secret the factory
or its dispatched work consumes. Secrets cross every component boundary:
the Orchestrator needs vendor API keys, Dev Products need credentials to
external services, Tool Transport needs auth tokens, Source Control + CI
needs deploy keys, the Inference Layer needs provider keys.

A single mismanaged secret can compromise the entire factory. This slot
exists to make secret handling explicit, contractual, and auditable.

## Contract

Any Adapter for this slot must:

- Maintain a **runtime contract** for every secret. Each entry declares:
  - `logical_name` — the abstract identity of the secret in factory
    docs.
  - `runtime_name` — environment variable or config key consumers see.
  - `source_of_truth` — where the canonical value lives.
  - `injection_path` — how the value reaches each consumer.
  - `consumers` — which Adapters and components read this secret.
  - `required_environments` — where the secret is required (dev, CI,
    prod).
  - `rotation_owner` — who is responsible for rotation.
  - `redaction_rules` — how the secret must be redacted in logs and
    error output.
  - `fallback` — break-glass path if the source of truth is unreachable.
- Resolve secrets at runtime; never persist plaintext to disk inside the
  factory's working storage.
- Enforce redaction in log output before events reach Audit &
  Observability.
- Emit `secret.accessed` events (without values) on every resolution.
- Refuse to serve a secret whose declared `required_environments` does
  not include the current environment.
- Support rotation without downtime: a secret may be in two states for a
  window, both honored by the resolver.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `store_backends` — where secrets can live (env vars, encrypted file,
  Vault, KMS, password manager, etc.).
- `rotation_supported` — boolean.
- `injection_modes` — env, config file, mounted path, in-process API.

## Boundaries

- **Is:** the contract for declaring and resolving secrets.
- **Is not:** an identity provider for humans. Operator login lives
  outside this component.
- **Is not:** a place to store non-secret config. Configuration that is
  not sensitive belongs in source control.

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog (env vars
on host, SOPS + age, HashiCorp Vault, AWS / GCP / Azure KMS, Keeper,
1Password, Doppler, etc.).


