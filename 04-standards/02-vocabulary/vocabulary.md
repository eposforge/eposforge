---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Vocabulary

## Status

- adopted: 2026-05-18
- supersedes: none
- declined-options: none
- spec-version: n/a

## Scope

This standard governs the ontology and editorial workflow for EposForge vocabulary terms and relationship keywords.

This standard does not govern ontology overlays that adopters add in their own instances.

## Normative requirements

1. `00-vision/01-ontology.ttl` MUST remain the canonical ontology for EposForge vocabulary classes, properties, and named individuals.
2. Vocabulary edits MUST be authored in OWL/Turtle directly in `00-vision/01-ontology.ttl`; markdown files MAY describe terms but MUST NOT redefine ontology semantics.
3. Ontology editing workflow MUST be executed through the `maintain-ontology` skill guidance (`skills/maintain-ontology/SKILL.md`).
4. Entity types used in architecture docs and workflows MUST use this reserved set: `component`, `adapter`, `phase`, `pillar`, `principle`, `factory`, `deliverable`, `constraint`, `concept`, `guidance`, `tenet`, `group`. The canonical definitions for `concept`, `guidance`, `tenet`, and `group` are in `00-vision/01-ontology.ttl` (EF-019); that file is the source of truth.
5. Relationship keywords used for graph extraction MUST stay aligned with ontology object properties: `FULFILLS_SLOT`, `DEPENDS_ON`, `MATURES_TO`, `GOVERNED_BY`, `IMPLEMENTS`, `LEGACY_SHAPE_OF`, `TARGET_SHAPE_OF`, `HAS_COMPONENT`, `HAS_STATUS`, `KIND`, `LIFECYCLE_STATUS`.
6. Any change to reserved entity types or relationship keywords MUST update both `00-vision/01-ontology.ttl` and `skills/maintain-ontology/SKILL.md` in the same change.
7. Vocabulary kind schemas (`concept`, `guidance`, `tenet`) MUST be defined in `00-vision/01-ontology.ttl` as OWL classes. Prose elaboration in markdown is permitted but MUST NOT redefine or contradict the ontology.

## Conformance

- Verify ontology canonical source with: `rg "01-ontology.ttl|maintain-ontology" AGENTS.md 04-standards skills/maintain-ontology`.
- Verify required relationship keywords are present in guidance and ontology labels by searching `AGENTS.md`, `skills/maintain-ontology/SKILL.md`, and `00-vision/01-ontology.ttl`.
- Review pull requests for paired updates when reserved types or relationship keywords change.

## Related

- [../00-standards-meta/standards-meta.md](../00-standards-meta/standards-meta.md)
- [../../00-vision/01-ontology.ttl](../../00-vision/01-ontology.ttl)
- [../../skills/maintain-ontology/SKILL.md](../../skills/maintain-ontology/SKILL.md)
- [../../AGENTS.md](../../AGENTS.md)