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
- **Self-host layer**: `instance/` (the concrete adapter choices for this repo).

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
| **Living Spec** | A machine-readable spec that travels with an artifact and drives agent behavior. |
| **Spec Graph** | Component 6: the queryable knowledge graph of this repo's corpus. |

- Vocabulary: `00-vision/01-ontology.ttl` is the authoritative ontology. Editorial workflow is governed by `04-standards/02-vocabulary/vocabulary.md` and executed via the `maintain-ontology` skill.
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
instance/           Self-host implementation for this repo
instance/installed/06-spec-graph/graphrag/  GraphRAG project (settings, prompts, output/)
instance/installed/06-spec-graph/cognee/    Cognee ontology-grounded extraction adapter
instance/installed/06-spec-graph/cognee/scripts/   Cognee adapter scripts
instance/installed/06-spec-graph/graphrag/scripts/ GraphRAG adapter scripts (rebuild.sh, index.sh, import.sh)
instance/installed/06-spec-graph/scripts/hooks/    Spec-graph hook fragments composed into .git/hooks/
instance/installed/09-source-control-ci/github-and-actions/scripts/ SCM/CI checks, hook composer, hook fragments
instance/SPEC.md    Living Spec for this repo's Spec Graph adapter (Component 6)
```

Paired-change rule: changes to the specific files enumerated in the
`instance/SPEC.md §Paired-change rule` section must update `instance/SPEC.md`
in the same commit. Additions to `instance/installed/06-spec-graph/` that
are not in that list do not require an `instance/SPEC.md` update.

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
  *   **Reserved Vocabulary:** Use exactly the terms from the [Vocabulary standard](04-standards/02-vocabulary/vocabulary.md) (`component`, `adapter`, `phase`, `pillar`, `principle`, `factory`, `deliverable`, `constraint`, `concept`, `guidance`, `tenet`, `group`) as entity types. Canonical definitions for `concept`, `guidance`, `tenet`, and `group` are in `00-vision/01-ontology.ttl`.
  *   **Relationship Keywords:** Use these exact keywords so Cognee's ontology-grounded extraction maps edges correctly:
    *   `FULFILLS_SLOT`: "fulfills", "fills slot", "candidate adapter".
    *   `DEPENDS_ON`: "depends on", "dependency", "requires".
    *   `MATURES_TO`: "matures", "operational at phase", "graduation".
    *   `GOVERNED_BY`: "governed", "enforced by", "policy".
    *   `IMPLEMENTS`: "implements", "implementation of".
    *   `KIND`: node kind discriminator (pillar|group|component|concept|guidance|tenet).
    *   `LIFECYCLE_STATUS`: lifecycle state of a Concept/Guidance/Tenet (proposed|adopted|retired).
  *   **Living Spec Contract:** If creating or updating a spec (e.g., `instance/SPEC.md` or `01-architecture/02-components/*.md`), ensure it contains: Purpose, Observable Behavior, Inputs/Outputs, Dependencies, Non-functional Bounds (Metadata Table), and Versioning Policy.
  *   **Metadata Tables:** Ensure every Adapter and Component doc includes a machine-readable metadata table per the [Adapter Pattern](01-architecture/00-adapter-pattern.md).
4.  **Validate & Rebuild:**
  *   Once files are updated, offer to perform the required steps to rebuild the Spec Graph:
      - Cognee (default): from `instance/installed/06-spec-graph/cognee/sync`, run `epos-secrets uv run cognee-sync --modified <changed-files>` (see sync/README.md for setup; use `--added` for new files, `--deleted` for removed files)
      - GraphRAG (fallback): `bash instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh`

---

## Conventions

Conventions are standardized under `04-standards/`.

- Naming and doc hygiene: `04-standards/01-naming-conventions/naming-conventions.md`
- Research path refactor discipline: `04-standards/06-research-mirror/research-mirror.md`

Operational conventions retained here:

- Do not commit `instance/installed/06-spec-graph/graphrag/output/`, `instance/installed/06-spec-graph/graphrag/cache/`, `instance/installed/06-spec-graph/graphrag/.venv/`, `instance/installed/06-spec-graph/cognee/.venv/`, `instance/installed/06-spec-graph/cognee/.cognee/`,
  `.env`, or any file containing API keys or passwords.
- Never edit generated output under `instance/installed/06-spec-graph/graphrag/output/`.
- **Adapter script placement (enforced).** All scripts owned by an installed
  adapter — hooks, runners, helpers — live under
  `instance/installed/<component>/scripts/` (or
  `instance/installed/<component>/<adapter>/scripts/` when a component has
  multiple adapters). The flat `instance/scripts/` directory is not permitted.
  The check at
  `instance/installed/09-source-control-ci/github-and-actions/scripts/check-installed-scripts-layout.sh`
  enforces this from the `pre-commit` hook and the
  `installed-scripts-layout` GitHub Actions workflow; both fail any commit
  that puts files under `instance/scripts/`.
- **Git hooks are component-owned and composed.** Each installed adapter that
  needs git-hook behaviour places a fragment at
  `instance/installed/<component>/scripts/hooks/<git-hook-name>` (or
  `<component>/<adapter>/scripts/hooks/<git-hook-name>`). The composer at
  `instance/installed/09-source-control-ci/github-and-actions/scripts/install-hooks.sh`
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
- Syncing to the Spec Graph (Cognee, default): from `instance/installed/06-spec-graph/cognee/sync`, run `epos-secrets uv run cognee-sync --modified <files>` (use `--added`/`--deleted` as appropriate; see sync/README.md for setup and full-corpus seed).
- Rebuilding the Spec Graph (GraphRAG, fallback): `python instance/installed/12-secrets-key-management/bin/epos-secrets -- bash instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh`
  (secrets are declared in [instance/installed/12-secrets-key-management/sops-age/secrets.toml](instance/installed/12-secrets-key-management/sops-age/secrets.toml)).

## Backlog management

- Backlog load rules:
  - Load `backlog/backlog.md` during active fix work (open,
    in-progress, blocked only).
  - Load `backlog/backlog-slated.md` during planning and deferral
    decisions.
  - Load `backlog/backlog-archive-index.md` first for regression checks;
    open `backlog/backlog-archive.md` only for full historical detail.
- Cross-repo planning: when multiple working directories are present,
  run `bash instance/installed/13-backlog/file-based-backlog/scripts/aggregate.sh --plan`
  before planning the next iteration.
- Operator commands:
  - `bash instance/installed/13-backlog/file-based-backlog/scripts/new-issue.sh`
  - `bash instance/installed/13-backlog/file-based-backlog/scripts/lint-backlog.sh`
  - `bash instance/installed/13-backlog/file-based-backlog/scripts/sweep-resolved.sh`
  - `bash instance/installed/13-backlog/file-based-backlog/scripts/aggregate.sh --plan`
  - `bash instance/installed/13-backlog/file-based-backlog/scripts/aggregate.sh --regressions <keyword>`
  - `bash instance/installed/13-backlog/file-based-backlog/scripts/aggregate.sh --graph`

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
     cd instance/installed/06-spec-graph/cognee/sync
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
bash instance/installed/06-spec-graph/cognee/scripts/bulk-rebuild.sh
```

The script collects all git-tracked `*.md` and `*.ttl` files, wipes the
cognee-sync state DB, and runs `cognee-sync --added` on the full corpus.

**Two-pass note:** a first cognify pass on 80+ docs may produce ~10 SQLite
contention errors. Re-run the script — the second pass picks up missed docs.
If the second pass also fails, restart `dkr-cgnee-api` first, then re-run.

**KG wipe before rebuild:** if the Ladybug version-code error appears at
container startup, the prior run left stale lock files in `cognee_system`.
Recovery (destroys KG — requires full rebuild after):

```bash
COMPOSE_FILE=/mnt/raid-storage/docker-volume-mounts/cognee/docker-compose.yml
docker compose -f "$COMPOSE_FILE" stop dkr-cgnee-api
sudo rm -rf /mnt/raid-storage/docker-volume-mounts/cognee/data/cognee_system
sudo mkdir -p /mnt/raid-storage/docker-volume-mounts/cognee/data/cognee_system
sudo chown -R cdfadmin: /mnt/raid-storage/docker-volume-mounts/cognee/data/cognee_system
docker compose -f "$COMPOSE_FILE" start dkr-cgnee-api
# then run bulk-rebuild.sh
```

---

#### Note on `graphrag`
- `graphrag` is a legacy fallback adapter for regenerating the Spec Graph. It is no longer the active implementation and should only be used for historical reference or specific fallback scenarios.
