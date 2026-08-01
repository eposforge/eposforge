---
name: portfolio-review
description: >-
  Periodic architect review of the combined backlog portfolio — produces a
  conceptual model, proposes supersessions, triages unanchored items, checks
  vision alignment, generates a re-entry briefing, and ends with a copy-paste
  Gas Town implement prompt for the highest-priority ready items. Requires
  EF-039 portfolio views (aggregate.sh --tags/--themes, --critical-path, --mermaid).

**Important**: For an adopter, run this from the **primary repo** that acts as the Adopter Platform Spec (the single repo containing documentation of the overall eposforge implementation for both product and platform factories, plus the `.eposforge/` adopted slice). This is where the real portfolio view lives. If your workspace only contains the framework or a sub-project, the tool can still operate on what is present, but that yields only a partial (single-project) backlog view rather than the adopter's portfolio.
---

Runs the periodic semantic garbage-collection pass that keeps the backlog corpus
from rotting into an unwieldy pool. Capture stays low-friction (a fuzzy sense of
priority at creation time is acceptable) because this pass recomputes importance
from structure and catches what capture missed.

The **terminal deliverable** is not only insight — it is a **simple, filled-in
prompt** the operator can paste into a Mayor session, overnight schedule, or
agent chat to implement the top ready items via Gas Town (file-backlog → beads
spawn rule). Without that handoff, the review is incomplete.

## When to use this skill

- Returning after time away and need a re-entry briefing
- Backlog has grown and you want to detect superseded, unanchored, or
  contradicting items before starting new work
- After a milestone lands and the priority landscape shifts
- Before a planning horizon or roadmap refresh
- Before arming Gas Town / Loop A with the next work slice

## Prerequisites

- `aggregate.sh --tags` (or `--themes` alias) output (grouped portfolio view)
- `aggregate.sh --critical-path <anchor-ID>` for each active anchor item
- `aggregate.sh --mermaid` to regenerate `backlog/portfolio.md` (the writer now enforces: if the aggregation crosses any `visibility=private` root, the file is written to the *first private root* in the list (e.g. the primary adopter root), never to a public root. Pure-public runs write to the framework as before. See aggregate.sh and EF-047.)
- `ready.sh` output (currently workable items)
- `00-vision/` and `02-roadmap/` docs (from the primary repo or framework) for vision alignment reference
- Cognee MCP (for graph-backed context when available)
- When Gas Town is the orchestrator adapter: knowledge of the spawn path
  (`backlog-to-beads.sh` / skill `gastown-backlog-to-beads`, adopter-007 boundary)

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

## Step 7 — Gas Town implement-next handoff (required)

**This step is mandatory.** The review is incomplete without a filled-in,
copy-pasteable implement prompt. Do not stop at analysis.

### 7a — Select the work slice

From `ready.sh` + the critical path of the most important active anchor + the
re-entry briefing, pick **1–5** highest-priority items the operator should send
to Gas Town next. Prefer:

1. Ready items on the critical path of the top anchor (unblocks the most)
2. Then other ready items that advance the same theme
3. Exclude resolved/slated items; prefer Effort S/M for autonomous drain
4. Cap at 5 — a handoff that dumps the whole backlog is a failure of this step

For each selected item record:

| Field | Source |
|---|---|
| `repo` | backlog root → Gas Town rig key (`gea`, `eposforge`, `iac`, `outreach_api`, …; else set `REPO_DIR=`) |
| `ID` | e.g. `adopter-034` |
| `title` | from the issue block |
| `effort` | S / M / L |
| `tier` | `tier1` (well-defined, single-rig, non-epic) or `tier3` (epic/mountain/cross-rig/arch — needs operator gate before sling) |
| `why now` | one short clause (critical-path position or theme) |

### 7b — Emit the sample prompt (chat)

Print a fenced code block the operator can paste **verbatim** into a Mayor
session, `gastown-schedule-work` body, or agent chat. Fill every placeholder
from 7a — never leave `<angle-brackets>` in the final block.

**Template (fill in, then print):**

```
Implement these highest-priority backlog items via Gas Town. Act autonomously
on tier-1 items. For any tier-3 item: pour mayor-elicit, show the plan/rubric,
and WAIT for explicit operator approval before sling.

Portfolio review date: <YYYY-MM-DD>
Priority order (do in this order; stop if kernels go red):

1. <repo>:<ID> — <title> [Effort <S|M|L>] [tier1|tier3] — <why now>
2. …

For EACH item above, in order:

1. Mint beads with the adopter-007 spawn rule (dry-run first, then apply only for
   that ID — never auto-scan backlog.md):
     .eposforge/router/gastown/config/scripts/backlog-to-beads.sh <repo> <ID>
     .eposforge/router/gastown/config/scripts/backlog-to-beads.sh <repo> <ID> --apply
   (or skill gastown-backlog-to-beads). Confirm --external-ref "<repo>:<ID>"
   exists: bd list --external-ref "<repo>:<ID>".
2. Select agent only via select-agent.sh (clearance ≥ rig privacy; never sling
   execution to chris). Attach a molecule (rule-of-five default; secure-impl
   for high-privacy; outreach-deliver for outreach).
3. Sling, iterate until the convoy closes with evidence matching the item's
   Verify with / acceptance criteria.
4. Between items: self-improve only safe-tier; do not invent extra backlog work.
5. Agent-discovered findings stay in Beads; promote-back to the file backlog
   is human-gated (do not write adopter-/EF- items yourself unless asked).

When the list is done, report: bead ids per external-ref, convoy status, and
any blocked/pending_deps.
```

Keep the printed prompt short enough to paste into overnight Mayor mail without
editing. If an item needs `REPO_DIR=` or `--epic`, add one explicit line under
that item in the list — do not invent a second procedure.

### 7c — Emit Loop A arm lines (optional, always include when any tier1 exists)

Below the prompt, print a second small block the operator can drop into
`loop-a-queue.md` (one ID per line, uncommented) if they want Loop A to drain
the tier-1 subset instead of a live Mayor session:

```
# loop-a-queue.md — arm after portfolio-review <date>
<ID>
…
```

Only tier-1 IDs. Omit tier-3 from this block (Loop A must not auto-pull epics).

### 7d — Persist the handoff

Write the same content (review date, selected table, filled sample prompt,
loop-a lines) to the **first private backlog root** as:

`portfolio-handoff.md`

(Same privacy rule as `portfolio.md` / EF-047: never write this file into a
public framework root when any private root is in the aggregation.)

Overwrite on each review so the file always means "current implement-next."
Point the operator at that path in the chat summary.

If Gas Town is **not** present for this adopter (no `.eposforge/router/gastown/`
on the primary platform repo and no `backlog-to-beads` skill), still emit a
generic implement-next prompt naming the same `repo:ID` list and say
"orchestrator adapter not detected — implement via your normal agent path;
spawn/mint steps above are Gas Town-specific."

## Step 8 — Apply accepted proposals

For each proposal the operator accepts during the review session:

- `Tags:` additions/appends: add or extend the field to the relevant item in `backlog.md`
- `Supersedes:` links: add to the newer item; add `Blocks: <newer-id>` to the older
- Slating: move the item to `backlog-slated.md` and set `Slated:` + `Re-evaluate by:`
- Archive: add `Validation:` + `Resolved:` + `Status: resolved` then run `sweep-resolved.sh`

Run lint after applying edits:

```bash
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}"/..eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh
```

Do **not** block Step 7 on Step 8. The implement handoff is produced even when
the operator defers structural edits.

## Outputs

- **conceptual model** — plain-language synthesis of what the portfolio is building
- **supersession proposals** — candidate `Supersedes:` edits for architect approval
- **triage proposals** — theme assignments, slating dates, or archive candidates
- **vision alignment notes** — gaps and contradictions relative to `00-vision/` and `02-roadmap/`
- **re-entry briefing** — ≤ 400-word actionable summary for the operator
- **Gas Town implement-next prompt** — filled copy-paste block for the top 1–5 ready items (required)
- **Loop A arm lines** — tier-1 ID list for `loop-a-queue.md` when applicable
- **`portfolio-handoff.md`** — durable copy of the handoff in the first private backlog root
- updated `backlog/portfolio.md` — regenerated Mermaid diagram
