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
- Apply resource limits declared by the dispatching Router (CPU, memory,
  wall clock, network egress budget).
- Enforce the privacy posture of the Dev Product Adapter running inside.
  A `privacy: local` Dev Product must run in a sandbox that prevents any
  outbound traffic except through approved channels.
- Tear down the sandbox cleanly after the sub-task completes; surface
  artifacts via the agreed return path.
- Emit audit events on creation, termination, and any policy violation
  attempts.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `isolation_mechanism` — container, VM, micro-VM, namespace, etc.
- `network_policy_modes` — what egress controls the sandbox supports.
- `gpu_support` — whether the sandbox can host GPU-accelerated Dev
  Products.
- `state_persistence` — whether the sandbox supports cross-invocation
  state (usually no; declare explicitly).

## Boundaries

- **Is:** the isolation layer for dispatched work.
- **Is not:** the orchestrator (that is the Router) or the policy point
  (that is Agent Policy); the Sandbox enforces what they decide.
- **Is not:** a long-lived service host. Sandboxes exist for the
  duration of a sub-task.

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog (Docker
containers, Kubernetes ephemeral pods, Firecracker micro-VMs,
devcontainers, OpenClaw / similar agent sandboxes, etc.).

