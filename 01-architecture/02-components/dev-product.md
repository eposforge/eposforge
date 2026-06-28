---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 3: Dev Product

## Purpose

The slot for products that take a sub-task description and produce
artifacts (code, configuration, infrastructure, prose, etc.). Dev
Products are the factory's hands. Concrete product choices are
instance-specific.

The Router selects a Dev Product Adapter per sub-task based on its
declared metadata (capabilities, privacy posture, cost). EposForge
expects multiple Dev Product Adapters to be installed simultaneously;
the factory chooses among them per task.

## Contract

Any Adapter for this slot must:

- Accept a normalized sub-task descriptor from the Router (input bounds
  defined by the Router contract, see
  [router.md](./router.md)).
- Execute the sub-task within the Execution Sandbox
  ([execution-sandbox.md](./execution-sandbox.md)) and return one
  of: success-with-artifacts, partial-with-artifacts, or failure-with-
  diagnosis.
- Honor agent policy ([agent-policy.md](./agent-policy.md)) on
  every action. Touching a resource the policy forbids must fail.
- Consume tool capabilities only via the configured Tool Transport
  ([tool-transport.md](./tool-transport.md)).
- Read secrets only via the Secrets & Key Management slot
  ([secrets-key-management.md](./secrets-key-management.md)).
- Emit audit events to Audit & Observability
  ([audit-observability.md](./audit-observability.md)).
- Update the Living Spec on any change with observable behavior; refusal
  to do so is a contract violation.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `task_shapes` — the kinds of sub-tasks the Adapter accepts (e.g.,
  `single-file-edit`, `multi-file-refactor`, `test-authoring`,
  `terminal-ops`, `browser-ops`).
- `context_window` — practical limits the Router should respect.
- `parallelism` — whether the Adapter supports concurrent invocations.
- `streaming` — whether the Adapter streams progress to the audit log.
- `autonomy_tos_posture` — the highest autonomy mode the Adapter's
  licensing / terms of service permit, expressed as a threshold (see
  [../03-autonomy-modes/autonomy-modes.md](../03-autonomy-modes/autonomy-modes.md)). OSS BYOK products
  are typically `byok-clean-all-modes`; subscription / OAuth products are
  typically `subscription-ok-through-supervised;
  api-key-required-for-autonomous`. A factory running in `autonomous`
  mode must not dispatch to an Adapter whose posture forbids it.

## Boundaries

- **Is:** the slot for tools that produce artifacts from sub-task
  descriptions.
- **Is not:** the orchestration layer (that is the Router) or the
  policy boundary (that is Agent Policy).
- **Is not:** required to be AI-driven. A deterministic code generator
  can fill this slot if it conforms to the contract.

## Reference implementations

See [../../03-research/01-architecture/02-components/dev-product/dev-products.md](../../03-research/01-architecture/02-components/dev-product/dev-products.md)
for the candidate catalog and [../../instance/dev-product/](../../instance/dev-product/)
for what THIS repo installs.

