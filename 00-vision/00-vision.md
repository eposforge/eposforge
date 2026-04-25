# DarkForge — Vision

## Mission

DarkForge is the open, vendor-agnostic pattern for a **dark factory**: a
fully agentic software, platform, and (eventually) physical-execution
factory driven by declarative intent. The operator declares what should
exist; the factory builds, deploys, and operates it.

The pattern is substrate-agnostic by design. The same architecture builds
a microservice, manages a server fleet, or — at the horizon — coordinates
robotic actuators. Software, platform, and physical work are peer
expressions of the same idea: machines executing human intent.

A dark factory is not an island. Every artifact it produces — Living
Specs, Adapters, components, research catalog entries — is publishable
to open-source platforms in a form other dark factories (including other
DarkForge instances) can discover, audit, and reuse on demand. The
endgame is **dynamic, on-demand software**: when a factory needs a
capability, it first asks the shared corpus whether something already
exists; only if nothing fits does it build new. Each factory's output
expands the substrate every other factory builds from.

## Three Pillars

### 1. Substrate-Agnostic Platform

A dark factory runs on top of a managed substrate: containers and
networking today, robotic actuators and physical workflows tomorrow.
DarkForge does not pick the substrate. The Platform Factory matures the
operator's chosen substrate from "humans configure everything" to
"agents observe, propose, execute, optimize." The pattern is the same
whether the substrate is a single server, a colo cluster, a Kubernetes
fleet, or — eventually — a warehouse of robots.

### 2. AI Factory

AI is the foundation, not a feature. Every workflow assumes agentic
execution. The factory progresses toward full autonomy: declarations
in, production artifacts out, minimal human touchpoints.

DarkForge defines the **components** of this AI factory and the
**Adapter Pattern** that plugs concrete products (Claude Code, Cursor,
Goose, Aider, Copilot, MCP servers, graph stores, sandboxes, etc.) into
those components without locking the factory to any one vendor.

### 3. Product Engine

The factory exists to produce things. Software products, platform
automations, physical workflows — all are deliverables. Each deliverable
ships with a **Living Spec** that travels with it for its lifetime; all
Living Specs are projected into a queryable **Spec Graph** so the factory
can detect reuse, trace dependencies, and reason about change impact.

## Design Principles

1. **Pain-driven.** Build what hurts, not what sounds interesting. Every
   change ships value immediately. Add structure only when the current
   approach breaks.

2. **Vendor-agnostic.** Every component is a slot; concrete products are
   Adapters. The factory must survive the obsolescence or replacement of
   any single vendor without re-architecture. Soft preferences are fine;
   hard lock-in is not.

3. **Substrate-portable.** Use commodity hardware and standard interfaces
   today. Make no decisions that prevent migration to colo, cloud, or
   physical-AI environments. Containerize where reasonable. Version
   everything.

4. **AI-native.** Every workflow assumes AI assistance by default. Human
   effort goes to specification, judgment, and relationships. Machines
   handle execution.

5. **Tight feedback loops.** Specs produce artifacts. Artifacts produce
   value. Value informs the next spec. Minimize the distance between an
   idea and a working deliverable.

## Core Principles (Immutable)

1. **Everything-as-Code** — Git is source of truth; no manual clicks.
2. **AI-First Operations** — Agents observe, reason, act; humans set
   policy and audit.
3. **Defense in Depth** — Assume breach; limit blast radius;
   cryptographic verification.
4. **Incremental Complexity** — Start simple, add layers as needed; no
   premature optimization.
5. **Cloud-Agnostic** — Run anywhere; portable workloads.
6. **Observable and Testable** — Every state change logged; every config
   pre-validated.

## Maturity Philosophy

A dark factory matures along two parallel ladders, one per peer factory:

- **Platform Factory** — Phases 0–4. From Everything-as-Code foundation
  through full autonomous ops.
- **Product Factory** — Phases A–F (or Levels 4–5 in the original
  framing). From human-in-the-loop authoring to specs-in / artifacts-out
  Level 5.

At Level 5 / Phase F, the operator's role becomes:

1. **Think clearly** about what should exist (not how to build it).
2. **Describe precisely** in specifications agents can execute.
3. **Evaluate outcomes** — does the result serve the humans it was built
   for?

The bottleneck shifts from *how fast you can write code* to *how
precisely you can describe what should exist*.

See [../02-roadmap/](../02-roadmap/) for the full maturity ladders.

## Horizon

These are aspirational directions that steer architectural posture today
without prescribing a current roadmap.

### Unified intent execution

The same dark-factory pattern coordinates software, platform, and
physical work. Robotics is not a separate vertical — it's a future
extension of the Platform substrate. An operator says "build me a
privacy-first invoicing service and have my warehouse robots fulfill
orders against it," and the factory dispatches to software adapters,
platform automations, and (eventually) robotic adapters with the same
orchestration spine.

### OSS flywheel — dynamic, on-demand software

The factory's outputs are first-class open-source artifacts, not
internal byproducts. Every Living Spec, Adapter, component, and research
catalog entry a DarkForge instance produces is structured to be
**publishable, discoverable, and reusable** by any other dark factory.

This unlocks a qualitatively different mode of software production:

- **Discover-before-build.** When a factory needs a capability, the
  Router first queries the shared Spec Graph and OSS registries for an
  existing Living Spec or Adapter that satisfies the intent. Building
  new is the fallback, not the default.
- **Reuse at the spec layer, not just the code layer.** Because Living
  Specs travel with their artifacts and are projected into queryable
  graphs, other factories can match on *intent and contract*, not just
  on package names or READMEs.
- **Compounding corpus.** Every factory that ships also publishes.
  The shared substrate of reusable specs and adapters grows with each
  deliverable across the ecosystem — including eposforge consuming
  artifacts produced by other DarkForge instances, and vice versa.
- **On-demand assembly.** At maturity, "needing software" looks less
  like a build project and more like a query: declare the intent, let
  the factory compose existing published pieces, and only generate the
  delta that is genuinely new.

This is the long-arc payoff of the pattern. A single dark factory
accelerates one operator. A network of publishing dark factories
collapses the cost of software for everyone.

### Appliance-ready

A complete dark factory should be packageable as a turnkey appliance
(self-hosted on commodity hardware, racks of accelerators, or vendor
reference platforms). DarkForge stays distribution-agnostic so any
hardware partner can ship a factory in a box.

### Bootstrap progression

Early in any DarkForge instance, most components don't yet exist. The
operator uses existing commercial products (Claude Code, Copilot, etc.)
manually to build the first components. As each component ships, the
factory increasingly uses *itself* to build the next one. The factory
builds the factory. This recursive bootstrap is the natural maturity
path; instances should plan for it explicitly.

## What DarkForge Is Not

- **Not a product.** No binary to install. DarkForge is a pattern,
  contracts, and a research catalog.
- **Not opinionated about implementation.** Tool Transport doesn't
  require MCP. Spec Graph doesn't require Neo4j. Router doesn't require
  any particular agent framework. Pick your Adapters.
- **Not a workflow engine.** DarkForge describes *what components a
  dark factory consists of*, not *how to script a particular factory's
  internal workflow*. Workflow choices are instance-level.

See [01-glossary.md](./01-glossary.md) for shared vocabulary.
