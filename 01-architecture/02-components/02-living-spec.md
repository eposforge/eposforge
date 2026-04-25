# Component 2: Living Spec

## Purpose

The durable, canonical description of an existing factory deliverable.
Every deliverable repository carries a Living Spec that describes the
exact behavior the deliverable implements. The Living Spec is the
source of truth; the code is the implementation.

Agents update the Living Spec and the code in the same change. A change
that modifies behavior without updating the Living Spec is rejected.

## Contract

Any Adapter for this slot must:

- Define a canonical location and format for the Living Spec inside a
  deliverable repo (e.g., `SPEC.md` at the repo root).
- Define the **paired-change rule**: any change that affects observable
  behavior must update both the Living Spec and the code in the same
  commit / PR.
- Provide a paired-change check enforceable in CI (see component 9,
  [Source Control + CI](./09-source-control-ci.md)).
- Define the minimum content of a Living Spec: purpose, observable
  behavior, inputs / outputs, dependencies, non-functional bounds,
  versioning policy.
- Be projectable into the Spec Graph (component 6) without lossy
  transformations.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern.md](../00-adapter-pattern.md):

- `format` — markdown, YAML, structured doc, etc.
- `paired_change_check` — identifier for the CI check that enforces the
  rule.
- `graph_projection` — pointer to the projection the Spec Graph Adapter
  will index.

## Boundaries

- **Is:** the durable spec living inside the deliverable repo for the
  deliverable's entire lifetime.
- **Is not:** the Spec Input ([01-spec-input.md](./01-spec-input.md)),
  which is request-shaped and consumed by the Router.
- **Is not:** API documentation, README, or operator runbook — though it
  may inform any of those.

## Reference implementations

See [../../03-research/](../../03-research/) for survey of Living-Spec
templates and paired-change check tooling.
