---
doc_kind: standard
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Conversational-First Delivery and Code-Surface Encapsulation

## Status

- draft: 2026-07-19
- supersedes: none
- declined-options:
  - "index whole mixed prose+code monorepo as one code graph" — declined;
    blurs intent vs implementation and defeats scoped code-structure tools.
  - "require code/UI before conversational delivery" — declined; contradicts
    pain-driven and AI-native factory bias.
- related: [Living Spec], [Tool Transport]
  (code-structure), [Spec Graph], Standard 11 (paired-change)
- spec-version: n/a

## Scope

This standard governs **how products evolve their delivery surface** and
**where deterministic code and UIs live on disk**, so:

1. Products can start as **conversational interfaces** (agents, skills,
   prompts, structured markdown) without premature applications.
2. **Deterministic source code and UIs** are introduced when use shows a
   need (pain-driven).
3. Growing code is **encapsulated** so Tool Transport **code-structure**
   tools (e.g. codebase-memory-mcp) can be scoped cleanly via product
   registry `code_globs` / dedicated repos — without indexing prose-first
   knowledge trees as if they were software.

It applies to Product Factory work and to mixed "knowledge + automation"
repos (e.g. assistant / ops corpora that later grow scripts or services).

It does **not** require every product to ship a traditional GUI, nor
forbid monorepos. It requires **clear encapsulation** when code exists.

## Normative requirements

### 1. Conversational-first, promote on demand

1. Prefer **declarative intent** (Product Living Spec) and **conversational
   delivery** (agent skills, MCP tools, structured docs) as the first
   working surface for a capability.
2. Introduce **deterministic source code** (libraries, services, CLIs,
   batch jobs) when use shows repeated, automatable, or reliability-critical
   paths that conversation alone cannot hold.
3. Introduce **dedicated UIs** (web, desktop, mobile) when operators or
   users need non-conversational interaction that has earned its keep —
   not by default on day one.
4. Align with vision **pain-driven** and **AI-native** principles: add
   structure when the current approach breaks or costs too much, not
   because a stack is fashionable.

### 2. Encapsulate code surfaces

When deterministic code or UI code exists for a Product:

1. It MUST live in one of:
   - a **code-focused repository** (or set of repos) dedicated to
     fulfillment of that Product (or a named module of it), or
   - one or more **declared code roots** inside a mixed repo (e.g.
     `src/`, `apps/`, `services/`, `ui/`, `packages/*`) that contain
     essentially all implementation code for indexing.
2. Agents and humans MUST NOT scatter product implementation code through
   knowledge trees, skill prose directories, contact DBs, or other
   prose-primary layouts without an explicit, documented exception.
3. Thin glue (a few scripts next to docs) MAY exist outside code roots
   only if listed in the product registry as **out of code-graph scope**
   or moved into a code root as soon as it grows past trivial size
   (instance rule of thumb: more than a handful of non-trivial modules,
   or any shared library surface).
4. Product registry `code_globs` (Standard 11 / [Source Control + CI]) MUST point at
   these code roots or code-focused repos — not at the entire mixed
   monorepo by default.

### 3. Scope code-structure tools to code surfaces

1. Tool Transport **code-structure** Adapters (codebase-memory-mcp,
   Code-Graph-RAG, etc.) MUST be configured to index **code surfaces**
   only (requirement 2), not whole prose-primary corpora.
2. Prose-primary products and knowledge repos MUST use Spec Graph,
   curated knowledge graphs, and/or file tools for semantic navigation —
   not a whole-repo code graph as the primary memory of the domain.
3. Multi-repo products: index all **code** repos that fulfill the Product;
   keep the Product Living Spec as the single intent HEAD ([Living Spec]).

### 4. Living Spec and paired-change still bind the Product

1. Conversational skills, code, and UIs are **fulfillment** of the same
   Product Living Spec. Promoting a path from skill → service → UI is a
   Spec refinement + paired-change event when observable behavior changes.
2. Episode/specify folders remain non-SoT; they do not replace code-root
   discipline.

## Layout examples (non-normative)

**Good — mixed product, code encapsulated:**

```text
my-product/
  SPEC.md                 # Product Living Spec (HEAD)
  docs/ skills/ knowledge/  # conversational / prose surface
  src/                    # code root — code-structure index here
  ui/                     # UI code root — same product, scoped index
```

**Good — split repos:**

```text
my-product-spec-and-ops/   # Spec, skills, runbooks (prose)
my-product-api/            # code repo — code graph
my-product-web/            # UI repo — code graph
```

**Bad — unscoped code graph bait:**

```text
my-product/
  knowledge/**/*.md
  random-handler.py        # scattered
  skills/**/helper.ts      # implementation hidden in skill trees
  # code-structure pointed at repo root
```

## Conformance

- [ ] Product registry `code_globs` (when code exists) name explicit code
      roots or code-focused repos, not unbounded prose trees.
- [ ] New non-trivial code lands under a declared code root or code repo.
- [ ] Code-structure MCP / indexer config matches those roots.
- [ ] Prose-primary repos without code roots do not claim a whole-repo
      code-structure index as product memory.
- [ ] Living Spec updated when promotion changes observable product
      behavior (Standard 11).

## Related

- [../../00-vision/00-vision.md](../../00-vision/00-vision.md) — pain-driven,
  AI-native principles.
- [../../01-architecture/02-components/living-spec.md](../../01-architecture/02-components/living-spec.md)
  — Product Living Spec; conversational and code fulfillment.
- [../../01-architecture/02-components/tool-transport.md](../../01-architecture/02-components/tool-transport.md)
  — code-structure capability.
- [../../01-architecture/02-components/spec-graph.md](../../01-architecture/02-components/spec-graph.md)
  — intent graph, not code graph.
- [../11-paired-change-enforcement/paired-change-enforcement.md](../11-paired-change-enforcement/paired-change-enforcement.md)
  — product registry `code_globs`.
- [../../03-research/01-architecture/02-components/dev-product/dev-products.md](../../03-research/01-architecture/02-components/dev-product/dev-products.md)
  — codebase-memory-mcp candidate.

<!-- component-links (generated by check-component-links.py --write-defs) -->
[Living Spec]: ../../01-architecture/02-components/living-spec.md
[Tool Transport]: ../../01-architecture/02-components/tool-transport.md
[Spec Graph]: ../../01-architecture/02-components/spec-graph.md
[Source Control + CI]: ../../01-architecture/02-components/source-control-ci.md
