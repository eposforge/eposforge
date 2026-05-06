---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Reference Architecture

System-level view of a EposForge instance. Shows how the twelve
components and the universal Adapter Pattern fit together. Concrete
hardware, networks, hostnames, and tooling choices are out of scope —
those are instance decisions.

> Read first: [00-adapter-pattern.md](./00-adapter-pattern.md). Each
> component referenced here has a contract under
> [02-components/](./02-components/).

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
│  │  Spec Input → Router → Dev Product (in Execution Sandbox) │  │
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

---

## Component Layout

The twelve components fall into three roles:

**Orchestration spine** — components that move work through the
factory.

- [01-spec-input.md](./02-components/01-spec-input.md) — accepts intent.
- [04-router.md](./02-components/04-router.md) — decomposes and
  dispatches.
- [03-dev-product.md](./02-components/03-dev-product.md) — produces
  artifacts.
- [05-tool-transport.md](./02-components/05-tool-transport.md) — exposes
  capabilities to Dev Products.
- [09-source-control-ci.md](./02-components/09-source-control-ci.md) —
  lands and gates artifacts.
- [09b-release-rings.md](./02-components/09b-release-rings.md) —
  governs where artifacts run and who may put them there.

**Memory and state** — components that record and project the factory's
work over time.

- [02-living-spec.md](./02-components/02-living-spec.md) — durable spec
  in each deliverable.
- [06-spec-graph.md](./02-components/06-spec-graph.md) — queryable
  projection of all Living Specs.
- [11-audit-observability.md](./02-components/11-audit-observability.md)
  — immutable record of what happened.

**Cross-cutting controls** — components consulted by every other
component.

- [07-execution-sandbox.md](./02-components/07-execution-sandbox.md) —
  isolation for dispatched work.
- [08-agent-policy.md](./02-components/08-agent-policy.md) — what
  agents may do.
- [10-inference.md](./02-components/10-inference.md) — model inference.
- [12-secrets-key-management.md](./02-components/12-secrets-key-management.md)
  — secret resolution and rotation.

---

## Primary Data Flow: Intent → Artifact

```text
1. Operator authors a Spec Input.
2. Router consumes it; queries the Spec Graph for reusable prior work.
3. Router decomposes into sub-tasks and selects a Dev Product Adapter
   per sub-task, consulting Agent Policy and Adapter metadata
   (privacy, cost, capabilities).
4. For each sub-task: Router opens an isolated Execution Sandbox,
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
Each deliverable repo
    │  Living Spec (canonical, paired-change protected)
    ▼
Source Control + CI emits a post-merge event
    │
    ▼
Spec Graph Adapter reads the changed Living Specs
    │  Projects into nodes / edges / embeddings per Adapter format
    ▼
Spec Graph (queryable surface)
    │  Reuse detection, dependency mapping, change-impact analysis,
    │  RAG over all specs
    ▼
Router consults the graph during decomposition and selection
```

The Spec Graph is a projection. If it disagrees with a Living Spec,
re-project. Living Specs win.

---

## Agentic Control Plane

The factory runs autonomously within bounds set by humans. The control
plane has three loops:

**Observe.** Audit & Observability collects everything: every Adapter
invocation, every policy decision, every artifact, every error, every
secret access (without values).

**Decide.** Agent Policy evaluates each proposed action. The Router
asks "may I dispatch this?" and gets back tier 0 / 1 / 2 / 3. Tier
gates determine whether human approval is required.

**Act.** The Router dispatches; Dev Products execute in sandboxes; the
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

