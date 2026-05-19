# Backlog Archive

Resolved issues are grouped by month (`## YYYY-MM`).

## 2026-05



## Issue EF-007 — Resolve component-slot kind-class symmetry
ID: EF-007
Title: Resolve component-slot kind-class symmetry
Date: 2026-05-18
Status: resolved
Effort: S
Fix surface: eposforge-pattern
Verify with: ontology has either 0 or 14 component-slot kind-classes (currently 5 of 14: DevProduct, Router, ToolTransport, SpecGraph, ExecutionSandbox); whichever direction is taken, the result is uniform and documented.
Validation: Added the missing nine adapter kind-classes so ontology slot-kind symmetry is now 14 of 14 and uniformly modeled in `00-vision/01-ontology.ttl`.
Resolved: 2026-05-18

## Issue EF-008 — Create 04-standards/02-vocabulary/ standard
ID: EF-008
Title: Create 04-standards/02-vocabulary/ standard
Date: 2026-05-18
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Verify with: `04-standards/02-vocabulary/` exists, frontmatter matches existing standards (meta, naming-conventions, research-mirror); the `maintain-ontology` skill and AGENTS.md defer to it for editorial workflow.
Validation: Added `04-standards/02-vocabulary/vocabulary.md`, listed it in `04-standards/README.md`, and updated AGENTS plus the maintain-ontology skill to defer editorial workflow to that standard.
Resolved: 2026-05-18

## Issue EF-006 — Add instance-scoped TTL files for installed adapters
ID: EF-006
Title: Add instance-scoped TTL files for installed adapters
Date: 2026-05-18
Status: resolved
Resolved: 2026-05-18
Effort: M
Fix surface: repo-instance
Verify with: SPARQL `?a rdf:type ef:ReferenceImplementation` against the merged graph returns each installed adapter with metadata; efi: namespace used consistently for instance individuals.
Validation: cognee-sync --added ingested ontology + reference-implementations.ttl without errors; state DB confirms 12 efi: adapter individuals tracked (data_id 25449d0a); efi: namespace used consistently, ef: reserved for ontology terms.


## Issue EF-009 — Model the adoption relationship in the ontology
ID: EF-009
Title: Model the adoption relationship in the ontology
Date: 2026-05-18
Status: resolved
Resolved: 2026-05-18
Effort: S
Fix surface: eposforge-pattern
Depends on: EF-006
Verify with: ef:adoptsFrom object property defined with domain/range; at least one adapter declares ?adapter ef:adoptsFrom ?ref linking to an ef:ReferenceImplementation; SPARQL returns expected pairs.
Validation: cognee-sync --added ingested adoption-links.ttl without errors; ef:adoptsFrom defined in ontology with efi:acme-copilot-adapter ef:adoptsFrom efi:copilot as verification triple; state DB confirms tracking (data_id 790fab00).

## Issue EF-001 — Initial corpus seed via cognee-sync against live backend
ID: EF-001
Title: Initial corpus seed via cognee-sync against live backend
Date: 2026-05-17
Status: resolved
Resolved: 2026-05-18
Effort: M
Fix surface: repo-instance
Verify with: `cognee-sync --added` ingests current corpus and query returns expected entities
Validation: cognee-sync --added seeded all 79 git-tracked .md files plus ontology and 2 instance TTL files (82 documents total); all reported `add` without errors; state DB confirms full tracking.
