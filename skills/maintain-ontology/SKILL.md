---
name: maintain-ontology
description: Keeps 00-vision/01-ontology.ttl well-formed, internally consistent, and aligned with adapter cards under instance/ so Cognee extraction remains ontology-grounded.
---

Maintains `00-vision/01-ontology.ttl` — the EposForge file that combines the domain **ontology** (OWL: the dark factory pattern model) and **knowledge taxonomy** (SKOS + ef:kind: the canonical tree organization of concepts, guidance, tenets, pillars, etc.). It grounds Cognee entity extraction for the Spec Graph so agents receive consistent, pattern-aligned knowledge.

This skill implements the editorial workflow. Distinguish:
- Domain ontology (OWL classes like ef:Component, properties like fulfillsSlot) — the *pattern*.
- Knowledge taxonomy (SKOS for labels/hierarchy on tree items + our NodeKind discriminator) — how we *organize what we know*.

The TTL remains the single source of truth. See also the updated owl-turtle-primer for SKOS usage. `04-standards/02-vocabulary/vocabulary.md` still governs reserved terms and policy (we are evolving its name toward "ontology policy").

Primary purpose: keep the ontology internally coherent and aligned with installed adapter cards so entities extracted by Cognee remain anchored to stable EposForge IRIs. This enables external EposForge consumers to point their agents at the EposForge Cognee MCP server and use graph-backed guidance to automate dark-factory design and creation.

If this ontology drifts, consumer agents can still query Cognee MCP, but the guidance quality degrades (missing entities, weak relationships, or inconsistent terminology). This skill exists to prevent that drift.

## Prerequisites

- `00-vision/01-ontology.ttl` — the ontology file under review
- previous ontology-grounded KG state via Cognee MCP when available — use it as the last published graph-backed memory of the ontology, not as authority over newer unrebuild corpus changes
- `git log` — commit history to detect drift
- adapter cards and specs — `instance/`, `instance/SPEC.md`, and core spec files under `00-vision/`, `01-architecture/`, `02-roadmap/`, `04-standards/`
- [owl-turtle-primer](./references/owl-turtle-primer.md) — OWL/Turtle reference (load when coaching is needed)

## Detect drift from git history

Find the last commit that edited `00-vision/01-ontology.ttl`. Then collect relevant spec and adapter-card changes between that commit and HEAD.

```bash
git log --oneline -- 00-vision/01-ontology.ttl
```

Store the most recent hash as `$last`. Then list changed markdown files:

```bash
git diff --name-only "${last}..HEAD" -- "*.md"
```

For each changed file, inspect the diff to identify new terms, new relationship keywords, new component docs, or new status values:

```bash
git diff "${last}..HEAD" -- <file>
```

The `drift report` is the list of changed files and the new concepts or relationships found in their diffs.

## Query the previous KG first when available

When Cognee MCP is available, query the most recent ontology-grounded KG before editing the TTL. Use it as the last rebuilt memory of what the ontology already meant in graph form.

Ask for:

- the candidate term itself
- nearby related concepts already in the graph
- existing aliases or overlapping labels
- current relationship structure around the candidate term

Use the KG to answer: "what did the last ontology-backed graph already think this term meant?"

Important constraint:

- if the KG predates recent conceptual work, treat it as previous-state evidence only
- the current corpus and `00-vision/01-ontology.ttl` remain the source of truth for the next edit
- if Cognee is unavailable or stale, fall back to repo files and the drift report

This is specifically useful for the adopted editorial doctrine already modeled in the ontology: the tenet `Randian concept formation`; the concepts `Rule of Fundamentality`, `measurement-omission`, `contextual essentiality`, and `explanatory power`; and the guidance `essential-characteristic node selection`.

The `previous-kg report` is the set of nearest existing graph terms and relationships around the candidate concept.

## Apply the concept-formation gate before minting terms

Before adding a new class, property, or individual to the TTL, force the proposal through the adopted concept-formation gate:

1. Name the units being grouped.
2. State the proposed essential characteristic.
3. Test whether that characteristic explains the greatest number of other characteristics of those units.
4. Check whether the characteristic is present across different measures or variants rather than being a one-off surface feature.
5. Ask whether this is the deepest available distinction supported by current knowledge, or whether a later/more abstract/sibling term already captures it.

If the proposal fails these checks:

- do not mint a new ontology term
- prefer an alias on an existing term, a prose explanation in guidance, or no explicit modeling yet

This is the engineering-use slice of Rand's epistemology adopted by EposForge. The goal is not to encode philosophy for its own sake; the goal is to keep the ontology grounded in explanatory structure so Cognee extraction stays useful.

## Scan corpus for ontology impacts

Walk the spec and adapter corpus in order, looking for concepts not yet modeled in the ontology.

**Scan targets and what to look for:**

| File / Glob | Signal | Maps to |
|---|---|---|
| `00-vision/01-ontology.ttl` | Existing class/property model | Baseline consistency |
| `01-architecture/00-adapter-pattern/adapter-pattern.md` | Metadata field names, status values | Properties, `AdapterStatus` individuals |
| `01-architecture/02-components/*.md` | Component names (one file = one Component individual) | `ef:Component` individuals |
| `02-roadmap/*.md` | Phase names (Phase 0–4, A–F) | `ef:Phase` individuals |
| `04-standards/**/*.md` | Standard titles, relationship keywords | `ef:Standard` individuals |
| `instance/**/*.md` | Adapter status/capabilities and slot mapping | `ef:Adapter` model alignment |
| `AGENTS.md` | RELATIONSHIP KEYWORDS in caps | Object properties |
| `.scratchpad/knowledge-tree.txt` | Node kind tags (`[concept]`, `[guidance]`, `[tenet]`, `[group]`) | `ef:Concept`, `ef:Guidance`, `ef:Tenet`, `ef:Group` individuals |
| previous Cognee KG state | last rebuilt meaning/aliases/nearby edges for existing terms | editorial disambiguation before minting new terms |

**Relationship keywords to detect (from AGENTS.md):**

- `FULFILLS_SLOT`, "fulfills", "fills slot" -> `ef:fulfillsSlot`
- `DEPENDS_ON`, "depends on", "requires" -> `ef:dependsOn`
- `MATURES_TO`, "matures", "operational at phase" -> `ef:maturesTo`
- `GOVERNED_BY`, "governed by", "enforced by" -> `ef:governedBy`
- `IMPLEMENTS`, "implements" -> `ef:implements`
- `LEGACY_SHAPE_OF`, `TARGET_SHAPE_OF` -> `ef:legacyShapeOf`, `ef:targetShapeOf`
- `HAS_COMPONENT` -> `ef:hasComponent`
- `HAS_STATUS` -> `ef:hasStatus` (Adapters only)
- `KIND` -> `ef:kind` (node kind discriminator: pillar|group|component|concept|guidance|tenet)
- `LIFECYCLE_STATUS` -> `ef:lifecycleStatus` (Concept/Guidance/Tenet only: proposed|adopted|retired)

The `gap report` is the set of concepts and relationships found in the corpus but absent from the TTL.

## Apply TTL edits

For each item in the `gap report`, model it in `00-vision/01-ontology.ttl` following these rules:

**New Class** (domain ontology — a *type* of thing in the dark factory pattern):
```turtle
ef:MyClass rdf:type owl:Class ;
    rdfs:label "My Class" ;
    rdfs:comment "One-sentence definition from the glossary." .
```

**Subclass** (specialization in the domain model):
```turtle
ef:MySubclass rdf:type owl:Class ;
    rdfs:subClassOf ef:ParentClass ;
    rdfs:label "My Subclass" ;
    rdfs:comment "Definition." .
```

**New Object Property** (domain relation):
```turtle
ef:myRelation rdf:type owl:ObjectProperty ;
    rdfs:label "MY_RELATION" ;
    rdfs:domain ef:SubjectClass ;
    rdfs:range ef:ObjectClass .
```
Omit domain/range when open.

**Knowledge tree item** (use SKOS for taxonomy layer + our kinds):
```turtle
ef:MyConcept rdf:type ef:Concept, skos:Concept ;
    skos:prefLabel "My Concept" ;
    skos:definition "..." ;
    ef:kind ef:NodeKindConcept ;
    ef:lifecycleStatus ef:StatusAdopted .
```

**New Individual** (domain or taxonomy item belonging to a class):
```turtle
ef:MyThing rdf:type ef:MyClass ;
    rdfs:label "My Thing" ;
    rdfs:comment "Optional detail." .
```

**Placement rules:**
- New classes -> add under `### Classes`, in alphabetical order within logical groupings
- New properties -> add under `### Object Properties (Relationships)`
- New component individuals -> add under `### Individuals (The 14 Core Components)`, update the count in the heading if adding
- New status individuals -> add under `### Adapter Status Individuals`
- New node kind individuals -> add under `### Node Kind Discriminator`
- New lifecycle status individuals -> add under `### Lifecycle Status`
- New Concept/Guidance/Tenet individuals -> add under a new `### Knowledge-Tree Individuals` section before the `### Adapter Status Individuals` section

After editing, verify the file is syntactically valid Turtle (no unclosed blocks, every statement ends with `.`).

Also verify the editorial rationale still passes the concept-formation gate: the new term should survive comparison against the nearest existing graph terms from the previous KG and the nearest current-corpus neighbors.

## Rebuild the graph after editing

A TTL edit does not change the live graph on its own — Cognee only re-anchors at cognify time, and its content-hash dedup skips re-extraction of unchanged docs. So editing the ontology requires a **full rebuild with a KG wipe**, not an incremental sync. Hand off to [update-spec-graph](../update-spec-graph/SKILL.md) to run it; that skill owns the wipe + `bulk-rebuild.sh` flow and the verification that anchoring took. Document-only changes stay incremental and are also handled there.

## Coach on OWL/Turtle + SKOS

Load `[owl-turtle-primer](./references/owl-turtle-primer.md)` (now includes SKOS section) when the user asks about modeling. Key topics:

- OWL for *domain ontology* (dark factory pattern classes/properties/constraints)
- SKOS for *knowledge taxonomy* (labels, definitions, hierarchy on tree items + ef:kind)
- Triple structure, shortcuts, Class vs Individual vs Property
- When a knowledge item should be typed as both ef:XXX and skos:Concept
- How Cognee uses the combined ontology (anchoring + richer properties)

## Outputs

- `drift report` — markdown files changed since last TTL edit, with new concepts highlighted
- `previous-kg report` — existing ontology-grounded graph terms relevant to the candidate concept, when Cognee is available
- `gap report` — concepts and relationships in the corpus not yet modeled in the TTL
- updated `00-vision/01-ontology.ttl` — ontology with all identified gaps closed
- `consumer guidance readiness` — confirmation that ontology-backed graph terms remain aligned for agent use through the EposForge Cognee MCP server
