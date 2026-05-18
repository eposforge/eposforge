---
name: maintain-ontology
description: Keeps 00-vision/01-ontology.ttl well-formed, internally consistent, and aligned with adapter cards under instance/installed/ so Cognee extraction remains ontology-grounded.
---

Maintains `00-vision/01-ontology.ttl` — the EposForge OWL ontology that grounds Cognee entity extraction for the Spec Graph.

This skill implements the editorial workflow defined by `04-standards/02-vocabulary/vocabulary.md`.

Primary purpose: keep the ontology internally coherent and aligned with installed adapter cards so entities extracted by Cognee remain anchored to stable EposForge IRIs. This enables external EposForge consumers to point their agents at the EposForge Cognee MCP server and use graph-backed guidance to automate dark-factory design and creation.

If this ontology drifts, consumer agents can still query Cognee MCP, but the guidance quality degrades (missing entities, weak relationships, or inconsistent terminology). This skill exists to prevent that drift.

## Prerequisites

- `00-vision/01-ontology.ttl` — the ontology file under review
- `git log` — commit history to detect drift
- adapter cards and specs — `instance/installed/`, `instance/SPEC.md`, and core spec files under `00-vision/`, `01-architecture/`, `02-roadmap/`, `04-standards/`
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

## Scan corpus for ontology impacts

Walk the spec and adapter corpus in order, looking for concepts not yet modeled in the ontology.

**Scan targets and what to look for:**

| File / Glob | Signal | Maps to |
|---|---|---|
| `00-vision/01-ontology.ttl` | Existing class/property model | Baseline consistency |
| `01-architecture/00-adapter-pattern.md` | Metadata field names, status values | Properties, `AdapterStatus` individuals |
| `01-architecture/02-components/*.md` | Component names (one file = one Component individual) | `ef:Component` individuals |
| `02-roadmap/*.md` | Phase names (Phase 0–4, A–F) | `ef:Phase` individuals |
| `04-standards/**/*.md` | Standard titles, relationship keywords | `ef:Standard` individuals |
| `instance/installed/**/*.md` | Adapter status/capabilities and slot mapping | `ef:Adapter` model alignment |
| `AGENTS.md` | RELATIONSHIP KEYWORDS in caps | Object properties |

**Relationship keywords to detect (from AGENTS.md):**

- `FULFILLS_SLOT`, "fulfills", "fills slot" -> `ef:fulfillsSlot`
- `DEPENDS_ON`, "depends on", "requires" -> `ef:dependsOn`
- `MATURES_TO`, "matures", "operational at phase" -> `ef:maturesTo`
- `GOVERNED_BY`, "governed by", "enforced by" -> `ef:governedBy`
- `IMPLEMENTS`, "implements" -> `ef:implements`
- `LEGACY_SHAPE_OF`, `TARGET_SHAPE_OF` -> `ef:legacyShapeOf`, `ef:targetShapeOf`
- `HAS_COMPONENT` -> `ef:hasComponent`
- `HAS_STATUS` -> `ef:hasStatus`

The `gap report` is the set of concepts and relationships found in the corpus but absent from the TTL.

## Apply TTL edits

For each item in the `gap report`, model it in `00-vision/01-ontology.ttl` following these rules:

**New Class** (concept that describes a *type* of thing):
```turtle
ef:MyClass rdf:type owl:Class ;
    rdfs:label "My Class" ;
    rdfs:comment "One-sentence definition from the glossary." .
```

**Subclass** (concept that is a specialization of another):
```turtle
ef:MySubclass rdf:type owl:Class ;
    rdfs:subClassOf ef:ParentClass ;
    rdfs:label "My Subclass" ;
    rdfs:comment "Definition." .
```

**New Object Property** (relationship between two things):
```turtle
ef:myRelation rdf:type owl:ObjectProperty ;
    rdfs:label "MY_RELATION" ;
    rdfs:domain ef:SubjectClass ;
    rdfs:range ef:ObjectClass .
```
Omit `rdfs:domain` / `rdfs:range` when the relationship is open (applies across many types).

**New Individual** (a specific named thing that belongs to a class):
```turtle
ef:MyThing rdf:type ef:MyClass ;
    rdfs:label "My Thing" ;
    rdfs:comment "Optional detail." .
```

**Placement rules:**
- New classes -> add under `### Classes`, in alphabetical order within logical groupings
- New properties -> add under `### Object Properties (Relationships)`
- New component individuals -> add under `### Individuals (The N Core Components)`, update the count in the heading
- New status individuals -> add under `### Adapter Status Individuals`

After editing, verify the file is syntactically valid Turtle (no unclosed blocks, every statement ends with `.`).

## Coach on OWL/Turtle

Load `[owl-turtle-primer](./references/owl-turtle-primer.md)` when the user asks about TTL syntax, OWL semantics, or how to model a specific concept. Key coaching topics covered there:

- Triple structure and Turtle syntax shortcuts (`;`, `,`)
- When to use a Class vs. an Individual vs. a Property
- `rdfs:subClassOf` for inheritance
- `rdfs:domain` and `rdfs:range` constraints
- This ontology's `ef:` namespace and naming conventions
- How Cognee uses this file during cognify

## Outputs

- `drift report` — markdown files changed since last TTL edit, with new concepts highlighted
- `gap report` — concepts and relationships in the corpus not yet modeled in the TTL
- updated `00-vision/01-ontology.ttl` — ontology with all identified gaps closed
- `consumer guidance readiness` — confirmation that ontology-backed graph terms remain aligned for agent use through the EposForge Cognee MCP server
