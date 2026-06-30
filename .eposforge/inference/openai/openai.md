---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---
# Installed Adapter: openai -> Inference (Component 10)

> Living Spec for this repo's indexing-time embedding adapter.
| `status` | `approved` |
> Slot contract: [../../../01-architecture/02-components/inference.md](../../../01-architecture/02-components/inference.md)

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `openai` |
| `component` | `inference` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `vendor-default` |
| `cost_hint` | `metered` |
| `capabilities` | `embedding-generation` |
| `invocation_surface` | GraphRAG pipeline config |

### Inference required fields

| Field | Value |
|---|---|
| `model_classes` | embedding |
| `selection_policy` | fixed default in settings file |
| `fallback_strategy` | none in v1 |
| `prompt_control` | n/a (embedding model, no prompts) |

### Repo-specific fields

| Field | Value |
|---|---|
| `embedding_model` | `text-embedding-3-small` |
| `api_bindings` | `OPENAI_API_KEY` |
| `component11_event_emitter` | `.eposforge/inference/scripts/emit-token-usage-event.sh` |
| `component11_event_type` | `adapter.invoked` |
| `component11_event_payload_fields` | `repo`, `dataset`, `phase` (`extract`\|`embed`\|`cognify`), `model`, `prompt_tokens`, `completion_tokens`, `total_tokens`, `latency_ms` |
| `provider_select_config` | `INFERENCE_PROVIDER` profile selection (`anthropic`\|`openai`\|`azure-foundry`) |
| `azure_route_contract` | `.eposforge/inference/azure-foundry-routing.md` |
| `azure_route_validator` | `.eposforge/inference/scripts/validate-azure-routing-config.sh` |
| `budget_policy_file` | `.eposforge/inference/budget-policy.json` |
| `budget_preflight_gate` | `.eposforge/inference/scripts/check-budget-gate.sh` |
| `budget_counter_updater` | `.eposforge/inference/scripts/record-budget-usage.sh` |
| `budget_contract` | `.eposforge/inference/budget-enforcement.md` |

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| No automatic failover | Rebuild fails if provider is unavailable | Add fallback model profiles in settings |
| Privacy posture is vendor-default | Not suitable for some private corpora | Add local embedding adapter (for example Ollama + nomic-embed-text) |
