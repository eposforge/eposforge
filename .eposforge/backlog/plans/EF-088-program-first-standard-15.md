# Plan: Vision principle 6 split + Standard 15 + Standard 12 amendment (EF-088)

**Date:** 2026-09-07
**Status:** Open; must not merge until EF-066 and EF-087 have landed
**Tracking:** EF-088 (target shape of `procedure-skills-to-programs`)
**Related:** EF-086 (owner), EF-089 (`operating_inference`), EF-090 (the gates), Standard 03 / 08 / 10 / 11 / 12

## Vision principle 6 — replacement text

> 6. **Conversational-first for product UX; program-first for known procedures.** Prefer
> conversational surfaces for a new product capability; promote to GUI and API when use pulls
> them. Once the steps of a factory or a product procedure are known, they live in a program.
> Skills and runbooks wrap that program (when, dry-run, human gate, refusals); they are not the
> program. Judgment stays in prose. Encapsulate programs in declared code roots so
> code-structure tools stay scoped. See Standard 12 (UX + encapsulation) and Standard 15
> (procedures + classification).

## Standard 15 — `04-standards/15-program-first-procedures/program-first-procedures.md`

Standards-meta order: Status, Scope, Normative requirements, Conformance, Related. Non-normative
notes may follow.

### Status — declined options (record all six)

- "keep known procedures in instruction files because they are cheaper than code" — declined;
  once the steps are written, the program is the source of truth
- "hard language default in agent instructions" — declined; classification first, and an
  adopter may record a class-3 prior in its own overlay
- "dual POSIX and PowerShell implementations of every shared program" — declined; write once,
  thin launchers
- "one factory-wide mega-library" — declined; second consumer plus home-follows-subject
- "born-public shared libraries with private trees only as bindings" — declined;
  write-publishable from day one, extract when gated
- "ban all operating inference" — declined; declare and budget `continuous-loop`

### Scope

Governs known factory and product **procedures** (declared step sequences). Does not govern
product UX (Standard 12). **Does not name a programming language.**

### Normative requirements (the MUST list)

1. **Program-first.** Once the steps of a procedure are known, they MUST live in a program
   under a declared code root. A skill or runbook MUST wrap that program (when, dry-run, human
   gate, refusals, verify) and MUST NOT be the only place the steps exist. Judgment MAY stay in
   prose.
2. **Classification before commit.** Before committed code, the author MUST name exactly one
   `vehicle-class:` from the table below. "It is the default" and "it is quicker" are not valid
   reasons. Ceremony scales: one line for glue, a short why for an in-repo pipeline or a
   library, an ADR for a new product or an off-list language.
3. **Class boundary.** A program whose job is transforming files or git state in a repo, with
   tests beside it, MUST be classed `in-repo-pipeline` even when a second consumer exists.
   `library-or-service` is APIs, long-lived domain models and network services. Second consumer
   decides **home**, not class.
4. **One canonical copy.** Invocation MUST use the documented home variable for that program's
   tree. For programs shipped in this repo that variable is `EPOSFORGE_HOME`, defined by
   `skills/install.sh` and `skills/INSTALL.md` (clone root, overridable); unset means a
   script-calling skill is not installed. Cwd-relative invocation is non-conformant. Product
   procedures MUST NOT be required to use `EPOSFORGE_HOME`; they use their product's own
   documented home.
5. **Reuse / home.** Share a library only with a second consumer, or a named one about to
   exist. Home follows subject: factory substrate → the pattern repo or the adopter's factory
   overlay; cross-product machinery that is not factory substrate → that product family's
   shared tree; one product's domain → that product.
6. **Write-publishable.** Programs and their docs MUST NOT contain instance data, adopter
   identifiers, host names or `*.lan` (Standard 08 requirement 5). Extract and publish is a
   separate, operator-gated decision; write-publishable is not a stage gate that delays
   usefulness.
7. **Code roots.** Programs live in declared code roots: product `code_globs` where a registry
   exists, plus `<container>/**/scripts` and `skills/*/scripts` for framework and self-host
   script trees. A procedure helper is not "thin glue next to docs".

### The vehicle-class table

| Class | What it is | Vehicle | Ceremony |
|---|---|---|---|
| `host-ci-glue` | Compose, systemd, git hooks, one-shot install, PATH wrappers | That OS's shell, or a thin launcher over a write-once core | One line naming the class |
| `in-repo-pipeline` | Transforms files or git state in a repo, with tests beside it. Stays this class **even when a second consumer exists.** | Any language with tests | Short why |
| `library-or-service` | APIs, long-lived domain models, network services | This standard names no language. An adopter overlay MAY record a prior. | Short why; **ADR** for a new product or an off-list language |
| `vendor-locked-runtime` | The platform accepts only one language | That vendor's language | Short why, citing the lock |
| `disposable-spike` | An empirical unknown | Anything | Do not commit it as the program |

Recorded as a one-line marker on the committed program so a gate can see it:

```text
# vehicle-class: host-ci-glue
```

Do not confuse this with `check-doc-classification.py`, which validates `doc_kind` / `scope` /
`maturity` on Markdown and is unrelated.

### Conformance

Points at the four checkers by requirement (the instance names the scripts): G1 new files in
declared code roots carry `vehicle-class:`; G2 a procedure `SKILL.md` whose body is a numbered
executable recipe invokes a program via the documented home variable; G3 no cwd-relative
invocation in `SKILL.md` or always-loaded instructions; G4 allowlisted Living Specs declare
`operating_inference`, and `continuous-loop` carries reason and budget.

## Standard 12 amendment

Keep Standard 12's title domain — product delivery surface and code-surface encapsulation.
Change only the normative reading that folds procedures into conversational-first:

- §1 continues to govern **product UX**: conversational first; GUI and API when pulled; no UI
  required on day one.
- A new §1.5 (or an explicit non-scope bullet): **known procedures are out of this standard's
  conversational-first rule** and are governed by Standard 15. A skill whose body is the step
  list of a known procedure is non-conformant under Standard 15 even if Standard 12 would have
  called it conversational delivery.
- §2 encapsulation still applies: when the program exists it lives in a declared code root,
  including `skills/<name>/scripts/` and the self-host script trees. The "thin glue MAY exist
  outside code roots" allowance is tightened — a procedure skill's helper is a program, not
  thin glue next to docs.
- Declined options gain: "treat a written-down procedure as cheaper to keep in a skill than in
  a program" — declined.

## `AGENTS.md`

Drop "There is no application code; the artefacts are Markdown files." Add the code-root
admission and three condensed lines: call the program via the documented home variable; name
`vehicle-class:` before committing a program ("default" and "quicker" are not reasons; file/git
transforms stay `in-repo-pipeline` even with a second consumer); Living Specs declare
`operating_inference`. The migration line itself is already there from EF-087.

## Public/private discipline for this item

Every file this item touches stays generic: no adopter names, no product-suite names, no host
names, no `*.lan`, no language prior. Overlay guidance — including any factory's class-3 prior
and any product family's shared-tree rules — belongs in that adopter's own repo, not here.
