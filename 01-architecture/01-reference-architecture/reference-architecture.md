---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Reference Architecture

System-level view of a EposForge instance. Shows how the
components and the universal Adapter Pattern fit together. Concrete
hardware, networks, hostnames, and tooling choices are out of scope —
those are instance decisions.

> Read first: [adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md). Each
> component referenced here has a contract in the
> [Component Catalog](../02-components/README.md).

---

## Logical Tiers

```text
┌───────────────────────────────────────────────────────────────────┐
│  OPERATOR TIER                                                    │
│  Where the human declares intent. Spec Input authored here.       │
│  Tooling: editor, browser, CLI, voice — the operator's choice.    │
└──────────────────────────┬────────────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────────────┐
│  FACTORY TIER                                                     │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Spec Input → Orchestrator → Dev Product (sandboxed)      │  │
│  │                  ▲           │                             │  │
│  │                  │           ▼                             │  │
│  │              Spec Graph   Tool Transport                   │  │
│  │                  ▲           │                             │  │
│  │                  │           ▼                             │  │
│  │                  └── Source Control + CI                   │  │
│  │                                                            │  │
│  │  Cross-cutting: Agent Policy, Audit & Observability,       │  │
│  │                 Inference Layer, Secrets & Key Management  │  │
│  │  Each cross-cutting slot is consulted or read by the       │  │
│  │  others; none of them is a leaf in the dispatch chain.     │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────┬────────────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────────────┐
│  SUBSTRATE TIER (managed by the Platform Factory)                 │
│  Hosts, networks, storage, OS, 3rd-party services, secrets        │
│  store, observability backend. Today usually containers + a       │
│  router. Tomorrow may include physical actuators.                 │
└──────────────────────────┬────────────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────────────┐
│  EXTERNAL TIER                                                    │
│  Vendor APIs (frontier models, hosted services, third-party       │
│  data) consumed via Adapters that declare the appropriate         │
│  privacy posture.                                                 │
└───────────────────────────────────────────────────────────────────┘
```

The operator tier and the external tier are open: EposForge does not
constrain how the operator works or which vendors are used, only how
they're plugged in.

The Logical Tiers are a **functional** view — *what role does each part
play?* They are deliberately distinct from the **stabilization** view —
*what has to be solid before what?* — which orders the same elements by
bootstrap dependency and asks which are kernels. A self-improving factory
needs both; for the stabilization view, the kernel definition, and the
bootstrap rule, see
[stabilization-and-kernels.md](../04-stabilization-and-kernels/stabilization-and-kernels.md).

---

## Component Layout

The components fall into three roles:

**Orchestration spine** — components that move work through the
factory.

- [Spec Input] — accepts intent.
- [Orchestrator] — decomposes and
  dispatches.
- [Dev Product] — produces
  artifacts.
- [Tool Transport] — exposes
  capabilities to Dev Products.
- [Source Control + CI] —
  lands and gates artifacts.
- [Release Rings] —
  governs where artifacts run and who may put them there.

**Memory and state** — components that record and project the factory's
work over time.

- [Living Spec] — durable current
  Spec per Product (or platform capability).
- [Spec Graph] — queryable
  projection of all Living Specs.
- [Audit & Observability]
  — immutable record of what happened.
- [Backlog] — durable, cross-repo
  work-item tracker for active, deferred, and archived items.

**Cross-cutting controls** — components consulted by every other
component.

- [Execution Sandbox] —
  isolation for dispatched work.
- [Agent Policy] — what
  agents may do.
- [Inference Layer] — model inference.
- [Secrets & Key Management]
  — secret resolution and rotation.

---

## Primary Data Flow: Intent → Artifact

```text
1. Operator authors a Spec Input.
2. Orchestrator consumes it; queries the Spec Graph for reusable prior work.
3. Orchestrator decomposes into sub-tasks and selects a Dev Product Adapter
   per sub-task, consulting Agent Policy and Adapter metadata
   (privacy, cost, capabilities).
4. For each sub-task: Orchestrator opens an isolated Execution Sandbox,
   dispatches the Dev Product, and exposes capabilities through the
   Tool Transport.
5. The Dev Product produces artifacts in a working branch in Source
   Control. Agent Policy gates each action; Secrets & Key Management
   resolves any required credentials; the Inference Layer serves any
   model calls; everything is logged to Audit & Observability.
6. The Dev Product updates the Living Spec in the same change.
   Source Control + CI runs tests and the paired-change check.
7. On green, Source Control + CI merges per Agent Policy tier rules
   (auto-merge for tier 1, human review for tier 2).
8. Post-merge, the Spec Graph re-projects the affected Living Specs.
9. The cycle is recorded in Audit & Observability and can inform the
   next iteration.
```

Every step is observable and policy-bounded; nothing happens off the
audit channel.

---

## Living Spec → Spec Graph Flow

```text
Each Product (one Living Spec = HEAD of product intent)
    │  may span multiple implementation repos
    │  paired-change protected
    ▼
Source Control + CI emits a post-merge event
    │
    ▼
Spec Graph Adapter reads the changed Living Specs
    │  Projects into nodes / edges / embeddings per Adapter format
    │  (Scope Spec Graphs → Factory Spec Graph composition)
    ▼
Spec Graph (queryable surface)
    │  Reuse detection, dependency mapping, change-impact analysis,
    │  RAG over product intent
    ▼
Orchestrator consults the graph during decomposition and selection
```

The Spec Graph is a projection. If it disagrees with a Living Spec,
re-project. Living Specs win. Episode/specify folders are not Living
Specs and are not the primary graph corpus.

---

## Agentic Control Plane

The factory runs autonomously within bounds set by humans. The degree of
human presence in this loop is the factory's **autonomy mode** —
`supervised` (human on the loop) or `autonomous` (off the loop); see
[autonomy-modes.md](../03-autonomy-modes/autonomy-modes.md). The control plane has
three loops:

**Observe.** Audit & Observability collects everything: every Adapter
invocation, every policy decision, every artifact, every error, every
secret access (without values).

**Decide.** Agent Policy evaluates each proposed action. The [Orchestrator]
asks "may I dispatch this?" and gets back tier 0 / 1 / 2 / 3. Tier
gates determine whether human approval is required.

**Act.** The [Orchestrator] dispatches; Dev Products execute in sandboxes; the
Tool Transport carries capability calls; Source Control + CI gates the
result.

The loop is observable end-to-end, and humans intervene only at
declared gates.

---

## Substrate Independence

The factory is substrate-agnostic by design. The same components, the
same Adapter Pattern, and the same data flows work whether the
substrate is:

- A single workstation running everything in one process.
- A single host running containers.
- A multi-host cluster (Docker Swarm, Kubernetes, Nomad).
- A colocation rack with dedicated GPU nodes for the Inference Layer.
- A cloud account.
- A vendor reference appliance.
- A future substrate including physical actuators (robotics).

What changes from substrate to substrate is the Platform Factory's job
([../02-roadmap/platform-factory-phases.md](../02-roadmap/platform-factory-phases.md)).
The Product Factory's components and contracts do not change.

What does not change between substrates: component contracts, Adapter
metadata schemas, the paired-change rule, the Spec Graph projection
contract, the audit event schema, the Agent Policy tier model.

---

## What This Document Does Not Specify

- **Specific Adapters.** Surveys live in
  [../03-research/](../03-research/).
- **Specific tooling choices** (which graph store, which model
  provider, which CI engine). Those are instance decisions.
- **Network topology, IP ranges, hostnames.** Substrate concerns.
- **Naming conventions** for repos, containers, hosts. Instance
  conventions.
- **Deploy strategy.** Per-deliverable; consult the Source Control + CI
  Adapter for whatever your instance uses.

This document specifies how the components fit together. Everything
else is the operator's choice, made with whatever Adapters they
install.

<!-- component-links (generated by check-component-links.py --write-defs) -->
[Spec Input]: ../02-components/spec-input.md
[Orchestrator]: ../02-components/orchestrator.md
[Dev Product]: ../02-components/dev-product.md
[Tool Transport]: ../02-components/tool-transport.md
[Source Control + CI]: ../02-components/source-control-ci.md
[Release Rings]: ../02-components/release-rings.md
[Living Spec]: ../02-components/living-spec.md
[Spec Graph]: ../02-components/spec-graph.md
[Audit & Observability]: ../02-components/audit-observability.md
[Backlog]: ../02-components/backlog.md
[Execution Sandbox]: ../02-components/execution-sandbox.md
[Agent Policy]: ../02-components/agent-policy.md
[Inference Layer]: ../02-components/inference.md
[Secrets & Key Management]: ../02-components/secrets-key-management.md
