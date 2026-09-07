# Plan: Skills wrap programs — home-anchored invocation and gates G1–G4 (EF-090)

**Date:** 2026-09-07
**Status:** Open; follows EF-088 and EF-089
**Tracking:** EF-090 — the **gate half** of EF-062
**Related:** EF-091 (the invocation half), Standard 03, Standard 09, Standard 10

## Standard 03 extension

The designation test (tool vs skill vs runbook vs prompt pack) is unchanged. Added:

- When the winner is skill or runbook **and** the steps are known, the skill MUST name the
  program and invoke it via the documented home variable. The skill body is when / dry-run /
  gate / verify.
- Platform or substrate lifecycle with a human gate (setting a secret, elevation, applying a
  compose change) MAY remain a skill wrapping a program that the human runs. The exception is
  the human gate — not "therefore the steps live only in prose".
- Judgment skills stay skills. Where a judgment skill has a mechanical half, that half is a
  program: the docs-lint pair is already the model, with a deterministic link checker as the
  floor and the skill carrying the semantic half.

`skills/INSTALL.md` gains the consume-checklist rule: an installed script-calling skill is not
installed if its home variable is unset and the skill cannot resolve the clone.

## The invocation contract

```bash
# non-conformant
bash .eposforge/<component>/.../<program>

# conformant
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}/.eposforge/<component>/.../<program>" <args>
```

Fail loud beats a cwd-relative path silently resolving against the wrong clone — which, for
tooling that touches a vault or a graph, is the actual hazard.

## The four gates

New checkers live next to the existing ones under
`.eposforge/source-control-ci/github-and-actions/scripts/`, composed into the pre-commit
fragment and a required CI workflow — the same pattern as the installed-scripts-layout and
sensitive-literals checks.

| Gate | Scan set (v1) | Fails when |
|---|---|---|
| **G1** classification present | Files **added** under `.eposforge/**/scripts/**` and `skills/*/scripts/**` (`git diff --diff-filter=A` vs the default branch in CI; staged-added at pre-commit). Union product `code_globs` later, when a registry exists — this repo has none on disk. | A scanned new file carries no `vehicle-class:` marker |
| **G2** procedure skill points at a program | `skills/*/SKILL.md` | The body is a numbered executable recipe and does not invoke a program via the documented home variable |
| **G3** no cwd-relative invocation | `skills/*/SKILL.md` and `AGENTS.md` | Contains `bash .eposforge/` or `bash skills/` without the home variable |
| **G4** Living Spec inference field | Allowlist: `.eposforge/SPEC.md` and `.eposforge/backlog/file-based-backlog/file-based-backlog.md` | An allowlisted file lacks `operating_inference`, or declares `continuous-loop` without reason and budget |

Suggested CLI names (instance-local; the public standard names the requirement, not the
script): `check-vehicle-class.sh`, `check-procedure-skills.sh` (G2 + G3 + the skill frontmatter
migration markers), `check-operating-inference.sh`.

## Fixtures

Held next to the checker, like the other lint tests:

- fail: a `SKILL.md` with ten bash steps and no program pointer
- pass: a `SKILL.md` that states when / dry-run / gate and calls `"${EPOSFORGE_HOME:?}/.eposforge/.../prog" --dry-run`
- fail: `bash .eposforge/foo.sh` — pass: `bash "${EPOSFORGE_HOME:?}/.eposforge/foo.sh"`
- fail: a spec with no `operating_inference`
- fail: `operating_inference: continuous-loop` with no reason or budget
- pass: `operating_inference: none`
- fail: a new `scripts/do_it.py` with no `vehicle-class:` — pass: the same file with `# vehicle-class: in-repo-pipeline`

## Ratchet

1. Land the checkers in **warn** mode with fixtures (CI reports, does not fail the branch).
2. Fail on **new** files and new `SKILL.md` recipes.
3. Fail on **touched** files — opportunistic alignment becomes mechanical.
4. Fail on the remaining known ugly paths, inside the migration's completion scope.

G1 applies to new files in the declared globs immediately. G4 applies to its two-file allowlist
as soon as the field exists in the contract.

**G2 must not ship as a guessed heuristic that fails builds.** Collect operator-reviewed
examples of recipe-vs-judgment first; only then fail new or newly-touched files. A gate that
false-positives judgment skills gets disabled, and then none of the four are enforcing anything.

## Standard 10 conformance note

- **Write scope:** the checkers live in `source-control-ci`, not inside the skill being judged.
  The same-repo limitation that applies to today's layout check applies here — durable
  enforcement is the required CI status check.
- **Spec-derived:** fixtures come from the standard's text, not from whatever implementation
  landed.
- **Outcome altitude:** these gates catch *shape* — cwd-relative invocation, a missing field, a
  skill acting as the program. They do not claim the procedure works; behavioral tests stay
  with the program under paired detection.
- A green G1–G4 is **not** a claim that a migration is finished. The remaining-debt view is.
