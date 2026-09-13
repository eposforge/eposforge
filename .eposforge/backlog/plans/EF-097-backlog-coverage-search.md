---
doc_kind: plan
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Plan — backlog coverage agent (EF-097)

> Owner item: EF-097. This file holds the narrative; the item holds the work.
> If the two disagree, the item wins.

## The problem in one sentence

When an agent is about to say how things are or should be, or to file or change
backlog work, nothing makes it look in the backlog first. The backlog is also the
one corpus its other search tools deliberately leave out.

## What happened

An operator asked whether a convention existed for where implementation plan
files live.

1. The agent searched the standards, architecture and agent-instruction docs.
   Nothing.
2. It queried the Spec Graph twice. Nothing, and correctly so: backlog items and
   `plans/` are excluded from graph ingest on purpose (EF-057).
3. It told the operator the rule was not written down. **Wrong.**
4. After the operator pushed back, it found the rule in the `Notes:` of an open
   item (EF-081): "the canonical plan location remains
   `.eposforge/backlog/plans/<ID>-<slug>.md`".

That took about fifteen tool calls and produced one confident wrong assertion.
The root cause was not a weak search. Every search the agent ran was scoped away
from backlog item files, and nothing prompted it to check the backlog before
asserting that something did not exist.

A plain keyword search over item `Notes:` for `plan` and `location` finds that
line. The motivating case needs no semantic matching.

## Why the existing surfaces miss it

| Surface | What it does | Why it did not help |
|---|---|---|
| Spec Graph recall | Structural knowledge | Backlog and plans excluded by design (EF-057). That exclusion is right; do not undo it. |
| `aggregate.sh --regressions <kw>` | One substring over archived items across roots | Archived items only, so no active or slated items and no plans. One substring, no ranking. With a root at the wrong depth it prints "No backlog adapters discovered" and exits 0. |
| EF-057's backlog-traversal skill | On-demand traversals | Someone has to think to call it. The failure was that no one did. |
| portfolio-review redundancy step | Periodic operator pass | Runs weekly-ish, not at the moment of assertion. |
| An adopter's prompt hook | Deterministic gate plus routing text | Tells the agent where to look for state questions. Never searches, and never fires for agent-originated work. |

## Design

### The command

`search-backlog.sh <terms...> [--json] [--limit N]`, a new script beside
`aggregate.sh`. It is a separate script rather than another `aggregate.sh` mode
because harnesses will call it from hooks. That needs a small, stable CLI and exit
code contract that does not move whenever a portfolio view changes.

Corpus, per discovered root (same precedence as the other scripts):

- every item in `backlog.md`, `backlog-slated.md`, `backlog-archive.md`, searching
  `Title:`, `Verify with:` and `Notes:` (with the same mechanical `Notes:`
  boundary EF-081 defines);
- every `.md` file directly under `backlog/plans/`, with the owning item ID taken
  from the filename when it follows EF-081's naming rule.

Matching is case-insensitive per term after a fixed, committed stopword list.
Nothing is stemmed in v1.

Ranking is computed, never judged:

1. number of distinct query terms matched in the item or plan;
2. best field: `Title` > `Verify with` > `Notes` > plan body;
3. status: active > slated > archived;
4. ID.

### Output is observations, not verdicts

Each hit reports the repo, the ID (or the plan path plus its owning ID), the
status or file kind, the field, the path, the line number, and the matching line
cut to a fixed length. The words "covered" and "not covered" never appear.
Whether the hit is the same idea is for the agent or the operator to decide.

`--json` adds a `searched` block: for each root, the resolved path and how many
active, slated and archived items and plan files were read. An empty result then
carries its denominator. "0 hits in 41 active, 8 slated, 210 archived items and 14
plans across 3 roots" is an observation. A bare "no results" invites the wrong
conclusion.

Exit codes follow `grep`: `0` hits, `1` searched and found none, `2` could not
evaluate.

### Refuse, don't report empty

The dangerous output of this tool is a clean "nothing found" from a search that
never read anything. The known way to get one is a `BACKLOG_ROOTS` entry that
names `<repo>/.eposforge/backlog` instead of `<repo>/.eposforge`. Root resolution
then finds no `config.toml`, and today's scripts skip that root silently. So exit
`2`, with a message naming the root, when:

- no root is discovered at all;
- a declared root has no `backlog/config.toml`. If the path ends in `/backlog`,
  the message names the parent directory to use instead;
- a backlog file contains `## Issue` lines but zero items parse (the parser and
  the file disagree);
- every root together holds zero items (nothing to search);
- every query term is a stopword.

A brand-new root with empty files next to populated ones is not an error. It
shows as zeros in `searched`.

The test for the malformed root is paired with a control: the same fixture with
the correct root depth must exit `0`. Without the control, a check that always
exits `2` would pass.

## Triggers

The capability is the coverage agent, with the command as its first step. When
it runs is a trigger contract, and there are four kinds of trigger point because
the work arrives four ways.

| Work arrives as | Trigger point | Owned by |
|---|---|---|
| An operator prompt about how things are or should be, or asking for a change | The adopter's prompt hook runs the coverage agent | Adopter |
| An agent filing through `backlog-author` (EF-081) | The author runs the coverage agent before it files | Pattern |
| An agent filing an item through the tooling | `new-issue.sh --title` | Pattern (this item) |
| An agent editing backlog files directly (subagents, autonomous work) | The adopter's agent-tool hooks, plus the backlog pre-commit hook | Adopter / pattern |

A prompt hook alone is not enough. It fires on operator prompts only, so
subagents, autonomous runs and anything that calls `new-issue.sh` get no
trigger. Those are exactly the paths with no human in the loop to push back.

### Filing: `new-issue.sh --title`

With a title, it searches first. While hits exist it prints them to stderr and
does not append unless `--after-coverage-check` is also passed. The flag is
deliberately explicit, so an agent that files anyway leaves the decision visible
in its transcript. With no title, it behaves as today, but it says on stderr that
no coverage search ran. It does not imply there was nothing to find.

### Commit: pre-commit

For each `## Issue` header the commit adds, the pre-commit hook prints the top
hits, excluding the added item itself. Non-blocking: this is a prompt to look,
and a blocking gate on a heuristic would get bypassed.

### The gate an adopter's prompt hook should use

The contract, stated in the backlog component doc so recall surfaces it:

- **Deterministic gate.** Scope (working directory under a declared root) plus a
  phrase match for normative or change language ("should", "convention", "rule",
  "do we have", "is there a", "where does … live", "file/add/change … item").
  Silent, with zero output, when it does not fire.
- **Deterministic term extraction** from the prompt: quoted strings, path-like and
  ID-like tokens, then remaining words that are not stopwords.
- **Run the coverage agent** on the prompt and the extracted terms, over every
  root. Its report, not raw hits, reaches the session before it replies. How the
  harness runs it is the adopter's choice; the property is that the conversing
  agent cannot skip it. A hook that injects "please delegate to the coverage
  agent" does not meet this: an agent not doing what it was told to consider is
  the failure this exists to remove.
- **Exit `2` is surfaced** as one line saying the lookup could not run and why.
  It is never dropped and never shown as an empty result.
- A time bound, failing open to that one line.

## The coverage agent

The operator asked for an agent that runs automatically, not a hook that pastes
search hits. The command stays, as the agent's first step and as the source of
its refusals; the agent adds what keyword search cannot.

**Why an agent.** Keyword search does find the motivating case. It stops finding
things as soon as the wording moves: "where do design docs for tickets go" shares
no useful term with "implementation plan". It also cannot read the plan a hit
points at and say whether the idea is the same one. Those are judgement calls,
and they are the part of the hunt that produced a wrong assertion.

**Definition.** One harness-neutral file,
`file-based-backlog/agents/backlog-coverage.md`, projected into each harness's
native subagent form by the same install EF-081 uses for `backlog-author`.

| Property | Decision | Why |
|---|---|---|
| Tools | The search command and file reads. No edit, write, filing or agent-spawning tools. | It reports; it cannot change what it is checking. |
| Input | The statement, question or proposed change, plus the gate's extracted terms. | The prompt is the question; the terms are a head start, not a limit. |
| Procedure | Run `search-backlog.sh --json`; read the top hits and any plan they point at; run a bounded number of further searches using wording it derives, including the field names the backlog actually uses. | The bound keeps the cost of each triggered prompt predictable. |
| Output | Each candidate with repo, ID or plan path, the quoted line, and *likely the same idea*, *related* or *different* with one sentence of reason. Keyword hits and candidates found only by its rewording stay distinguishable. Ends with the `searched` counts. | Evidence first, so the session and operator can check the label. |
| Refusal | Command exit `2` or a timeout: one line, "could not check", and why. | Same rule as the command: never an empty result from a search that did not run. |
| Authority | Never files, edits or closes an item. | The operator gate stays on. |

**Cost.** The gate decides whether the agent runs, and a prompt that misses it
spends nothing. The model is pinned in the definition. The adopter measures how
often the gate fires before widening its phrase list.

## Operator constraints this design keeps

- Compute everything that can be computed: gate, terms, search, ranking. The
  model runs only after the gate fires, and only for the judgement the search
  cannot do.
- Default quiet: nothing when not triggered.
- Operator gate stays on: nothing here creates, edits or closes an item.
- Cannot-evaluate refuses; it never reports "nothing found".

## Relationship to other work

- **EF-057.** Its on-demand traversal skill should call this command for search
  rather than grow its own. Not a `Depends on:` edge: EF-057 sits behind EF-056's
  larger graph work, and this is useful without either.
- **EF-081.** Plans live in one known folder, which is what makes "search the
  plans" a directory glob instead of a hunt. Its `backlog-author` subagent runs
  this agent before filing, and the two share one install.
- **`--regressions`.** Observed defect, out of scope here: it shares the silent
  zero-root exit. Once this lands it could become `search-backlog.sh` filtered to
  archived items instead of a second search implementation.
- **`prose-to-contract` (EF-093), phase 4 NAVIGATE.** "Check the backlog before
  you assert" is today an instruction an agent must remember. It becomes a
  command a trigger runs, and agents stop re-reading whole backlog files to
  answer one question. That meets the migration's filing test.

## Open questions

- The stopword list and the prompt-gate phrase list both need a first version.
  Tune them against real prompts before widening them.
- How many follow-up searches the agent may run, and which model it pins. Both
  set the cost per triggered prompt; start low and raise only on observed misses.
- Is `--after-coverage-check` enough of a gate, given an agent can pass it? The
  alternative is an operator-typed confirmation, which would stop autonomous
  filing through the tooling altogether.
- Should the pre-commit output also cover `Title:` changes on existing items, not
  only added headers?
