# Plan: Living Spec `operating_inference` (EF-089)

**Date:** 2026-09-07
**Status:** Open; follows EF-088
**Tracking:** EF-089
**Related:** EF-088 (the standard that justifies the field), EF-090 (gate G4), `.eposforge/inference/budget-enforcement.md`

## The field

Grain is the Living Spec grain: one Product, or one platform capability. **Not every script.**

| Field | Values | Rule |
|---|---|---|
| `operating_inference` | `none` \| `on-demand-judgment` \| `continuous-loop` | Required |
| `operating_inference_reason` | prose | Required when `continuous-loop` |
| `operating_inference_budget` | pointer to a budget policy + envelope | Required when `continuous-loop`; recommended when `on-demand-judgment` |

Added to the Living Spec contract (`01-architecture/02-components/living-spec.md`) and to the
required Adapter metadata where the Adapter *is* the capability, alongside `privacy_posture`,
`cost_hint` and `invocation_surface`.

## Meanings, so the enum is not overloaded

- **`none`** — a program holds the path; no model is consulted to *operate* the procedure. A
  program may still *call* a model as a library (an embedding API inside a batch job, say) when
  that call is bounded, deterministic in role, and budgeted elsewhere. When the call is
  load-bearing, prefer `on-demand-judgment`.
- **`on-demand-judgment`** — a program holds the path and occasionally asks a model for a
  judgment; or a skill wraps a program and the *choice of path* is the judgment. Budget the
  calls.
- **`continuous-loop`** — an agent stays in the loop as the operating path. Allowed only with a
  written reason a program cannot hold the path, plus a budget. Missing reason or budget fails
  the check.

No fourth value for batch or index jobs. Add one only when two such jobs genuinely need to look
different.

## Dogfood declarations

| Subject | Value | Why |
|---|---|---|
| Spec Graph capability (`.eposforge/SPEC.md`) | `on-demand-judgment` | Extraction and cognify are load-bearing inference, but a program still holds the path. The full-rebuild embedding-token envelope is already documented; point the budget field at it. |
| File-based backlog (`file-based-backlog.md`) | `none` | Lint, aggregate and sweep are deterministic. Revisit only if a view grows judgment. |

`continuous-loop` is deliberately *not* used here. An agent that "keeps recalling until the
graph looks right" as the operating path would need a written reason a program cannot hold it,
and should be refused rather than declared.

## Enforcement wiring

A `continuous-loop` capability that cannot name a budget policy is non-conformant. Point the
budget field at the existing inference budget enforcement and its gate, and at the token-usage
events; do not build a second budgeting mechanism.

## Scan-set discipline (matters for EF-090's G4)

v1 is the **two-file allowlist above and nothing else**. Do not grep for the words "Living
Spec": many adapter documents use the phrase and carry a reference-implementation doc kind, so
a prose search would sweep in files this contract does not govern. Expansion waits for a
machine-readable marker — a dedicated `doc_kind`, or an explicit registry list — and should not
happen at all until the two-file check is actually failing in CI. Adopter overlays adopt the
field opportunistically as files are touched, after they opt into the marker.

## Observability

The missing field *is* the signal. Counting capabilities by enum is a later dashboard, not a v1
requirement. A `continuous-loop` without a budget is a CI failure, not a page.
