# OWL / Turtle Primer for EposForge

Reference for maintaining `00-vision/01-ontology.ttl`. Covers the syntax and
OWL semantics used in this file.

---

## What is RDF?

RDF (Resource Description Framework) is a data model built entirely from
**triples**: `subject -> predicate -> object`. Every fact is one triple.
A collection of triples is a graph.

```
ef:Adapter  rdf:type  owl:Class .
subject     predicate  object
```

Everything is identified by a URI. The `@prefix` declarations at the top of
the file let you write short names instead of full URIs:

```turtle
@prefix ef: <http://eposforge.org/ontology/> .

ef:Adapter   ->   <http://eposforge.org/ontology/Adapter>
```

---

## Turtle syntax shortcuts

Turtle is a compact syntax for writing RDF. Two key shortcuts:

**Semicolon `;`** - same subject, new predicate:
```turtle
ef:Adapter rdf:type owl:Class ;     <- Adapter is a Class
    rdfs:label "Adapter" ;           <- Adapter has label "Adapter"
    rdfs:comment "..." .             <- Adapter has comment "..."
                   ^ dot ends the subject block
```

**Comma `,`** - same subject AND predicate, new object:
```turtle
ef:myProp rdfs:domain ef:Adapter, ef:Agent .
```
(Adapter and Agent are both valid domains for myProp.)

---

## The three layers of this ontology

### 1. Classes (`owl:Class`)

A class describes a *type* of thing. Think of it like a table definition in a
database - it names a category but does not put any rows in it.

```turtle
ef:Component rdf:type owl:Class ;
    rdfs:label "Component" ;
    rdfs:comment "An architectural slot in a dark factory." .
```

Use a class when the concept describes a *kind* of thing that multiple
instances of it can exist (e.g. many Components exist, many Adapters exist).

**Subclass** - use `rdfs:subClassOf` when one class is a specialization of
another. All members of the subclass are automatically members of the parent:

```turtle
ef:LivingSpec rdf:type owl:Class ;
    rdfs:subClassOf ef:Spec ;   <- every LivingSpec is also a Spec
    rdfs:label "Living Spec" .
```

### 2. Object Properties (`owl:ObjectProperty`)

A property defines a *kind of edge* that can exist between two nodes. It does
not assert that any particular edge exists - it just declares the edge type.

```turtle
ef:fulfillsSlot rdf:type owl:ObjectProperty ;
    rdfs:label "FULFILLS_SLOT" ;
    rdfs:domain ef:Adapter ;     <- the subject of this edge is an Adapter
    rdfs:range  ef:Component .   <- the object of this edge is a Component
```

`rdfs:domain` and `rdfs:range` are constraints. Omit them when the
relationship is open-ended and applies across many types (e.g. `ef:dependsOn`
- anything can depend on anything).

### 3. Individuals (named instances)

An individual is a *specific named thing* that belongs to a class.

```turtle
ef:SpecGraphComponent rdf:type ef:Component ;
    rdfs:label "Spec Graph" .
```

This says "there is a thing called SpecGraphComponent, and it is a Component."
This is like inserting a row in the database.

---

## Class vs. Individual: how to decide

| The concept is... | Model as |
|---|---|
| A *category* (many things are this type) | Class |
| A *specific named thing* (one thing, referenced by name) | Individual |
| A *named relationship* between two things | Object Property |

Examples in this ontology:
- `ef:Component` is a **Class** - many components exist
- `ef:SpecGraphComponent` is an **Individual** - the one Spec Graph slot
- `ef:fulfillsSlot` is a **Property** - the relationship "fills this slot"
- `ef:AdapterStatus` is a **Class** - the category of status values
- `ef:AdapterStatusShelved` is an **Individual** - the specific status "shelved"

## Adding SKOS for the Knowledge Taxonomy (in addition to OWL)

The ontology mixes two concerns:

- **Domain ontology (OWL)**: The formal model of the *dark factory pattern* itself (ef:Component, ef:Adapter, ef:fulfillsSlot, phases, constraints). Use `owl:Class`, `owl:ObjectProperty`, `rdfs:subClassOf`, domain/range.

- **Knowledge taxonomy (SKOS)**: How we *organize* EposForge's own knowledge (the canonical tree of pillars, groups, concepts, guidance, tenets). Use `skos:Concept`, `skos:ConceptScheme`, `skos:prefLabel`, `skos:altLabel`, `skos:definition`, and later `skos:broader`/`skos:narrower` for hierarchy.

We declare both in the same file because Cognee anchors to one uploaded ontology. SKOS concepts can also be typed as OWL individuals or our ef: kinds.

Example (see 01-ontology.ttl):

```turtle
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .

ef:NodeKind rdf:type owl:Class, skos:ConceptScheme ;
    skos:prefLabel "Node Kind" .

ef:NodeKindConcept rdf:type ef:NodeKind, skos:Concept ;
    skos:prefLabel "concept" ;
    skos:definition "..." .

ef:SomeConcept rdf:type ef:Concept, skos:Concept ;
    skos:prefLabel "Rule of Fundamentality" ;
    skos:altLabel "essential characteristic" ;
    ef:kind ef:NodeKindConcept .
```

**When to use which:**
- New *pattern concept* (e.g. a new type of Adapter or relation) → OWL class or property.
- New *knowledge item* in the tree (a specific concept, guidance, or tenet we teach agents) → primarily SKOS Concept + our ef:kind and lifecycle.
- Need hierarchy or preferred labels for the tree → SKOS.

This makes extraction more precise and gives agents richer structured data (labels, definitions, broader/narrower paths).

---

## The `ef:` namespace

All EposForge terms use the prefix `ef:` which expands to
`http://eposforge.org/ontology/`. This is a stable namespace - Cognee anchors
extracted entities to these URIs. Do not change existing URIs; add new ones
only.

**Naming convention:**
- Classes: `UpperCamelCase` -> `ef:AdapterStatus`
- Properties: `lowerCamelCase` -> `ef:fulfillsSlot`
- Individuals: descriptive `UpperCamelCase` -> `ef:AdapterStatusShelved`
- Property labels: `UPPER_SNAKE_CASE` (matches AGENTS.md keywords) -> `"FULFILLS_SLOT"`

---

## How Cognee uses this file

When Cognee ingests a markdown file with `cognee-sync`, it runs an entity
extraction step called *cognify*. The ontology is uploaded to Cognee first;
during cognify, extracted entities are *grounded* - matched to the class IRIs
defined here. This means:

- A doc mentioning "the Spec Graph adapter fulfills the Spec Graph slot"
  can produce a triple: `<cognee-adapter-node> ef:fulfillsSlot ef:SpecGraphComponent`
- The graph query layer can then traverse typed edges

If a concept appears in the docs but has no class in the ontology, Cognee
extracts it as an untyped node - it exists in the graph but cannot be
reasoned over by class. That is why keeping the ontology in sync matters.

---

## Common patterns

**Adding a new component (13th, 14th, ...):**
```turtle
ef:MyNewComponent rdf:type ef:Component ; rdfs:label "My New Component" .
```
Also update the `### Individuals (The N Core Components)` heading count.

**Adding a new relationship keyword from AGENTS.md:**
```turtle
ef:newRelation rdf:type owl:ObjectProperty ;
    rdfs:label "NEW_RELATION" .
```
If the domain and range are known, add them. If open, omit.

**Adding a new standard:**
```turtle
ef:NamingConventionsStandard rdf:type ef:Standard ;
    rdfs:label "Naming Conventions" ;
    rdfs:comment "Governs file naming, heading style, and documentation hygiene." .
```

**Modeling a deprecation/supersession:**
```turtle
ef:OldClass ef:supersedes ef:NewClass .
```
or set `owl:deprecated true` on the old class:
```turtle
ef:OldClass owl:deprecated "true"^^xsd:boolean .
```

---

## Validating syntax

Quick check - pipe through `rapper` (if installed) or paste into an online
Turtle validator:

```bash
rapper -i turtle 00-vision/01-ontology.ttl
```

Signs of a broken file:
- A statement missing its closing `.`
- An unclosed `;` block where the next subject starts without a `.`
- A URI prefix used before it is declared with `@prefix`
