---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Product Factory — Maturity Phases

The Product Factory is the side of a dark factory that authors
software (and, eventually, other artifacts) from declarative specs. It
matures along six phases (A–F). At Phase F, the factory operates at
"Level 5": specs in, production artifacts out, with humans approving
outcomes rather than diffs.

This roadmap is **generic**. Instances declare their own component
Adapters and adopt phases at their own pace. Phases ship independently
— value at every phase, not only at the end.

---

## Phase A — Adapter Foundation

**Goal:** decide which Adapters fill which component slots, and
ratify their metadata.

By the end of Phase A:

- For each of the twelve components, the operator has either:
  - selected an Adapter and registered its metadata, or
  - explicitly declared the component as "deferred until later phase"
    with a reason.
- An ADR records the routing policy: privacy posture, cost ceiling,
  capability requirements, soft preferences.
- The Adapter set is queryable (the emergent registry described in
  [../01-architecture/00-adapter-pattern.md](../01-architecture/00-adapter-pattern.md)).

**Risk:** low. Documentation and decisions, not code.

---

## Phase B — Tool Transport Foundation

**Goal:** the Tool Transport Adapter is operational and at least two
Dev Product Adapters can perform real work through it.

By the end of Phase B:

- The Tool Transport (component 5) exposes the required minimum
  capability set: git, fs, shell, graph-query, browser, http.
- At least two Dev Product Adapters are installed and can complete a
  non-trivial task using only the Tool Transport — no back doors.
- Each capability has a Living Spec describing its observable
  behavior.

**Risk:** medium. Tool transport ecosystems are still maturing;
reference implementations may need extension.

---

## Phase C — Living Spec Rollout

**Goal:** every factory deliverable has a Living Spec; paired-change
enforcement is active.

By the end of Phase C:

- Every existing factory deliverable has a `SPEC.md` (or whatever
  format the Living Spec Adapter declares), backfilled from existing
  documentation where needed.
- New deliverables ship with a Living Spec from commit 1.
- Source Control + CI (component 9) enforces the paired-change check.
  Soft warning at first, hard fail within two weeks.

**Risk:** low-medium. Paired-change enforcement surfaces sloppy
commit habits — expect a week of friction.

---

## Phase D — Router v0

**Goal:** the Router can take a Spec Input and dispatch one sub-task
to a chosen Dev Product Adapter, end-to-end.

By the end of Phase D:

- The Router (component 4) accepts normalized Spec Input output and
  produces a sub-task descriptor.
- The Router selects a Dev Product Adapter using metadata + Agent
  Policy.
- The Router dispatches via Tool Transport in an Execution Sandbox.
- The Router opens a PR with the resulting change and the paired
  Living Spec update.
- An end-to-end demo: spec → Router → Dev Product → MCP-driven (or
  other transport-driven) edit → PR → human merges.

**Risk:** high. Decomposition quality is the core unknown; start with
single-task dispatch before attempting sub-task splitting.

---

## Phase E — Spec Graph

**Goal:** the Spec Graph is operational; the Router consults it
during decomposition and Adapter selection.

By the end of Phase E:

- The Spec Graph Adapter (component 6) indexes every Living Spec.
- A post-merge hook re-projects affected deliverables.
- The Router queries the graph for reuse and dependency detection
  before dispatching new work.
- Operator-facing queries are documented for common questions
  ("what uses X?", "what's affected if I change Y?").

**Risk:** medium. Schema iterates as the factory's vocabulary
stabilizes.

---

## Phase F — Level 5 Gate

**Goal:** Tier-1 changes auto-merge on green; humans approve
Tier-2 outcomes rather than diffs.

By the end of Phase F:

- Tier-1 changes (per Agent Policy) auto-merge after green CI, clean
  paired-change, and successful Spec Graph re-projection.
- Tier-2 changes require human approval at the gate; the human
  reviews **outcomes** (does the result serve the humans it was built
  for?) rather than line-by-line diffs.
- A weekly dashboard reports: spec → deploy time, retry rate, Adapter
  usage mix, cost per deliverable.

**Risk:** ongoing. Safety here compounds — gate escalation should lag
confidence, not lead it. Move tier categories from Tier-2 to Tier-1
slowly, only after sustained low-incident operation.

---

## Adoption Notes

- Phases are **mostly sequential** but B and C can overlap. Living
  Spec rollout does not require Tool Transport to be complete.
- E and D can overlap once a meaningful Living Spec corpus exists.
- Phases A–C are **mostly free** — documentation, decisions, and
  conventions. Phases D–F require real engineering investment.
- Adopting **only Phases A–C** is a reasonable steady state for a
  small instance that wants the discipline without the autonomy. The
  factory still benefits from clear contracts and Living Specs even
  without a Router.

---

## Bootstrap Reality

Early in any instance, most of these components don't yet exist.
Operators use existing commercial Dev Products (Claude Code, Copilot,
etc.) manually to build the first Adapters. As each component ships,
the factory increasingly uses **itself** to build the next one.

The factory builds the factory. Plan for it explicitly: each phase's
deliverables are themselves authored under the previous phase's
constraints.

