---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Azure AI Content Safety Adapter

This adapter implements Component 14 (Content Safety) using Azure AI Content Safety.

## Adapter Metadata

| Field | Value |
|---|---|
| `name` | `azure-ai-content-safety` |
| `component` | `content-safety` |
| `version` | `0.1.0` |
| `privacy_posture` | `vendor-api` |
| `cost_hint` | Metered per text/image unit |
| `capabilities` | text-analysis, image-analysis, prompt-shield, jailbreak-detection, pii-detection |
| `invocation_surface` | HTTP REST API / SDK invoked by Orchestrator / Tool Transport |
| `status` | `experimental` |
| `decision_latency_target` | < 500ms |
| `supported_action_set` | `{log, warn, block, escalate}` |
| `ring_aware_policy_refs` | Development uses `{log, warn}`, Production enforces `{block, escalate}` for severity > low |

## Configuration & Endpoint

The adapter requires the following configuration injected at runtime:
- `AZURE_CONTENT_SAFETY_ENDPOINT`: The Azure resource endpoint.
- `AZURE_CONTENT_SAFETY_KEY`: The API key (stored securely, not in plaintext).

## Category Mapping & Actions

Azure AI Content Safety categorizes harmful content into Hate, Sexual, Violence, and Self-Harm, each scored on a severity scale (0-7).
The adapter maps these severities to the C14 action set:
- **0-1 (Safe)**: No action.
- **2-3 (Low)**: `log` (record the event, allow payload).
- **4-5 (Medium)**: `warn` (allow payload but inject a warning to the user/agent).
- **6-7 (High)**: `block` (reject the payload, fail the tool call or prompt).
- **Prompt Shield (Jailbreak/Injection)**: Automatically `block` and `escalate`.

## Fail-Closed & Audit Emission

- **Fail-Closed**: If the Azure endpoint times out or returns a 5xx error, the adapter returns `block` to ensure no unchecked payload passes.
- **Audit Emission**: Every decision (including `log` and `warn` levels, and timeouts) emits a standardized audit event to Component 11 (Audit & Observability).
