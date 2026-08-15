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

> **Stop** when no `claims_verified[].result == "refuted"`, **and**
> `uncovered_scope[]` is empty, **and** no finding has `severity` in
> {blocker, major} with an effective attribution of `introduced-by-change`.
> **Else** another round, to a hard cap.

It reads closed-vocabulary fields only. `verdict` is ignored on purpose:
termination must not depend on either agent's opinion that it is done. There is
a test for exactly that.

## Opened at session start, not assembled at the end

This is the one design decision the rest hangs off. `crosscheck-claim` opens the
handoff when the work starts and appends to it as the work happens:

```sh
crosscheck-claim open  --repo . --clearance medium --agent alpha --provider cli-a --model m1
crosscheck-claim add   --statement "the linter reports zero errors in every root" \
                       --evidence-cmd './scripts/lint.sh --all' --check exit0 \
                       --files scripts/lint.sh,config/roots.txt
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

The shipped defaults (8000 out, 4000 back) come from measuring one real
cross-vendor review, not from intuition: the hand-written reviewer prompt that
motivated this contract was ~2.6k tokens, and the reviewer's own replies across
that session had a median of ~0.7k and a 90th percentile of ~3.2k. Outbound gets
3× the reference prompt; inbound sits just above p90, so a findings payload
larger than most of that review's turns has to move its evidence behind
`evidence_ref`. Re-measure on your own traffic and set your own numbers.

## Tools

| Command | Does |
|---|---|
| `crosscheck-claim` | open / append to a handoff; validates on every write |
| `crosscheck-verify-scope.sh` | do the promised revisions still exist and still sit on their branch → `scope[].integrity` |
| `crosscheck-run-checks.sh` | execute every mechanical claim → `check_results[]` |
| `crosscheck-coverage.sh` | changed files minus claimed files → `coverage.uncovered[]` |
| `crosscheck-attribute.sh` | run `repro_cmd` at both SHAs → `attribution_checked` |
| `validate-payload.sh` | schema + cross-field validation of any payload |
| `crosscheck-decide.sh` | the stop rule; prints `stop` \| `continue` \| `halt` |
| `test.sh` | all of the above, no model involved |

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
| `CROSSCHECK_FINDINGS_TOKEN_CAP` | `4000` | inbound ceiling, deliberately tighter |
| `CROSSCHECK_MAX_ROUNDS` | `3` | after which `crosscheck-decide.sh` returns `halt` |

## Where this ends up

Every recurring finding is a candidate to become a permanent lint rule or repo
test, so the next review never re-litigates it. The loop is best understood as a
factory for deterministic checks; that, and not the loop itself, is the long-run
payoff.

Related: EF-042 (blocker records), EF-046 (the multi-valued field precedent),
EF-076 (`Fix surface:`, the same extend-don't-collapse principle).
