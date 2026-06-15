# Plan — Deploy backlog skills anywhere on srv-docker-hp (EF-033 + EF-032 + rollout)

**Status:** draft for ratification
**Date:** 2026-06-15
**Goal:** make the backlog skills (`portfolio-review`, `milestone-elicitation`,
and by extension any `skills/<name>/`) **discoverable and functional from any
working directory and any agent CLI on srv-docker-hp** — operator Claude Code
sessions (any cwd), the Copilot Remote-SSH surface, and the `dkr-gstwn-01`
containerized CLIs.

**Owning repos:** framework work lands in `eposforge` (EF-032, EF-033, skill
anchoring); host rollout lands in `GraceEnterprisesArchitecture` (new GEA item).

---

## 0. Why this is more than "symlink the skill"

Discoverability is trivial — anything under `~/.claude/skills/<name>/SKILL.md`
is found in every Claude Code session regardless of cwd (the host already proves
this: `~/.claude/skills/faster-whisper` is a symlink into `~/.agents/skills/`).

But the two backlog skills are **not self-contained**. They shell out to the
Component 13 scripts by **repo-relative path**, e.g. in
`skills/portfolio-review/SKILL.md`:

```
bash instance/installed/13-backlog/file-based-backlog/scripts/aggregate.sh --mermaid
bash instance/installed/13-backlog/file-based-backlog/scripts/lint-backlog.sh
```

and those scripts then resolve the backlog they operate on. So "works anywhere"
has **three** independent couplings to break, not one:

| # | Coupling | Symptom when broken | Fixed by |
|---|----------|---------------------|----------|
| A | SKILL.md not on the user-scope path | skill invisible outside the eposforge clone | symlink/install (EF-032 / rollout) |
| B | SKILL.md calls scripts by repo-relative path | `aggregate.sh: No such file` from any other cwd | skill anchoring (§3) |
| C | scripts can't find the right backlog from an arbitrary cwd / CLI | operates on the wrong (or no) backlog | **EF-033** (§2) |

A is easy. **C is the load-bearing unblock and is partially mis-built today.**
B is a small gap no current ticket cleanly owns.

---

## 1. As-built reality (verified 2026-06-15) — read before editing EF-033

The scripts under
`instance/installed/13-backlog/file-based-backlog/scripts/` are **already
partially relocatable**, but the implementation diverged from the EF-033 ticket
and does not handle the real adopter layout:

- **`BACKLOG_HOME` is taken.** It already means *"where the framework tooling
  lives"* (`lint-backlog.sh:44` reads `${BACKLOG_HOME}/scripts/VERSION`;
  `sync-tooling.sh:40-41` uses it as the copy source). EF-033's ticket proposes
  `BACKLOG_HOME` for the *backlog data root* — **a direct collision.** The data
  root is actually carried by **`BACKLOG_ROOTS`** (colon-separated).
- **Discovery is IDE-coupled, not cwd-based.** `lint-backlog.sh`,
  `new-issue.sh`, `sweep-resolved.sh` resolve the backlog via:
  `VSCODE_WORKSPACE_FILE`/`WORKSPACE_FILE` (parse `.code-workspace` folders) →
  `BACKLOG_ROOTS` env → `${git-root}/backlog`. **There is no walk-up-from-cwd
  tier** — the exact tier the ticket calls for and the host-wide goal needs.
- **Path-depth mismatch (live bug).** Discovery probes
  `<folder>/backlog/config.toml`, but every local adopter is at
  `<repo>/eposforge/backlog/config.toml`, and `OutreachAssistant.code-workspace`
  lists only folder `.`. Result: workspace discovery checks
  `<repo>/backlog/config.toml` → miss → falls back to `<git-root>/backlog` →
  miss. **The tooling cannot currently find any local adopter backlog** unless
  `BACKLOG_ROOTS` is hand-set to `<repo>/eposforge`.
- **Two divergent code paths.** `aggregate.sh` / `ready.sh` re-resolve roots
  inside embedded Python (`--roots` CLI → `BACKLOG_ROOTS` → git-root) and support
  multiple roots; the other three are single-root Bash. Any fix must land in
  both shapes consistently.

**Conclusion:** EF-033 is not greenfield. The work is to **reconcile the ticket
with the code, add the missing cwd tier, fix the path-depth assumption, and make
all five scripts share one precedence.**

---

## 2. EF-033 (reconciled) — relocatable backlog scripts

**Effort:** S→M (larger than the ticket's S, because of reconciliation + path-depth).
**Fix surface:** eposforge-pattern.

### 2.1 First action — correct the ticket
Update EF-033's `Verify with:`/`Notes:` to match reality before coding:
- Replace `BACKLOG_HOME` (as the data-root var) with **`BACKLOG_ROOTS`**;
  explicitly note `BACKLOG_HOME` is reserved for the tooling source and must
  **not** be overloaded.
- State the resolution precedence (§2.2) as the contract.
- Record the adopter layout as `<adoption-root>/backlog/` where
  **`<adoption-root>` = `<repo>/eposforge`** for the current local adopters, and
  resolve the `<repo>/backlog` vs `<repo>/eposforge/backlog` depth question
  (§2.4, decision D1).

### 2.2 Single shared resolution precedence (all five scripts)
Factor one resolver (a sourced `resolve-backlog.sh` helper, or an identical
block) used by `lint-backlog.sh`, `new-issue.sh`, `sweep-resolved.sh`, and the
Python in `aggregate.sh` / `ready.sh`:

1. **Explicit CLI** — `--roots <p..>` / a new `--backlog <dir>` (highest).
2. **`BACKLOG_ROOTS` env** — colon-separated data roots.
3. **cwd walk-up (NEW)** — from `$PWD` upward, first ancestor containing
   `backlog/config.toml` (also probe `<ancestor>/eposforge/backlog/config.toml`
   per D1). This is the tier that makes "run from anywhere inside an adopter
   tree" work with zero env setup.
4. **VS Code workspace file** — keep as IDE convenience, demoted below cwd.
5. **`<git-root>/backlog`** — back-compat fallback (eposforge itself).

Single-root scripts take the first match; multi-root scripts (`aggregate`,
`ready`) keep collecting per existing semantics.

### 2.3 Error behavior
When no `config.toml` is found at the resolved root, fail with a message that
states the bootstrap (`create backlog/config.toml with prefix = "<XX>"`) and the
precedence tried — never a bare path error. (Matches the ticket's verify-with.)

### 2.4 Decisions to ratify
- **D1 — adoption-root depth.** Either (a) make the resolver tolerant of the
  interposed `eposforge/` dir (probe `<dir>/eposforge/backlog/config.toml` in
  walk-up), or (b) declare `<repo>/eposforge` the canonical adoption root and fix
  the workspace files / `BACKLOG_ROOTS` docs to point there. (a) is more
  forgiving for headless/container use; recommend (a) **and** documenting (b).
- **D2 — env var rename.** Confirm nothing external depends on the *current*
  `BACKLOG_HOME` semantics before documenting it as tooling-only. (`sync-tooling`
  and `lint`'s VERSION read are the only consumers found.)

### 2.5 Verification (maps to EF-033 verify-with)
```bash
# from an arbitrary cwd inside an adopter tree (no env, no workspace file):
cd /mnt/raid-storage/src/git/local/OutreachAssistant/eposforge/specs 2>/dev/null || cd /mnt/raid-storage/src/git/local/OutreachAssistant/eposforge
bash <EPOS>/.../scripts/lint-backlog.sh            # lints OA backlog, passes
bash <EPOS>/.../scripts/new-issue.sh ...           # allocates next OA- id
bash <EPOS>/.../scripts/aggregate.sh --mermaid     # writes OA backlog/portfolio.md
# eposforge's own backlog still works unchanged (back-compat tier 5)
# missing config.toml → bootstrap message, not a path error
```
Also: `sync-tooling.sh` propagates the new scripts to adopters; run
`sync-tooling.sh --check <adopter>` to confirm no drift after the change.

---

## 3. Skill anchoring (coupling B) — make script-calling skills cwd-independent

**Problem:** even with EF-033, `SKILL.md` calls
`instance/installed/13-backlog/.../aggregate.sh` relatively, which only resolves
at the eposforge repo root.

**Fix:** the skills resolve the tooling via an explicit anchor, not a relative
path. Define **`EPOSFORGE_HOME`** (default to the canonical clone
`/mnt/raid-storage/src/git/gh/eposforge`, overridable) and rewrite the skill
commands as:

```
bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}"/instance/installed/13-backlog/file-based-backlog/scripts/aggregate.sh --mermaid
```

Combined with EF-033 (scripts then find the *backlog* via cwd/`BACKLOG_ROOTS`),
the skill works from any cwd and any CLI.

**Ownership:** this is the skills-side sibling of EF-033/EF-022. Recommend
**folding it into EF-032's scope** (an installed skill that can't find its
tooling isn't really "installed") rather than a standalone ticket. If kept
separate, file as **EF-045 — "Anchor script-calling skills to EPOSFORGE_HOME so
installed skills resolve framework tooling from any cwd."**

---

## 4. EF-032 — per-surface skill install adapters (the deployment mechanism)

**Effort:** M. **Fix surface:** eposforge-pattern.

Build the one-command installer that projects any canonical `skills/<name>/`
into a chosen agent surface. Per the ticket:

### 4.1 Data-driven surface table
A table (TOML/JSON), one row per surface — adding a CLI is a row, not code:

| surface | target path | method |
|---|---|---|
| claude-code-user | `~/.claude/skills/<name>/` | symlink |
| claude-code-cmd | `~/.claude/commands/<name>.md` | symlink (or copy) |
| copilot-workspace | `<repo>/.github/prompts/` `/.github/skills/` | symlink |
| copilot-user | `~/.vscode-server/data/User/prompts/` (+ remote variant) | copy-with-provenance |

`method` is a property of the surface (some tools don't follow symlinks /
sandbox their config dirs) → **symlink where tolerated, copy-with-provenance
where not.**

### 4.2 Modes & behavior
- **Adoption modes:** `fork` (in-tree paths) and `consume-without-fork` (paths
  into a clone/submodule) — symlinks point at the clone; copies stamp a
  provenance header (`# source: <canonical-path>@<version>`).
- **Idempotent re-run** with **drift report** when a copied projection diverged
  from canonical.
- **`--list`** and **`--uninstall`** modes.
- **Generic docs** (no host/org names) so a recall query for "installing an
  EposForge skill into my agent CLI" returns it.
- When installing a script-calling skill, the installer also ensures the
  `EPOSFORGE_HOME` anchor (§3) is set/derivable for the target surface.

### 4.3 Out of scope (per ticket) — do NOT build here
Runtime skill discovery/registry (C3/C4); **containerized agent-home installs
(that's the adopter overlay = §5)**; any auto-update/watcher.

### 4.4 Verification
`install.sh <skill> --surface claude-code-user --mode consume` produces a
working symlink; re-run is idempotent; a tampered copy is reported as drift;
`--uninstall` removes cleanly; `--list` shows installed projections.

---

## 5. GEA-015 (new) — roll the backlog skills onto srv-docker-hp surfaces

**Repo:** GraceEnterprisesArchitecture. **Effort:** M.
**Depends on:** `eposforge:EF-032`, `eposforge:EF-033` (and §3 anchoring).
**Sibling of:** GEA-012 (which covers only `refine-prompt`; this covers the
backlog skills).

Deploy `portfolio-review` + `milestone-elicitation` (and `refine-prompt` if
co-scheduled) across the three host surfaces named in GEA-012:
1. **Claude Code user scope** — `~/.claude/skills/<name>` symlinked to the
   eposforge clone (matches the `faster-whisper` pattern), via EF-032's installer.
2. **Copilot Remote-SSH user prompts** — `~/.vscode-server/data/User/prompts/`,
   copy-with-provenance via EF-032.
3. **`dkr-gstwn-01` containerized CLIs** — via the **GEA overlay Dockerfile**
   (never by patching the gastownmirror base), persisted on the `/root` volume
   alongside the OAuth login files; bake a provenance comment (source path +
   commit) so drift is detectable; survives an image rebuild. Set
   `EPOSFORGE_HOME` + a sane default `BACKLOG_ROOTS` inside the container.

**Verify with:** `/portfolio-review` and `/milestone-elicitation` are invokable
in each surface from an arbitrary cwd, locate the intended adopter backlog, and
run `aggregate.sh`/`lint-backlog.sh`/`new-issue.sh` against it without manual
path or env fixup; container installs survive a rebuild.

---

## 6. Sequencing

```
EF-033 (reconcile + cwd tier + path-depth)        ← load-bearing; unblocks function
   │
   ├── §3 skill anchoring (EPOSFORGE_HOME)         ← fold into EF-032 or EF-045
   │
EF-032 (installer)                                ← uses anchoring; deploys files
   │
GEA-015 (host rollout across 3 surfaces)          ← consumes EF-032 + EF-033
```

Interim (today, no new code): symlink the two skills into `~/.claude/skills/`
for **discoverability now**, accepting they only fully run from the eposforge
repo cwd until EF-033 + §3 land. Useful for dogfooding the skills themselves;
not the finished state.

## 7. Risks / watch-items
- **EF-012 drift, inverted:** here the *ticket* lagged the *code*. Re-read the
  scripts, not just the ticket, before each step. Keep EF-033's text in sync
  with what ships.
- **`sync-tooling.sh` propagation:** the relocatability fix must reach adopters,
  or they keep the broken resolver. Run `--check` post-change.
- **Container OAuth/secret surfaces:** GEA-015's overlay must follow the
  GEA-005/GEA-012 no-plaintext pattern for any credentials; the skills
  themselves need none, but the install layer touches the agent home.
- **Decision D1 unresolved** blocks a clean walk-up implementation — settle it
  first.

## 8. Deliverables checklist
- [ ] EF-033 ticket text corrected (`BACKLOG_ROOTS`, precedence, depth) — §2.1
- [ ] Shared resolver + cwd walk-up in all five scripts — §2.2
- [ ] Bootstrap-aware error message — §2.3
- [ ] D1 / D2 ratified — §2.4
- [ ] Skill anchoring via `EPOSFORGE_HOME` (EF-032 scope or EF-045) — §3
- [ ] EF-032 installer: surface table, modes, drift, list/uninstall, docs — §4
- [ ] GEA-015 filed + 3-surface rollout — §5
- [ ] `sync-tooling.sh --check` clean across adopters
```
