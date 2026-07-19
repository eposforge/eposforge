---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 14: Content Safety

## Purpose

Provides runtime guardrails for the agentic factory. While Component 8 (Agent Policy)
authorizes *actions* (e.g. "can this agent write to the production database?"),
Component 14 inspects the *content* of payloads passing through the system.

It is responsible for:
- **Input safety**: detecting prompt-injection, jailbreak attempts, or data exfiltration in prompts.
- **Output safety**: harmful content classification, PII / secret leak prevention in model outputs.
- **Tool-call argument inspection**: content-level validation orthogonal to C8 tier checks (e.g. validating that a shell command doesn't contain malicious payloads).

## Contract

Any Adapter for this slot must:

- Provide a **decision API** consumed by the Orchestrator (C4), Tool Transport (C3), and optionally Dev Product (C5).
- Return one of the following decisions on every inspection: `{log, warn, block, escalate}`.
- Implement **fail-closed semantics**: if the content safety adapter is unreachable or errors, the caller must treat the payload as blocked.
- Maintain **deployment-ring awareness** mirroring C8 (e.g., policies may be looser in local development and strictly blocking in production).
- Emit a Component 11 (Audit & Observability) event for every C14 decision made.

## Required Adapter metadata

In addition to the universal fields in `../00-adapter-pattern/adapter-pattern.md`:

- `decision_latency_target` — max milliseconds the engine should take to evaluate a payload.
- `supported_action_set` — the subset of `{log, warn, block, escalate}` the adapter supports.
- `ring_aware_policy_refs` — how the adapter links its safety thresholds to deployment rings.

## Boundaries

- **Is:** the runtime content-safety enforcement point.
- **Is not:** Agent Policy (C8). C8 makes permission decisions on actions; C14 inspects payload content.
- **Is not:** Audit & Observability (C11). C11 observes and records; C14 actively blocks or warns.

## Reference implementations

See `../../03-research/01-architecture/02-components/14-content-safety/content-safety.md` for the catalog (Llama Guard, NeMo Guardrails, Azure AI Content Safety, Lakera, PromptArmor, etc.).
