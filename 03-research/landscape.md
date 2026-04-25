# Landscape Scan

> **Snapshot date:** 2026-04. This document goes stale fast. Update or
> retire when stale. Treat as recon, not gospel.

What's already being built in the dark-factory / agent-orchestration /
physical-AI space, and where DarkForge fits.

---

## Why this exists

DarkForge is a pattern, not a product. The pattern only matters if
operators reach for it instead of (re-)building one of the platforms
already in the field. This scan keeps the project honest about the
overlap and the genuine gap.

---

## Adjacent categories

### Software-only AI factories (proprietary)

Examples in the space include: Factory.ai, Blitzy, Harness AIDA,
StackGen, Autonomy AI.

Common shape: integrated platform, GraphRAG-backed memory, opinionated
toolchain, enterprise-priced. Strong for organizations that want to
buy a complete autonomous coding solution.

Gap: vertically integrated. The catalog of supported underlying tools
is the vendor's choice, not the operator's. Switching is a re-platform.

### Software-only agent platforms (open-source)

Examples: OpenHands, Goose, Aider, Continue.dev, Microsoft Agent
Framework (successor to AutoGen), LangGraph-based custom orchestrators.

Common shape: framework or single-product agent. Strong for builders
who want a starting point. Few opinions about Living Specs, Spec
Graphs, paired-change rules, or factory-wide governance.

Gap: components rather than a system. None ships an opinionated
end-to-end factory pattern with cross-component contracts.

### Code-graph and spec-graph projects

Examples: Code-Graph-RAG, Blitzy GraphRAG (proprietary), various
hand-rolled Neo4j projections.

Common shape: indexes a codebase or documentation corpus into a graph
and exposes queries / RAG. Strong for retrieval over large code.

Gap: most are read-only over code, not over **specs**. The Living
Spec → Spec Graph projection (separating durable behavior description
from implementation) is a different shape than a code graph.

### Physical-AI and robotics platforms

Examples: NVIDIA Isaac / Omniverse / GR00T, robot-maker stacks (ABB,
FANUC, KUKA, Yaskawa), robotics-native AI agent frameworks (RAI,
llama_ros, ROS2-bridged stacks), humanoid platforms (Figure, Agility,
Skild AI, Unitree).

Common shape: simulation, motion control, perception, and fleet
orchestration. Strong for operators with real robots.

Gap: software factory and robotic fleet are usually separate stacks
with separate operator interfaces. No widely adopted layer treats
"build a service" and "execute a physical workflow" as peer outputs of
the same factory pattern.

### Hardware-bundled AI factories

Examples: NVIDIA DGX-based "AI factories," vendor reference racks with
preinstalled stacks.

Common shape: hardware ships with vendor-curated software. Strong for
operators who want a turnkey accelerator.

Gap: vendor lock-in at the orchestration layer. The pattern that runs
on the hardware is the vendor's choice.

---

## Where DarkForge sits

DarkForge is **not** trying to be any of the above. It is trying to be
the **shared, opinionated pattern** that:

- Names the twelve components every dark factory needs.
- Defines a uniform Adapter Pattern so vendors and OSS projects above
  can plug in without re-architecting.
- Includes Platform Factory and Product Factory as peer maturity
  ladders so software, ops, and (eventually) physical work share an
  orchestration spine.
- Enforces Living Specs and Spec Graph projection as factory-wide
  invariants so memory and reasoning compound rather than fragment.
- Stays distribution-agnostic so any hardware partner or community can
  ship an instance.

The bet: an opinionated open pattern is more valuable than another
vertically integrated platform — provided the pattern is sharp enough
to disagree with.

---

## What this scan does not promise

- **Completeness.** The space changes monthly; entries here are
  illustrative, not exhaustive.
- **Endorsement.** Listing a product is not a recommendation.
- **Accuracy of pricing or features.** Vendors change both freely. Do
  your own current diligence before committing.

If you find a meaningful project missing or mischaracterized, open an
issue or a PR. Scope this doc to "what shapes of work exist," not
"every vendor or repo in the field."

---

## Per-component implementation catalogs

Concrete Adapter candidates per component slot:

- [dev-products.md](./dev-products.md) — Dev Product slot (component 3).
- More to come as research surveys mature.
