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

## Standards

Normative cross-cutting standards are defined under `04-standards/`.

- Vocabulary: `04-standards/02-vocabulary/` (until that lands, use `00-vision/01-glossary.md`)
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
instance/scripts/   hooks/ (git hook helpers only)
instance/installed/06-spec-graph/cognee/scripts/  Cognee adapter scripts (ingest_dual_container.sh)
instance/installed/06-spec-graph/graphrag/scripts/ GraphRAG adapter scripts (rebuild.sh, index.sh, import.sh)
instance/SPEC.md    Living Spec for this repo's Spec Graph adapter (Component 6)
```

Paired-change rule: changes to the specific files enumerated in the
`instance/SPEC.md §Paired-change rule` section must update `instance/SPEC.md`
in the same commit. Additions to `instance/scripts/` or
`instance/installed/06-spec-graph/` that are not in that list do not require an
`instance/SPEC.md` update.

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
  *   **Reserved Vocabulary:** Use exactly the terms from `00-vision/01-glossary.md` until `04-standards/02-vocabulary/` lands (`component`, `adapter`, `phase`, `pillar`, `principle`, `factory`, `deliverable`, `constraint`) as entity types.
  *   **Relationship Keywords:** Explicitly use keywords to ensure the `spec-graph-import.sh` script maps edges correctly:
    *   `FULFILLS_SLOT`: "fulfills", "fills slot", "candidate adapter".
    *   `DEPENDS_ON`: "depends on", "dependency", "requires".
    *   `MATURES_TO`: "matures", "operational at phase", "graduation".
    *   `GOVERNED_BY`: "governed", "enforced by", "policy".
    *   `IMPLEMENTS`: "implements", "implementation of".
  *   **Living Spec Contract:** If creating or updating a spec (e.g., `instance/SPEC.md` or `01-architecture/02-components/*.md`), ensure it contains: Purpose, Observable Behavior, Inputs/Outputs, Dependencies, Non-functional Bounds (Metadata Table), and Versioning Policy.
  *   **Metadata Tables:** Ensure every Adapter and Component doc includes a machine-readable metadata table per the [Adapter Pattern](01-architecture/00-adapter-pattern.md).
4.  **Validate & Rebuild:**
  *   Once files are updated, offer to perform the required steps to rebuild the Spec Graph:
      - Cognee (default): `bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh`
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
- Implementation script placement: scripts that implement a specific adapter
  must live with that adapter under
  `instance/installed/<component>/<adapter>/scripts/`.
- `instance/scripts/` is a legacy compatibility area for repo-level
  orchestration shims and git hook helpers only; do not add new
  adapter-specific implementation scripts there.
- Troubleshooting scratchpad: use `scratchpad/` (repo root) for ad-hoc test
  artifacts, logs, and proto-test data. This directory is gitignored. Do not
  use `instance/scripts/` as a scratchpad.
- Rebuilding the Spec Graph (Cognee, default): `bash instance/installed/06-spec-graph/cognee/scripts/ingest_dual_container.sh`
- Rebuilding the Spec Graph (GraphRAG, fallback): `python instance/installed/12-secrets-key-management/bin/epos-secrets -- bash instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh`
  (secrets are declared in [instance/installed/12-secrets-key-management/sops-age/secrets.toml](instance/installed/12-secrets-key-management/sops-age/secrets.toml)).
