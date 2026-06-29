---
name: milestone-elicitation
description: Guided interview for discovering milestones and value-harvest points. Writes confirmed anchors back as ordinary backlog items and keeps durable elicitation records. Re-runnable — subsequent runs diff against existing anchors and prior records so the milestone map evolves without replaying history.
---

Bootstrap counterpart to the `portfolio-review` skill: the portfolio-review skill
maintains an anchored backlog, but assumes anchors exist. This skill establishes
them through guided discovery. Knowing where the milestones and value-harvest
opportunities are is judgment work the architect does in dialogue, not data sitting
in any file.

## When to use this skill

- First run: no anchor backlog items exist yet
- After a major roadmap shift where existing anchors need revision
- When the portfolio-review triage pass finds clusters of unanchored items (a
  signal that the milestone map is incomplete)
- Periodically, to evolve the milestone map as the vision develops

## Elicitation records

Elicitation records are the durable home for interview answers. They live at
`backlog/elicitation-records/` (one file per session, named `<date>-elicitation.md`).
They capture:

- Accepted milestones (distilled rationale, before being written to the backlog)
- Rejected proposals (with the reason — prevents re-proposing what was already
  declined)
- Deferred items (with a re-examine date)
- The architect's own phrasing of the milestone value (verbatim)

These records are decision data, not chat exhaust. They must not depend on
transcript capture. The graph-visible rationale for accepted anchors is distilled
into each anchor item's `Notes:` field; full interview detail lives only in the records.

## Step 1 — Load prior context

Before the interview begins, load:

1. **Prior elicitation records** — read all files under `backlog/elicitation-records/`.
   Extract the list of previously accepted, rejected, and deferred proposals. This
   is the rejection/deferral memory that prevents re-proposing what the architect
   already declined.

2. **Existing anchor items** — grep for items in `backlog/backlog.md` that have
   `Blocks:` fields (these are likely anchors) or whose `Notes:` mentions "anchor"
   or "milestone".

3. **Roadmap and vision** — read `02-roadmap/` and `00-vision/` to ground the
   interview in the current phase structure.

4. **Aggregated backlog** — run `aggregate.sh --tags` (or `--themes` alias via `$EPOSFORGE_HOME`) to see the current tags
   clusters and what work is already in flight.

5. **Cognee MCP** (if available) — recall roadmap milestones and anchor items from
   the graph: `"milestones anchors value-harvest roadmap phases"`

Present a brief prior-state summary to the architect before the first interview
question:
- How many elicitation sessions have run before
- Existing confirmed anchors (by ID and title)
- Any deferred proposals from prior sessions that are due for re-examination

## Step 2 — Walk phase exits

For each roadmap phase in `02-roadmap/` (in order), ask:

> "Phase [N] exits when [stated exit criteria]. Does that exit represent a
> harvestable value point — something you or a customer could actually use — or
> is it an internal progress gate?"

If harvestable:
> "What could you do at that exit point that you cannot do today? Who benefits?"

If internal:
> "Is there a nearer increment within Phase [N] that represents harvestable value?"

Record the architect's answers verbatim in the session record. For each confirmed
value-harvest point, note:
- The phase and increment
- The architect's description of the value
- The capability unlocked

## Step 3 — Walk active themes

For each tag in the `--tags` (or `--themes`) output that contains open items:

> "If everything in the [theme] cluster landed tomorrow, what could you do that
> you can't do today? Would you actually use that capability?"

If yes:
> "Is there a smaller increment within this cluster where you'd already get
> meaningful value — before the full cluster lands?"

The goal is to find nearer harvest points hiding inside far milestones.

Record the architect's threshold description: "I'd consider this useful when..."

## Step 4 — Propose anchors

Based on the phase-exit and theme interviews, synthesize candidate anchor items.
For each candidate:

1. Name the anchor item (one-line title)
2. State the value delivered ("enables X that was previously impossible/painful")
3. Identify which existing backlog items flow toward it (the `Blocks:` candidates)
4. Ask for confirmation:
   > "I'm proposing anchor: [title]. This represents [value]. Does that match
   > what you have in mind, or should we adjust?"

If the architect adjusts: revise and re-confirm before recording as accepted.
If the architect declines: record the rejection with the stated reason — do not
re-propose in subsequent sessions.

Do not write the anchor to the backlog until it is explicitly confirmed.

## Step 5 — Check prior deferred proposals

From the prior elicitation records, surface any deferred proposals whose
re-examine date has passed:

> "In the [date] session, we deferred [proposal] with the reason [reason].
> Is it worth revisiting now?"

Apply the same confirm/reject/defer flow.

## Step 6 — Write confirmed anchors

For each confirmed anchor, create a backlog item using `new-issue.sh` or by
appending directly to `backlog/backlog.md`. The anchor item must have:

```
## Issue <ID> — <anchor-title>
ID: <ID>
Title: <anchor-title>
Date: <today>
Status: open
Effort: S
Fix surface: process
Tags: <most-relevant-tag>
Notes: Anchor item — <architect's distilled rationale for why this milestone
  represents harvestable value>. Elicitation session: <date>.
Verify with: <observable signal that the milestone has been reached>
```

Then update existing backlog items that flow toward this anchor by adding
`Blocks: <anchor-ID>` to their entries (or confirm the architect will do this
during the next portfolio-review pass).

Run lint after writing:

```bash
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}"/instance/backlog/file-based-backlog/scripts/lint-backlog.sh
```

## Step 7 — Write elicitation record

Write a session record to `backlog/elicitation-records/<today>-elicitation.md`:

```markdown
# Elicitation session — <date>

## Accepted anchors
- <ID>: <title> — <one-line rationale>

## Rejected proposals
- <proposal>: <reason declined>

## Deferred proposals
- <proposal>: <reason deferred> (re-examine: <date>)

## Architect phrasing (verbatim excerpts)
> <architect's own words for key value statements>

## Context at time of session
- Roadmap phase: <current phase>
- Active themes: <list>
- Prior anchor count: <N>
```

## Re-run behavior

On subsequent runs:

1. Load prior records (Step 1)
2. Skip phase-exit questions for phases already represented by a confirmed anchor
3. Only re-ask if the roadmap has changed since the last session covering that phase
4. Surface deferred proposals that are due
5. Walk any new themes added since the last session
6. Propose additions/supersessions rather than starting from scratch

The milestone map evolves without requiring the architect to replay what was
already decided.

## Outputs

- Confirmed anchor backlog items (ordinary items in `backlog/backlog.md`)
- Updated `Blocks:` links on items that flow toward each anchor
- Elicitation record in `backlog/elicitation-records/<date>-elicitation.md`
- Clean lint run confirming schema validity
