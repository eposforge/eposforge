---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Repository Roles & Ownership

## The Adopter Platform Spec

An adopter should have a **single primary repo** that acts as the primary eposforge implementer in the environment.

This primary repo:

- Contains documentation about the overall eposforge implementation, for both product and platform factories.
- Includes the `.eposforge/` container (the adopted pattern slice under the stable component names).

EposForge instructs adopters to set it up that way. The primary adopter fills that role.

**Portfolio reviews should happen from this primary repo.**

See `skills/portfolio-review/SKILL.md` and the architecture plan/capture (tracked by EF-056/058).

## Terminology

- **Adopter Platform Spec**: the single primary repo (an adopting repository designated for the environment) as described above.
- **Platform Instance** (srv-docker-hp + IaC + concrete LAN): the actual running substrate and configuration.

## Living Spec Contract

Living Spec attaches to a **Product** (one current Spec per product),
not to every repo or shippable deliverable. Multi-repo products share
one Product Living Spec; specify episodes fold into it. See
`01-architecture/02-components/living-spec.md`.

Pattern-scale / adopter-scale work may use a **declared current corpus**
as one logical Spec (not an unbounded episode pile).

## Backlog Adapter Roles

The backlog adapter distinguishes `role = "substrate"` vs `"product"`. The primary repo for an adopter is typically substrate-oriented, with links (`Blocks:`) toward product-repo anchors.

See `01-architecture/02-components/backlog.md` and `.eposforge/backlog/file-based-backlog/file-based-backlog.md`.

## Cross-References

- EF-058: Terminology + repository roles & ownership section
- the architecture implementation plan and discussion capture docs (see `docs/`)
- `04-standards/07-adapter-layout-mirror/adapter-layout-mirror.md` (.eposforge/ container inside the primary repo)
