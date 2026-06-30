---
name: portfolio-review
description: Periodic architect review of the combined backlog portfolio — produces a conceptual model, proposes supersessions, triages unanchored items, checks vision alignment, and generates a re-entry briefing. Requires EF-039 portfolio views (aggregate.sh --tags/--themes, --critical-path, --mermaid).

**Important**: For an adopter, run this from the **primary repo** that acts as the Adopter Platform Spec (the single repo containing documentation of the overall eposforge implementation for both product and platform factories, plus the `.eposforge/` adopted slice). This is where the real portfolio view lives. If your workspace only contains the framework or a sub-project, the tool can still operate on what is present, but that yields only a partial (single-project) backlog view rather than the adopter's portfolio.
---

Runs the periodic semantic garbage-collection pass that keeps the backlog corpus
from rotting into an unwieldy pool. Capture stays low-friction (a fuzzy sense of
priority at creation time is acceptable) because this pass recomputes importance
from structure and catches what capture missed.

## When to use this skill

- Returning after time away and need a re-entry briefing
- Backlog has grown and you want to detect superseded, unanchored, or
  contradicting items before starting new work
- After a milestone lands and the priority landscape shifts
- Before a planning horizon or roadmap refresh

## Prerequisites

- `aggregate.sh --tags` (or `--themes` alias) output (grouped portfolio view)
- `aggregate.sh --critical-path <anchor-ID>` for each active anchor item
- `aggregate.sh --mermaid` to regenerate `backlog/portfolio.md` (the writer now enforces: if the aggregation crosses any `visibility=private` root, the file is written to the *first private root* in the list (e.g. the primary adopter root), never to a public root. Pure-public runs write to the framework as before. See aggregate.sh and EF-047.)
- `ready.sh` output (currently workable items)
- `00-vision/` and `02-roadmap/` docs (from the primary repo or framework) for vision alignment reference
- Cognee MCP (for graph-backed context when available)

**Invocation context**: Run from (or point tooling at) the adopter's primary repo (the Adopter Platform Spec). Set `BACKLOG_ROOTS` (or use `.code-workspace`) so that the primary repo's `..eposforge/backlog` (and any other project backlogs it tracks) are discovered. The framework clone supplies the `aggregate.sh` / scripts. See the adapter-layout-mirror standard and EF-056 plan.

## Step 1 — Gather portfolio state

Run the views (adjust paths for your primary adopter repo; the framework clone provides the scripts):

```bash
# From (or with EPOSFORGE_HOME pointing to) the framework
# BACKLOG_ROOTS includes the primary repo's .eposforge/backlog (and any other roots)
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}"/..eposforge/backlog/file-based-backlog/scripts/aggregate.sh --tags
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}"/..eposforge/backlog/file-based-backlog/scripts/ready.sh
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}"/..eposforge/backlog/file-based-backlog/scripts/aggregate.sh --mermaid
```

For each anchor item identified in the backlog, also run:

```bash
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}"/..eposforge/backlog/file-based-backlog/scripts/aggregate.sh --critical-path <anchor-ID>
```

If Cognee MCP is available, recall recent portfolio and roadmap state:

```
mcp__cognee__recall: "backlog milestones themes critical path portfolio"
```

## Step 2 — Build the conceptual model

Using the `--tags` (or `--themes`) output and the critical-path chains, describe in one paragraph
per tag:

- What the theme is trying to achieve
- Which anchor items it flows toward
- Whether items within the theme form a coherent progression or are scattered

The **conceptual model** is a plain-language synthesis — not a re-list of items.
It answers: "what is this portfolio actually trying to build, and is the backlog
structured to get there?"

## Step 3 — Supersession proposals

For each pair (or cluster) of items where one seems to render another obsolete or
subsumed:

- Name both items and the supersession direction
- State the criterion: what changed that makes the older item redundant?
- Propose the edit: add `Supersedes: <old-id>` to the newer item and update the
  older item's `Notes:` with a pointer

Do not apply these edits yet — record them as proposals. Accepted proposals become
mechanical edits the operator applies after the review.

## Step 4 — Unanchored item triage

From the `--tags` unanchored section, for each item that carries no `Tags:` and
no `Blocks:` link toward an anchor:

- Ask: which theme or anchor does this item serve?
- If it clearly fits a tag: propose adding `Tags: <value>` (or append to existing)
- If it has no near-term anchor: propose slating it with a `Re-evaluate by:` date
- If it is clearly obsolete: propose archiving it as resolved with a `Validation:` note

Record these as proposals.

## Step 5 — Vision alignment check

Read `00-vision/` and `02-roadmap/` (or use Cognee recall for the vision graph).

For each active theme, check:

- Does the work in this theme advance a stated phase exit or value-harvest milestone?
- Are there items that directly contradict the current roadmap direction?
- Are there roadmap capabilities not represented in any backlog item?

Flag misalignments and gaps as observations — not prescriptions. The architect
decides what to act on.

## Step 6 — Re-entry briefing

Produce a short briefing (≤ 400 words) structured as:

```
## Portfolio re-entry briefing — <date>

### What is ready to work on now
<3–5 items from ready.sh, with effort tags>

### Most important anchor and its critical path
<Target anchor + summary of the critical path steps>

### Top supersession proposals
<2–3 highest-confidence proposals>

### Items needing triage
<Unanchored items that need a home or a slating date>

### Vision alignment notes
<1–3 observations about gaps or contradictions>
```

This briefing is the re-entry point. Understanding the portfolio must not require
replaying conversation history or prior session context.

## Step 7 — Apply accepted proposals

For each proposal the operator accepts during the review session:

- `Tags:` additions/appends: add or extend the field to the relevant item in `backlog.md`
- `Supersedes:` links: add to the newer item; add `Blocks: <newer-id>` to the older
- Slating: move the item to `backlog-slated.md` and set `Slated:` + `Re-evaluate by:`
- Archive: add `Validation:` + `Resolved:` + `Status: resolved` then run `sweep-resolved.sh`

Run lint after applying edits:

```bash
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}"/..eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh
```

## Outputs

- **conceptual model** — plain-language synthesis of what the portfolio is building
- **supersession proposals** — candidate `Supersedes:` edits for architect approval
- **triage proposals** — theme assignments, slating dates, or archive candidates
- **vision alignment notes** — gaps and contradictions relative to `00-vision/` and `02-roadmap/`
- **re-entry briefing** — ≤ 400-word actionable summary for the operator
- updated `backlog/portfolio.md` — regenerated Mermaid diagram
