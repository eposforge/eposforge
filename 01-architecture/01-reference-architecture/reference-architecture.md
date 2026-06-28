---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Reference Architecture

System-level view of a EposForge instance. Shows how the fourteen
components and the universal Adapter Pattern fit together. Concrete
hardware, networks, hostnames, and tooling choices are out of scope —
those are instance decisions.

> Read first: [adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md). Each
> component referenced here has a contract under
> [02-components/](.../02-components/).

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

The Logical Tiers are a **functional** view — *what role does each part
play?* They are deliberately distinct from the **stabilization** view —
*what has to be solid before what?* — which orders the same elements by
bootstrap dependency and asks which are kernels. A self-improving factory
needs both; for the stabilization view, the kernel definition, and the
bootstrap rule, see
[stabilization-and-kernels.md](../04-stabilization-and-kernels/stabilization-and-kernels.md).

---

## Component Layout

The fourteen components fall into three roles:

**Orchestration spine** — components that move work through the
factory.

- [spec-input.md](../02-components/spec-input.md) — accepts intent.
- [router.md](../02-components/router.md) — decomposes and
  dispatches.
- [dev-product.md](../02-components/dev-product.md) — produces
  artifacts.
- [tool-transport.md](../02-components/tool-transport.md) — exposes
  capabilities to Dev Products.
- [source-control-ci.md](../02-components/source-control-ci.md) —
  lands and gates artifacts.
- [release-rings.md](../02-components/release-rings.md) —
  governs where artifacts run and who may put them there.

**Memory and state** — components that record and project the factory's
work over time.

- [living-spec.md](../02-components/living-spec.md) — durable spec
  in each deliverable.
- [spec-graph.md](../02-components/spec-graph.md) — queryable
  projection of all Living Specs.
- [audit-observability.md](../02-components/audit-observability.md)
  — immutable record of what happened.
- [backlog.md](../02-components/backlog.md) — durable, cross-repo
  work-item tracker for active, deferred, and archived items.

**Cross-cutting controls** — components consulted by every other
component.

- [execution-sandbox.md](../02-components/execution-sandbox.md) —
  isolation for dispatched work.
- [agent-policy.md](../02-components/agent-policy.md) — what
  agents may do.
- [inference.md](../02-components/inference.md) — model inference.
- [secrets-key-management.md](../02-components/secrets-key-management.md)
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

The factory runs autonomously within bounds set by humans. The degree of
human presence in this loop is the factory's **autonomy mode** —
`supervised` (human on the loop) or `autonomous` (off the loop); see
[autonomy-modes.md](../03-autonomy-modes/autonomy-modes.md). The control plane has
three loops:

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

