# Plan: Strangler-tracking backlog schema (EF-066) — slice scope

**Date:** 2026-09-07
**Status:** Open; designated NEXT BUILD 2026-07-24
**Tracking:** EF-066
**Related:** EF-086 (second encoded migration), EF-046 (sibling associative-field evolution), EF-047 (public/private), EF-078 (multi-root lint, already landed)

This plan does not restate EF-066's own `Verify with:` — that is the contract. It records the
slice scope agreed while planning the `procedure-skills-to-programs` migration, the minimum
subset if the item is split, and two corrections to earlier notes.

## Deliverables

| Deliverable | Where | Notes |
|---|---|---|
| Optional fields `Migration:`, `LegacyShapeOf:`, `TargetShapeOf:` | `file-based-backlog/docs/schema.md` | Kebab-case slugs, comma-separated in the same style as `Blocks:`. Associative migration-membership edges — **not** `Depends on:` / `Blocks:`, which continue to drive critical-path ordering. |
| Lint | `scripts/lint-backlog.sh` | A shape field names a slug some item declares via `Migration:`; a `Migration:` slug resolves to ≥1 legacy **and** ≥1 target *backlog item*; unknown slug is an error. Skills are not items. |
| `--strangler` view | `scripts/aggregate.sh` | One section per slug: legacy items, target items, plus an "unlabeled candidates" hint. Mirror the `--tags` structure. |
| Debt marker convention | `AGENTS.md` condensed + a lint advisory | One generic line: "this shape is being strangled toward `<slug>` — do not invest". |
| Living Spec bump | `file-based-backlog.md` | `0.4.0` → next minor, in the same change as the fields; the command list reads `--strangler`. |
| Dogfood proof | Backfill of the resolved component-rename items | Stays `numbered-to-named-components` (see open questions). |
| Second migration's rows | `backlog.md` | EF-086 owner, EF-088 target shape, EF-091 legacy shape — generic text only. |

## Minimum subset if this item is split

1. The three fields plus lint.
2. The rows for both encoded migrations.
3. The moment-of-contact markers (EF-087, a separate item but the same slice).

`--strangler` is not optional for long: it is the remaining-debt view the adoption strategy
requires, and it is the only thing that will show a migration shrinking.

## Two corrections to earlier notes on this item

**The multi-root lint remark is stale.** The 2026-08-15 note said `lint-backlog.sh` only
checked the first `BACKLOG_ROOTS` entry, so the "lint passes across all roots" criterion needed
restating in terms of a loop. Adapter `0.4.0` / EF-078 already lints every root in one
invocation. Do not re-solve it; restate the criterion as "one invocation, all roots" and move
on. (Note for anyone running it by hand: `BACKLOG_ROOTS` wants the container directory, not
the backlog directory inside it — the wrong depth indexes zero issues and then reports
unknown-issue-ID errors that read like real findings.)

**This item now carries a second migration.** `procedure-skills-to-programs` (EF-086) is
encoded here *in addition to* the component-rename dogfood, not instead of it. Open question
(1) on the item — whether to retarget the dogfood proof to `theme-to-tags` — is unaffected and
still undecided. Open question (2) — how a migration whose legacy shape is diffuse corpus state
satisfies the "at least one legacy-shape item" rule — is likewise untouched: the second
migration deliberately encodes as items plus skill-file labels, so it does not need an answer
to (2), and no "search still finds it" rule is being added here.

## Boundaries

- Skill frontmatter (`legacy_shape_of` / `target_shape_of`) is a separate population mechanism.
  It is not a backlog field and will not satisfy this lint. Do not put backlog fields on a
  `SKILL.md`, and do not put skill labels through this checker.
- Adopters backfill their own in-flight migrations in their own backlogs. Adopter migration
  identifiers stay out of this repo (EF-047).
- Graph projection of the new fields is a *consumer* of this item, not a blocker. No ontology
  change is required: `ef:Migration`, `ef:legacyShapeOf` and `ef:targetShapeOf` already exist.
