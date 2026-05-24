# EposForge

> **epos** \e-ˌpäs\ — see [Merriam-Webster](https://www.merriam-webster.com/dictionary/epos).
>
> Open-source dark factory: declarative specs in, production artifacts out.
> Vendor-agnostic orchestration that ships software today and unifies platform
> ops and physical (robotics) execution tomorrow.

---

## What this is

EposForge is the open, vendor-agnostic **pattern** for a dark factory — a
fully agentic software, platform, and (eventually) physical-execution
factory driven by declarative intent. You describe what should exist;
the factory builds, deploys, and operates it.

EposForge defines:

- A **vision** for unified intent execution across software, platform, and
  physical substrates.
- A set of **architectural components** (slots) every dark factory needs.
- A universal **Adapter Pattern** that plugs concrete products into those
  slots without locking the factory to any one vendor.
- **Maturity roadmaps** for both the Platform Factory (ops autonomy) and
  the Product Factory (dev autonomy).
- A **research catalog** of candidate Adapters so you don't reinvent the
  wheel.

Instances pick implementations.

## How to use it

EposForge is delivers value via a Cognee MCP server which LLMs can use for a GraphRag grounding.  
eposforge/instance/installed/06-spec-graph/cognee is the implementation

Once agents have access to the server, they can ground their chats and actions by accessing the EposForge ontology grounded knowledge graph through Cognee MCP.

This guides your agents in building a dark factory from scratch in a greenfield scenario, guides them on incrementally moving towards a dark factory in a brownfield scenario, and guides the development of eposforge itself when contributing to the eposforge github project.

## How to read this repo

```text
00-vision/         # Mission, pillars, principles, horizon
01-architecture/   # Adapter pattern, reference architecture, component contracts
02-roadmap/        # Maturity phases for Platform and Product factories
03-research/       # Surveys of products that can fill each component slot
04-standards/      # Adopted cross-cutting standards and conformance rules
```

This repo is docs-first. Code lands as components mature.

## Repository Layers

This repository has three distinct layers. Keep them separate in commits,
reviews, and docs so it is always clear what is normative architecture and
what is a concrete local implementation.

| Layer | Paths | Meaning | Portability |
| --- | --- | --- | --- |
| Architecture definition | `00-vision/`, `01-architecture/`, `02-roadmap/` | Normative EposForge pattern, contracts, and maturity models | Reused across adopting repos |
| Standards definition | `04-standards/` | Adopted cross-cutting standards and conformance requirements | Reused across adopting repos |
| Implementation for this repo instance | `instance/`, `docs/runbooks/` | Concrete implementation choices used by this repository | Varies by repo |
| Research and candidates | `03-research/` | Candidate adapters, comparative analysis, and implementation options | Reused as reference, non-normative |

See `instance/README.md` for a slot-by-slot map of what this repo installs.

## Portable Conventions For Adopting Repos

The following conventions are intended to be reused by any repo that adopts
the EposForge architecture.

Required conventions:

- Separate architecture definition, implementation, and research content.
- Use machine-readable doc classification metadata (for example:
  `doc_kind`, `scope`, `maturity`, `source_of_truth`).
- Require adapter metadata for each adapter per
  [01-architecture/00-adapter-pattern.md](01-architecture/00-adapter-pattern.md).
- Maintain a single adapter registry view that shows candidate vs implemented
  vs active status per component slot.

Repo-local conventions (customizable per adopting repo):

- Folder layout and naming details.
- CI/lint enforcement tooling.
- Runtime stack and specific adapter implementations.
- Rebuild and operational scripts.

## Documentation maintenance (Spec Graph)

This repo implements its own Spec Graph (Component 6) with two
adapters: **Cognee** (default) performs ontology-grounded extraction
from the Markdown corpus and writes normalized entities and
relationships into **Neo4j CE**, and **Microsoft GraphRAG** remains
installed as an opt-in fallback path for extraction and community
detection. Any MCP-compatible client (Claude Code, Gemini CLI,
Cursor, Goose, etc.) connects to Neo4j via the Neo4j MCP extension
and gains graph-augmented memory of the full architecture for
spec generation, ADR authoring, and consistency checks.

See [instance/SPEC.md](./instance/SPEC.md) for the Living Spec and
adapter registry, [instance/installed/06-spec-graph/cognee/cognee.md](./instance/installed/06-spec-graph/cognee/cognee.md)
for the default adapter, and [instance/installed/06-spec-graph/graphrag/README.md](./instance/installed/06-spec-graph/graphrag/README.md)
for the fallback adapter and current invocation surface.

## Status

Early. Vision, components, and maturity roadmaps are being extracted from
a private reference instance and generalized. Expect active iteration.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) — we
use the [Developer Certificate of Origin](https://developercertificate.org/)
sign-off for every commit. No CLA.

## License

Apache License, Version 2.0. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
