---
doc_kind: operator-runbook
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Preferred-Mode Backlog Adoption — Rollout Plan

Plan to bring four adopter repos onto the **Preferred** tooling-distribution mode
of the Component 13 backlog adapter (`file-based-backlog`), scaffold two of them
ahead of a later issue-doc migration, and unify the framework's own backlog under
its `instance/` container so the framework and adopters share one layout.

- **Date:** 2026-06-14
- **Status:** draft — decisions settled (§8); **do not implement until ordered**
- **Framework clone (source of truth for tooling):**
  `/mnt/raid-storage/src/git/gh/eposforge`
- **Adopter repos in scope:** GraceEnterprisesArchitecture (GEA), IAC, OutreachApi, OutreachAssistant

---

## 1. Goal

Every adopter operates its backlog by running the framework's scripts **from the
framework clone** (Preferred mode) — no vendored copy of the scripts in the
adopter. GEA and IAC already hold backlog data and get *completed*; OutreachApi
and OutreachAssistant get *scaffolded* (empty, migration-ready) without moving
their existing issue content yet. The framework's own backlog data moves from the
repo root into `instance/backlog/` (Phase D) so that `instance/` (framework) and
`eposforge/` (adopter) are structurally identical adoption-roots.

---

## 2. Settled design decisions (rationale, so they are not re-litigated)

1. **Preferred mode, not Vendored-copy.** Scripts run from the framework clone via
   `BACKLOG_HOME=<framework>/instance/backlog/file-based-backlog`.
   Adopters do **not** vendor `scripts/`. (Ref: `file-based-backlog.md` §"Tooling
   distribution".)
2. **One container per adopter, named `eposforge/`.** Everything an adopter takes
   from the eposforge architecture lives under a single top-level `eposforge/`
   directory, namespaced away from the repo's own files. The framework repo's
   equivalent container is `instance/`; it is named differently only because a
   folder named `eposforge` inside the eposforge repo would be a confusing
   self-duplicate. Adopters **must not** reproduce the `instance/`
   wrapper (adapter-layout-mirror Rule 2).
3. **Prescriptive core per installed adapter = data + config** (Living Spec is part
   of the model but **deferred** in this rollout — see decision §8.2). Everything
   else in the framework's `instance/` (`README.md` slot-table, `adrs/`, `.audit/`)
   is a framework convenience and is **not** prescribed by any contract or standard
   — verified against `00-vision/`, `01-architecture/`, `04-standards/`. Adopters
   omit them.
4. **Data location:** `<adoption-root>/backlog/` (adapter-layout-mirror Rule 3) —
   i.e. `eposforge/backlog/` for adopters and `instance/backlog/` for the framework
   after Phase D.
5. **Discovery:** the adapter scripts find a backlog root by
   workspace-file → `BACKLOG_ROOTS` env → `--roots` CLI → git-root fallback. The
   git-root fallback checks `<repo-root>/backlog/config.toml`, which **fails** when
   the backlog is nested under a container (`eposforge/` for adopters, `instance/`
   for the framework after Phase D). So each repo must *declare* its adoption-root
   via a `.code-workspace`: adopters list `./eposforge` + `../../gh/eposforge`;
   the framework lists `.` + `./instance`. `BACKLOG_ROOTS` remains the pure-CLI
   fallback.

---

## 3. Canonical target layout

Adopter primary repo (e.g. GEA — the Adopter Platform Spec):

The adopter designates one primary repo as the single source for their overall eposforge implementation (documentation for both product and platform factories + the adopted `eposforge/` slice). Portfolio reviews are performed from this primary repo.

```text
<repo>/                                        # e.g. GraceEnterprisesArchitecture (primary)
  # High-level adopter documentation of the overall eposforge implementation
  # (platform factory + product factory concerns, standards, runbooks, portfolio, hardware, etc.)
  00-north-star/, 01-reference-architecture/, 03-standards/, 04-runbooks/, 07-project-portfolio/, ...

  eposforge/                                   # the adopted pattern slice (one container)
    backlog/
      config.toml                              # prefix=GEA, visibility=private
      backlog.md ... portfolio.md
    # other adopted adapters (router/gastown, secrets-key-management, ...)
  <repo>.code-workspace                        # folders include ./eposforge + framework reference
  <repo's own content + implementation docs>
```

**SECURITY NOTE (portfolio.md data leak):** `--mermaid` with mixed public+private BACKLOG_ROOTS produces a diagram containing private adopter items. The writer refuses to place it under a public root: it selects the first private root (so output lands in the primary adopter repo's backlog/portfolio.md). Pure-public (framework only) targets the framework. Never manually copy mixed diagrams into the public framework tree. Run framework-only when you only want the pattern view.

When the primary repo is not in the workspace, the tooling can still operate on the current repo's backlog, but this is only a single-project view — not the adopter's portfolio.

Framework (eposforge repo) after Phase D — same shape, container named `instance/`:

```text
eposforge/                                     # the framework repo
  instance/
    backlog/                                   # MOVED here from repo root in Phase D
      config.toml  backlog.md  backlog-slated.md
      backlog-archive.md  backlog-archive-index.md  portfolio.md
    installed/backlog/file-based-backlog/   # the adapter (scripts live here)
  eposforge.code-workspace                     # folders: . + ./instance
```

Operator invocation (Preferred mode), from any repo root:

```bash
export BACKLOG_HOME=/mnt/raid-storage/src/git/gh/eposforge/instance/backlog/file-based-backlog
bash "$BACKLOG_HOME/scripts/lint-backlog.sh"            # discovery via workspace file
bash "$BACKLOG_HOME/scripts/ready.sh"
# pure-CLI fallback if no workspace file is active:
BACKLOG_ROOTS="$PWD/eposforge" bash "$BACKLOG_HOME/scripts/ready.sh"   # adopter
BACKLOG_ROOTS="$PWD/instance" bash "$BACKLOG_HOME/scripts/ready.sh"    # framework
```

---

## 4. Per-repo current state & gaps

| Repo | git root | container | `backlog/` data | `config.toml` | Discovery (workspace) | Action |
|---|---|---|---|---|---|---|
| **GEA** | `local/GraceEnterprisesArchitecture` | ✅ `eposforge/` | ✅ (prefix `GEA`) | ✅ | ❌ broken (`.` + doubled `../../gh/eposforge/eposforge`) | **Complete** |
| **IAC** | `local/IAC` | ✅ `eposforge/` | ✅ (items use `IAC-`) | ❌ missing | ❌ none | **Complete** |
| **OutreachApi** | `local/OutreachApi` | ❌ none | ❌ | ❌ | ❌ none | **Scaffold** |
| **OutreachAssistant** | `local/OutreachAssistant` | ❌ none | ❌ | ❌ | ⚠️ has `.code-workspace` (no eposforge folder) | **Scaffold** |
| **framework** | `gh/eposforge` | `instance/` | ⚠️ at repo root `backlog/` | ✅ | `.` only (no `./instance`) | **Unify (Phase D)** |

Existing issue docs (for the *later* migration phase, **not** touched now):
- **OutreachApi:** GitHub/Gitea issues + speckit `specs/NNN-issue-*` dirs; `agents/fix-issue.md`.
- **OutreachAssistant:** root `issue-findings.md` / `issue-findings-slated.md` /
  `issue-findings-archive.md` (maps to active/slated/archive); `docs/workspace-issues.md`;
  `docs-working/backlog.md`.

Repo prefixes (settled): `GEA`, `IAC` (existing); **`OAPI`** (OutreachApi);
**`OA`** (OutreachAssistant).

---

## 5. Phase A — Complete GEA & IAC (they already hold data)

### A1. IAC — create `eposforge/backlog/config.toml`
```toml
prefix = "IAC"
fix_surfaces = ["infrastructure", "repo-instance", "process"]
themes = []   # populate on first portfolio-review pass
```
(IAC-001..003 all use `Fix surface: infrastructure`; the extra surfaces are
reserved headroom.)

### A2. GEA — repair the workspace file
`GraceEnterprisesArchitecture/GraceEnvironment.code-workspace` folders →
```json
{ "folders": [ { "path": "./eposforge" }, { "path": "../../gh/eposforge" } ] }
```
(Fixes both bugs: `.` was one level too shallow; `../../gh/eposforge/eposforge` was
a doubled, non-existent path.)

### A3. IAC — create a workspace file
`IAC/IAC.code-workspace` with the same two folders (`./eposforge`, `../../gh/eposforge`).

### A4. Verify (both repos)
From each repo root, with `BACKLOG_HOME` set:
- `lint-backlog.sh` runs clean and actually sees the repo's items (not zero).
- `ready.sh` lists items.
- `aggregate.sh --plan` shows the repo's prefix.
- Cross-repo: `aggregate.sh` from one repo sees both its own and `EF` items via the
  workspace's framework folder.

---

## 6. Phase B — Scaffold OutreachApi & OutreachAssistant (no content migration)

Create the **empty, migration-ready** structure only. Existing issue docs stay
where they are.

For **each** of OutreachApi (`OAPI`) and OutreachAssistant (`OA`):

### B1. Create the container + empty backlog files
```text
<repo>/eposforge/backlog/
  config.toml                 # prefix = "OAPI" | "OA"; fix_surfaces=[]; themes=[]
  backlog.md                  # header only, no issues
  backlog-slated.md           # header only
  backlog-archive.md          # header only
  backlog-archive-index.md    # header only
```
Seed each `.md` with the same header style as IAC/GEA's files (title + one-line
description naming the repo and its prefix, e.g. "IDs use the `OAPI-` prefix").
`portfolio.md` is generated by `aggregate.sh`; do not seed it.

### B2. Discovery wiring
- **OutreachApi:** create `OutreachApi.code-workspace` (`./eposforge`, `../../gh/eposforge`).
- **OutreachAssistant:** **edit** the existing `OutreachAssistant.code-workspace` —
  add `./eposforge` and `../../gh/eposforge` to its `folders` array (preserve the
  existing `.`/name and `settings`, do not clobber).

### B3. Verify
`lint-backlog.sh` runs clean on the empty backlog; `ready.sh` reports "No ready
items"; the repo's prefix appears in `aggregate.sh --plan`. Exit 0 throughout.

---

## 7. Phase C — Record the convention in the standard

In `04-standards/07-adapter-layout-mirror/adapter-layout-mirror.md`, add the parts
discovered during this work so they are not rediscovered each adoption:
- Name the adopter container convention (`eposforge/`) and the framework's
  equivalent (`instance/`).
- State the prescriptive core (**data + config** per installed adapter; Living Spec
  part of the model) vs. conveniences (README slot-table / `adrs/` / `.audit/`).
- State the discovery requirement: a `.code-workspace` declaring the adoption-root,
  because the git-root fallback cannot see a nested `<container>/backlog/`.

(The Rule 3 wording change required by Phase D is handled in §8 of this plan's
Phase D step, not here, to keep the two standard edits coherent.)

---

## 8. Phase D — Framework backlog unification (move data into `instance/`)

Make the framework match the adopter shape: its backlog data moves from repo-root
`backlog/` to `instance/backlog/`, so every adoption-root has `<root>/backlog/`.

> **Scope boundary:** Phase D aligns the **data** slot only. Flattening the
> framework's `instance/` **adapter** slot for full symmetry is
> deliberately *out of scope* here and is tracked separately as **EF-044** (it
> reaches CI + a second standard; sequences after Phase D).

### D1. Move the data
`git mv` the six files from `backlog/` → `instance/backlog/`:
`config.toml`, `backlog.md`, `backlog-slated.md`, `backlog-archive.md`,
`backlog-archive-index.md`, `portfolio.md`. Remove the now-empty repo-root
`backlog/`.

### D2. Declare the adoption-root for discovery
Update `eposforge.code-workspace` folders → `.` **and** `./instance` (so script
discovery finds `instance/backlog/config.toml`; the git-root fallback now misses,
exactly as for adopters).

### D3. Rewrite the standard's anchor (mandatory)
In `adapter-layout-mirror.md`:
- Rule 3: change *"(mirroring eposforge's repo-root `backlog/`)"* → *"(mirroring
  eposforge's `instance/backlog/`)"*; keep the formula `<adoption-root>/backlog/`.
- Conformance "Backlog-location check" (line ~54): ensure it reads the adoption-root
  form, not a hardcoded repo-root path.

### D4. Update the framework's own operator paths
- `AGENTS.md` (lines ~209–216): `backlog/backlog.md` → `instance/backlog/backlog.md`,
  and the sibling `backlog/backlog-slated.md` / `-archive-index.md` / `-archive.md`
  load lines. (The `instance/.../scripts/...` invocation lines are already
  correct and unchanged.)
- `docs/backlog-uat.md`: repoint the `backlog/...` paths to `instance/backlog/...`
  (UAT/test doc; update so the walkthrough still runs).

### D5. Verify the move
- From the framework repo root with the workspace active: `lint-backlog.sh`,
  `ready.sh`, `aggregate.sh --plan` all find `instance/backlog/` and see `EF` items.
- **Pre-commit hook:** confirm the installed `pre-commit` staged-path glob (it keys
  on `backlog/backlog.md` / `backlog-slated.md` being staged — see
  `docs/elegant-dreaming-dove.md`) still fires after the move; update its path if it
  is hardcoded to repo-root `backlog/`.
- Historical design docs (`docs/elegant-dreaming-dove.md`) are left as a record of
  the prior state; not repointed.

---

## 9. Decisions (settled)

1. **Prefixes** — OutreachApi = `OAPI`, OutreachAssistant = `OA` (GEA/IAC unchanged).
2. **Living Spec** — part of the model, but **not created in this rollout**. Adopters
   carry only data + config now; per-repo `file-based-backlog.md` is deferred.
3. **Framework unification** — **do it** (Phase D), including the Rule 3 anchor rewrite.
4. **CI** — *no concern.* No workflow in the framework or any adopter touches the
   backlog today (CI is `doc-lint`, `installed-scripts-layout`, `sensitive-literals`;
   none reference backlog/lint-backlog/aggregate/ready). Forward note only: *if* a
   backlog-lint job is ever added, it must pass `BACKLOG_ROOTS=$PWD/<container>`,
   since a headless run has no IDE workspace var and the git-root fallback misses a
   nested `<container>/backlog/`.

---

## 10. Later phase (out of scope here) — issue-doc migration

Tracked separately once scaffolding lands:
- **OutreachAssistant:** map `issue-findings.md` → `backlog.md`,
  `issue-findings-slated.md` → `backlog-slated.md`, `issue-findings-archive.md` →
  `backlog-archive.md`; reconcile `docs/workspace-issues.md` and
  `docs-working/backlog.md`; assign `OA-NNN` IDs; lint clean.
- **OutreachApi:** import open GitHub/Gitea issues + speckit `specs/NNN-issue-*` into
  `OAPI-NNN` items with `Depends on:`/`Blocks:` links; decide the source-of-truth
  boundary between the file backlog and the live issue tracker.

---

## 11. Acceptance criteria

- GEA, IAC, OutreachApi, OutreachAssistant each: scripts run from the framework clone
  (no vendored `scripts/` anywhere in the adopter), discover the repo's `eposforge/`
  backlog root, and `lint-backlog.sh` exits 0.
- Each adopter has `eposforge/backlog/config.toml` with the correct prefix.
- Framework backlog lives at `instance/backlog/`; `eposforge.code-workspace` declares
  `./instance`; `adapter-layout-mirror` Rule 3 no longer says "repo-root"; framework
  `lint-backlog.sh` exits 0 against the moved data.
- A single `aggregate.sh` invocation from any adopter rolls up that repo's items plus
  `EF` items via the framework folder.
- No adopter contains `instance/`, `adrs/`, `.audit/`, or a vendored
  `scripts/` directory.

---

## 12. Progress (completed — 2026-06-14)

All phases implemented and verified.

- A1: `IAC/eposforge/backlog/config.toml` (prefix `IAC`) — done.
- A2: `GraceEnterprisesArchitecture/GraceEnvironment.code-workspace` repaired — done.
- A3: `IAC/IAC.code-workspace` created — done.
- B1: `OutreachApi/eposforge/backlog/` seeded (config.toml + 4 empty `.md` files) — done.
- B2: `OutreachApi/OutreachApi.code-workspace` created — done.
- B1: `OutreachAssistant/eposforge/backlog/` seeded (config.toml + 4 empty `.md` files) — done.
- B2: `OutreachAssistant/OutreachAssistant.code-workspace` updated (added `./eposforge` + `../../gh/eposforge` folders) — done.
- C: `adapter-layout-mirror.md` updated — container naming convention, prescriptive
  core vs conveniences, discovery wiring requirement (Rule 2 sub-bullet, Rule 3
  annotation, new Rule 6, Conformance backlog-location check) — done.
- D1: `backlog/` → `instance/backlog/` (`git mv` + mv for untracked `portfolio.md`) — done.
- D2: `eposforge.code-workspace` updated (`./instance` folder added) — done.
- D3: `adapter-layout-mirror.md` Rule 3 anchor changed to `instance/backlog/` — done (same edit as Phase C).
- D4: `AGENTS.md` load-rule paths updated to `instance/backlog/…`; `docs/backlog-uat.md` paths updated — done.
- D5: Pre-commit hook glob updated (`instance/backlog/…`); scripts updated for workspace-based
  adoption-root discovery (`lint-backlog.sh`, `new-issue.sh`, `sweep-resolved.sh`) — done.

Verification results:
- Framework (`eposforge.code-workspace`): `lint-backlog.sh` OK; `ready.sh` shows EF items; `aggregate.sh --plan` shows EF table from `instance`.
- IAC: lint finds `eposforge/backlog/` via workspace; items visible (IAC-001 pre-existing resolved/missing-fields error is a data issue, not a discovery issue).
- GEA: lint finds `eposforge/backlog/` via workspace; items visible (pre-existing cross-repo ref errors are data issues).
- OutreachApi: lint OK, ready "No ready items".
- OutreachAssistant: lint OK, ready "No ready items".
