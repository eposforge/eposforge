---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 10: Inference Layer

## Purpose

Provides language-model and other inference capabilities to Adapters
that need them — primarily Dev Products and the Router, but also any
component performing semantic reasoning. The Inference Layer abstracts
away whether a model runs locally or at a vendor, what privacy posture
applies, and how cost is metered.

A factory with mixed privacy needs almost always installs multiple
Inference Adapters (e.g., one frontier vendor for general work, one
local model for privacy-sensitive workloads).

## Contract

Any Adapter for this slot must:

- Accept inference requests with: model class, max tokens, temperature
  / sampling controls, prompt, optional tool definitions, optional
  streaming flag, declared privacy posture.
- Route the request to the appropriate underlying provider (vendor API
  or local engine).
- Refuse requests whose declared privacy posture exceeds what the
  Adapter can provide (e.g., a `privacy: local` request must not be
  served by a vendor API).
- Report token / time / cost metrics back to Audit & Observability for
  every call.
- Expose model capabilities (context window, tool calling, vision,
  reasoning, etc.) so the Router can pick appropriately.
- Read API credentials only via the Secrets & Key Management slot.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `provider` — vendor name or "local."
- `models` — list of model identifiers the Adapter can serve.
- `max_context_tokens` — per-model.
- `tool_calling` — boolean per model.
- `streaming` — boolean.
- `cost_metering` — how cost is reported (per-token, per-request,
  flat-rate, n/a for local).

## Boundaries

- **Is:** the slot for model inference.
- **Is not:** the Dev Product slot. A Dev Product may consume inference
  via this layer; the Inference Layer itself does not author artifacts.
- **Is not:** an embedding store. Embeddings produced by inference are
  consumed by other components (e.g., Spec Graph if that Adapter uses
  vector search).

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog (Anthropic,
OpenAI, xAI, Azure OpenAI, Ollama, vLLM, llama.cpp, etc.).

