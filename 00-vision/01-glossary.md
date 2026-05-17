---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Glossary and Taxonomy

Shared vocabulary for EposForge. Every other doc in this repo — and any
agent operating against it — should use these terms as defined here. If a
concept is missing, add it here first, then use it elsewhere.

---

## Taxonomy

```text
Dark Factory  (the vision: human declares capabilities → AI builds them)
│
├── Platform Factory   (ops autonomy — the substrate everything runs on)
│    • Scope: hardware, network, operating systems, 3rd-party server apps,
│      configuration, secrets, observability, backups, and — at the
│      horizon — physical actuators (robotics).
│    • Maturity ladder: Phases 0–4
│         Phase 0: Foundation (Everything-as-Code + observability)
│         Phase 1: Agent Observation (agents query, propose, wait)
│         Phase 2: Agent Proposals (agents PR, humans review, apply)
│         Phase 3: Supervised Autonomy (agents execute pre-approved actions)
│         Phase 4: Full Autonomy (agents self-update, coordinate, optimize)
│
└── Product Factory   (dev autonomy — software the operator authors)
     • Scope: custom applications, services, and APIs authored in this
       instance. Excludes 3rd-party software (that is Platform scope).
     • Maturity ladder: Phases A–F (Levels 4–5 in earlier framings)
          Phase A: Registry as ground truth
          Phase B: Tool transport foundation
          Phase C: Living Spec rollout
          Phase D: Router v0
          Phase E: Spec Graph
          Phase F: Level 5 gate (auto-merge tier-1 changes)
```

Both factories inherit the same agentic principles, guardrails, and
approval gates.

---

## Glossary

**Dark Factory** — The unifying vision. A system where the operator
declares desired capabilities and AI agents build, deploy, and operate
them with minimal supervision. Spans both Platform and Product.

**Platform** — The operational substrate: hardware, network, operating
systems, 3rd-party server apps, configuration, secrets, observability,
backups, and physical actuators where applicable. Everything the Product
runs *on*.

**Product** — Software (or physical workflow) authored by the operator
(or by agents on the operator's behalf) that delivers business
capabilities. Does not include 3rd-party software — that is Platform
scope.

**Factory** — A maturity ladder for a given domain. The Platform Factory
matures through Phases 0–4; the Product Factory matures through Phases
A–F. The endpoint of each ladder is full autonomy within its domain.

**Component** — An architectural slot in a dark factory (Spec Input,
Living Spec, Dev Product, Router, Tool Transport, Spec Graph, Execution
Sandbox, Agent Policy, Source Control + CI, Inference Layer, Audit &
Observability, Secrets & Key Management). EposForge defines twelve
components and the contract each must satisfy. See
[../01-architecture/02-components/](../01-architecture/02-components/).

**Adapter** — A concrete implementation that plugs into a component
slot. Adapters self-declare metadata (capabilities, privacy posture,
cost hints, invocation surface) and conform to their component's
contract. The set of installed Adapters is queryable; the Router uses
Adapter metadata to make routing decisions.

**Adapter Pattern** — EposForge's universal plug-in pattern. Applies
uniformly across all twelve components. See
[../01-architecture/00-adapter-pattern.md](../01-architecture/00-adapter-pattern.md).

**Agent** — An autonomous AI-driven executor that observes, reasons,
proposes, or acts within a scoped policy. Agents are domain-scoped (a
Platform agent cannot author Product code unless explicitly allowed by
policy, and vice versa).

**Spec** — A declarative statement of desired capability, written by the
operator. The input to the Product Factory. Specs are versioned like
code.

**Phase** — A stage of factory maturity. Sequential; each phase's
verification criteria gate the next.

**Migration** — A named, in-flight transition between two coexisting
architectural shapes (legacy and target) within an instance. Each
Migration has a stated completion commitment. Entities in the Spec
Graph declare which side they are on via `LEGACY_SHAPE_OF` or
`TARGET_SHAPE_OF`. The mechanism backing obligation 3 of
[adoption strategy](../02-roadmap/adoption-strategy.md): remaining
migration debt is mechanically visible rather than
memory-dependent. How an instance populates the relationships
(frontmatter markers, manifest, lint rules) is an instance choice.

**Policy** — A machine-enforceable rule that constrains what an agent
may do (e.g., "Platform agents may not touch application containers").

**Guardrail** — A runtime check or approval gate that enforces a policy
(signed commits, protected branches, secret access controls, cost
budgets, production-merge approval).

**Operator** — The human in charge of a EposForge instance. In a mature
factory, the operator declares capabilities, sets policy, and approves
final gates; they do not write code or configure services directly.

**Dev Product** — A third-party AI coding tool that the Product Factory
consumes as an executor (Claude Code, Cursor, Goose, Aider, Copilot,
etc.). Dev Products plug in via Adapters. Distinct from *Product* (which
is operator-authored software) and from *Platform* (which is the
operational substrate). Dev Products are swappable by design.

**Router** (a.k.a. **Orchestrator**) — The decomposition and dispatch
layer of the Product Factory. Takes a high-level spec, breaks it into
sub-tasks, selects appropriate Dev Product Adapters, dispatches via the
Tool Transport, evaluates results, iterates. The Router is the factory's
"brain"; Dev Products are its "hands."

**Tool Transport** — The protocol/contract by which Dev Products
consume capabilities (git, file ops, browser, shell, graph queries,
etc.). EposForge defines the required capability set; specific
transports (e.g., MCP) are Adapters.

**Living Spec** — A canonical spec document (commonly `SPEC.md`) that
lives inside every factory deliverable repo and describes the exact
behavior the deliverable implements. Agents update the spec and the
code in the same change, keeping the two in sync. Contrast with an input
*Spec* (a request for new capability): the Living Spec is the *durable*
ground-truth artifact that travels with the deliverable for its entire
lifetime.

**Spec Graph** — A queryable projection of every Living Spec across the
factory. Enables factory-scale reasoning: reuse detection, dependency
mapping, change-impact analysis, RAG over all specs. The Spec Graph is a
*projection* — the Living Specs are the source of truth; the graph is
rebuilt from them.

**Execution Sandbox** — The isolated runtime in which dispatched Dev
Product work executes. Provides shell, filesystem, browser, and
network capabilities under policy.

---

## Disambiguation

**"Infrastructure"** is avoided as a top-level organizing term. Use
**Platform** when referring to the operational substrate. The word
"infrastructure" may still appear in plain prose (e.g., "testing
infrastructure"), but should not be used as a domain or directory name.

**"Software"** is avoided as a top-level term because it cannot cleanly
distinguish between operator-authored applications (Product) and
3rd-party server apps (Platform).

**"Dark factory" (lowercase / informal)** refers to the unifying vision
— both Platform and Product factories at their autonomous endpoints.
When the phrase specifically means software authoring, tighten to
**Product Factory**. When it specifically means autonomous ops, tighten
to **Platform Factory**.

**"Registry"** is not a EposForge component. Earlier framings used "Dev
Product Registry" as a slot; the current model treats the catalog as
emergent from installed Adapters per the universal Adapter Pattern.

---

## Extending This Document

- Add a new term only if it will appear in more than one doc.
- Put the canonical definition here; link to it from other docs rather
  than redefining.
- If a term's meaning changes, update here first, then sweep dependent
  docs.
- If two terms overlap, pick one and mark the other as an alias or
  retire it.

