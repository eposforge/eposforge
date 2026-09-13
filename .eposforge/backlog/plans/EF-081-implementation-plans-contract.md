---
doc_kind: plan
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Plan — implementation plans as a contract (EF-081)

> Owner item: EF-081. This file holds the narrative; the item holds the work.
> If the two disagree, the item wins.

## The problem in one sentence

The rule "a detailed plan lives at `.eposforge/backlog/plans/<ID>-<slug>.md`"
existed only inside one backlog item's notes, so nothing an agent loads or
recalls ever told it, and nothing checked it.

## What was observed

- **No home.** No standard, living spec, template, lint rule or agent instruction
  stated the location. Backlog items and anything under `backlog/` or `plans/`
  are excluded from Spec Graph ingest (EF-057; the exclusion pattern in the
  bulk and incremental sync scripts is `(^|/)(backlog/|\.eposforge/backlog/|plans/)`),
  so recall could not surface it either.
- **Drift already happened.** An adopting repository grew a second, top-level
  `plans/` folder beside its `.eposforge/backlog/plans/`. The folder was
  reasonable-looking and nothing objected.
- **The first-draft lint would not have caught it.** As first worded, EF-081's
  lint rejected only broken paths — missing, traversing, non-Markdown, not a file.
  A plan in the wrong folder passes all four.
- **No scaffolder.** Nothing in the pattern creates a new backlog. `new-issue.sh`
  and `lint-backlog.sh` print a "create config.toml" hint; `sync-tooling.sh`
  maintains an existing vendored install and refuses a repo that has none.
  Adopters hand-create the files, so whether `plans/` exists depends on who
  wrote their scaffolding.
- **Long notes.** In the pattern repo's active backlog (40 items on 2026-09-13)
  the median `Notes:` runs about 1,350 characters and 12 items exceed 2,000.
  The operator's position — an item is a work contract, not a place to keep a
  plan — was not written down anywhere.

## Where the standard lives, and why there

The standard goes in **Standard 07 (Adapter Layout Mirror)**, as a new normative
requirement next to requirement 3 (backlog data location). Plans are backlog
data, and that standard already decides where backlog data lives.

The obvious homes are wrong for a mechanical reason: the file-based-backlog
Living Spec and `docs/schema.md` sit under `.eposforge/backlog/`, which ingest
excludes. A rule stated only there has the same defect as a rule stated only in
a backlog item. They still document the field and the config key — as reference,
pointing at the standard.

The backlog component contract (`01-architecture/02-components/backlog.md`) gets
one pointer line, not a copy. Two normative copies drift.

## The standard's content

| Rule | Decision | Why |
|---|---|---|
| Location | Directly under `<adoption-root>/backlog/plans/`. No subfolders. | One place to look; a flat folder makes the lint check a string test. |
| Naming | `<PREFIX>-<NNN>-<kebab-slug>.md`, the ID of the item it serves. | The filename alone tells an agent which item owns it. |
| Multi-item plans | Named after the **owner item**. Every member item, the owner included, carries the same `Implementation plan:` pointer. | Matches how migrations already work (one owner row, members point at it). Lint can check the owner carries the pointer, so a plan can't claim an owner that disowns it. |
| Front matter | `doc_kind: plan`, `scope`, `maturity`, `source_of_truth: no` (the shape the prose-to-contract plan already uses). | `source_of_truth: no` is the machine-readable form of "the items win". |
| Item vs plan | Item: `Verify with:`, short `Notes:`, `Implementation plan:` pointer. Plan: narrative, design, options considered, evidence. | The item is loaded and linted often; the plan is read when working the item. |
| Precedence | If plan and item disagree, the item wins. | The item is the thing lint and review check. |
| Optional | Small items need no plan. | Plans are a cost; the Notes-length warning is the prompt to write one. |

## Lint severity

**Errors** are for pointers, because an item that names a plan is making a claim
the tool can check completely: path shape, location, naming, owner consistency,
front matter.

**Warnings** are for two cases where an error would do harm:

- *A misnamed file in `backlog/plans/`.* Existing adopters have them. Making this
  an error would turn an adopter red the moment it syncs new tooling, before it
  has had a chance to migrate. The warning keeps the drift visible.
- *Long `Notes:` with no plan.* Length is a hint, not proof. Some long notes are
  legitimate evidence logs.

The notes threshold is `notes_warn_chars` in `config.toml`, default 2,000 when
absent. A value that is not a positive integer is an **error**, deliberately:
this backlog has already been bitten by a config key whose empty value silently
switched a check off.

### Notes length is a ratchet, not a flood

A plain threshold warning is noise on day one. Counted on 2026-09-13, 2,000
characters flags about 16 active and slated items in this repo and about 25 in
the primary adopter. Those are warnings about items nobody is working on. People
learn to skim past lint output that always has warnings in it, and then they
skim past the errors too. So the check only speaks about long notes that are
*new*:

| Case | Lint result |
|---|---|
| Over threshold, no plan, ID not in the baseline | warning |
| Over threshold, no plan, ID in the baseline | silent (grandfathered) |
| Baseline ID now under threshold, or now has `Implementation plan:` | **error**: prune it |
| Baseline ID not an active or slated item in this repo | **error** |
| No baseline file, some item over threshold | **error**: cannot evaluate; names the command to run |
| No baseline file, no item over threshold | fine |

The baseline is `<adoption-root>/backlog/notes-length-baseline.txt`: one ID per
line, `#` comments allowed. It sits beside the data files, not in `plans/`, where
the naming warning would fire on it.

Why each choice:

- **A committed file, not a config key.** It diffs one ID per line, so review
  can see the list shrink. `config.toml` stays a vocabulary file.
- **The generator refuses to overwrite, and prune only removes.**
  `--write-notes-baseline` creates the file once; `--prune-notes-baseline` drops
  IDs that no longer qualify and never adds one. If regenerating could add IDs,
  "regenerate the baseline" would become the way to silence the warning, and the
  ratchet would be an off switch again. Hand-adding an ID is still possible, but
  it shows up in the diff.
- **Stale entries are errors.** A baseline that keeps an ID after its item is
  fixed stops meaning "debt we know about". It becomes a permanent exemption for
  whatever that item's notes grow into next.
- **A missing baseline is an error when there is something to grandfather.**
  Treating missing as empty is the flood this section exists to avoid. Skipping
  the check is green by omission. The error is one line with one command to run,
  and a repo sees it once. It will appear in an adopter the first time the adopter
  syncs this tooling. That is intended: the fix takes no judgement.
- **Only active and slated items are checked.** Archived notes are history.
- **Rejected: a date cutoff** ("warn only for items filed after X"). `Date:` is
  the discovery date, and most long notes grow by amending old items, so a cutoff
  would never fire on the usual case.
- **Accepted trade-off:** a grandfathered item's notes can keep growing without
  a warning. The baseline stores IDs, not lengths. Storing lengths would warn on
  every small edit and make pruning fiddly. The list is meant to be worked down,
  and the prune error forces it to shrink as items get fixed.

"Notes text" must be defined mechanically, because the parser treats any
`Word: text` line as a field and notes often have continuation lines that look
like that. The definition: the `Notes:` line plus every following line up to the
next line starting with a field name listed in `docs/schema.md`, or the next
issue header.

## Scaffolding

A new `init-backlog.sh` rather than an `--init` flag on `sync-tooling.sh`:
preferred mode runs the scripts from a framework clone and vendors nothing, so
creating backlog *data* must not be tied to the tool that copies *scripts*. It
creates the `config.toml`, the four data files and `plans/.gitkeep` (git does not
track empty folders), refuses to overwrite an existing backlog, and becomes the
command the bootstrap hint names. An adopter's own repo-scaffolding tooling
should call it rather than keep its own file list.

Observed and out of scope here: `sync-tooling.sh` still builds its destination as
`<repo>/eposforge/backlog/...` (no leading dot), which predates the `.eposforge/`
container rename (EF-059).

## Backlog work goes through a subagent

The operator's rule: work on the backlog is delegated to a subagent, and this
item sets that up rather than only stating it. The conversing session writes a
brief and reviews what comes back; it does not edit backlog files itself.

| Decision | Why |
|---|---|
| One harness-neutral definition, `file-based-backlog/agents/backlog-author.md`, beside the adapter. | The procedure belongs to the backlog adapter. No pattern-level home for subagent definitions exists yet; the second component that needs one is the moment to write that standard. |
| Projected by the consume-side install used for skills and chairs (`skills/INSTALL.md`). Canonical in git; projections are pointers or copies with provenance. | Standard 14 requirement 3 already says how a role file reaches each CLI. A second installer would be a second source of truth. |
| It sits in the implementer chair. | It writes. Reviewing what it wrote is the delegating session's job, or a reviewer's. |
| Procedure: coverage agent (EF-097), file through `new-issue.sh`, write any plan to the standard, lint once per root at the `.eposforge` depth, return diff summary and lint output, never commit. | Each step answers an observed failure: duplicate filing, plans in the wrong folder, lint at the wrong depth reporting fake errors, commits nobody asked for. |
| Its instructions point at the Standard 07 requirement instead of restating it. | Two copies of a rule drift. |
| The definition's tool list is a default. Where an adopter assigns tools per role, that assignment decides. | EF-093 phase 3: one plane decides content; generators only project it. |
| `init-backlog.sh` reports whether the projection is installed and names the install command. | A new repo gets the rule and the means together, while the scaffolder still creates data only. |
| Enforcement (refusing direct backlog edits from the conversing session) is left to the adopter's harness. | Whether a harness can tell a subagent's edit from the main session's varies by harness. |

## What this does not do

- Does not backfill front matter on the existing pattern plans. Lint only checks
  plans an item points at; add front matter when an item first points at one.
- Does not move any adopter's files. Adopters file their own counterpart item
  (EF-047: adopter IDs never appear here).
- Does not define execution units. That is EF-096, which reuses these plan rules
  rather than defining a second plan location.
