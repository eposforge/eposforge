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

## Live findings — fp-llm-gateway (verified 2026-05-25)

`fp-llm-gateway` is an Azure AI **Services/Foundry** account (RG `internal`,
sub `7016b2fe-…`) hosting multiple model families on **different API surfaces at
different hosts**. Hitting the wrong host or an unsupported api-version returns a
generic `404 {"code":"404","message":"Resource not found"}` (not a helpful
"deployment not found"), which makes this easy to misdiagnose.

| Model family | API surface | Host | Call shape |
|---|---|---|---|
| OpenAI (gpt-4.1, gpt-4.1-mini, text-embedding-3-large) | Azure OpenAI API | `https://fp-llm-gateway.openai.azure.com/` | `/openai/deployments/<deployment>/chat/completions?api-version=…` — deployment in URL |
| xAI (Grok), Anthropic (Claude), Mistral, Cohere | Azure AI Model Inference (MaaS) | `https://fp-llm-gateway.services.ai.azure.com/` | `/models/chat/completions?api-version=…` — model in request **body** |
| Vision / Language / Content Safety / etc. | classic Cognitive Services | `https://fp-llm-gateway.cognitiveservices.azure.com/` | per-service |

**cognee uses `LLM_PROVIDER=azure` → the OpenAI SDK → the Azure OpenAI surface**,
so it can only call OpenAI-family deployments on the `openai.azure.com` host.

Working cognee config (managed identity):

- `LLM_ENDPOINT=https://fp-llm-gateway.openai.azure.com/` — **not** the
  `cognitiveservices.azure.com` host (that serves Vision/Language/etc. and 404s
  for `/openai`).
- `LLM_API_VERSION=2024-12-01-preview` — the GA `2024-10-01` **404s** for the
  gpt-4.1 family; `>= 2024-12-01-preview` works.
- `LLM_AZURE_USE_MANAGED_IDENTITY=true` + `AZURE_CLIENT_ID/SECRET/TENANT_ID`;
  cognee's `AzureOpenAIAdapter` builds a native `AzureOpenAI` client with a
  `DefaultAzureCredential` bearer-token provider (scope
  `https://cognitiveservices.azure.com/.default`).
- The runtime SP needs **Cognitive Services OpenAI User** on the account.

**Using a non-OpenAI family (Grok/Claude) is a bigger lift**, requiring both:
(1) the MaaS data action
`Microsoft.CognitiveServices/accounts/MaaS/chat/completions/action` (granted by
e.g. *Azure AI Developer* / *Cognitive Services User* — the *OpenAI User* role
does **not** grant it, which is why `/models` returns 401); and (2) a different
cognee routing path (LiteLLM `azure_ai/<deployment>` against
`services.ai.azure.com`), since `AzureOpenAIAdapter` cannot call the Inference
API. Managed-identity token flow through that litellm path is unverified.

**Embedding-store / re-graph note:** changing `EMBEDDING_MODEL` changes vector
dimensionality (old `text-embedding-3-large` = 3072-dim; current fastembed
`BAAI/bge-small-en-v1.5` = 384-dim). cognify then fails with a LanceDB
`fixed_size_list[3072]` vs `dim=384` mismatch (`RuntimeError: lance error …`).
**Reset the LanceDB vector store before re-graphing after any embedding-model
change** so the tables are recreated at the new dimension.
