# DarkForge

> Open-source dark factory: declarative specs in, production artifacts out.
> Vendor-agnostic orchestration that ships software today and unifies platform
> ops and physical (robotics) execution tomorrow.

---

## What this is

DarkForge is the open, vendor-agnostic **pattern** for a dark factory — a
fully agentic software, platform, and (eventually) physical-execution
factory driven by declarative intent. You describe what should exist;
the factory builds, deploys, and operates it.

DarkForge defines:

- A **vision** for unified intent execution across software, platform, and
  physical substrates.
- A set of **architectural components** (slots) every dark factory needs.
- A universal **Adapter Pattern** that plugs concrete products into those
  slots without locking the factory to any one vendor.
- **Maturity roadmaps** for both the Platform Factory (ops autonomy) and
  the Product Factory (dev autonomy).
- A **research catalog** of candidate Adapters so you don't reinvent the
  wheel.

DarkForge does not pick implementations. Instances pick implementations.

## How to read this repo

```text
00-vision/         # Mission, pillars, principles, horizon
01-architecture/   # Adapter pattern, reference architecture, component contracts
02-roadmap/        # Maturity phases for Platform and Product factories
03-research/       # Surveys of products that can fill each component slot
```

This repo is docs-first. Code lands as components mature.

## Status

Early. Vision, components, and maturity roadmaps are being extracted from
a private reference instance and generalized. Expect active iteration.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) — we
use the [Developer Certificate of Origin](https://developercertificate.org/)
sign-off for every commit. No CLA.

## License

Apache License, Version 2.0. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
