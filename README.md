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

EposForge does not pick implementations. Instances pick implementations.

## How to read this repo

```text
00-vision/         # Mission, pillars, principles, horizon
01-architecture/   # Adapter pattern, reference architecture, component contracts
02-roadmap/        # Maturity phases for Platform and Product factories
03-research/       # Surveys of products that can fill each component slot
```

This repo is docs-first. Code lands as components mature.

## Repository Layers

This repository has three distinct layers. Keep them separate in commits,
reviews, and docs so it is always clear what is normative architecture and
what is a concrete local implementation.

| Layer | Paths | Meaning | Portability |
|---|---|---|---|
| Architecture definition | `00-vision/`, `01-architecture/`, `02-roadmap/` | Normative EposForge pattern, contracts, and maturity models | Reused across adopting repos |
| Implementation for this repo instance | `SPEC.md`, `scripts/`, `graphrag/`, `docs/runbooks/` | Concrete implementation choices used by this repository | Varies by repo |
| Research and candidates | `03-research/` | Candidate adapters, comparative analysis, and implementation options | Reused as reference, non-normative |

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

This repo implements its own Spec Graph (Component 6) using Microsoft
GraphRAG + Neo4j CE. See [SPEC.md](./SPEC.md) for the Living Spec and
[graphrag/README.md](./graphrag/README.md) for setup instructions.
Run `bash scripts/spec-graph-rebuild.sh` after significant doc batches
to refresh the knowledge graph.

## Status

Early. Vision, components, and maturity roadmaps are being extracted from
a private reference instance and generalized. Expect active iteration.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) — we
use the [Developer Certificate of Origin](https://developercertificate.org/)
sign-off for every commit. No CLA.

## License

Apache License, Version 2.0. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
