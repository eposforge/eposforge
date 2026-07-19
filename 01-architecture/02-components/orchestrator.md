---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 4: Orchestrator

> **Formerly named "Router."** This component was previously called the **Router**
> and was renamed to **Orchestrator** (per EF-026) to match industry agentic-AI
> conventions. "Router" is now a deprecated alias for the Orchestrator. AutoGen,
> Microsoft Agent Framework, LangGraph, etc. are *implementations* an Orchestrator
> can use — they are not former names of this component.

## Purpose

The decomposition and dispatch layer. Takes a normalized Spec Input,
breaks it into sub-tasks, selects appropriate Dev Product Adapters per
sub-task, dispatches via the Tool Transport, evaluates results, and
iterates.

The Orchestrator is the factory's "brain." Without it, there is no factory —
just a collection of Adapters.

## Contract

Any Adapter for this slot must:

- Accept normalized output from a Spec Input Adapter
  ([spec-input.md](./spec-input.md)).
- Decompose into sub-tasks of bounded scope; each sub-task must be
  executable by at least one installed Dev Product Adapter.
- Select a Dev Product Adapter per sub-task using declared metadata
  (privacy, cost, capabilities), Agent Policy
  ([agent-policy.md](./agent-policy.md)), and the Spec Graph
  ([spec-graph.md](./spec-graph.md)) when reuse is possible.
- Dispatch the sub-task and consume the result.
- On failure, retry within policy limits, escalate to a different
  Adapter, or fail loudly to the operator. The Orchestrator never silently
  abandons work.
- Open pull requests for completed work; respect the merge tier rules
  defined by Agent Policy.
- Emit audit events for every decomposition, selection, dispatch, and
  result.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `decomposition_strategy` — how the Orchestrator decomposes (LLM-driven,
  rule-based, hybrid).
- `selection_strategy` — how Adapters are picked (cost-first, privacy-
  first, capability-match, weighted).
- `escalation_policy` — what happens on persistent failure.
- `tier_support` — which Agent Policy tiers the Orchestrator enforces.

## Boundaries

- **Is:** the orchestration layer.
- **Is not:** a Dev Product. The Orchestrator does not author artifacts
  itself; it dispatches to Dev Products.
- **Is not:** an approval system. Final merge decisions live in
  Source Control + CI under Agent Policy.
- **Is not:** the runtime content-safety enforcement point. The Orchestrator calls Content Safety (C14), the runtime content-safety enforcement point, to inspect payloads.

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog (Microsoft
Agent Framework, OpenHands, AutoGen, LangGraph, custom in-house
orchestrators, etc.).

