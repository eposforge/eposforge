---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 7: Execution Sandbox

## Purpose

The isolated runtime in which dispatched Dev Product work executes.
Provides shell, filesystem, browser, and network capabilities under
strict isolation from the rest of the factory and the host system.

Every Dev Product invocation runs in a sandbox. Nothing a Dev Product
does should be able to escape its sandbox without going through the
Tool Transport.

## Contract

Any Adapter for this slot must:

- Provide a fresh, isolated workspace per dispatched sub-task.
- Declare the isolation guarantees an orchestrator may rely on:
  - per-dispatched-task confinement (filesystem scope, non-root identity, network policy, and the absence of host-control primitives — e.g. a mounted container-runtime socket)
  - enforced resource limits
  - clean teardown
- Apply resource limits declared by the dispatching Orchestrator (CPU, memory,
  wall clock, network egress budget).
- Enforce the privacy posture of the Dev Product Adapter running inside.
- Emit sandbox lifecycle + escape-attempt events emit to Audit & Observability (C11).

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `isolation_mechanism` — container / rootless-container / micro-VM / socket-proxy.
- `isolation_strength`
- `host_escape_surface`
- `runtime_overhead`

## Boundaries

- **Is:** the isolation layer for dispatched work.
- **Is not:** the orchestrator (that is the Orchestrator) or the policy point
  (that is Agent Policy). C8 decides whether an action is permitted; C7 bounds what a permitted action can reach — a denylist at C8 is accident-prevention, C7 is the containment boundary.
- **Is not:** a long-lived service host. Sandboxes exist for the
  duration of a sub-task.

## Phased Adoption

C7 is recommended under supervised mode and mandatory once autonomous (human-off-the-loop).

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog.
