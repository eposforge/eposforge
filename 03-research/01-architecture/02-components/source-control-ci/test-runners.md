---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Test runners — candidate catalog

> **Snapshot date:** 2026-08. Verify current details before adopting.
> This catalog scores existing runners against the
> [test-runner sub-contract](../../../../../01-architecture/02-components/source-control-ci-test-runner.md).
> It is **not exhaustive** and **not an endorsement**. No row is a
> required vendor.

The sub-contract is owned by
[Source Control + CI](../../../../../01-architecture/02-components/source-control-ci.md).
The ungameable-gate standard is the *rules*; this catalog is which
existing tools can *host* those rules.

## How to read the scores

| Property | Meaning |
| --- | --- |
| One command | A single invocation is pass/fail. |
| Clone-local | Same command in an implementer tree and an isolated orchestrator clone; no host review-payload directory, no implementer working-clone path. |
| Three classes | Can run standing checks for agent-config, platform, and product trees. Language-specific runners fail this unless every tree uses that language. |
| Write-scope | Can refuse a mixed gate+code change and stay red under merge. |
| Spec-derived | The *tests* can be spec-derived; this is mostly a property of what you put in the suite, not of the binary. |
| Held-out | Can run extra checks the builder does not see. |
| No backfill | Process property; every runner can obey it. |
| Vendor mandate | Does filling the slot with this tool force a named vendor on every repo? |

Scores: **yes** / **partial** / **no**.

## Candidates

### POSIX standing-suite (`.eposforge/standing-suite`)

- **Type:** convention + dispatcher (executable suite, or a list of
  repo-relative commands).
- **Cost tier:** free OSS (POSIX shell).
- **One command:** yes.
- **Clone-local:** yes — the suite lives in the tree.
- **Three classes:** yes — language-agnostic; each tree declares its
  own commands.
- **Write-scope:** yes if the dispatcher (or CI) runs `--check-gate`.
- **Held-out:** yes (`--held-out DIR`).
- **Vendor mandate:** no. The suite may *invoke* pytest in a Python
  product repo without forcing pytest on agent-config or platform trees.
- **Notes:** Worked reference in this repository, tagged
  **example-not-mandate**. This is a convention, not a product. It
  exists because mixed-language factories cannot fill the three-class
  property with a single language runner.

### GNU Make (`make test`)

- **Type:** build tool used as a runner.
- **One command:** yes, if every repo has a `test` target.
- **Clone-local:** yes.
- **Three classes:** partial — only if every tree has a Makefile.
- **Write-scope:** no native mixed-change refusal.
- **Held-out:** partial — extra target possible; not hidden by default.
- **Vendor mandate:** partial (Make itself).
- **Notes:** Fine as *what a standing-suite line runs*. Not sufficient
  alone for a mixed-language factory unless every repo already has Make.

### pytest

- **Type:** Python test runner.
- **One command:** yes (`pytest`).
- **Clone-local:** yes, if the clone has Python + deps.
- **Three classes:** **no** — agent-config and platform trees are often
  shell, not Python.
- **Write-scope:** no native mixed-change refusal.
- **Held-out:** partial (`--rootdir` extra path / `pytest.ini` addopts
  the builder does not see, if you arrange it).
- **Vendor mandate:** yes, if this is *the* slot filler.
- **Notes:** Excellent inside a Python product repo. Does not fill the
  slot for the factory.

### go test

- **Type:** Go toolchain.
- **Three classes:** **no**.
- **Vendor mandate:** yes as a slot filler.
- **Notes:** Same shape as pytest: right for a Go product, wrong as the
  factory runner.

### dotnet test / xUnit

- **Type:** .NET toolchain.
- **Three classes:** **no**.
- **Vendor mandate:** yes as a slot filler.
- **Notes:** Same shape. An adopter's .NET product standard (xUnit,
  NSubstitute, …) stays a *product* default, not the factory runner.

### Jest / Vitest / `npm test`

- **Type:** JavaScript/TypeScript runners.
- **Three classes:** **no**.
- **Vendor mandate:** yes as a slot filler.

### bats / shellspec

- **Type:** shell test frameworks.
- **Three classes:** partial — only if every tree is shell.
- **Vendor mandate:** yes as a slot filler.
- **Notes:** Useful for agent-config and platform scripts. Not a
  product-repo default for compiled languages.

### GitHub Actions / Gitea Actions / GitLab CI

- **Type:** CI engines.
- **One command:** no locally, unless paired with `act` or equivalent.
- **Clone-local:** **no** by themselves — they run on a runner, not in
  an implementer tree or an isolated orchestrator clone as one command.
- **Three classes:** yes, as separate jobs.
- **Write-scope:** yes, as a required status check (durable
  enforcement). That is [Source Control + CI] duty, not a substitute
  for a local runner.
- **Held-out:** yes (secret workflow / hidden repo).
- **Vendor mandate:** no (the engine is already the CI adapter).
- **Notes:** Required as the merge gate. Not the standing runner. The
  same suite the local command runs should be the CI job.

### act (nektos/act)

- **Type:** local GitHub Actions runner.
- **One command:** yes (`act`).
- **Clone-local:** partial — needs Docker and the workflow files.
- **Three classes:** yes, if workflows cover them.
- **Held-out:** partial.
- **Vendor mandate:** no, but it is a heavy local dependency.
- **Notes:** Use when the durable gate *is* Actions and you want
  parity locally. Heavier than a POSIX suite for mixed trees.

## Choosing

Score the factory, not the favourite language:

1. If agent-config, platform, and product are one language, that
   language's runner can fill the slot.
2. If they are not, pick a language-agnostic convention (POSIX
   standing-suite, or Make if it is already everywhere) and let each
   tree's suite *call* pytest / go test / dotnet test as needed.
3. CI remains the durable merge gate. The local command and the CI job
   MUST run the same class of check.
4. Tag any worked example **example-not-mandate**. Do not write
   "adopters MUST use X".

<!-- component-links (generated by check-component-links.py --write-defs) -->
[Source Control + CI]: ../../../../01-architecture/02-components/source-control-ci.md
