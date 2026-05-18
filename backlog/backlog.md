# Backlog

Active issues (`open`, `in-progress`, `blocked`) for this repo.

## Issue EF-001 — Initial corpus seed via cognee-sync against live backend
ID: EF-001
Title: Initial corpus seed via cognee-sync against live backend
Date: 2026-05-17
Status: open
Effort: M
Fix surface: repo-instance
Verify with: `cognee-sync --added` ingests current corpus and query returns expected entities

## Issue EF-002 — Git-based authoritative sync from server-side post-receive or CI workflow
ID: EF-002
Title: Git-based authoritative sync from server-side post-receive or CI workflow
Date: 2026-05-17
Status: open
Effort: L
Fix surface: infrastructure
Depends on: EF-001
Verify with: post-receive or CI trigger updates graph on merge to default branch

## Issue EF-003 — Add --reconcile-from-disk mode on cognee-sync CLI
ID: EF-003
Title: Add --reconcile-from-disk mode on cognee-sync CLI
Date: 2026-05-17
Status: open
Effort: M
Fix surface: repo-instance
Depends on: EF-001
Verify with: reconcile mode removes stale graph entities not present in source docs

## Issue EF-004 — Automate ontology re-upload path for .owl extension requirement
ID: EF-004
Title: Automate ontology re-upload path for .owl extension requirement
Date: 2026-05-17
Status: open
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-001
Verify with: ontology upload step runs from CLI without manual extension workaround

## Issue EF-005 — Self-hosted MCP server with adopter-extensible ontology and cognee KG
ID: EF-005
Title: Self-hosted MCP server with adopter-extensible ontology and cognee KG
Date: 2026-05-18
Status: open
Effort: XL
Fix surface: eposforge-pattern
Depends on: EF-001
Notes: Adopters host the EposForge MCP server themselves. The server supports (1) an adopter-owned TTL overlay that extends the canonical eposforge glossary ontology with implementation-specific classes and relationships, (2) ingestion of adopter docs into a cognee KG dataset that augments (not replaces) the base EposForge KG, and (3) MCP tools that ground agents in the adopter's iteratively-developing implementation — so agents can query "what have we built so far?" against both the pattern spec and the adopter's own context. Delivery likely splits: MCP server scaffold → ontology overlay mechanism → KG federation/namespace strategy → adopter onboarding docs.
Verify with: an adopter can (a) supply a custom .ttl file that is merged with the canonical ontology on upload, (b) ingest their own markdown/specs into a named adopter dataset in cognee, and (c) issue an MCP query that returns entities from both the base EposForge KG and their adoption-specific KG

## Issue EF-006 — Add instance-scoped TTL files for installed adapters
ID: EF-006
Title: Add instance-scoped TTL files for installed adapters
Date: 2026-05-18
Status: open
Effort: M
Fix surface: repo-instance
Verify with: SPARQL `?a rdf:type ef:ReferenceImplementation` against the merged graph returns each installed adapter with metadata matching its markdown card; the `efi:` namespace is used consistently for instance individuals and `ef:` is never used for them.

## Issue EF-007 — Resolve component-slot kind-class symmetry
ID: EF-007
Title: Resolve component-slot kind-class symmetry
Date: 2026-05-18
Status: open
Effort: S
Fix surface: eposforge-pattern
Verify with: ontology has either 0 or 14 component-slot kind-classes (currently 5 of 14: DevProduct, Router, ToolTransport, SpecGraph, ExecutionSandbox); whichever direction is taken, the result is uniform and documented.

## Issue EF-008 — Create 04-standards/02-vocabulary/ standard
ID: EF-008
Title: Create 04-standards/02-vocabulary/ standard
Date: 2026-05-18
Status: open
Effort: M
Fix surface: eposforge-pattern
Verify with: `04-standards/02-vocabulary/` exists, frontmatter matches existing standards (meta, naming-conventions, research-mirror); the `maintain-ontology` skill and AGENTS.md defer to it for editorial workflow.

## Issue EF-009 — Model the adoption relationship in the ontology
ID: EF-009
Title: Model the adoption relationship in the ontology
Date: 2026-05-18
Status: open
Effort: S
Fix surface: eposforge-pattern
Depends on: EF-006
Verify with: an `ef:adoptsFrom` (or equivalent) object property is defined with appropriate domain/range; at least one Adopter-scoped adapter declares `?adapter ef:adoptsFrom ?ref` linking to an `ef:ReferenceImplementation`; SPARQL returns the expected pairs. Skip if the operational pattern (agent reads markdown card) is judged sufficient — close with a rationale comment.
