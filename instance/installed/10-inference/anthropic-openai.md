---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: anthropic-extraction-plus-openai-embeddings -> Inference (Component 10)

> Living Spec for this repo's indexing-time inference adapter pair.
> Slot contract: [../../../01-architecture/02-components/10-inference.md](../../../01-architecture/02-components/10-inference.md)

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `anthropic-extraction-plus-openai-embeddings` |
| `component` | `10-inference` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `vendor-default` |
| `cost_hint` | `metered` |
| `capabilities` | `text-extraction`, `entity-generation`, `embedding-generation` |
| `invocation_surface` | GraphRAG pipeline config |

### Inference required fields

| Field | Value |
|---|---|
| `model_classes` | completion + embedding |
| `selection_policy` | fixed defaults in settings file |
| `fallback_strategy` | none in v1 |
| `prompt_control` | prompt files under `instance/installed/06-spec-graph/prompts/` |

### Repo-specific fields

| Field | Value |
|---|---|
| `completion_model` | `claude-sonnet-4-6` |
| `embedding_model` | `text-embedding-3-small` |
| `settings_file` | `instance/installed/06-spec-graph/settings.yaml` |
| `api_bindings` | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` |

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| No automatic failover between providers | Rebuild fails if either provider is unavailable | Add fallback model profiles in settings |
| Privacy posture is vendor-default | Not suitable for some private corpora | Add local inference adapter (for example Ollama) |
