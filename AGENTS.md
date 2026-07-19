## Agent Workflows

### `/modifyef` — Reconcile and apply design changes
Use this workflow when the user provides a description of additions, deletions, or edits to the EposForge architecture.

3. **Implement (Graph-Influence Checklist):**
  *   **Adapter status enforcement:** Agents MUST NOT select or invoke adapters whose status is `shelved`. Only adapters with status `experimental`, `approved`, or `deprecated` may be considered for use. Adapters marked `shelved` are retained for possible future work but are not eligible for selection or invocation by agents.
# Agent Instructions — EposForge

Shared instructions for AI coding assistants (GitHub Copilot, Claude Code,
and others) working in this repo. `.github/copilot-instructions.md`,
`CLAUDE.md`, and `GEMINI.md` are thin pointers to this file.

---

## What this repo is

EposForge is the specification and reference implementation of the
**dark-factory pattern** — a system where the operator declares capabilities
and AI agents build, deploy, and operate them. The repo contains vision
docs, architecture decision records, component contracts, and research.
There is no application code; the artefacts are Markdown files.

This repo has two layers that must stay explicit:

- **Spec layer**: `00-vision/`, `01-architecture/`, `02-roadmap/`, `03-research/`, `04-standards/`.
- **Self-host layer**: `.eposforge/` (the concrete adapter choices for this repo; uniform container name across framework and adopters).

---

## Agent coding guidelines

Behavioral ground rules for all agents working in this repo. Source of
truth: [04-standards/08-agent-coding-guidelines/agent-coding-guidelines.md](04-standards/08-agent-coding-guidelines/agent-coding-guidelines.md).
The bias is toward caution over speed; for trivial edits, use judgment.

1. **Think before coding.** State assumptions explicitly. If multiple
   interpretations exist, present them — don't pick silently. Push back
   when a simpler approach exists. If something is unclear, stop, name
   what's confusing, and ask.
2. **Simplicity first.** Minimum change that solves the problem. No
   features beyond what was asked, no abstractions for single-use content,
   no speculative configurability, no handling for impossible scenarios.
3. **Surgical changes.** Touch only what the task requires. Don't
   "improve" adjacent content, refactor what isn't broken, or remove
   pre-existing dead content — mention it instead. Remove only orphans
   your own change created. Every changed line should trace to the request.
4. **Goal-driven execution.** Restate the task as verifiable success
   criteria before starting — in this repo that means a named conformance
   command, lint script, or recall query, not "make it better". For graded/qualitative
   outcomes, success criteria MAY be expressed as a rubric. The scoring authority
   for a rubric must sit external to the implementing agent. For multi-step work,
   state a brief plan with a verify step per item, and loop until verified.
5. **Public/private boundary hygiene.** This public repo and all its docs, plans, standards, comments, and backlog items MUST NEVER name a specific adopter repository, its short identifier, or internal paths. Use only generic language ("the primary adopter", "an adopting repository", "the Adopter Platform Spec"). Specific names are leaks. Run the sensitive-literals check (and any adopter-name check) before proposing changes. When the task touches adoption, layout, or examples, first recall the boundary rules.

---

## Active execution plan (instance)

When executing backlog items for the in-flight **inference cost-control +
knowledge-tree migration** (`EF-015` onward), first load the detailed execution
plan at `.scratchpad/execution-plan.md` and the strategic context in
`.scratchpad/high-level-plan.md` (both local / gitignored on this instance). They
carry the execution order, the **inference-cost gate** (do not run a bulk
re-cognify before the credit-funded inference gateway is live and budget-capped),
cross-repo host-stack coordination, and the migration design source
`.scratchpad/knowledge-tree.txt`.

---

## Standards

| Term | Meaning |
|---|---|
| **Component** | An architectural slot (e.g. Spec Graph, Router, Dev Product). Twelve components defined in `01-architecture/02-components/`. |
| **Adapter** | A concrete implementation plugged into a component slot. Self-declares `capabilities`, `privacy_posture`, `cost_hint`, `invocation_surface`. |
| **Migration** | A named, in-flight transition between two coexisting architectural shapes (legacy and target) within an instance, with a stated completion commitment. Defined in `00-vision/01-ontology.ttl`; used by `02-roadmap/adoption-strategy.md`. |
| **FULFILLS_SLOT** | Relationship: an Adapter fulfills a component slot. |
| **DEPENDS_ON** | Relationship: one entity depends on another. |
| **MATURES_TO** | Relationship: an entity reaches maturity at a phase. |
| **GOVERNED_BY** | Relationship: an entity is governed by a policy or principle. |
| **IMPLEMENTS** | Relationship: an entity is an implementation of another. |
| **LEGACY_SHAPE_OF** | Relationship: an entity is on the legacy side of a Migration. |
| **TARGET_SHAPE_OF** | Relationship: an entity is on the target side of a Migration. |
| **Phase 0–4** | Platform Factory maturity ladder (Foundation → Full Autonomy). |
| **Phase A–F** | Product Factory maturity ladder (Registry → Level 5 gate). |
| **Product** | Operator-authored application/capability (Product Factory). **Unit of Living Spec attachment** — one Product, one current Living Spec (even if multi-repo). |
| **Deliverable** | Shippable **output** (release, deployable unit) that fulfills a Product — not the Spec attachment unit; not “each git repo.” |
| **Living Spec** | Current HEAD of intent for a **Product** (or platform capability at the same grain). Not Spec Kit episodes; not one Spec per module repo of the same product. Continuously refined; paired-change with fulfillment code. |
| **Paired-change enforcement** | Fail-closed CI (Standard 11): product code change requires Spec path change or finite audited exemption; Spec-derived tests required. Ceremony may be light; Spec fidelity is not optional. |
| **Code-surface encapsulation** | Standard 12: conversational-first; promote to code/UI when earned; keep implementation in declared code roots or code-focused repos so code-structure graphs (e.g. codebase-memory-mcp) stay scoped. |
| **Spec Graph** | Component 6: queryable projection of Living Specs. Prefer **Scope Spec Graph** vs **Factory Spec Graph**. See `01-architecture/02-components/spec-graph.md`. |
| **Scope Spec Graph** | Projection of Living Specs in one ownership scope (pattern, adopter platform, IAC, product scope). |
| **Factory Spec Graph** | Logical factory-wide Spec Graph: all Scope Spec Graphs + ontology mappings + orchestration. |

- Ontology + Taxonomy: `00-vision/01-ontology.ttl` is the source combining the domain ontology (dark factory pattern in OWL) and knowledge taxonomy (SKOS + ef:kind for the canonical tree). Editorial workflow is governed by the maintain-ontology skill (and evolving 04-standards policy).
- MCP-first and canonical source policy: `04-standards/05-canonical-doc-sources/` and `04-standards/04-mcp/`
- Naming and documentation hygiene: `04-standards/01-naming-conventions/naming-conventions.md`
- Refactoring discipline for mirrored research paths: `04-standards/06-research-mirror/research-mirror.md`

---

## Files and structure

```
00-vision/          Principles, glossary, north star
01-architecture/    Component contracts, adapter pattern, pattern ADRs
02-roadmap/         Phase plans
03-research/        Domain research including spec-graph integration notes
.eposforge/           Self-host implementation for this repo (uniform container)
.eposforge/spec-graph/graphrag/  GraphRAG project (settings, prompts, output/)
.eposforge/spec-graph/cognee/    Cognee ontology-grounded extraction adapter
.eposforge/spec-graph/cognee/scripts/   Cognee adapter scripts
.eposforge/spec-graph/graphrag/scripts/ GraphRAG adapter scripts (rebuild.sh, index.sh, import.sh)
.eposforge/spec-graph/scripts/hooks/    Spec-graph hook fragments composed into .git/hooks/
.eposforge/source-control-ci/github-and-actions/scripts/ SCM/CI checks, hook composer, hook fragments
.eposforge/SPEC.md    Living Spec for this repo's Spec Graph adapter (Component 6)
```

Paired-change rule: changes to the specific files enumerated in the
`.eposforge/SPEC.md §Paired-change rule` section must update `.eposforge/SPEC.md`
in the same commit. Additions to `.eposforge/spec-graph/` that
are not in that list do not require an `.eposforge/SPEC.md` update.

---

## Agent Workflows

### `/modifyef` — Reconcile and apply design changes
Use this workflow when the user provides a description of additions, deletions, or edits to the EposForge architecture.

1.  **Research & Reconcile:**
  *   Query `cognee` to identify current components, adapters, and relationships affected by the requested change.
  *   Compare the requested state with the existing design to identify contradictions or missing dependencies.
2.  **Clarify:**
  *   Prompt the user for clarification if the intent is ambiguous (e.g., if a new entity should be a `component` or an `adapter`, or which `phase` it matures to).
3.  **Implement (Graph-Influence Checklist):**
  *   **Reserved Taxonomic Kinds + Domain Terms:** Use the node kinds from the knowledge taxonomy (`pillar`, `group`, `component`, `concept`, `guidance`, `tenet`) exactly when tagging in prose or docs. Use domain ontology terms (`component`, `adapter`, `phase`, etc.) for the pattern itself. The distinction and canonical list live in `00-vision/01-ontology.ttl` (see maintain-ontology skill and owl-turtle-primer for SKOS/OWL guidance). Definitions are in the TTL.
  *   **Relationship Keywords:** Use these exact keywords so Cognee's ontology-grounded extraction maps edges correctly:
    *   `FULFILLS_SLOT`: "fulfills", "fills slot", "candidate adapter".
    *   `DEPENDS_ON`: "depends on", "dependency", "requires".
    *   `MATURES_TO`: "matures", "operational at phase", "graduation".
    *   `GOVERNED_BY`: "governed", "enforced by", "policy".
    *   `IMPLEMENTS`: "implements", "implementation of".
    *   `KIND`: node kind discriminator (pillar|group|component|concept|guidance|tenet).
    *   `LIFECYCLE_STATUS`: lifecycle state of a Concept/Guidance/Tenet (proposed|adopted|retired).
  *   **Living Spec Contract:** If creating or updating a spec (e.g., `.eposforge/SPEC.md` or `01-architecture/02-components/*.md`), ensure it contains: Purpose, Observable Behavior, Inputs/Outputs, Dependencies, Non-functional Bounds (Metadata Table), and Versioning Policy.
  *   **Metadata Tables:** Ensure every Adapter and Component doc includes a machine-readable metadata table per the [Adapter Pattern](01-architecture/00-adapter-pattern/adapter-pattern.md).
4.  **Validate & Rebuild:**
  *   Once files are updated, offer to perform the required steps to rebuild the Spec Graph:
      - Cognee (default): from `.eposforge/spec-graph/cognee/sync`, run `epos-secrets uv run cognee-sync --modified <changed-files>` (see sync/README.md for setup; use `--added` for new files, `--deleted` for removed files)
      - GraphRAG (fallback): `bash .eposforge/spec-graph/graphrag/scripts/rebuild.sh`

---

## Conventions

Conventions are standardized under `04-standards/`.

- Naming and doc hygiene: `04-standards/01-naming-conventions/naming-conventions.md`
- Research path refactor discipline: `04-standards/06-research-mirror/research-mirror.md`

Operational conventions retained here:

- Do not commit `.eposforge/spec-graph/graphrag/output/`, `.eposforge/spec-graph/graphrag/cache/`, `.eposforge/spec-graph/graphrag/.venv/`, `.eposforge/spec-graph/cognee/.venv/`, `.eposforge/spec-graph/cognee/.cognee/`,
  `.env`, or any file containing API keys or passwords.
- Never edit generated output under `.eposforge/spec-graph/graphrag/output/`.
- **Adapter script placement (enforced).** All scripts owned by an installed
  adapter — hooks, runners, helpers — live under
  `.eposforge/<component>/scripts/` (or
  `.eposforge/<component>/<adapter>/scripts/` when a component has
  multiple adapters). The flat `.eposforge/scripts/` directory is not permitted.
  The check at
  `.eposforge/source-control-ci/github-and-actions/scripts/check-installed-scripts-layout.sh`
  enforces this from the `pre-commit` hook and the
  `installed-scripts-layout` GitHub Actions workflow; both fail any commit
  that puts files under `.eposforge/scripts/`.
- **Git hooks are component-owned and composed.** Each installed adapter that
  needs git-hook behaviour places a fragment at
  `.eposforge/<component>/scripts/hooks/<git-hook-name>` (or
  `<component>/<adapter>/scripts/hooks/<git-hook-name>`). The composer at
  `.eposforge/source-control-ci/github-and-actions/scripts/install-hooks.sh`
  discovers all fragments and writes a dispatcher into `.git/hooks/<name>`
  that runs every fragment in order. Developers run the composer once per
  clone, per host; it is portable between srv-docker-hp (native bash) and
  ws-dev-1 (Git Bash).
- Scratchpad: write all temporary files — plans, scratch notes, ad-hoc test
  artifacts, logs, proto-test data, diff outputs — under `.scratchpad/` (repo
  root). This directory is gitignored. Never write temp files (for example
  `diff*.txt`) to the repo root or any tracked path. (`scratchpad/` without the
  dot remains gitignored as a legacy alias.)
- Skills placement: store canonical skill content under `skills/<name>/`.
  Keep `.github/skills/<name>/SKILL.md` as a thin wrapper that points to the
  canonical location.
- Syncing to the Spec Graph (Cognee, default): from `.eposforge/spec-graph/cognee/sync`, run `epos-secrets uv run cognee-sync --modified <files>` (use `--added`/`--deleted` as appropriate; see sync/README.md for setup and full-corpus seed).
- Rebuilding the Spec Graph (GraphRAG, fallback): `python .eposforge/secrets-key-management/bin/epos-secrets -- bash .eposforge/spec-graph/graphrag/scripts/rebuild.sh`
  (secrets are declared in [.eposforge/secrets-key-management/sops-age/secrets.toml](.eposforge/secrets-key-management/sops-age/secrets.toml)).
- **Technical findings go in the repo, not personal memory.** When you discover
  vendor bugs, version-specific behavior, API quirks, or diagnostic recipes for
  a system this repo integrates with (Cognee, Anthropic SDK, Kuzu, etc.),
  document them in the relevant adapter doc under
  `.eposforge/<component>/<adapter>/` (e.g. `cognee/cognee.md`).
  Operational and access setup belongs in the relevant repo skill. Personal
  memory is for pointers to where the canonical info lives, not for the info
  itself.
- **Pull before editing source-of-truth files.** This repo is developed from
  multiple hosts (srv-docker-hp and ws-dev-1). Before editing a shared
  source-of-truth file (e.g. `00-vision/01-ontology.ttl`), run
  `git fetch && git log HEAD..origin/<branch> --oneline` and pull if upstream
  commits exist. Prefer `git pull --ff-only` when local uncommitted work is
  absent. Don't trust `git status`'s "up to date with origin" without a fresh
  fetch first.

## Backlog management

- Backlog load rules:
  - Load `.eposforge/backlog/backlog.md` during active fix work (open,
    in-progress, blocked only).
  - Load `.eposforge/backlog/backlog-slated.md` during planning and deferral
    decisions.
  - Load `.eposforge/backlog/backlog-archive-index.md` first for regression checks;
    open `.eposforge/backlog/backlog-archive.md` only for full historical detail.
- Cross-repo planning: when multiple working directories are present,
  run `bash .eposforge/backlog/file-based-backlog/scripts/aggregate.sh --plan`
  before planning the next iteration.
- Operator commands:
  - `bash .eposforge/backlog/file-based-backlog/scripts/new-issue.sh`
  - `bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh`
  - `bash .eposforge/backlog/file-based-backlog/scripts/sweep-resolved.sh`
  - `bash .eposforge/backlog/file-based-backlog/scripts/aggregate.sh --plan`
  - `bash .eposforge/backlog/file-based-backlog/scripts/aggregate.sh --regressions <keyword>`
  - `bash .eposforge/backlog/file-based-backlog/scripts/aggregate.sh --graph`

---

adapter: cognee-sync
status: active

### Updated Instructions for Regenerating Graph DB

#### Primary Path: `cognee-sync`

**Overview:** `cognee-sync` is the default incremental sync tool for the Cognee knowledge graph. It handles per-file add, update, and delete operations via the Cognee HTTP API. The process involves three sequential steps: updating the ontology, running the sync, and validating results.

---

1. **Update/Verify Ontology (Prerequisite)**:
  - The ontology file (`00-vision/01-ontology.ttl`) must be updated **before** running cognee-sync.
   - The ontology is uploaded to Cognee and used to ground entity extraction during cognify—ensuring extracted entities align with your defined class IRIs and relationships.
  - If you have modified vocabulary terms, added new entity types, or changed relationships, ensure the corresponding changes are reflected in `00-vision/01-ontology.ttl` (OWL/Turtle format).
   - Verify the ontology is syntactically valid before proceeding (use an RDF validator or Protégé).

2. **Prerequisites (Environment)**:
   - Ensure the following environment variables are set:
     - `COGNEE_API_URL`: Base URL of the Cognee HTTP API.
     - `COGNEE_API_TOKEN`: Optional bearer token.
     - `COGNEE_DATASET_NAME`: Defaults to `eposforge-sync`.
   - The `dkr-cgnee-api` container must be running and reachable.

3. **Run cognee-sync**:
   - Navigate to the `cognee/sync` directory:
     ```bash
     cd .eposforge/spec-graph/cognee/sync
     ```
   - Always include the ontology file when adding or modifying files:
     - **Add new files and ontology**:
       ```bash
      epos-secrets uv run cognee-sync --added 00-vision/01-ontology.ttl path/to/file.md
       ```
     - **Modify existing files and update ontology**:
       ```bash
      epos-secrets uv run cognee-sync --modified 00-vision/01-ontology.ttl path/a.md path/b.md
       ```
     - **Delete files**:
       ```bash
       epos-secrets uv run cognee-sync --deleted path/old.md
       ```
     - **Check sync status**:
       ```bash
       epos-secrets uv run cognee-sync --status
       ```

4. **Validation**:
   - After sync completes, verify that:
     - The knowledge graph reflects the new or updated ontology classes and relationships.
     - Entity nodes are anchored to the ontology IRIs (discoverable via `/api/v1/datasets/{dataset_id}/graph` endpoint).
     - Search queries return results aligned with the updated ontology structure.
   - If discrepancies appear, check the ontology for syntax errors or missing relationships and re-sync.

5. **Token usage note**: `completion=0` in cognee-sync output is expected.
   The token tracker only counts embedding prompt tokens; LLM completion
   tokens are recorded separately by the Azure gateway. A corpus rebuild of
   ~97 files costs roughly 180K–200K embedding tokens.

---

#### Bulk corpus rebuild (from scratch)

Use when the KG needs to be rebuilt from a clean state — after a KG wipe,
a container migration, or any time incremental state is suspect.

```bash
# From repo root:
bash .eposforge/spec-graph/cognee/scripts/bulk-rebuild.sh
```

The script collects all git-tracked `*.md` and `*.ttl` files, wipes the
cognee-sync state DB, and runs `cognee-sync --added` on the full corpus.

**Two-pass note:** a first cognify pass on 80+ docs may produce ~10 SQLite
contention errors. Re-run the script — the second pass picks up missed docs.
If the second pass also fails, restart `dkr-cgnee-api` first, then re-run.

**KG wipe — operator-only:** wiping `cognee_system` destroys all graph data
and requires a full token-budget rebuild. Agents MUST NOT wipe the KG without
explicit operator confirmation using the exact phrase **"I authorize KG wipe"**.
Note: the Ladybug version-code error is unreliable as a wipe trigger — it has
appeared on already-empty databases and does not by itself indicate corruption.
The wipe procedure is in
`.eposforge/spec-graph/cognee/MAINTENANCE.md`.

---

#### Note on `graphrag`
- `graphrag` is a legacy fallback adapter for regenerating the Spec Graph. It is no longer the active implementation and should only be used for historical reference or specific fallback scenarios.
