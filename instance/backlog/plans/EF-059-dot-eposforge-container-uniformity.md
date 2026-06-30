# Plan: Adopt uniform `.eposforge/` container folder (EF-059 / EF-060)

**Date:** 2026-06-30  
**Status:** in-progress (backlog items created; plan written)  
**Tracking:** EF-059 (decision + standard), EF-060 (execution + migration)
**Note on private details:** High-level public plan here. Full operational details, private repo paths, mounts, and gastown/docker specifics for adopters are in the primary adopter repo (GEA) under its backlog/plans/.  
**Related:** EF-056 (master Phase 0 alignment), EF-057, EF-058 (terminology / roles), adapter-layout-mirror standard, preferred-mode-adoption-plan.md

## Summary / Goal

Make the EposForge container folder uniform across the framework and all adopting repositories by using a single dot-prefixed name:

- Adopters: change `eposforge/` → `.eposforge/`
- Framework: change `instance/` → `.eposforge/` (use it instead of the special `instance/` name)

This produces one consistent layout:

```
<repo>/
  .eposforge/
    backlog/
      config.toml
      ...
    <component>/          # e.g. secrets-key-management/, router/, backlog/file-based-backlog/, ...
      <adapter>/...
  ... (adopter's own source/docs)
```

**Why now / why this change?**

- Conforms to the established convention for tool-specific / config / "owned by the tool" directories (`.github/`, `.claude/`, `.vscode/`, `.config/`, etc.).
- Eliminates the special-case naming split that was only introduced "to avoid a confusing self-duplicate" inside the eposforge repo itself.
- Makes discovery, scripts, workspaces, documentation, docker mounts, and cross-repo tooling (aggregate, portfolio-review, spec-graph) simpler and more uniform.
- "Instance" was never a great public name for the self-host layer once the pattern was being adopted.

## Sources Consulted

**Cognee MCP (recall, multiple strategies: GRAPH_COMPLETION, CHUNKS, GRAPH_COMPLETION_COT):**
- Adapter layout mirror standard is the SSoT.
- "Adopter container name: `eposforge/` — all eposforge-owned content for an adopting repo lives under this single top-level directory. The framework repo uses `instance/` for the same role (to avoid a confusing self-duplicate)."
- Workspace declaration rules, prescriptive core (data + config.toml), backlog location `<container>/backlog/`.
- No prior dot-prefix convention recorded.
- Primary repo ("Adopter Platform Spec") owns the overall docs + the container slice. Portfolio reviews run from there. (GEA is the established public example of such a primary adopter repo.)
- Related: 00-vision/02-roles-ownership.md, EF-056/058 work.

**Files (greps, reads of standards, docs, scripts, workspaces, actual trees):**
- `04-standards/07-adapter-layout-mirror/adapter-layout-mirror.md` (full text)
- `04-standards/01-naming-conventions/naming-conventions.md`
- `00-vision/02-roles-ownership.md`
- `docs/preferred-mode-adoption-plan.md` (detailed layout diagrams + per-repo state table)
- `docs/adopter-architecture-discussion-capture.md`
- `instance/README.md` (slot table)
- `AGENTS.md`, `README.md`
- `.code-workspace` files declare the container (framework uses `./instance` today; adopters use `./eposforge`).
- Actual trees (high level):
  - Framework self-host layer under its container (full adapters + backlog data).
  - Primary adopter and other adopting repos have their own container holding backlog data + selected adapters.
  - Some adopters have additional custom content under the container.
- Scripts & skills that embed paths:
  - `instance/backlog/file-based-backlog/scripts/*` (new-issue, aggregate, ready, lint, install-hooks, etc.)
  - Skills: `portfolio-review/SKILL.md`, `update-spec-graph/SKILL.md`, `milestone-elicitation/SKILL.md`, `install.sh`
  - Source control checks: `check-installed-scripts-layout.sh`, `generate-installed-index.py`, `check-doc-classification.py`, `install-hooks.sh` (hard `INSTALLED_ROOT=.../instance`)
  - Many component docs, runbooks, research notes with `instance/...` and `eposforge/...` examples.
- Primary adopter blast radius for private mounts, configs, and runbooks (docker, gastown, systemd, backup, etc.). Concrete details live in the primary adopter's private backlog.
- eposforge-scrub-work copy also follows old layout.

## Scope & Impact

**In scope (must change):**
- The adapter-layout-mirror standard (and related standards/docs that quote the container rules).
- All `.code-workspace` declarations.
- Physical folders (git mv).
- All hard-coded paths in framework docs, skills, scripts, generators.
- All references in primary and secondary adopting repos.
- Discovery + invocation examples (BACKLOG_ROOTS, EPOSFORGE_HOME usage).
- Index generators, layout linters, hook composers.
- Any docker volume mounts, container entrypoints, gastown formulas that reference the old container paths.

**Out of scope (or optional/deferred):**
- Renaming of component subdirectories inside the container (they already use stable node names per the standard).
- Full history rewrite.
- Non-primary product repos (they can follow later or via workspace discovery).
- Changing the meaning of "instance" when it refers to something else (Platform Instance = the running substrate).

## High-Level Approach

1. **Decision & Standard first** (EF-059).
2. **Update all references** (docs, code, scripts) while still on old names (safer diffs).
3. **Perform renames** with `git mv` (preserves history).
4. **Fix anything that broke**, run generators/checks.
5. **Coordinate adopters** (primary adopter usually has the largest private surface for mounts and configs).
6. **Verify** (scripts, skills, graph, mounts).
7. **Document** migration notes.

Do the framework first so `EPOSFORGE_HOME` examples are correct when adopters migrate.

## Detailed Steps

### 1. Create backlog items + this plan (done)
- Ran `new-issue.sh` (with `BACKLOG_ROOTS=.../instance`) to create stubs.
- Cleaned duplicates.
- Filled EF-059 + EF-060.
- Wrote this plan to `instance/backlog/plans/EF-059-dot-eposforge-container-uniformity.md`.
- (Optional later) Use `cognee__remember` to ingest the decision into the graph.

### 2. Update the authoritative standard and explanatory docs (EF-059 work)
Edit (while names are still old for clear diffs):
- `04-standards/07-adapter-layout-mirror/adapter-layout-mirror.md`
  - Change "Adopter container name: `eposforge/`" → "`.eposforge/`"
  - Change framework role description to use `.eposforge/` (remove self-dupe rationale or reframe it).
  - Update all examples, workspace snippets, conformance rules, "Adopter container name" bullets.
  - Add note about dot-prefix convention and uniformity benefit.
- `00-vision/02-roles-ownership.md`
- `docs/preferred-mode-adoption-plan.md` (update diagrams + text)
- `docs/adopter-architecture-discussion-capture.md`
- `instance/README.md` (title + "mirror this `.eposforge/` layout")
- `AGENTS.md` (structure table)
- `README.md` and any other top-level docs quoting paths.
- Component docs / runbooks that show example layouts (add migration note where historical paths are mentioned).

Also update any "instance/" mentions that are *container* references vs other uses.

### 3. Update code, scripts, skills, generators (while old names still exist)
- `skills/portfolio-review/SKILL.md`, `update-spec-graph/SKILL.md`, `milestone-elicitation/SKILL.md`, `install.sh`
- `instance/source-control-ci/github-and-actions/scripts/`:
  - `install-hooks.sh` (INSTALLED_ROOT, find commands, comments)
  - `check-installed-scripts-layout.sh`
  - `generate-installed-index.py`
  - `check-doc-classification.py`
  - `setup-signed-commits.sh` (comments)
- `instance/backlog/file-based-backlog/scripts/` (any internal path assumptions + shebang/EPOSFORGE_HOME usage in comments)
- `instance/spec-graph/cognee/` scripts and docs that reference `instance/`
- Any other Python/Shell that builds paths under the container.
- Update examples that use `BACKLOG_ROOTS="$PWD/eposforge"` or `"$PWD/instance"`

### 4. Update workspaces
- Framework workspace: update to `./.eposforge`
- Primary and secondary adopter workspaces: update to `./.eposforge`
- Any other workspaces declaring the container folder.
- Update any legacy workspaces in `99-archive/`

### 5. Physical renames (git mv)
From framework root:
```bash
git mv instance .eposforge
```

From each adopter root:
```bash
git mv eposforge .eposforge
```

Commit the renames together with the preceding reference updates where possible (or in stacked changes).

### 6. Post-rename fixes
- Any relative links that broke inside moved files.
- Run the generators from the new location:
  - `python .eposforge/source-control-ci/github-and-actions/scripts/generate-installed-index.py`
  - Layout + classification checks.
- Update any remaining absolute/relative strings that the mechanical replace missed.
- In adopting repos: bulk search/replace (container paths only). Be careful not to touch prose about the project itself. Clean any legacy numbered component references encountered.
- Update docker / compose / gastown / systemd / backup / runbook references in adopting repos that mount or reference the old container. Restart affected services. Concrete private mount details are tracked privately.
- Framework top-level `backlog/` (if any data still lives there) — decide whether to move under `.eposforge/backlog/`.

### 7. Adopter coordination & secondary repos
- Primary adopter repo (largest private surface for mounts/configs).
- Other adopting repos with a container.
- Product repos discovered via workspaces.
- Update cross-repo references generically. Detailed private notes, mounts, and adopter-specific paths live in the primary adopter repo's backlog (see e.g. GEA's private plan under its container).

### 8. Verification (repeatable checklist)
- Backlog tooling:
  ```bash
  export EPOSFORGE_HOME=<path-to-framework-clone>
  BACKLOG_ROOTS=".../.eposforge" bash "$EPOSFORGE_HOME/.eposforge/backlog/file-based-backlog/scripts/ready.sh"
  BACKLOG_ROOTS=".../.eposforge" bash "$EPOSFORGE_HOME/.eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh"
  BACKLOG_ROOTS=".../.eposforge" bash "$EPOSFORGE_HOME/.eposforge/backlog/file-based-backlog/scripts/aggregate.sh --tags"
  ```
- Workspace-driven discovery (open the .code-workspace).
- Layout enforcement from framework:
  - `bash .eposforge/source-control-ci/github-and-actions/scripts/check-installed-scripts-layout.sh`
  - Classification + sensitive literal checks.
- Skills: run `portfolio-review`, `update-spec-graph` (with correct EPOSFORGE_HOME).
- Git: `git status`, ensure dot dir is tracked (`git ls-files | grep .eposforge`).
- `ls -a` shows `.eposforge`; plain `ls` hides it (expected).
- Docker mounts / gastown: relevant services start and can reach configs/secrets/backlog.
- Cognee / spec-graph: after changes, run bulk-rebuild or the update skill; perform a recall for "eposforge container" or "adapter layout" to confirm graph sees new structure.
- No dangling references: `rg 'eposforge/[^/]' | grep -v '.eposforge'` (post-change, minus historical notes) and same for old `instance/` container uses.

### 9. Documentation & communication
- Add a short migration note to the standard and to `docs/` (or this plan).
- Update any "how to read this repo" or "adopting" sections.
- Mention in next portfolio review.
- (Optional) Add an entry under `backlog/plans/` or a dedicated migration runbook.

### 10. Cognee / graph considerations
- The graph is built from the Markdown corpus. After the renames + doc updates, re-ingest the affected repos.
- Historical graph nodes may still reference old paths (normal staleness).
- Because this is a structural layout decision, the final state should be reflected in the adapter-layout-mirror node.

## Risks & Mitigations

- **High surface area of string changes** — Use careful, reviewed search/replace. Distinguish container paths from project-name prose, GitHub org references, etc.
- **Primary adopter private surface (mounts, configs, gastown, docker, runbooks)** — Usually the highest coordination cost. Do framework first, then primary adopter.
- **Docker / runtime mounts** — Changing host path requires service restart. Data is not moved (rename in place).
- **Duplicate ID or plan file location** — This plan lives under current `instance/backlog/plans/`; after rename it will naturally live at `.eposforge/backlog/plans/`.
- **Workspace discovery during transition** — Update workspaces before or atomically with renames.
- **Legacy numbered paths in adopters** — Clean opportunistically (they already violate the stable-name rule).
- **eposforge-scrub-work** — Rename for consistency or treat as historical snapshot.
- **Dot dir surprise** — Document that `ls -a` or explicit paths are needed to list contents. Most dev tools (git, editors, docker) are unaffected.

## Sequencing Recommendation

1. EF-059 work: standards + docs + code references (no renames yet).
2. Framework rename + its internal cleanup + workspace.
3. Re-verify framework tooling.
4. Primary adopter rename + reference fixes + private mounts.
5. Other adopting repos.
6. Global verification + graph refresh.
7. Close EF-059 / EF-060 with validation notes.

## Commands (cheat sheet)

```bash
# Create next item (example)
export EPOSFORGE_HOME=<path-to-framework-clone>
BACKLOG_ROOTS="${EPOSFORGE_HOME}/instance" bash "$EPOSFORGE_HOME/instance/backlog/file-based-backlog/scripts/new-issue.sh"

# After rename
BACKLOG_ROOTS="$PWD/.eposforge" bash "$EPOSFORGE_HOME/.eposforge/backlog/file-based-backlog/scripts/..."
```

## Success Criteria (from the Verify with: fields)

See the `Verify with:` sections on EF-059 and EF-060 in `backlog.md`.

## Open Questions / Decisions to Record

- Should the framework keep any top-level `backlog/` after full unification?
- How aggressively to clean legacy numbered component refs inside adopting repos during the pass?
- Any special handling for the scrub-work copy?

## Post-edit note (leak prevention)

As of this plan, explicit instructions and deterministic enforcement have been added so that *no AI agent* (Copilot, Claude, Grok, Gemini, etc.) can re-introduce specific adopter names into the public tree:

- `04-standards/01-naming-conventions/naming-conventions.md` now forbids it.
- `04-standards/08-agent-coding-guidelines/agent-coding-guidelines.md` has a new normative rule (#5).
- `AGENTS.md` (the single source loaded by all agents) includes the rule.
- `check-sensitive-literals.sh` now detects private adopter patterns (`GraceEnterprisesArchitecture` etc.) and fails the check (run via pre-commit hooks and CI).

All agents and changes must respect generic terminology only. The private detailed execution plan for any specific adopter lives in that adopter's own (private) backlog.

---

This is the public/sanitized version of the plan. It was written after direct consultation of the cognee graph and file inspection of standards + public docs. Concrete private execution details (specific adopters, mounts on hosts, gastown configs, etc.) live in the primary adopter repo's backlog (e.g. `GEA-dot-eposforge-container-private.md`).

It is stored under the backlog plans area so it is discoverable by the file-based backlog tooling and portfolio review. Private details are kept in the primary adopter repo only.

Next actions: begin the reference updates in the standard and key docs (or spawn an implement/review loop for the mechanical changes).
