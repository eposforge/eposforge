---
name: idea-capture
description: >-
  Keep a per-repo register of notional product ideas — ideas not yet decided,
  kept as food for future development instead of being forgotten, and kept out
  of the backlog. Captures napkin notes as structured idea entries (one per
  idea, duplicate-checked, with typed edges to related ideas and backlog
  items), promotes an idea to an ordinary backlog item, rejects an idea with a
  reason, and reads the register as a graph. Use when the operator says
  "capture this idea", "napkin note", "notional feature", "food for future
  development", "add to ideas", "park this idea", "not a backlog item yet",
  "promote IDEA-NNN to the backlog", "reject that idea", or "what's in the
  ideas register". Do not use for work that is already decided — that is a
  backlog item.
---

The backlog's undecided sibling. The backlog holds decided work (active,
slated, archived); the ideas register holds what might be worth deciding one
day. An idea in the register carries no effort, no priority and no
dependency links in the backlog sense, and nothing in it is a commitment.

Capture stays low-friction: a sparse entry is fine and is refined later. What
the register must not lose is the idea itself, where it came from, and its
relationships to the other ideas and to the backlog.

Designation (Standard 03, requirement 4): **skill**. Splitting a note into
ideas, judging duplicates and proposing edges are judgment steps; there is no
store verb to wrap.

## Where the register lives

- One file per repo: `.eposforge/ideas/ideas.md`, beside
  `.eposforge/backlog/`.
- IDs are `<PREFIX>-IDEA-NNN`, where `<PREFIX>` is the `prefix` value in that
  repo's `.eposforge/backlog/config.toml`. Three digits, zero-padded,
  sequential, never reused.
- If the repo has no `.eposforge/backlog/config.toml`, ask the operator for a
  prefix and offer to create only `.eposforge/ideas/ideas.md`. Do not
  scaffold a backlog as a side effect.

## Rules

- **Not a backlog.** No effort, no priority, no `Depends on:` / `Blocks:`.
  Phase is labelled a guess.
- **Status values only:** `idea` (default), `refining`, `promoted → <ID>`,
  `rejected — <one-line reason>`. Rejected and promoted entries stay in the
  file forever — they are what stops the same idea being rediscovered.
- **Promotion bar.** An idea becomes a backlog item only when the repo's own
  backlog rules allow it (for example, a live decision is blocked on it, or
  there is measured, repeated pain). Ask; do not promote on your own
  judgment.
- **One entry per distinct idea** in a note.
- **Duplicates refine, not repeat.** If a new idea overlaps an existing entry
  (including a rejected one), refine the existing entry instead of adding a
  new one.
- **Privacy.** Entries describe product ideas only. No account numbers,
  balances, names of private persons, or other private facts. Raw source
  material stays in the repo's private area or scratchpad; the entry's
  Source line points at it.
- **Review cadence.** Review the register with the repo's slated-backlog
  re-evaluate dates, or when a new batch of ideas arrives. No weekly review.

## Edges

Each entry has an **Edges** field: one typed edge per line, so agents can read
the register as a graph.

Format: `- <type>: <TARGET-ID> — <short reason>`. The reason is optional but
expected for `conflicts-with` and `alternative-to`. A target is an IDEA ID in
the same file, a backlog ID in the same repo (`<PREFIX>-NNN`), or a
cross-repo ID written `<repo>:<ID>`. Write `- none yet` when there are none.

Closed vocabulary — use no other types:

| Type | Direction | Meaning |
|---|---|---|
| `depends-on` | directed | This idea needs the target to exist first. |
| `part-of` | directed | This idea is a component or refinement of the larger target idea. |
| `enables` | directed | This idea makes the target easier or possible (soft, not required). |
| `overlaps` | symmetric | Substantially the same ground; a merge candidate. Also used toward a backlog item that would serve this idea. |
| `conflicts-with` | symmetric | Assumptions or outcomes are in tension; give the reason. |
| `alternative-to` | symmetric | A different way to meet the same need; pick one. |
| `supersedes` | directed | This idea replaces the target (the target is usually then rejected). |
| `promoted-to` | directed | Written on promotion, pointing at the backlog item. |

- **Symmetric edges are written on both nodes.** When you add
  `overlaps: X` to entry A, add `overlaps: A` to entry X in the same edit.
  An edge toward a backlog item is written on the idea only — backlog items
  are never edited to point back at ideas.
- **Directed edges are written on the source node only.** Never write an
  inverse (`required-by`, `has-part`, `superseded-by`); agents derive
  inverses when analyzing.
- **No dangling edges.** Every target must exist: an IDEA ID in this file, a
  backlog ID in this repo's backlog files (active, slated or archive index),
  or an ID in a named repo you can read. Check this whenever you add or edit
  an entry.

## Entry template

```markdown
## <PREFIX>-IDEA-001: Short descriptive title (5–8 words)

**Story**
As a [user type], I want [capability] so that [outcome].

**Area**
<one value from this file's Area vocabulary; secondary in parentheses if relevant>

**Phase** (a guess, not a priority)
core | next | later | explore

**Status**
idea | refining | promoted → <BACKLOG-ID> | rejected — <one-line reason>

**Source**
<where it came from, e.g. "chat transcript: <topic>, <YYYY-MM-DD>">

**Serves**
<which goal in the repo's intent/vision it moves>

**Acceptance criteria** (optional until clearer)
- [ ] ... (or TBD)

**Notes / context**
...

**Open questions**
- ...

**Edges**
- depends-on: <PREFIX>-IDEA-003 — needs the canonical data model first
- part-of: <PREFIX>-IDEA-001
- conflicts-with: <PREFIX>-IDEA-009 — assumes a daily cadence; the workflow is monthly
- overlaps: <PREFIX>-011
```

Keep the field order. Omit nothing; a field with no content yet gets `TBD`
(or `- none yet` for Edges).

**Format rules — the file is machine-read.** Graph viewers that read
EposForge file backlogs can read this file too, so keep it strictly
parseable:

- Entry heading exactly `## <PREFIX>-IDEA-NNN: Title` — colon straight after
  the ID, one space.
- Each field label on its own line as `**Label**`, optionally followed by a
  parenthetical on the same line (`**Phase** (a guess, not a priority)`). The
  value runs on the following lines until the next `**Label**` line or the
  next `## ` heading.
- The Status value starts with `idea`, `refining`, `promoted` or `rejected`.
- Edges are list items `- <type>: <TARGET> — <reason>` (em dash, or ` - `,
  before the reason), or `- none yet`.
- Text before the first entry heading is the header, not an entry. The header
  uses no `## ` heading that matches the entry pattern.
- Fenced code blocks are ignored by readers, so templates and examples inside
  fences are never entries.

## File header template

A new `ideas.md` starts with this header. Fill the Area vocabulary with the
operator — it is repo-specific and it is the only list Area values may come
from.

```markdown
# Ideas register — <repo name>

Notional product ideas for this repo: not yet decided, kept as food for future
development. **This is not the backlog.** Nothing here has effort, priority or
a commitment. An idea becomes work only by promotion, which writes an ordinary
backlog item and marks the idea `promoted → <ID>`. Rejected and promoted
entries stay in this file.

- **ID prefix:** `<PREFIX>-IDEA-NNN` (from `.eposforge/backlog/config.toml`)
- **Area vocabulary:** `<area-one>` | `<area-two>` | `<area-three>` | `other`
- **Serves:** goals in `<path to this repo's intent or vision doc>`
- **Edge vocabulary:** depends-on, part-of, enables, overlaps (symmetric),
  conflicts-with (symmetric), alternative-to (symmetric), supersedes,
  promoted-to
- **Review:** with the slated backlog's re-evaluate dates, or when a new batch
  of ideas arrives.

Entries follow, newest at the end.

---
```

## Workflow — capture

1. **Locate the repo.** Use the repo the operator names, else the current
   working repo (`git rev-parse --show-toplevel`). Say which repo you are
   writing to before you write.
2. **Locate the ideas file** at `.eposforge/ideas/ideas.md`.
   - Missing: say so and offer to create it with the header above. Ask the
     operator for the Area vocabulary (offer a short draft drawn from the
     repo's intent or vision doc, but let them decide) and for the path that
     **Serves** points at. Do not create it without a yes.
   - Present: read the header for the Area vocabulary and Serves target.
3. **Read the prefix** from `.eposforge/backlog/config.toml` (`prefix = "..."`).
   If there is no config, ask for a prefix (see above).
4. **Split the note.** One entry per distinct idea. If a note mixes an idea
   with already-decided work, say which part looks like backlog material
   rather than filing it as an idea.
5. **Duplicate and edge check.** For each idea, scan every existing entry —
   including `rejected` and `promoted` ones — and the repo's backlog files.
   - Substantially the same as an existing entry: **refine that entry**
     instead of adding one. Add a Source line, merge notes and open
     questions, keep its ID. If the existing entry is rejected, show the
     operator the rejection reason and ask whether anything has changed
     before reopening it.
   - Related but distinct: propose typed edges from the closed vocabulary,
     with a one-line reason for each. Show the proposals; write only the
     ones the operator accepts (or all of them, if the operator asked you
     not to check in).
   - Already covered by a backlog item: propose `overlaps: <PREFIX>-NNN` and
     tell the operator the idea may already be decided work.
6. **Assign the next ID.** Highest `<PREFIX>-IDEA-NNN` in the file plus one.
   Entries are never deleted, so this never reuses an ID; if the file looks
   edited by hand and numbers are missing, still go above the highest.
7. **Fill only what the input supports.** Story, Area (from the header's
   vocabulary only), Phase (a guess), Status `idea`, Source. Leave
   Acceptance criteria and Open questions sparse or `TBD`. Do not invent
   requirements. If the note is too vague for a coherent story, still write
   the entry, put the raw note (minus anything private) in Notes / context
   and mark the Story as needing refinement.
8. **Append** the entry at the end of the file. In the same edit, back-fill
   every accepted symmetric edge on the other node.
9. **Check edges.** Every edge you wrote or touched resolves to an ID that
   exists, and every symmetric edge appears on both nodes. Report any
   dangling target instead of writing it; if the target is in another repo
   you cannot read, say the edge is unverified.
10. **Report** the IDs written or refined, the edges added (and back-filled),
    and anything you chose not to file.

## Workflow — promote

1. Confirm the promotion bar with the operator: what decision is blocked, or
   what repeated pain was measured. If neither, say so and stop unless they
   still want it promoted.
2. Write an **ordinary backlog item** in that repo's backlog format. For a
   repo on the file-based backlog adapter, use its `new-issue.sh` through the
   framework home (`"${EPOSFORGE_HOME:?set EPOSFORGE_HOME}"/.eposforge/backlog/file-based-backlog/scripts/new-issue.sh`)
   and fill the item to that repo's schema; carry the Story, Acceptance
   criteria and Notes across, and cite the idea ID in the item's notes. Run
   that repo's backlog lint afterwards.
3. On the idea entry, set **Status** to `promoted → <BACKLOG-ID>` and add the
   edge `- promoted-to: <BACKLOG-ID>`. Leave the entry in place.
4. Check the idea's other edges still resolve, and report the new backlog ID.

## Workflow — reject

1. Ask for (or confirm) a one-line reason. A rejection without a reason is
   not recorded.
2. Set **Status** to `rejected — <reason>`. Leave the entry and its edges in
   place — they explain the rejection later.
3. If another idea replaces it, add `supersedes: <this ID>` on the replacing
   entry (directed: source only).

## Editing an entry

When refining, renaming or re-linking an entry: keep its ID, re-run the edge
check (step 9 above), keep symmetric edges on both nodes, and fix any edge
that pointed at an ID that no longer resolves (for example a backlog item
that was renumbered or superseded) — say what you changed.

## Analyzing the register

Read the Edges fields as a directed graph whose nodes are ideas and backlog
items. Derive inverses yourself; they are never written.

- **Clusters.** Follow `part-of` (toward the larger idea) and `overlaps`. A
  connected group is one theme; several `overlaps` inside it are merge
  candidates to put to the operator.
- **Prerequisite chains.** Follow `depends-on` to its roots. An idea whose
  prerequisites are all promoted or already built is closer to ready; an idea
  that many others depend on is a likely next promotion.
- **Conflicts to resolve.** Every `conflicts-with` and `alternative-to` pair
  is an open choice. List them with their reasons; do not resolve them
  yourself.
- **What a backlog item would serve.** For a backlog ID, collect the ideas
  with `overlaps: <ID>`, `depends-on: <ID>` or `enables` chains reaching it —
  that is the undecided value the item would unlock.
- **Hygiene.** Report dangling targets, symmetric edges present on only one
  node, edge types outside the closed vocabulary, and written inverses.

Report findings; change entries only when the operator asks.

## Example

The repo is a reading-list app with backlog prefix `APP`. Its ideas file
already holds `APP-IDEA-002: Import highlights from e-reader exports`. Its
Area vocabulary is `capture | organize | share | other`.

**Input:** "Napkin note — when I finish a book I'd like the app to pull my
highlights in automatically and show me the three I marked most, so I
actually revisit them."

The highlight import overlaps `APP-IDEA-002`, so that part refines the
existing entry (new Source line, merged note). The "show the top three to
revisit" part is a distinct idea that needs the import first. One new entry:

```markdown
## APP-IDEA-007: Resurface top highlights after finishing

**Story**
As a reader, I want the app to show my most-marked highlights when I finish a
book so that I actually revisit them.

**Area**
organize (capture)

**Phase** (a guess, not a priority)
next

**Status**
idea

**Source**
napkin note in chat, <YYYY-MM-DD>

**Serves**
"Turn reading into something I remember" (intent doc, goal 2)

**Acceptance criteria** (optional until clearer)
- [ ] TBD

**Notes / context**
"Most marked" is undefined — could mean most-revisited or explicitly starred.

**Open questions**
- What counts as most marked?
- In-app prompt, or a later reminder?

**Edges**
- depends-on: APP-IDEA-002 — needs imported highlights to rank
```

`depends-on` is directed, so nothing is written on `APP-IDEA-002` for it. Had
the operator accepted `overlaps: APP-IDEA-002` instead, the same edit would
also add `- overlaps: APP-IDEA-007` to `APP-IDEA-002`.
