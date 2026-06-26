---
doc_kind: architecture-concept
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Stabilization & Kernels

## Purpose

A EposForge factory is a system that builds and improves systems —
including itself. That makes it acutely vulnerable to a failure mode that
ordinary software escapes: it can be asked to operate *on top of itself*
before any part of itself is solid. The symptom is a grind — using a
not-yet-working tool to fix a not-yet-working tool — where effort
compounds into entropy instead of into capability.

This document names the primitive that prevents the grind: the
**kernel**, and the **bootstrap order** that says what may be built on
what. It answers a question the maturity model and release rings do *not*
answer. Those govern *"is this product good enough to ship?"* The kernel
concept governs a prior question: *"what is solid enough to build ON?"*

> This is a **stabilization** view. It is distinct from, and must not be
> confused with, the **functional** decomposition in
> [01-reference-architecture.md](./01-reference-architecture.md) (the
> Logical Tiers — Operator / Factory / Substrate / External). The
> functional view answers *"what role does this play?"*; the stabilization
> view answers *"what has to be solid before what?"* An element has a
> place in both, and the two places are related but not identical.

## What makes something a kernel

A kernel needs **two** properties, not one:

1. **Stable** — pinned, frozen, or source-controlled. It does not change
   under you.
2. **Detectable** — you can confirm it is still good in **one command** (a
   smoke test or a hard gate).

Stability without detection is only *"code you haven't broken yet."* The
property that is almost always missing is detection, not stability — and
detection is the half that does the work (see
[Detection is the negentropy input](#detection-is-the-negentropy-input)).

This yields three states an element can be in:

| State | Stable? | Detectable? | Meaning |
|---|---|---|---|
| **Kernel** | yes | yes (one command) | Trustworthy foundation. Build on it. |
| **Candidate kernel** | yes | partial / just added | On its way; do not yet treat as solid. |
| **Not a kernel** | no | — | Fast-moving / in active development. MUST NOT be built upon as if solid. |

Kernel state is **the maturity model applied to substrate**, not a new
vocabulary. The promotion gate from candidate to kernel is exactly one
event: *detection was added.* Treat candidate→kernel the way the rest of
the pattern treats a maturity tag — see
[Reconciliation: two axes, not four](#reconciliation-two-axes-not-four).

## The External tier is never a kernel

Elements in the **External tier** — frontier-model and vendor APIs — are
**inherently un-kernelable**. They change under you on the vendor's
schedule (model auto-migrations, deprecations, silent behavior shifts) and
cannot be pinned. They therefore can never satisfy property 1, and no
amount of detection promotes them. They must be wrapped by the Inference
Layer / Adapters, each carrying *its own* detection, and must never be
trusted as foundation. An Adapter over an un-kernelable dependency can
itself become a candidate kernel — the Adapter is stable and detectable
even though the thing behind it is not.

## The bootstrap rule

> **Trust autonomy upward only.** A layer's autonomy may be trusted only
> once the layers beneath it are kernels.

This is **Gall's Law** operationalized:

> A complex system that works is invariably found to have evolved from a
> simple system that worked. A complex system designed from scratch never
> works and cannot be patched into working. — John Gall, *Systemantics*

A kernel *is* the "simple system that worked" that Gall says you must grow
from. The grind is the Gall failure mode exactly: building a factory's
autonomy from scratch, over a substrate that was never a working-simple
system. So the rule is not a style preference — it is the only known way a
complex self-improving system reaches "works."

Note the rule governs **trusting autonomy**, not **adding detection**. You
may — and should — add detection to *any* layer at any time, including
layers whose autonomy you do not yet trust. This asymmetry is the whole
move, and it is spelled out as Loop A vs Loop B in
[03-autonomy-modes.md](./03-autonomy-modes.md#two-loops-autonomy-vs-self-detection).

## Detection is the negentropy input

> A system in active use undergoes continuing change and increasing
> complexity; complexity rises unless deliberate work is spent reducing
> it. — Lehman's Laws of Software Evolution

Lehman says entropy is inevitable in any layer still in use. So a kernel
is **not "frozen and forgotten" — it is "frozen AND continuously
verified."** The detection half (the one-command smoke / hard gate) is the
"deliberate work" Lehman requires: it is the negentropy input that *keeps*
a kernel a kernel. Detection converts Lehman's silent decay into a caught,
bounded event — drift trips a red gate instead of leaking upward
unnoticed. Without kernels, every layer is subject to Lehman drift at
once; that simultaneity *is* the grind.

The standard
[09-paired-detection](../04-standards/09-paired-detection/paired-detection.md)
turns this into a working habit: every fix ships the cheap, re-runnable
check that proves it.

## The synthesis

The two laws govern two different axes, and the kernel is the unit both
point at.

| | Gall's Law | Lehman's Laws |
|---|---|---|
| Axis | construction order (space) | maintenance (time) |
| Says about a kernel | *start from it* | *keep verifying it* |
| Maps to | the bootstrap order | the per-layer detection ratchet |
| Failure mode it names | autonomy built from scratch (the grind's cause) | entropy leaking in unnoticed (the grind's persistence) |

A layer becomes a kernel when it satisfies both laws at once: it was
*grown from a working simpler layer* (Gall — stability-in-order) **and**
it is *held stable by continuous detection* (Lehman — detectability). That
two-law test is identical to the two-property definition above. Kernels
are where construction order and maintenance energy meet.

## Reconciliation: two axes, not four

A factory already carries several ways to talk about "how solid is this?":
the Logical Tiers, the maturity model, and release rings. Adding "kernels"
must **reduce** that vocabulary, not grow it. Net it to exactly **two
orthogonal axes**:

- **Foundation-trust** — *what may I build on?* Governed by **kernel state
  + the bootstrap order**. Applies to the substrate and control layers.
- **Product-promotion** — *is this artifact safe to ship?* Governed by the
  **maturity model + release rings**. Applies to the products the factory
  builds.

These are independent. A product moving alpha→beta→GA on the
product-promotion axis is a different question from whether the substrate
it runs on is a kernel. Quality of a shipped product is controlled by
rings and feedback-minted checks, not by being frozen; trust in a
foundation is controlled by kernels, not by ring promotion.

Two guardrails keep this from becoming a fourth taxonomy:

1. **Kernel state reuses the maturity model.** candidate→kernel is a
   maturity transition gated on "detection added," not a parallel concept
   tree. Do not invent new lifecycle words for it.
2. **Any layer numbering is a derived view, not a second axis.** An
   instance may find it useful to number its stabilization layers
   (L0 host → upward) to express bootstrap order concretely. That
   numbering is an *instance artifact* and a *projection* of the bootstrap
   rule — it is **not** a second mandatory classification stacked on top of
   the Logical Tiers, and an element's layer number is not a property the
   pattern requires every component to carry.

If promoting this concept ever adds a third overlapping stabilization
story instead of slotting into these two axes, it has increased
documentation entropy — which would be self-refuting for a doctrine about
fighting entropy.

## Instance responsibilities

This document is the pattern. An instance applies it by:

- Identifying which of *its* elements are kernels, candidates, and
  not-kernels (a host-specific map — an instance artifact, not part of this
  pattern).
- Expressing its bootstrap order concretely (optionally as numbered
  stabilization layers).
- Standing up one detection ratchet per layer per
  [09-paired-detection](../04-standards/09-paired-detection/paired-detection.md).

Keep that map at the instance's adoption layer. It will name concrete
hosts, containers, and services — none of which belong in this pattern
document.

## Related

- [03-autonomy-modes.md](./03-autonomy-modes.md) — Loop A (autonomy,
  bootstrap-gated) vs Loop B (detection, allowed now); the autonomy
  progression the bootstrap rule governs.
- [09-paired-detection](../04-standards/09-paired-detection/paired-detection.md)
  — the habit that mints and keeps the detection half.
- [01-reference-architecture.md](./01-reference-architecture.md) — the
  functional Logical Tiers this stabilization view is distinct from.
- [02-components/09-source-control-ci.md](./02-components/09-source-control-ci.md),
  [02-components/11-audit-observability.md](./02-components/11-audit-observability.md)
  — where one-command gates run and where their results are recorded.
