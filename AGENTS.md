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
- **Spec layer**: `00-vision/`, `01-architecture/`, `02-roadmap/`, `03-research/`.
- **Self-host layer**: `instance/` (the concrete adapter choices for this repo).

---

## Vocabulary — use these terms exactly

| Term | Meaning |
|---|---|
| **Component** | An architectural slot (e.g. Spec Graph, Router, Dev Product). Twelve components defined in `01-architecture/02-components/`. |
| **Adapter** | A concrete implementation plugged into a component slot. Self-declares `capabilities`, `privacy_posture`, `cost_hint`, `invocation_surface`. |
| **FULFILLS_SLOT** | Relationship: an Adapter fulfills a component slot. |
| **DEPENDS_ON** | Relationship: one entity depends on another. |
| **MATURES_TO** | Relationship: an entity reaches maturity at a phase. |
| **GOVERNED_BY** | Relationship: an entity is governed by a policy or principle. |
| **IMPLEMENTS** | Relationship: an entity is an implementation of another. |
| **Phase 0–4** | Platform Factory maturity ladder (Foundation → Full Autonomy). |
| **Phase A–F** | Product Factory maturity ladder (Registry → Level 5 gate). |
| **Living Spec** | A machine-readable spec that travels with an artifact and drives agent behavior. |
| **Spec Graph** | Component 6: the queryable knowledge graph of this repo's corpus. |

---

## Authoritative-docs MCPs — MCP-FIRST POLICY

Before answering from training data or routing to external-LLM research,
query the relevant authoritative MCP. These are expected to be available
to any agent working in this repo (configured user-scope or via a
repo-pinned `.mcp.json`):

| MCP server | Use for |
|---|---|
| `cognee` | This repo's architecture, components, adapters, principles, phases, and research surveys via Cognee's graph-query interface. See policy below. |
| `github` | Open-source repos and their issues, PRs, commits, releases, labels — anything hosted on github.com. |
| `microsoft.docs` | Azure, .NET, and the broader Microsoft platform via Microsoft Learn. |
| Hugging Face Hub *(optional)* | ML models, datasets, papers, Hub metadata. Use when extending the Inference component (10) or evaluating model adapters. |

These MCPs are THIS repo's Tool Transport choices in `instance/`; other
instances choose their own adapters.

Prefer the MCP over `WebFetch` or `WebSearch` against the same source —
MCP results are structured, citation-aware, and avoid stale verbatim
recall from training data. If a question spans multiple MCPs (e.g.
"which Azure SDK does adapter X depend on, and is that SDK still
maintained?"), chain the calls: `cognee` → `github` → `microsoft.docs`.

For Cognee documentation and Cognee source-code lookups, use the `github` MCP
against `topoteretes/cognee` (and related integration repositories) first.
Do not route Cognee docs/source searches through the `cognee` MCP server.
Do not use `WebFetch`/`WebSearch` for Cognee docs/source lookups unless the
`github` MCP is unavailable; if fallback is required, state that explicitly.

### Spec Graph MCP (`cognee`) rules

The `cognee` MCP server exposes the Neo4j Spec Graph via Cognee's graph-query
and semantic-search tools. It is the authoritative interface for architecture
knowledge in this repo.

You MUST query `cognee` before reading Markdown when the prompt
mentions any of: adapter, component, slot, contract, FULFILLS_SLOT,
DEPENDS_ON, MATURES_TO, GOVERNED_BY, IMPLEMENTS, phase, principle, ADR,
Living Spec, Spec Graph, dark factory, Router, Dev Product, Tool
Transport, Execution Sandbox, Agent Policy, Inference, Audit, Secrets,
Spec Input, vocabulary, or any of the twelve component names.

Anti-pattern (outside fallback cases): do not open
`01-architecture/02-components/*.md` or grep the corpus to answer
"what adapters fulfill the X slot?" — a single `graph_query` call against
`cognee` returns the canonical answer with cross-references intact.

Example question: *"Which adapters fulfill the Inference slot?"*
Correct first action — call `cognee`'s `graph_query` with:
~~~cypher
MATCH (a:Entity {type:'ADAPTER'})-[:FULFILLS_SLOT]->(s:Entity {name:'INFERENCE'})
RETURN a.name, a.description ORDER BY a.name;
~~~

For semantic/conceptual questions, prefer `cognee`'s `search` tool with a
natural-language query; use `graph_query` for relationship traversal.

Fall back to Markdown only if (a) the MCP server is unreachable,
(b) the question is about prose/wording rather than structure, or
(c) the graph returns zero results and you need to verify the corpus.
When fallback is needed, targeted repo-file reads and searches are allowed.

### Graph schema

Cognee extracts entities and relationships from the documentation corpus
and writes them to Neo4j. The primary node label is `Entity`; relationships
are labelled by the extracted predicate. Use `CALL db.labels()` and
`CALL db.relationshipTypes()` to enumerate the live schema.

Key entity properties: `id`, `name`, `description`, `type`.
Key relationship properties vary by predicate; `description` is common.

### Vector indexes

Cognee creates its own vector indexes (fastembed `BAAI/bge-small-en-v1.5`,
384 dims). Prefer the `search` MCP tool for semantic similarity queries
rather than constructing raw vector Cypher.

### Query patterns

**Structural — use `graph_query` when the question is about relationships:**
```cypher
MATCH (a:Entity {type: 'ADAPTER'})-[:FULFILLS_SLOT]->(s:Entity {name: 'SPEC_GRAPH'})
RETURN a.name, a.description;
```

**Semantic — use `search` with a natural-language query:**
```
cognee.search("Which adapters fulfill the Spec Graph slot?")
```

**Exploratory — list entity types and relationship types:**
```cypher
CALL db.labels() YIELD label RETURN label;
CALL db.relationshipTypes() YIELD relationshipType RETURN relationshipType;
```

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
instance/installed/06-spec-graph/scripts/  rebuild.sh and other Spec Graph orchestration
instance/installed/06-spec-graph/cognee/scripts/  Cognee adapter scripts
instance/installed/06-spec-graph/graphrag/scripts/ GraphRAG adapter scripts
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
  *   **Reserved Vocabulary:** Use exactly the terms from the [Vocabulary](#vocabulary--use-these-terms-exactly) section (`component`, `adapter`, `phase`, `pillar`, `principle`, `factory`, `deliverable`, `constraint`) as entity types.
  *   **Relationship Keywords:** Explicitly use keywords to ensure the `spec-graph-import.sh` script maps edges correctly:
    *   `FULFILLS_SLOT`: "fulfills", "fills slot", "candidate adapter".
    *   `DEPENDS_ON`: "depends on", "dependency", "requires".
    *   `MATURES_TO`: "matures", "operational at phase", "graduation".
    *   `GOVERNED_BY`: "governed", "enforced by", "policy".
    *   `IMPLEMENTS`: "implements", "implementation of".
  *   **Living Spec Contract:** If creating or updating a spec (e.g., `instance/SPEC.md` or `01-architecture/02-components/*.md`), ensure it contains: Purpose, Observable Behavior, Inputs/Outputs, Dependencies, Non-functional Bounds (Metadata Table), and Versioning Policy.
  *   **Metadata Tables:** Ensure every Adapter and Component doc includes a machine-readable metadata table per the [Adapter Pattern](01-architecture/00-adapter-pattern.md).
4.  **Validate & Rebuild:**
  *   Once files are updated, offer to perform the required steps to rebuild the Spec Graph: `bash instance/installed/06-spec-graph/scripts/rebuild.sh`.

---

## Conventions

- All docs use American English.
- File and heading names are lowercase-hyphenated.
- Never commit internal environment identifiers in docs: private IP
  addresses, internal hostnames, internal DNS zones, machine names,
  VPN details, or user-specific network topology.
- When examples require endpoints, use placeholders like
  `https://<service-host>` and `bolt://<neo4j-host-or-ip>:7688`.
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
- Rebuilding the Spec Graph: `python instance/installed/12-secrets-key-management/bin/epos-secrets -- bash instance/installed/06-spec-graph/scripts/rebuild.sh`
  (secrets are declared in [instance/installed/12-secrets-key-management/sops-age/secrets.toml](instance/installed/12-secrets-key-management/sops-age/secrets.toml);
  runtime invocation is `epos-secrets -- bash instance/installed/06-spec-graph/scripts/rebuild.sh`).
