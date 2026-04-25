# Spec Input — Implementation Catalog

> **Snapshot date:** 2026-04. Verify current details before adopting.

Candidate Adapters for the Spec Input slot
([../01-architecture/02-components/01-spec-input.md](../01-architecture/02-components/01-spec-input.md)).
A Spec Input Adapter accepts human-authored declarative intent and
normalizes it into a structured form the Router can decompose.

This catalog is **not exhaustive** and **not an endorsement**.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — markdown convention, IDE, web tool, framework.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Input format** — markdown, YAML, structured form, etc.
- **Capabilities** — what task shapes the Adapter handles well.
- **Notes** — anything notable for Adapter authors.

---

## Candidates

### GitHub Spec Kit

- **Type:** opinionated markdown convention + slash-command workflow
  (`/specify`, `/plan`, `/tasks`).
- **Cost tier:** free OSS.
- **Input format:** markdown briefs with structured sections.
- **Capabilities:** decomposes intent into a plan and concrete task
  list before any code is written; pairs naturally with
  agent-driven Dev Products.
- **Notes:** widely adoptable because it lives in repo files, not in
  a vendor tool. Adapter is straightforward — parse the brief,
  emit normalized sub-tasks. Common starting choice for instances
  that want a low-lock-in Spec Input.

### Kiro

- **Type:** spec-driven IDE.
- **Cost tier:** consumer-paid.
- **Input format:** structured spec → tasks workflow inside the IDE.
- **Capabilities:** intent → spec → task decomposition, with
  IDE-native authoring affordances.
- **Notes:** also listed in [dev-products.md](./dev-products.md) for
  awareness; better fit for Spec Input in most instances.

### Custom markdown briefs

- **Type:** repo-local convention.
- **Cost tier:** free.
- **Input format:** markdown files at a known path (e.g.,
  `specs/<feature>.md`) with operator-defined sections.
- **Capabilities:** whatever the instance needs.
- **Notes:** the floor option. Every instance can fall back to this
  while a richer Adapter is being chosen. Avoid letting "custom"
  become permanent — consolidate on a real Adapter once one fits.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
that produce structured sub-tasks (not just freeform prose) and that
declare acceptance criteria explicitly.
