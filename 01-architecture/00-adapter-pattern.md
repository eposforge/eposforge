---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# The Adapter Pattern

## Why this exists once, here

DarkForge defines twelve **components** — architectural slots every dark
factory needs (Spec Input, Living Spec, Dev Product, Router, Tool
Transport, Spec Graph, Execution Sandbox, Agent Policy, Source Control +
CI, Inference Layer, Audit & Observability, Secrets & Key Management).

Concrete products plug into those slots as **Adapters**. Rather than
repeat the plug-in machinery in twelve component contracts, we define it
once here and reference it everywhere.

## Definitions

**Adapter** — A concrete implementation that fulfills a component's
contract. Each Adapter is bound to exactly one component slot. An
instance may install many Adapters per slot (e.g., multiple Dev Product
Adapters, one Spec Graph Adapter).

**Adapter metadata** — Self-declared properties an Adapter exposes so
the factory can reason about it without invoking it. Required for every
Adapter:

- `name` — stable identifier within its component slot.
- `component` — which slot it fulfills.
- `version` — semver or equivalent.
- `privacy_posture` — `local` | `vendor-no-training` | `vendor-default`.
- `cost_hint` — coarse cost tier (free, consumer-paid, commercial,
  metered, n/a).
- `capabilities` — set of capability tags relevant to its component.
- `invocation_surface` — how the Adapter is invoked (CLI, HTTP, library,
  process, etc.).
- `status` — `experimental` | `approved` | `deprecated`.

Components may add their own required metadata fields. Adapters MUST
declare all required fields for their component plus the global fields
above.

**Adapter contract** — The interface the Adapter must implement, defined
per component. Components specify: inputs accepted, outputs produced,
error semantics, and any required side-effects (e.g., logging to the
audit channel).

## How the factory uses Adapters

1. **Discovery.** At startup (or on change) the factory enumerates
   installed Adapters. The aggregated set is queryable; this is the
   factory's "registry," but it is emergent from installed Adapters
   rather than a separate component.
2. **Selection.** When a component slot must act, a selector — usually
   the Router for Dev Products, sometimes the operator for one-off slots
   — picks an Adapter from the set whose metadata matches the
   constraints (privacy, cost, required capabilities).
3. **Invocation.** The factory invokes the Adapter through its declared
   invocation surface. The Adapter must respect its component's contract
   and emit the required audit signals.
4. **Lifecycle.** Adapters can be added, deprecated, or removed without
   touching the Router or other components. A new Dev Product becomes
   available by writing its Adapter and registering it; nothing else
   needs to change.

## Required of every Adapter

- Self-declared metadata, machine-readable.
- Conforms to its component's contract.
- Emits audit events to the factory's Audit & Observability slot.
- Reads secrets only via the Secrets & Key Management slot.
- Operates within Agent Policy boundaries when invoked by an agent.

## What this pattern is not

- **Not a transport spec.** How Adapters are physically distributed
  (npm package, Docker image, Python wheel, plain script, MCP server) is
  out of scope. DarkForge cares about what an Adapter declares and does,
  not how it ships.
- **Not a marketplace.** DarkForge does not run a registry service. The
  research folder ([../03-research/](../03-research/)) catalogs known
  Adapters per slot; instances install what they want.
- **Not a sandbox.** Execution isolation for Adapter invocation is the
  Execution Sandbox component's job, not the pattern's.

## Reading the component contracts

Each file in [02-components/](./02-components/) follows the same shape:

- **Purpose** — what the slot is for.
- **Contract** — what any Adapter for this slot must do.
- **Required Adapter metadata** — fields specific to this slot, beyond
  the universal set above.
- **Boundaries** — what the slot is and is not.
- **Reference implementations** — pointer to the catalog in
  [../03-research/](../03-research/).

Read the contract; pick (or write) an Adapter; install. That's the loop.

