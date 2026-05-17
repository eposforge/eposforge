---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Adoption Strategies — Survey

> **Snapshot date:** 2026-05. AI mass-transformation tooling is an
> active variable in this analysis. Update or retire when stale.

Brownfield instances adopting eposforge, or advancing between phases
within it, face a choice of migration strategy. This survey is
non-normative; the default is named in
[02-roadmap/adoption-strategy.md](../02-roadmap/adoption-strategy.md).

---

## Comparison dimensions

| Dimension | What it measures |
|---|---|
| **Cutover risk** | How much breaks if the strategy goes wrong at the moment of switchover. |
| **Throughput cost** | How much ongoing feature/bug work slows during the migration. |
| **Rollback** | How easy it is to revert if the new shape turns out wrong. |
| **Discipline required** | How much organizational follow-through is needed for the strategy to actually complete. |
| **AI-tool leverage** | Whether AI mass-transformation tools (Blitzy and equivalents) materially reduce the cost. |

---

## Strategies

### 1. Opportunistic alignment / strangler fig — *default*

Backlog work is delivered against the target shape as it passes
through. Legacy and target coexist until the migration finishes.

- **Cutover risk:** very low (no cutover; gradual replacement).
- **Throughput cost:** low (work was going to happen anyway).
- **Rollback:** trivial per change.
- **Discipline required:** **high** — without active management,
  drifts into permanent inconsistency.
- **AI-tool leverage:** modest (per-touch transformation help).

### 2. Big-bang rewrite

A bounded corpus is rewritten in a single coordinated effort and
cut over.

- **Cutover risk:** very high.
- **Throughput cost:** high during the rewrite; zero after.
- **Rollback:** all-or-nothing.
- **Discipline required:** moderate (mostly project-managed).
- **AI-tool leverage:** **very high.** Tools like Blitzy decouple
  human effort from codebase size, so the historical "big-bang is
  impossibly expensive" objection weakens substantially. What
  remains — verification, cutover risk, business continuity — is
  exactly what an eposforge instance at Phase 0+ already invests
  in. This is the strategy whose cost curve has shifted most
  recently; see [How AI tools change the menu](#how-ai-mass-transformation-tools-change-the-menu).

### 3. Branch by abstraction

An abstraction layer is introduced between callers and the
implementation. The implementation is swapped under the abstraction;
callers are unaffected.

- **Cutover risk:** low.
- **Throughput cost:** moderate (the abstraction must be built first).
- **Rollback:** swap back to the legacy implementation.
- **Discipline required:** moderate.
- **AI-tool leverage:** moderate (tooling helps build the abstraction
  and migrate callers).

### 4. Parallel run / dual-write

Legacy and target operate side by side. Outputs are compared. Cut
over once parity is observed.

- **Cutover risk:** very low (parity-verified).
- **Throughput cost:** **high** during parallel period (double-write,
  reconciliation).
- **Rollback:** trivial during parallel period.
- **Discipline required:** high (someone must close the gap, not run
  in parallel forever).
- **AI-tool leverage:** moderate.

### 5. Walking skeleton / tracer bullet

Build a minimal end-to-end slice of the target architecture first.
Expand outward.

- **Cutover risk:** low for the slice; deferred for the rest.
- **Throughput cost:** moderate.
- **Rollback:** abandon the slice.
- **Discipline required:** moderate.
- **AI-tool leverage:** low at first; rises once the slice
  establishes the pattern and replication takes over.

### 6. Greenfield carve-out

One new feature is delivered fully on the target architecture as a
beachhead. The legacy is left alone until the beachhead proves
itself.

- **Cutover risk:** isolated to the new feature.
- **Throughput cost:** low (new work either way).
- **Rollback:** abandon the feature.
- **Discipline required:** moderate — the beachhead must actually
  expand, not become a permanent island.
- **AI-tool leverage:** low for the beachhead, higher when it
  expands.

### 7. Sunset with hard dates

Set a deadline. Block new work on the legacy shape after a stated
date. Escalate enforcement (warnings → CI errors → removal) over
time.

- **Cutover risk:** moderate (enforcement-driven).
- **Throughput cost:** depends on how much work moves into
  pre-deadline panic.
- **Rollback:** push the deadline.
- **Discipline required:** moderate-to-high (enforcing the date).
- **AI-tool leverage:** rises sharply as the deadline approaches.

---

## How AI mass-transformation tools change the menu

Tools such as Blitzy plan and execute large-scale code
transformations across legacy corpora with AI agents, decoupling
human effort from codebase size. This shifts the calculus in two
ways:

1. **Big-bang becomes more viable.** The historically dominant cost
   of big-bang — human effort scaling with code volume — collapses.
   The remaining real costs are verification, cutover risk, and
   business continuity, and these are exactly what an eposforge
   instance at Phase 0+ already invests in.
2. **Opportunistic alignment amortizes faster.** Per-touch
   transformation help reduces the per-PR cost of the default
   strategy. Larger chunks become routinely affordable during normal
   backlog work, shifting the balance-management decision
   (obligation 4 in the default strategy) toward bigger bounded
   batches.

This is an active variable. Restate the comparison when significant
tooling shifts arrive.
