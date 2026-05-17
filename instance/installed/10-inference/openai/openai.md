---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---
# Installed Adapter: openai -> Inference (Component 10)

> Living Spec for this repo's indexing-time embedding adapter.
| `status` | `approved` |
> Slot contract: [../../../../01-architecture/02-components/10-inference.md](../../../../01-architecture/02-components/10-inference.md)

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `openai` |
| `component` | `10-inference` |
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

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| No automatic failover | Rebuild fails if provider is unavailable | Add fallback model profiles in settings |
| Privacy posture is vendor-default | Not suitable for some private corpora | Add local embedding adapter (for example Ollama + nomic-embed-text) |
