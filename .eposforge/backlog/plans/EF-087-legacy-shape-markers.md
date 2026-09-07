# Plan: Moment-of-contact markers on step-list procedure skills (EF-087)

**Date:** 2026-09-07
**Status:** Open; blocked behind EF-066's schema landing (the slug must be a declared migration)
**Tracking:** EF-087. Hard predecessor of EF-088.
**Related:** EF-086 (migration owner), EF-066 (the backlog half), EF-090 (lints these keys), EF-091 (flips them)

## Why this is its own item, before the principle rewrite

The backlog fields from EF-066 are read by someone looking at the backlog. They are not read by
the agent that opens a `SKILL.md` and starts following it. Adoption strategy obligation 3
requires the migration to be visible *at the moment of contact*, and frontmatter on the file is
a named population method for exactly that.

An always-loaded one-liner is not a substitute. It is the same class of prose that already
failed: conversational-first was itself an always-loaded rule, and it got misapplied to
procedures for as long as it has existed. Ship both — the label on the file **and** the line in
always-loaded context — so the two agree.

## The change

```yaml
# SKILL.md frontmatter (additive; keep name + description exactly as they are)
legacy_shape_of: procedure-skills-to-programs
```

on the three known step-list procedure skills:

- `skills/update-spec-graph/SKILL.md`
- `skills/upstream-bug-report/SKILL.md`
- `skills/portfolio-review/SKILL.md`

plus one line in `AGENTS.md` naming the same slug: a step-list skill or a cwd-relative
invocation is the legacy shape — do not invest, wrap a program instead.

## What this item does not do

- It does not rewrite any recipe.
- It does not change any invocation path (EF-091).
- It does not strip leaks (EF-091).
- It does not wait for the G2 recipe-vs-judgment check (EF-090). The markers go on the files
  the operator has already identified; the checker comes later and lints what is there.
- It does not wait for graph projection of the migration edges. Backlog items plus frontmatter
  plus `AGENTS.md` are the mechanical population; the graph is a later consumer.

## Compatibility

The keys are additive and optional. Unknown frontmatter keys are tolerated by current
agentskills.io consumers; `name` and `description` stay required exactly as today. If some CLI
does choke on the extra key, keep the always-loaded line and fix the label — do not drop the
signal.

## Lifecycle of the keys

| State | Key |
|---|---|
| Step-list skill not yet strangled | `legacy_shape_of: procedure-skills-to-programs` |
| Skill now wraps a program (EF-091) | `target_shape_of: …`, or drop both keys once the migration completes |
| Judgment-only skill | neither key |

Judgment-only means elicitation, prompt refinement, the portfolio-review *judgment* steps, the
docs-lint *semantic* half. Those are not the legacy shape and labelling them would train people
to ignore the label.
