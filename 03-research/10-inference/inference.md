# Inference — Implementation Catalog

> **Snapshot date:** 2026-04. Pricing, model availability, and
> privacy postures change frequently. Verify current details before
> committing.

Candidate Adapters for the Inference slot
([../01-architecture/02-components/10-inference.md](../01-architecture/02-components/10-inference.md)).
An Inference Adapter serves language-model (and related) inference
to Adapters that need it — primarily Dev Products and the Router.
Most factories install **multiple** Inference Adapters and pick per
request based on privacy and cost.

This catalog is **not exhaustive** and **not an endorsement**.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — vendor API, local engine, hosted self-managed.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Privacy posture** — `local`, `vendor-no-training`, or
  `vendor-default` (best-effort summary; verify with the vendor).
- **Capabilities** — context window, tool calling, vision,
  reasoning modes.
- **Notes** — anything notable for Adapter authors.

---

## Vendor APIs

### Anthropic (Claude)

- **Type:** vendor API.
- **Cost tier:** consumer-paid; commercial / enterprise tiers.
- **Privacy posture:** `vendor-no-training` on commercial /
  enterprise plans by default; consumer plans require opt-out.
- **Capabilities:** strong reasoning, large context, mature tool
  calling, prompt caching, vision.
- **Notes:** common default for the Router and for general-purpose
  Dev Product inference. Adapter consumes the Anthropic SDK; reads
  API key via Secrets & Key Management.

### OpenAI

- **Type:** vendor API.
- **Cost tier:** consumer-paid; commercial / enterprise tiers.
- **Privacy posture:** `vendor-no-training` on API by default;
  ChatGPT plans separate.
- **Capabilities:** broad model line-up (frontier reasoning, fast,
  vision); tool calling; structured outputs; assistants API.
- **Notes:** strong fit when the operator wants access to OpenAI's
  specific model capabilities or Codex-family workflows.

### xAI (Grok)

- **Type:** vendor API.
- **Cost tier:** consumer-paid.
- **Privacy posture:** `vendor-default` (verify current ToS); paid
  tiers generally do not train.
- **Capabilities:** real-time web search, large context, fast
  responses; useful for enrichment / research workloads.
- **Notes:** good fit for Dev Products doing data enrichment over
  current web content (e.g., job listing context, company research).

### Azure OpenAI

- **Type:** Microsoft-hosted OpenAI models with enterprise
  controls.
- **Cost tier:** commercial.
- **Privacy posture:** `vendor-no-training` by contract; data
  residency controls.
- **Capabilities:** OpenAI model line-up plus Azure-side IAM, VNet
  integration, content filtering.
- **Notes:** appropriate when the operator needs Microsoft-stack
  alignment or Azure data-residency guarantees.

---

## Local engines

### Ollama

- **Type:** local model runtime.
- **Cost tier:** free OSS.
- **Privacy posture:** `local` — never leaves the host.
- **Capabilities:** simple model pull / serve workflow, broad open-
  weight model support, OpenAI-compatible API surface.
- **Notes:** common choice for instances bootstrapping local
  inference quickly. Adapter exposes Ollama's HTTP API; declares
  `provider: local`.

### vLLM

- **Type:** high-throughput local inference engine.
- **Cost tier:** free OSS.
- **Privacy posture:** `local`.
- **Capabilities:** GPU-optimized batched inference, paged attention,
  large concurrent request volume.
- **Notes:** stronger fit than Ollama for instances running a
  dedicated inference server with multiple concurrent agents. Adapter
  exposes vLLM's OpenAI-compatible endpoint.

### llama.cpp

- **Type:** CPU- and GPU-capable local inference runtime.
- **Cost tier:** free OSS.
- **Privacy posture:** `local`.
- **Capabilities:** runs quantized models on modest hardware;
  embedded use cases.
- **Notes:** option for instances with constrained hardware budgets
  or edge deployments.

---

## Mixed-provider posture

Factories typically install at least:

- One **frontier vendor** Adapter (Anthropic / OpenAI / xAI) for
  general work.
- One **local** Adapter (Ollama / vLLM) for privacy-sensitive
  workloads (declared `privacy: local` in the Spec Input).

The Inference slot's contract requires that requests with declared
privacy posture are routed only to Adapters that can honor it —
the multi-Adapter posture is what makes this enforceable.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
with declared cost metering and explicit support for the slot's
privacy-routing contract.
