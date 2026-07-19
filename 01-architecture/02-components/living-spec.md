---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 2: Living Spec

## Purpose

The durable, **current** canonical description of a **Product** (Product
Factory) — or, for Platform Factory work, of a **platform capability**
at the same grain (one coherent capability the factory operates, not
every script or repo).

The Living Spec is the source of truth for **what that product (or
platform capability) is supposed to do**. Fulfillment artifacts (code,
config, automations across one or more repos) **implement** it.

### Why Product — not “every deliverable / repo / specify run”

If Living Spec attached to every repo, package, or change episode, you
get the same failure as Spec Kit folders: many partial docs, unclear
supersession, and “what is true now?” becomes an amalgamation exercise.
**Living Spec is HEAD of product intent**, not a pile of memoirs.

| Term | Meaning | Living Spec? |
| --- | --- | --- |
| **Product** | Operator-authored application or capability the Product Factory builds (`ef:Product`). Coherent unit of user/operator value. | **Yes — one current Living Spec per Product** |
| **Platform capability** | Coherent Platform Factory automation/ops capability (same Spec grain as Product for platform work). | **Yes — one current Living Spec per capability** |
| **Repo / package / service** | Implementation surface that **fulfills** part or all of a Product. Multi-repo products still share **one** Product Living Spec. | No separate competing Living Spec (optional thin module notes only) |
| **Deliverable** | Shippable **output** the factory produces (release artifact, deployed unit, built package). Instance/result of building a Product or platform capability — **not** the Spec attachment unit. | No |
| **Specify / Spec Kit episode** | Change proposal / work package for a slice of work. | **No** — delta/history; must **fold into** the Product Living Spec when applied |

### Multi-repo products

One Product may span several repos (e.g. API + assistant + shared lib).
That does **not** mean several Living Specs:

- **One Product Living Spec** (current intent for the whole product).
- Repos are fulfillment surfaces; paired-change updates the Product Spec
  plus the code that implements the changed behavior (wherever it lives).
- Product Spec may be structured by module/section for navigation; those
  are sections of **one** Spec, not peer SoTs.
- Spec Graph projects **Products’** Living Specs (and platform
  capability Specs), not every repo’s ad hoc docs.

Where the Spec file lives is an Adapter choice (primary product repo,
`docs/` monorepo layout, etc.). Identity is **product_id**, not
“whichever repo you opened.”

### Behavior

When developing new features, agents first update the **Product** Living
Spec (or platform capability Spec). That is the requirements-gathering
step: intended observable behavior, inputs/outputs, dependencies,
non-functional bounds, and acceptance criteria. Implementation then
fulfills the Spec.

Agents update the Living Spec and the affected fulfillment artifacts in
the same change (**paired-change**). A change that modifies product
behavior without updating the Product Living Spec is rejected.

Episodic packages (Spec Kit `specify` folders, one-off plans) are not
Living Specs. Applied work folds into the Product Living Spec; episodes
archive as history.

## Contract

Any Adapter for this slot must:

- Define a canonical location and format for the Living Spec of each
  **Product** (and each platform capability that uses this slot) —
  e.g. `SPEC.md` or a **declared current corpus** that is still one
  logical Spec (not an unbounded stack of episode folders).
- Define product identity (`product_id`) so multi-repo work binds to the
  same Spec.
- Define the **paired-change rule**: any change that affects observable
  **product** behavior must update the Product Living Spec and the
  fulfillment artifacts in the same commit / PR (or linked change set).
- Provide a paired-change check enforceable in CI (see component 9,
  [Source Control + CI](./source-control-ci.md)).
- Define minimum content: purpose, observable behavior, inputs /
  outputs, dependencies, non-functional bounds, versioning policy.
- Declare inputs/outputs and non-functional bounds with enough precision
  that black-box test partitions can be derived from the Spec without
  reading implementation code.
- Be projectable into the Spec Graph (component 6) without lossy
  transformations.
- Treat episode/specify outputs as non-SoT; require fold-in to the
  Product Living Spec for applied behavior changes.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `format` — markdown, YAML, structured doc, etc.
- `paired_change_check` — identifier for the CI check that enforces the
  rule.
- `graph_projection` — pointer to the projection the Spec Graph Adapter
  will index.
- `product_id` — stable identity of the Product (or platform capability)
  this Living Spec describes.
- `spec_home` — where the current Spec lives (repo path, monorepo path);
  may differ from individual implementation repos.

## Boundaries

- **Is:** current HEAD of intent for a **Product** (or platform
  capability at the same grain).
- **Is not:** one Living Spec per git repo by default when those repos
  are modules of one Product.
- **Is not:** Spec Kit / specify episode folders or PR-sized memoirs.
- **Is not:** “deliverable” as the attachment unit — deliverables are
  outputs; the Spec describes the Product they fulfill.
- **Is not:** the Spec Input ([spec-input.md](./spec-input.md)),
  which is request-shaped and consumed by the Orchestrator.
- **Is not:** API documentation, README, or operator runbook — though it
  may inform any of those.
- **Is not:** the Spec Graph (component 6); the graph is a projection of
  Living Specs.

## Reference implementations

See [../../03-research/](../../03-research/) for survey of Living-Spec
templates and paired-change check tooling.
