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
  [04-router.md](./04-router.md)).
- Execute the sub-task within the Execution Sandbox
  ([07-execution-sandbox.md](./07-execution-sandbox.md)) and return one
  of: success-with-artifacts, partial-with-artifacts, or failure-with-
  diagnosis.
- Honor agent policy ([08-agent-policy.md](./08-agent-policy.md)) on
  every action. Touching a resource the policy forbids must fail.
- Consume tool capabilities only via the configured Tool Transport
  ([05-tool-transport.md](./05-tool-transport.md)).
- Read secrets only via the Secrets & Key Management slot
  ([12-secrets-key-management.md](./12-secrets-key-management.md)).
- Emit audit events to Audit & Observability
  ([11-audit-observability.md](./11-audit-observability.md)).
- Update the Living Spec on any change with observable behavior; refusal
  to do so is a contract violation.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern.md](../00-adapter-pattern.md):

- `task_shapes` — the kinds of sub-tasks the Adapter accepts (e.g.,
  `single-file-edit`, `multi-file-refactor`, `test-authoring`,
  `terminal-ops`, `browser-ops`).
- `context_window` — practical limits the Router should respect.
- `parallelism` — whether the Adapter supports concurrent invocations.
- `streaming` — whether the Adapter streams progress to the audit log.

## Boundaries

- **Is:** the slot for tools that produce artifacts from sub-task
  descriptions.
- **Is not:** the orchestration layer (that is the Router) or the
  policy boundary (that is Agent Policy).
- **Is not:** required to be AI-driven. A deterministic code generator
  can fill this slot if it conforms to the contract.

## Reference implementations

See [../../03-research/03-dev-product/dev-products.md](../../03-research/03-dev-product/dev-products.md)
for the candidate catalog and [../../instance/installed/03-dev-product/](../../instance/installed/03-dev-product/)
for what THIS repo installs.

