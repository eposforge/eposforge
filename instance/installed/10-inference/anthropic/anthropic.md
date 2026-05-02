---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: anthropic -> Inference (Component 10)

> Living Spec for this repo's indexing-time completion adapter.
> Slot contract: [../../../../01-architecture/02-components/10-inference.md](../../../../01-architecture/02-components/10-inference.md)

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `anthropic` |
| `component` | `10-inference` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `vendor-default` |
| `cost_hint` | `metered` |
| `capabilities` | `text-extraction`, `entity-generation` |
| `invocation_surface` | GraphRAG pipeline config, Cognee pipeline config |

### Inference required fields

| Field | Value |
|---|---|
| `model_classes` | completion |
| `selection_policy` | fixed default in settings file |
| `fallback_strategy` | none in v1 |
| `prompt_control` | GraphRAG: prompt files under `instance/installed/06-spec-graph/graphrag/prompts/`; Cognee: none (structured extraction built-in) |

### Repo-specific fields

| Field | Value |
|---|---|
| `completion_model` | GraphRAG: `claude-sonnet-4-6`; Cognee: `claude-haiku-3-5-20241022` (default, overridable via `LLM_MODEL`) |
| `api_bindings` | `ANTHROPIC_API_KEY` |

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| No automatic failover | Rebuild fails if provider is unavailable | Add fallback model profiles in settings |
| Privacy posture is vendor-default | Not suitable for some private corpora | Add local inference adapter (for example Ollama) |
