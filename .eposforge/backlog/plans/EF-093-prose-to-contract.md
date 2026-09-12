---
doc_kind: plan
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Plan — `prose-to-contract` (EF-093)

> Owner item: EF-093. This file holds the narrative; the items hold the work.
> If the two disagree, the items win.

## The direction in one sentence

Knowledge an agent needs is currently held as prose the agent re-reads and
re-interprets on every use. It should be held as contracts a runtime
enforces — a tool schema, a generated config, a declared root, a queryable
graph.

## Why it needs an umbrella at all

The member items are individually small and mostly obvious. The risk is not
that any one of them is hard; it is that a dozen small tickets filed over six
months read as unrelated housekeeping, and the direction disappears. A named
migration is the mechanism this backlog already has for exactly that:
`aggregate.sh --strangler` renders every member in one view regardless of which
repo it lives in, and an agent that opens any member can reach the owner row.

The test of whether this file is doing its job: someone who has never seen this
work should be able to read the owner item plus this file and correctly predict
which bucket a new idea belongs in.

## The four phases

Ordering is real. Each phase makes the next one cheap, and doing them out of
order produces work that has to be redone against a moved target.

### 1. DECLARE — say what each repo is made of

Nothing else can be pointed anywhere until this is true. A code indexer, an
instruction graph, or a conformance dataset built against an undeclared tree
indexes the wrong files, and the error is silent.

The estate's own cautionary example: the pattern repo reports roughly 890
source files, almost all of which are a vendored virtualenv.

Done when every repo declares its code roots and, by complement, its prose
surfaces.

### 2. REGISTER — procedures become callable things with schemas

Two hops, and the second is the one people skip:

- **Hop one** — the steps move out of prose into a committed program. This is
  `procedure-skills-to-programs` (EF-086), already in flight with its own
  completion commitment. It is a phase of this migration, not a sibling; it is
  not re-parented and not closed early.
- **Hop two** — the program is registered as a tool with a declared schema.
  A program the agent shells out to still loads invocation prose into the
  conversation and still costs a round trip. The model sees instructions about
  a command, not a schema.

Hop two is not universal. Registering has a real cost — a server to host it, a
schema to maintain, an owner. The deliverable of EF-094 is the test that
separates the cases, not a rule that everything becomes a tool.

**And some prose does not become a contract — it goes away.** A migration that
only ever adds is not a strangler. The designation review is expected to
produce deletions, and a wrapper left behind after its body moved is debt
(EF-095).

### 3. GENERATE — one declaration, many surfaces

Harness configuration, tool assignment and instruction projection stop being
hand-maintained per surface.

The load-bearing rule for this phase: **one plane decides content, generators
only project it.** The MCP assignment plane already answers "which servers does
this CLI load in this repo"; it grows an agent-role axis to answer "which tools
does this subagent get." A second generator keeping its own answer to that
question is the failure mode, because when an agent has the wrong tools nobody
can tell which file it obeyed.

Measure before converting. "Too many tools overwhelms the agent" needs a number
or the phase cannot be evaluated. The number is **callable operations visible to
one agent**, not registered server names — otherwise the cheapest way to hit any
target is to merge ten tools into one with a `mode` argument, which makes
discoverability worse while the metric improves. A duplicate-verb-name check
runs alongside it, because independently built per-repo servers will all reach
for `search`.

### 4. NAVIGATE — graphs replace whole-corpus reads

The surfaces, deliberately kept distinct because they answer different
questions and merging them is the failure this estate has already declined
once:

| Surface | Question | Epistemic position |
|---|---|---|
| Contracts / Spec Graph | what does the pattern say? | intent |
| Code structure | what does this code call? | as-built |
| Instruction topology | what loads into context, and from where? | as-built |
| Host / estate topology | what exists in the factory? | as-built |
| Interaction corpus | what was actually said? | record |
| Curated domain graphs | what is known about this subject? | curated |

Phase 4 will outlive the completion commitment. That is expected.

## Completion commitment

**2027-12-31** — every member item resolved or explicitly re-scoped by that
date. Not a promise the direction is finished.

## How to file into this

- Does it move knowledge from prose an agent re-reads toward a contract a
  runtime enforces? Then it is a member: add `TargetShapeOf: prose-to-contract`.
- Does its own work still invest in the prose shape — including deleting it?
  `LegacyShapeOf: prose-to-contract`.
- Is it in one of the four phases but doesn't change where knowledge lives
  (a bug fix in an existing tool, say)? Not a member. Over-labelling makes the
  view useless faster than under-labelling.
- Adopters file in their own backlogs and reference this slug. Adopter IDs
  never appear in this repo (EF-047).

## Cross-repo lint note

Members live in several repos, so `LegacyShapeOf:` / `TargetShapeOf:` only
resolve when every participating root is in `BACKLOG_ROOTS` in one invocation.
Linting one adopter repo alone reports the slug as unknown. That is the same
constraint cross-repo `Depends on:` / `Blocks:` already has; it is not specific
to this migration, but it will be hit more often now.
