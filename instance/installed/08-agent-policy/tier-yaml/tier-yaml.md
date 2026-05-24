---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: tier-yaml -> Agent Policy (Component 8)

> Living Spec for this repo's Component 8 adapter.
> Slot contract: [../../../../01-architecture/02-components/08-agent-policy.md](../../../../01-architecture/02-components/08-agent-policy.md)

## Purpose

Declare agent-policy tiers in a repository-owned YAML contract and generate a
per-adopter Claude permissions file from tier-0 auto-approved rules.

## Observable behavior

- Loads `policy.tiers.yaml` (YAML 1.2 JSON-compatible structure).
- Reads tier-0 rules containing predicates for Bash command shapes and MCP tool
  names.
- Emits `.claude/settings.json` permissions allowlist from tier-0 entries.
- Supports baseline equivalence checks against a hand-verified settings file.

## Inputs / outputs

- Input contract: `policy.tiers.yaml`.
- Generator: `scripts/generate-claude-settings.py`.
- Baseline comparator: `scripts/check-baseline.sh`.
- Output target: `.claude/settings.json` by default.

## Dependencies

- Python 3.11+ (stdlib only).
- Bash for helper scripts.

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `tier-yaml` |
| `component` | `08-agent-policy` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `local` |
| `cost_hint` | `free` |
| `capabilities` | `tiered-policy`, `claude-settings-generation`, `baseline-equivalence-check` |
| `invocation_surface` | `CLI scripts` |

### Agent Policy required fields

| Field | Value |
|---|---|
| `policy_format` | `yaml` (JSON-compatible YAML 1.2) |
| `tiers_supported` | `tier-0` (auto), `tier-1` (supervised), `tier-2` (manual) |
| `rings_supported` | `alpha`, `beta`, `preview`, `ga` |
| `ring_lock_rules_ref` | `policy.tiers.yaml` -> `ring_lock` |
| `decision_latency_target` | `p99 <= 50ms` for local file-based decisions |

### Repo-specific fields

| Field | Value |
|---|---|
| `tier_contract_file` | `instance/installed/08-agent-policy/tier-yaml/policy.tiers.yaml` |
| `generator_target_default` | `.claude/settings.json` |
| `baseline_expected` | `instance/installed/08-agent-policy/tier-yaml/baseline/settings.expected.json` |

## Non-functional bounds (metadata table)

| Bound | Value |
|---|---|
| Decision availability | fail closed on parse/validation errors |
| Drift detection | baseline check returns non-zero when generated output differs |
| Scope | v0 generates Claude permissions only |

## Versioning policy

- `0.x`: tier schema and generator behavior may evolve while experimental.
- `1.0`: requires stable schema guarantees and migration guidance.
