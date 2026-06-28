---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Ontology and Knowledge Taxonomy Policy

## Status

- adopted: 2026-06-28
- supersedes: the previous "vocabulary" standard (see git history under 04-standards/02-vocabulary/)
- declined-options: none
- spec-version: n/a

## Scope

This standard governs policy for EposForge's combined domain **ontology** (OWL model of the dark factory pattern) and **knowledge taxonomy** (organization of the canonical tree using SKOS + reserved kinds like pillar/group/component/concept/guidance/tenet).

It covers:
- Reserved taxonomic node kinds and relationship keywords used in prose and extraction.
- Requirements that edits to the model happen in `00-vision/01-ontology.ttl` (which now explicitly mixes OWL for domain semantics and SKOS for the taxonomy layer).
- Editorial workflow executed via the `maintain-ontology` skill.

Markdown may describe terms but must not redefine semantics. This standard does not govern adopter-specific overlays.

## Normative requirements

1. `00-vision/01-ontology.ttl` MUST remain the single source combining the domain ontology (OWL) and knowledge taxonomy (SKOS + ef:kind discriminator).
2. Model edits MUST be authored in Turtle in `00-vision/01-ontology.ttl` (use OWL for domain classes/properties of the dark factory pattern; SKOS for taxonomy labels, definitions, and hierarchy on knowledge-tree items). Markdown MAY describe but MUST NOT redefine.
3. Editorial workflow (including the taxonomy vs. ontology distinction) MUST be executed through the `maintain-ontology` skill.
4. Reserved taxonomic node kinds for the knowledge tree (`pillar | group | component | concept | guidance | tenet`) and domain terms MUST be used exactly. Canonical definitions and SKOS/OWL modeling live in the TTL.
5. Relationship keywords for extraction MUST align with the ontology properties and taxonomy: `FULFILLS_SLOT`, `DEPENDS_ON`, `MATURES_TO`, `GOVERNED_BY`, `IMPLEMENTS`, `LEGACY_SHAPE_OF`, `TARGET_SHAPE_OF`, `HAS_COMPONENT`, `HAS_STATUS`, `KIND`, `LIFECYCLE_STATUS`.
6. Changes to reserved kinds, keywords, or the ontology/taxonomy split MUST update the TTL + maintain-ontology/SKILL.md (and usually AGENTS.md) together.
7. Knowledge taxonomy items (`concept`, `guidance`, `tenet`) SHOULD be modeled with both our ef: classes/kinds and skos:Concept (for labels and future hierarchy). See the owl-turtle-primer.

## Conformance

- Verify the ontology+taxonomy source: `rg "01-ontology.ttl|maintain-ontology|skos:" AGENTS.md skills/maintain-ontology 00-vision`.
- Verify reserved kinds + keywords appear in AGENTS.md, the skill, and are modeled (with SKOS where appropriate) in the TTL.
- Review PRs for paired updates on the TTL, skill, and AGENTS when changing kinds, keywords, or the OWL/SKOS split.
- Validate Turtle (including SKOS) parses cleanly before sync.

## Related

- [../00-standards-meta/standards-meta.md](../00-standards-meta/standards-meta.md)
- [../../00-vision/01-ontology.ttl](../../00-vision/01-ontology.ttl)
- [../../skills/maintain-ontology/SKILL.md](../../skills/maintain-ontology/SKILL.md) (now coaches SKOS)
- [../../skills/maintain-ontology/references/owl-turtle-primer.md](../../skills/maintain-ontology/references/owl-turtle-primer.md) (SKOS section added)
- [../../AGENTS.md](../../AGENTS.md)

## Notes on superseded standards

Superseded standards (such as the prior `02-vocabulary/vocabulary.md`) are removed from the working tree for readability. The supersession is declared in this file's Status section. Complete prior content is preserved in the git history. See `00-standards-meta/standards-meta.md` for the current policy.

## Agent and MCP Usage Model

Adopter agents access the EposForge knowledge via the Cognee MCP (recall, graph search).
- Prefer the SKOS layer (skos:inScheme on ef:KnowledgeTree, skos:broader/narrower, skos:prefLabel) for navigating the knowledge tree structure and classification.
- Use the OWL domain model and ef:kind for the dark factory pattern relationships and semantics.
- Agents should start with recall("EposForge MCP usage") or recall on the KnowledgeTree label.
A dedicated usage node (ef:EposForgeMCPUsage) and scopeNotes on the main schemes encode the current contract. These must be maintained when extending the taxonomy.

When editing, ensure new knowledge-tree items are linked into the SKOS scheme and have clear labels/definitions suitable for agent recall. See maintain-ontology skill for workflow.