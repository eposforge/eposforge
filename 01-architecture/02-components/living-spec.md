---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Living Spec

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

Fulfillment may start as **conversational** surfaces (skills, agents)
and later add **deterministic code and UIs**. When code exists, it must
be encapsulated in code roots or code-focused repos so code-structure
tools stay scoped — see
[Standard 12](../../04-standards/12-code-surface-encapsulation/code-surface-encapsulation.md).

### Behavior

When developing new features, agents first update the **Product** Living
Spec (or platform capability Spec). That is the requirements-gathering
step: intended observable behavior, inputs/outputs, dependencies,
non-functional bounds, and acceptance criteria. Implementation then
fulfills the Spec.

As the product develops, the Living Spec is **continuously refined**
(clarified, edged, corrected). That refinement *is* product work, not a
separate optional documentation track. The hard line between “intent”
and “implementation choice” is judged by: **if the prior Spec would
become false or incomplete as a description of the product, the Spec
must change in the same work.** When unsure, update the Spec.

Agents update the Living Spec and the affected fulfillment artifacts in
the same change (**paired-change**). A change that modifies product
behavior without updating the Product Living Spec is rejected — and
must be **rejected by CI**, not only by prompt compliance. See
[Source Control + CI] and
[Standard 11: Paired-Change Enforcement](../../04-standards/11-paired-change-enforcement/paired-change-enforcement.md).

### Ceremony vs fidelity

| | |
| --- | --- |
| **Fidelity (always)** | Product meaning changes ⇒ Product Living Spec (HEAD) changes in the same gated change set (or a narrow audited exemption that meaning did not change). |
| **Ceremony (optional scale)** | Large/ambiguous work MAY use a heavy authoring Adapter (e.g. Spec Kit-style episode) to draft a delta, then **fold into** the Product Living Spec. Small fixes use a **light path**: edit the same Spec file + code. |
| **Never** | “Too small / low risk for Spec ⇒ code only.” That is how Specs rot. |
| **Never** | Treat episode folders as the Living Spec or as the Spec Graph corpus. |

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
- Require that paired-change be enforced as a **fail-closed CI gate**
  per [Source Control + CI] and
  [Standard 11](../../04-standards/11-paired-change-enforcement/paired-change-enforcement.md)
  (product registry, default code⇒Spec rule, finite audited exemptions,
  Spec-derived tests). Prompt-only enforcement is non-conformant.
- Support a **light path** (in-place Spec HEAD edit) so full specify
  pipelines are not the only way to stay compliant.
- Define minimum content: purpose, observable behavior, inputs /
  outputs, dependencies, non-functional bounds, versioning policy.
- Declare inputs/outputs and non-functional bounds with enough precision
  that black-box test partitions can be derived from the Spec without
  reading implementation code.
- Be projectable into the [Spec Graph] without lossy
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
- **Is not:** the [Spec Input],
  which is request-shaped and consumed by the Orchestrator.
- **Is not:** API documentation, README, or operator runbook — though it
  may inform any of those.
- **Is not:** the [Spec Graph]; the graph is a projection of
  Living Specs.

## Reference implementations

See [../../03-research/](../../03-research/) for survey of Living-Spec
templates and paired-change check tooling.

Enforcement (normative for instances that claim Living Spec maturity):
[Standard 11: Paired-Change Enforcement](../../04-standards/11-paired-change-enforcement/paired-change-enforcement.md).


<!-- component-links (generated by check-component-links.py --write-defs) -->
[Source Control + CI]: ./source-control-ci.md
[Spec Graph]: ./spec-graph.md
[Spec Input]: ./spec-input.md
