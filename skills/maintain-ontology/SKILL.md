---
name: maintain-ontology
description: Synchronizes 00-vision/01-glossary.ttl with the EposForge markdown corpus. Use when updating the ontology after doc changes, auditing for missing classes or relationships, or getting coaching on how to model a new term in OWL/Turtle.
---

Maintains `00-vision/01-glossary.ttl` — the EposForge OWL ontology that grounds Cognee entity extraction for the Spec Graph. The ontology must stay in sync with the markdown corpus; Cognee uses it to anchor extracted entities to defined IRIs.

## Prerequisites

- `00-vision/01-glossary.ttl` — the ontology file under review
- `git log` — commit history to detect drift
- markdown corpus — `00-vision/`, `01-architecture/`, `02-roadmap/`, `04-standards/` spec files
- `[owl-turtle-primer](./references/owl-turtle-primer.md)` — OWL/Turtle reference (load when coaching is needed)

## Detect drift from git history

Find the last commit that edited `00-vision/01-glossary.ttl`. Then collect all markdown changes between that commit and HEAD.

```bash
git log --oneline -- 00-vision/01-glossary.ttl
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

## Scan corpus for missing concepts

Walk the markdown corpus in order, looking for concepts not yet modeled in the TTL.

**Scan targets and what to look for:**

| File / Glob | Signal | Maps to |
|---|---|---|
| `00-vision/01-glossary.md` | Bold terms `**term**` | Classes |
| `01-architecture/00-adapter-pattern.md` | Metadata field names, status values | Properties, `AdapterStatus` individuals |
| `01-architecture/02-components/*.md` | Component names (one file = one Component individual) | `ef:Component` individuals |
| `02-roadmap/*.md` | Phase names (Phase 0–4, A–F) | `ef:Phase` individuals |
| `04-standards/**/*.md` | Standard titles, relationship keywords | `ef:Standard` individuals |
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

For each item in the `gap report`, model it in `00-vision/01-glossary.ttl` following these rules:

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
- updated `00-vision/01-glossary.ttl` — ontology with all identified gaps closed
