# Cross-agent review contract

The contract between an agent that did the work and a different agent that
checks it. Three payloads, a mechanical stop rule, and the pure bash + jq tooling
that makes all three decidable without a model in the loop.

Filed as **EF-075**. Which agent reviews, and at what privacy clearance, is
adopter routing policy and is deliberately not here.

## Why a contract at all

A reviewer spawns cold. Its entire context is what the handoff carries plus what
it reads for itself, which makes the payload the only place the exchange can be
designed. Two payloads cannot terminate — without a disposition leg the
implementer never answers the findings and round N+1 merely re-asserts — so
there are three.

## The three payloads

| File | Direction | Schema id |
|---|---|---|
| `handoff.v1.json` | implementer → reviewer | `eposforge.crosscheck.handoff/1` |
| `findings.v1.json` | reviewer → implementer | `eposforge.crosscheck.findings/1` |
| `disposition.v1.json` | implementer → reviewer, round N+1 | `eposforge.crosscheck.disposition/1` |

Payloads live outside any repository, one directory per round:

```
$CROSSCHECK_DIR/<session>/round-<N>/{handoff,findings,disposition}.json
```

Outside, because a payload that *can* be committed eventually *will* be — and it
carries paths, SHAs and claims that have no business in a public tree.

## The stop rule

> **Stop** when no `claims_verified[].result == "refuted"`, **and** no mechanical
> claim's own check failed, **and** `uncovered_scope[]` is empty, **and** no
> finding has `severity` in {blocker, major} with an effective attribution of
> `introduced-by-change`.
> **Else** another round, to a hard cap.

It reads closed-vocabulary fields only. `verdict` is ignored on purpose:
termination must not depend on either agent's opinion that it is done. There is
a test for exactly that.

The check-results clause matters more than it looks. A reviewer can confirm a
claim the harness already disproved — through inattention, or because the claim
reads plausibly — and without this clause that confirmation would end the loop.
Where the machine has an answer, the machine's answer wins. That is the whole
reason the checks run before the reviewer is spawned.

## Opened at session start, not assembled at the end

This is the one design decision the rest hangs off. `crosscheck-claim` opens the
handoff when the work starts and appends to it as the work happens:

```sh
crosscheck-claim open  --repo . --clearance medium --agent alpha --provider cli-a --model m1
crosscheck-claim add   --statement "the linter reports zero errors in every root" \
                       --evidence-cmd './scripts/lint.sh --all' --check exit0 \
                       --files scripts/lint.sh,config/roots.txt \
                       --cwd .
crosscheck-claim trap  "the linter only ever acts on the first roots entry"
crosscheck-claim flag  --item item-014 --judgment "deferred -> slated" --rationale "the blocker shipped"
```

Four things follow from appending rather than reconstructing:

1. A claim is written while the evidence is still on screen, together with the
   command that produced it.
2. A trap is recorded at the moment it is discovered, which is the only moment
   anyone remembers it. Reconstruction loses these first and they are worth the
   most.
3. Writing into a field called `evidence_cmd` is a different act from summarising
   at the end. "The commit says it is done" does not survive it.
4. The claims are on disk, so they survive a compaction that would otherwise
   destroy the author's ability to state what it did.

It is a shell command rather than hook plumbing so that every agent CLI can call
it. Only the trigger ever needs per-tool work; the accumulate half never did.

`open` is optional. Any append opens a payload when the session has none, using
the git work tree the command was run in — because "record claims as you go" is
an instruction agents read in a persona file, and an instruction that fails on
the first command is not an instruction. Only one agent CLI has a session-start
hook to call `open` for it; the rest have to be able to just start.

Two pointers, and the per-repo one is the important half:

- `$CROSSCHECK_DIR/current` — the last session opened. A single slot.
- `$CROSSCHECK_DIR/by-repo/<percent-encoded repo path>` — the session for that
  work tree. Written by `open`, by `scope` (a session that spans two
  repositories would otherwise split in half the moment `current` belongs to
  someone else), and whenever an append resolves the slow way. Percent-encoded
  because substituting `/` for `_` makes `/a/b/c` and `/a/b_c` the same file.

An append with no session named asks the repository first, then `current` — and
`current` only counts when the payload it names actually has that repository in
its `scope[]`. A payload that never mentions the tree you are working in is not
yours, whatever the pointer says. Getting this wrong is silent: the claim is
written, to somebody else's payload.

## What is computed, and what is left to judgment

The tooling exists to stop spending model attention on arithmetic — not to
pretend judgment is arithmetic.

| Decision | Where it is settled |
|---|---|
| Is a mechanical claim true | `crosscheck-run-checks.sh` runs it before the reviewer spawns |
| Was anything changed but not claimed | `crosscheck-coverage.sh`, set arithmetic over the diff |
| Introduced or pre-existing | `crosscheck-attribute.sh` runs `repro_cmd` at both revisions |
| Should the loop continue | `crosscheck-decide.sh` over closed vocabulary |
| How severe is it | the reviewer — irreducible |
| What to attack first | the reviewer — irreducible |
| Does an uncovered file *matter* | the reviewer, but only after the gap is computed for it |

`class: judgment` is first-class for that last reason. If every claim had to be
mechanically checkable, authors would only claim mechanizable things and the
interesting questions would be excluded by construction — "was live work buried?"
has no exit code.

A mechanical claim names the directory it runs in. `claim.cwd` is the explicit
form (`crosscheck-claim add --cwd`); when it is omitted the harness picks the
unique `scope[]` entry that contains every `files[]` path. A multi-repo claim
that does not disambiguate is refused, not executed in `scope[0]` — that is how
a true claim about a later repo used to become a harness failure. `--cwd` on
`crosscheck-run-checks.sh` is an operator fallback for the whole handoff, not
the directory every claim shares.

Resolution also happens at write time, but only to prove the command runs. The
resolved directory is **not** stored unless the author passed `--cwd`: baking it
in would freeze today's answer, and the `files[]` fallback would never be
consulted again — on this host or on any other.

Check types that parse output:

- `regex` is `jq test` over the whole captured output (Oniguruma). It is not
  GNU grep ERE, and it is not per-line: `(?i)HELLO` matches `hello`.
- `count-eq` / `count-lt` accept the last non-empty line only when that line
  is itself an optional-sign integer (`grep -c` / `wc -l` shape).
  `'58 passed, 0 failed'` is not the number 580.

## The promise a handoff makes, and how it expires

`scope[]` carries SHAs and the reviewer reads the diff itself. That is the
largest saving in the whole design — and it means the payload is a promise that
a specific tree will still be there when the reviewer arrives.

The promise expires, and not only when someone rewrites history on purpose. An
ordinary `git pull` on a branch with unpushed commits rebases them; the
replacement carries a **byte-identical commit subject**. No amend, no rebase
command, no force-push, and nothing a human reads says the revision moved. The
old commit survives in the reflog, so it still reads correctly on the machine
that made it and nowhere else.

So `crosscheck-verify-scope.sh` runs at transport, not at authoring, and
`validate-payload.sh --final` refuses any payload whose `scope[].integrity` is
missing or not `ok`. The distinction it draws is reachability, not existence:
`head-orphaned` means the commit is still an object but no longer on the branch,
which is the case that hides.

**Re-verify, do not refresh.** Advancing `head_sha` to whatever HEAD says now
makes the payload valid again while destroying the only fact that mattered —
that the claims were written against a different tree than the one being handed
over.

There is exactly one moment when advancing `head_sha` is right, and it is the
opposite end of the payload's life. `head_sha` is stamped when the handoff
*opens*, which — with a session-start trigger — is before any work exists. A
session that commits its work therefore arrives at transport with
`base_sha == head_sha`: an empty commit range, from which coverage reports
`uncovered: 0` for a change it never looked at. Nothing drifted, so no integrity
check fires and nothing says a word. `crosscheck-claim refresh` closes that,
advancing `head_sha` and leaving `base_sha` exactly alone; run it when the work
stops and before the payload is prepared, never after a round has been
transported. (`scope --repo X` with no `--base` is not a substitute: it re-reads
the base from today's HEAD and silently destroys the baseline.)

Two guards keep the same pressure off the payload:

- **`uncovered_scope[]`** is the counterweight to an author who knows the rubric.
  An empty `claims[]` against a large `scope[]` must fail, or teaching to the
  test becomes the winning strategy.
- **`attribution`** is machine-checked because "it was already broken" is the
  most abused category and the one that decides whether the loop continues.
  `crosscheck-attribute.sh` prints when its answer contradicts the reviewer's.

## Budgets

Asymmetric on purpose. The reviewer spawns cold, so spending on the way out buys
review quality; findings arrive at the implementer's most context-loaded moment,
so the return path is tight. Diffs travel by reference — `scope[]` carries SHAs
and the reviewer runs `git show` itself, which doubles as clearance enforcement
since it can only read repos it already has.

Over budget **blocks** rather than truncating. Silent truncation would drop
exactly the `traps[]` and `attack_first[]` entries that make the review worth
running. `crosscheck-claim` keeps writing an over-budget payload (so the author
can see what to trim) and warns; `validate-payload.sh` refuses it at transport.

A payload declares its own `budget.cap`, so the cap needs a ceiling of its own —
otherwise "under budget" is satisfied by raising the budget. `validate-payload.sh`
enforces the environment's ceiling against the declared cap.

The shipped defaults (8000 out, 6000 back) come from measurement, not intuition,
and the inbound one has already been re-set once by it.

The first numbers (8000 / 4000) were derived from a single hand-written
cross-vendor review: its reviewer prompt was ~2.6k tokens and the reviewer's own
replies had a median of ~0.7k and a 90th percentile of ~3.2k. Outbound got 3× the
reference prompt; inbound was put just above p90.

Nineteen real findings payloads later, inbound at 4000 was tighter than reality:
the largest was 3519 and three sat within 15 % of the cap. Outbound was never
close — 4468 against 8000 across eighteen handoffs — so only one number moved.

The asymmetry of the two errors is what set it. A cap too low **refuses a review
that already happened**, costing a whole round, and where rounds run unattended
nobody is watching when it does. A cap too high costs a longer payload for the
next round's reader — bounded, visible, and already reported by the round-delta
guard. When the evidence is that a default is nearly binding on ordinary traffic,
the cheap error is the one to take.

These caps gate the size of the payload **files** (`check_budget` measures
`wc -c / 4`), not what the reviewer spent at the model, so they can be measured
exactly from a payload corpus on disk. Re-measure on your own traffic and set your
own numbers — and if you override, set the environment variable rather than
editing the literal, since a harness that writes `budget.cap` and the validator
that enforces the ceiling both read it and must agree.

## Tools

| Command | Does |
|---|---|
| `crosscheck-claim` | open / append to a handoff; validates on every write; `refresh` re-stamps `head_sha` |
| `crosscheck-verify-scope.sh` | do the promised revisions still exist and still sit on their branch → `scope[].integrity` |
| `crosscheck-run-checks.sh` | execute every mechanical claim → `check_results[]` |
| `crosscheck-coverage.sh` | changed files minus claimed files → `coverage.uncovered[]` |
| `crosscheck-attribute.sh` | run `repro_cmd` at both SHAs → `attribution_checked` |
| `validate-payload.sh` | schema + cross-field validation of any payload; `--json-errors` adds a machine-readable error channel |
| `crosscheck-decide.sh` | the stop rule; prints `stop` \| `continue` \| `halt` |
| `crosscheck-next-round.sh` | open round N+1 from a disposed round N |
| `test.sh` | all of the above, no model involved |

### Acting on a validator error without parsing its prose

`validate-payload.sh --json-errors` writes one JSON object to stdout describing
every error it found. The human `INVALID:` lines still go to stderr exactly as
before; this adds a channel rather than replacing one, and without the flag the
output and the exit code are byte-for-byte what they were.

```json
{ "schema": "eposforge.crosscheck.validation-errors/1",
  "kind": "findings", "valid": false, "exit": 3,
  "errors": [ { "pointer": "/findings/0", "path": "$.findings[0]",
                "keyword": "additionalProperties", "property": "correct_state",
                "message": "unexpected property \"correct_state\"",
                "phase": "schema" } ] }
```

It exists because the bounded re-ask has to *act* on these errors, and the only
way to do that used to be matching the English of `unexpected property "X"` — so
a copy-edit to an error string became a test edit in another repository.
`pointer` is RFC 6901; `property` is present whenever the error names a key.

Two properties worth stating plainly, because a machine-readable channel is
exactly the shape of thing that grows a way to say "close enough":

- **It is never a second verdict.** The exit code is computed identically with
  and without the flag, and `valid` is derived from that code rather than from a
  second look at the errors. There is no input for which asking for structured
  errors turns a refusal into a pass; `test.sh` asserts this across every fixture
  and schema, and separately asserts that the pre-`--json-errors` revision cannot
  even accept the flag, so the comparison is against something that really differs.
- **`phase` tells you which errors you may act on.** `schema` errors are shape;
  `cross` errors are substantive and must never be re-asked, because "every claim
  got a verdict" is the check that stops an author shipping unreviewed work. A
  caller that re-asks should require that *no* error has `phase: "cross"` — a
  positive test, not an inference from an absence.

`crosscheck-next-round.sh` is the round-to-round half of the loop, and what it
*drops* is the part worth reading. It carries the session, the implementer, the
scope and the ground rules; it carries no claims, no traps, no attacks. Round
N+1 is a delta — what changed in answer to the findings — because a payload that
re-asserts everything grows every round and buries the two lines that are new.
The same discipline shows up as arithmetic: each `base_sha` advances to that
round's `head_sha`, so coverage measures the fixes rather than the original
work.

It refuses to open a round the loop has no business opening: findings that were
never answered, a disposition that skips a finding (presence is not an answer),
and a loop the stop rule already ended. `--force` overrides the last of those
and says so.

Only `bash`, `jq` and `git` are required. Schema validation runs against the
JSON Schema files here via `lib/jsonschema.jq`, a small validator covering the
subset those schemas use — so the schema stays the single source of truth for
shape and vocabulary, and the shell adds only the rules a schema cannot express.

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `CROSSCHECK_DIR` | `~/.crosscheck` | payload root; keep it outside every repo |
| `CROSSCHECK_SESSION` | generated | session id; adopters capturing wire traffic should reuse theirs |
| `CROSSCHECK_ROUND` | `1` | round within the loop |
| `CROSSCHECK_HANDOFF_TOKEN_CAP` | `8000` | outbound ceiling; a handoff may not declare a larger cap |
| `CROSSCHECK_FINDINGS_TOKEN_CAP` | `6000` | inbound ceiling; raised from 4000 by measurement — see above |
| `CROSSCHECK_MAX_ROUNDS` | `3` | after which `crosscheck-decide.sh` returns `halt` |
| `CROSSCHECK_CLEARANCE_ORDER` | unset | adopter clearance vocabulary, weakest first. When set, `clearance_required` is recomputed as the maximum over `scope[]` |
| `CROSSCHECK_CMD_TIMEOUT` | `120` | seconds before any executed command is killed |
| `CROSSCHECK_CHECK_OUTPUT_MAX` | `65536` | bytes of captured check output kept |
| `CROSSCHECK_ALLOW_REVIEWER_EXEC` | `0` | permits executing `repro_cmd` — see below |
| `CROSSCHECK_SESSION_TTL` | `8 hours` | how recently a payload must have been touched for `open` to treat its session as live |

Liveness is a property of the session, not of a round: `open` looks for a
recently-touched payload in **any** round of the session `current` names. When
one is live, `open` leaves `current` where it is and opens anyway — nothing is
refused for want of a session name, because `by-repo/` is what finds the payload
again. Name a session when you want a stable identity across rounds or across
machines, not in order to start.

## Executing the reviewer's commands

`evidence_cmd` is written by the author, so running it grants nothing that was
not already granted. `repro_cmd` is the opposite: it arrives inside
`findings.json`, written by a different vendor's model, and attribution would
otherwise hand it a shell on the host with the operator's ambient credentials.
It is the only inbound execution path in the contract, and clearance-on-transport
does not address it — that protects what goes *out*.

So `crosscheck-attribute.sh --findings` **prints every command and refuses**
(exit 4) unless `--allow-reviewer-exec` or `CROSSCHECK_ALLOW_REVIEWER_EXEC=1`
says otherwise. Consent is given with the text in view. Without it, attribution
stays the reviewer's assertion and the stop rule treats it as unverified rather
than settled — a worse review, not an unsafe one.

`--repo/--cmd` is not gated: that command came from whoever typed the command
line. Feeding a payload's `repro_cmd` into `--cmd` defeats the gate and is a
deliberate act.

Everything executed is bounded in time (`CROSSCHECK_CMD_TIMEOUT`) and in
captured output (`CROSSCHECK_CHECK_OUTPUT_MAX`). A timeout is not a result: it
fails the check and says so.

## Where this ends up

Every recurring finding is a candidate to become a permanent lint rule or repo
test, so the next review never re-litigates it. The loop is best understood as a
factory for deterministic checks; that, and not the loop itself, is the long-run
payoff.

Related: EF-042 (blocker records), EF-046 (the multi-valued field precedent),
EF-076 (`Fix surface:`, the same extend-don't-collapse principle).
