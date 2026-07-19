---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 2: Living Spec

## Purpose

The durable, canonical description of an existing factory deliverable.
Every deliverable repository carries a Living Spec that describes the
exact behavior the deliverable implements. The Living Spec is the
source of truth; the code is the implementation.

When developing new features, agents first update the Living Spec.
Updating the Living Spec is the requirements-gathering step performed
by the agent, analogous to the practice on traditional software
development teams. The agent captures the intended observable behavior,
inputs/outputs, dependencies, non-functional bounds, and acceptance
criteria in the Living Spec before implementation work begins. The
updated Living Spec then drives the implementation; subsequent code
changes fulfill the Living Spec.

Agents update the Living Spec and the code in the same change to satisfy
the paired-change rule. A change that modifies behavior without updating
the Living Spec is rejected.

## Contract

Any Adapter for this slot must:

- Define a canonical location and format for the Living Spec inside a
  deliverable repo (e.g., `SPEC.md` at the repo root).
- Define the **paired-change rule**: any change that affects observable
  behavior must update both the Living Spec and the code in the same
  commit / PR.
- Provide a paired-change check enforceable in CI (see component 9,
  [Source Control + CI](./source-control-ci.md)).
- Define the minimum content of a Living Spec: purpose, observable
  behavior, inputs / outputs, dependencies, non-functional bounds,
  versioning policy.
- Declare inputs/outputs and non-functional bounds with enough
  precision that black-box test partitions (equivalence classes and
  boundary values) can be derived from the spec mechanically, without
  reading implementation code. A Living Spec that cannot support this
  derivation is under-specified.
- Be projectable into the Spec Graph (component 6) without lossy
  transformations.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `format` — markdown, YAML, structured doc, etc.
- `paired_change_check` — identifier for the CI check that enforces the
  rule.
- `graph_projection` — pointer to the projection the Spec Graph Adapter
  will index.

## Boundaries

- **Is:** the durable spec living inside the deliverable repo for the
  deliverable's entire lifetime.
- **Is not:** the Spec Input ([spec-input.md](./spec-input.md)),
  which is request-shaped and consumed by the Orchestrator.
- **Is not:** API documentation, README, or operator runbook — though it
  may inform any of those.

## Reference implementations

See [../../03-research/](../../03-research/) for survey of Living-Spec
templates and paired-change check tooling.

