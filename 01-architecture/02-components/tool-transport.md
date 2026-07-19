---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 5: Tool Transport

## Purpose

The protocol layer by which Dev Products consume capabilities (git,
file ops, shell, browser, graph queries, HTTP, etc.). One Tool Transport
serves all Dev Products in the factory; the Transport is what keeps the
factory vendor-agnostic at the tool layer — one tool implementation per
capability, many consumers.

## Contract

Any Adapter for this slot must:

- Expose a defined set of capability categories to Dev Products. The
  minimum required set:
  - **git** — read, write, branch, commit against the factory's source
    control.
  - **fs** — read / write inside a scoped workspace.
  - **shell** — sandboxed command execution (delegated to the Execution
    Sandbox).
  - **graph-query** — read (and tier-gated write) against the Spec
    Graph.
  - **browser** — headless browser operations.
  - **http** — outbound HTTP calls within policy.
- Authenticate the calling Dev Product Adapter and apply its declared
  privacy posture.
- Enforce Agent Policy on every capability call.
- Read secrets only via the Secrets & Key Management slot.
- Emit audit events to Audit & Observability for each capability call.

Components must not call into the factory through any path other than
the Tool Transport. There is no "back door" for a Dev Product.

## Required Adapter metadata


In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `capabilities_exposed` — full capability set, beyond the required
  minimum.
- `transport_protocol` — wire-level protocol (e.g., MCP, gRPC, HTTP+JSON).
- `authentication` — how Dev Products authenticate to the Transport.

## Boundaries

- **Is:** the protocol contract that Dev Products use to do work.
- **Is not:** the sandbox in which work runs (that is Execution
  Sandbox).
- **Is not:** the policy decision point (that is Agent Policy); the
  Transport asks for permission and enforces the answer.
- **Is not:** the runtime content-safety enforcement point. Content Safety (C14) is the runtime content-safety enforcement point.

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog. A
common choice is Model Context Protocol (MCP); other transports are
acceptable as long as the contract is met.
