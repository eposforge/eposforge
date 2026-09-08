---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Program-First Procedures and Vehicle Classification

## Status

- adopted: 2026-09-08
- supersedes: none
- declined-options:
  - "keep known procedures in instruction files because they are cheaper than code" —
    declined; once the steps are written, the program is the source of truth.
  - "hard language default in agent instructions" — declined; classification first,
    and an adopter may record a class-3 prior in its own overlay.
  - "dual POSIX and PowerShell implementations of every shared program" — declined;
    write once, thin launchers.
  - "one factory-wide mega-library" — declined; second consumer plus
    home-follows-subject.
  - "born-public shared libraries with private trees only as bindings" — declined;
    write-publishable from day one, extract when gated.
  - "ban all operating inference" — declined; declare and budget `continuous-loop`.
- related: Standard 03 (agent skills), Standard 08 (agent coding guidelines),
  Standard 10 (ungameable gate), Standard 11 (paired-change enforcement),
  Standard 12 (code-surface encapsulation)
- spec-version: n/a

## Scope

Governs known factory and product **procedures** (declared step sequences). Does
not govern product UX ([Standard 12](../12-code-surface-encapsulation/code-surface-encapsulation.md)).
**Does not name a programming language.**

## Normative requirements

1. **Program-first.** Once the steps of a procedure are known, they MUST live in
   a program under a declared code root. A skill or runbook MUST wrap that
   program (when, dry-run, human gate, refusals, verify) and MUST NOT be the
   only place the steps exist. Judgment MAY stay in prose.
2. **Classification before commit.** Before committed code, the author MUST name
   exactly one `vehicle-class:` from the table below. "It is the default" and
   "it is quicker" are not valid reasons. Ceremony scales: one line for glue, a
   short why for an in-repo pipeline or a library, an ADR for a new product or
   an off-list language.
3. **Class boundary.** A program whose job is transforming files or git state in
   a repo, with tests beside it, MUST be classed `in-repo-pipeline` even when a
   second consumer exists. `library-or-service` is APIs, long-lived domain
   models and network services. Second consumer decides **home**, not class.
4. **One canonical copy.** Invocation MUST use the documented home variable for
   that program's tree. For programs shipped in this repo that variable is
   `EPOSFORGE_HOME`, defined by `skills/install.sh` and `skills/INSTALL.md`
   (clone root, overridable); unset means a script-calling skill is not
   installed. Cwd-relative invocation is non-conformant. Product procedures
   MUST NOT be required to use `EPOSFORGE_HOME`; they use their product's own
   documented home.
5. **Reuse / home.** Share a library only with a second consumer, or a named one
   about to exist. Home follows subject: factory substrate → the pattern repo
   or the adopter's factory overlay; cross-product machinery that is not
   factory substrate → that product family's shared tree; one product's
   domain → that product.
6. **Write-publishable.** Programs and their docs MUST NOT contain instance
   data, adopter identifiers, or host names (Standard 08 requirement 5).
   Extract and publish is a separate, operator-gated decision;
   write-publishable is not a stage gate that delays usefulness.
7. **Code roots.** Programs live in declared code roots: product `code_globs`
   where a registry exists, plus `<container>/**/scripts` and `skills/*/scripts`
   for framework and self-host script trees. A procedure helper is not "thin
   glue next to docs".

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

Do not confuse this with `check-doc-classification.py`, which validates
`doc_kind` / `scope` / `maturity` on Markdown and is unrelated.

## Conformance

Points at the four checkers by requirement (the instance names the scripts):

- **G1** — new files in declared code roots carry `vehicle-class:`.
- **G2** — a procedure `SKILL.md` whose body is a numbered executable recipe
  invokes a program via the documented home variable.
- **G3** — no cwd-relative invocation in `SKILL.md` or always-loaded
  instructions.
- **G4** — allowlisted Living Specs declare `operating_inference`, and
  `continuous-loop` carries reason and budget.

## Related

- [../03-agent-skills/agent-skills.md](../03-agent-skills/agent-skills.md) —
  skill vs tool vs runbook; a procedure skill wraps a program under this
  standard.
- [../08-agent-coding-guidelines/agent-coding-guidelines.md](../08-agent-coding-guidelines/agent-coding-guidelines.md) —
  requirement 5, write-publishable / public-private discipline.
- [../10-ungameable-gate/ungameable-gate.md](../10-ungameable-gate/ungameable-gate.md) —
  green gates are shape, not proof a migration is finished.
- [../11-paired-change-enforcement/paired-change-enforcement.md](../11-paired-change-enforcement/paired-change-enforcement.md) —
  `code_globs` as declared code roots.
- [../12-code-surface-encapsulation/code-surface-encapsulation.md](../12-code-surface-encapsulation/code-surface-encapsulation.md) —
  conversational-first for product UX; this standard carves out known
  procedures.
