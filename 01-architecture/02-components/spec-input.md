---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 1: Spec Input

## Purpose

The slot for declaring intent. Operators write Spec Input documents that
describe a desired capability — what should exist, why, and the
non-functional bounds (privacy, cost, latency, etc.). The Router consumes
Spec Input and decomposes it into work the factory can execute.

Spec Input is **request-shaped** ("build me X"); it is distinct from the
Living Spec ([living-spec.md](./living-spec.md)), which is the
durable description of an existing deliverable.

## Contract

Any Adapter for this slot must:

- Accept human-authored declarative input in a defined format.
- Normalize the input into a structured form the Router can decompose
  (sub-tasks, acceptance criteria, non-functional requirements).
- Validate the input against the Adapter's schema and reject malformed
  input with actionable feedback.
- Produce output that names: target deliverable(s), success criteria,
  privacy posture, cost ceiling (if any), and any constraints the Router
  must respect during dispatch.
- Be idempotent: re-submitting the same input yields the same normalized
  output.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `input_format` — markdown, YAML, structured form, etc.
- `decomposition_hints` — capability tags the Adapter recognizes and
  passes to the Router.
- `acceptance_format` — how acceptance criteria are expressed (Gherkin,
  free text, etc.).

## Boundaries

- **Is:** the contract for getting intent into the factory.
- **Is not:** a workflow engine. Spec Input does not orchestrate; it
  hands off to the Router.
- **Is not:** the durable Living Spec. Spec Input is consumed and
  archived; Living Specs are persistent.

## Reference implementations

See [../../03-research/](../../03-research/) for a catalog of products
that can fill this slot (e.g., GitHub Spec Kit, Kiro, custom
markdown-based briefs).

