---
doc_kind: operator-runbook
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Azure Foundry Routing Profile (EF-017)

This document defines the Component 10 mechanism for routing Cognee LLM and
embedding calls through Azure AI Foundry via LiteLLM-compatible model strings.

## Contract

- Provider selection is config-driven.
- Azure routing profile uses:
  - `AZURE_API_BASE`
  - `AZURE_API_KEY`
  - `AZURE_API_VERSION`
- When provider is Azure, model identifiers use:
  - `azure/<deployment-name>`

## Provider-selectable config shape

Use a provider selector in runtime config (env file, secrets-managed env, or
equivalent host config), for example:

```env
INFERENCE_PROVIDER=azure-foundry
LLM_MODEL=azure/<deployment-name-for-completion>
EMBEDDING_MODEL=azure/<deployment-name-for-embedding>
AZURE_API_BASE=https://<your-foundry-endpoint>
AZURE_API_KEY=<managed-secret>
AZURE_API_VERSION=<api-version>
```

Alternative providers remain valid (`anthropic`, `openai`) and are selected by
setting `INFERENCE_PROVIDER` accordingly.

## Validation helper

Run the profile validator:

```bash
bash instance/installed/10-inference/scripts/validate-azure-routing-config.sh \
  --provider azure-foundry \
  --llm-model "azure/<deployment-name-for-completion>" \
  --embedding-model "azure/<deployment-name-for-embedding>"
```

The validator confirms model naming and required Azure env bindings for Azure
profile selection.

## Cost-gate note

This is mechanism-only work in this repo. Full-corpus or full re-graph
verification against Foundry remains gated by the cost-control dependency chain.
