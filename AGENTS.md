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

## Spec Graph MCP tool (`eposforge-graph`) — MCP-FIRST POLICY

The `eposforge-graph` MCP server exposes the Neo4j Spec Graph via Cypher.
It is the **authoritative interface** for architecture knowledge in this
repo.

You MUST query `eposforge-graph` before reading Markdown when the prompt
mentions any of: adapter, component, slot, contract, FULFILLS_SLOT,
DEPENDS_ON, MATURES_TO, GOVERNED_BY, IMPLEMENTS, phase, principle, ADR,
Living Spec, Spec Graph, dark factory, Router, Dev Product, Tool
Transport, Execution Sandbox, Agent Policy, Inference, Audit, Secrets,
Spec Input, vocabulary, or any of the twelve component names.

**Anti-pattern.** Do not open `01-architecture/02-components/*.md` or
grep the corpus to answer “what adapters fulfill the X slot?” — a single
Cypher query against `eposforge-graph` returns the canonical answer with
cross-references intact.

**Example.** Question: *“Which adapters fulfill the Inference slot?”*
Correct first action — call `read_neo4j_cypher` with:
~~~cypher
MATCH (a:Entity {type:'ADAPTER'})-[:FULFILLS_SLOT]->(s:Entity {title:'INFERENCE'})
RETURN a.title, a.description ORDER BY a.title;
~~~

Fall back to Markdown only if (a) the MCP server is unreachable, (b) the
question is about prose/wording rather than structure, or (c) the graph
returns zero results and you need to verify the corpus.

### Graph schema

| Label | Key properties | Notes |
|---|---|---|
| `Entity` | `id`, `title`, `type`, `description`, `embedding` | `type` matches vocabulary above |
| `Community` | `id`, `title`, `level`, `size` | Leiden cluster |
| `CommunityReport` | `id`, `title`, `summary`, `full_content`, `embedding` | Thematic summary of a cluster |
| `TextUnit` | `id`, `text`, `document_id`, `embedding` | Source paragraph chunk |

Relationships: `FULFILLS_SLOT`, `DEPENDS_ON`, `MATURES_TO`, `GOVERNED_BY`,
`IMPLEMENTS`, `SUPERSEDES`, `PART_OF`, `RELATED_TO`, `APPEARS_IN`,
`HAS_REPORT`.

### Vector indexes

Three indexes support semantic similarity queries (Neo4j native, cosine,
1536 dims, `text-embedding-3-small`):

| Index name | On label |
|---|---|
| `entity_embedding` | `Entity` |
| `text_unit_embedding` | `TextUnit` |
| `community_report_embedding` | `CommunityReport` |

### Query patterns

**Structural — use when the question is about relationships:**
```cypher
MATCH (a:Entity {type: 'ADAPTER'})-[:FULFILLS_SLOT]->(s:Entity {title: 'SPEC_GRAPH'})
RETURN a.title, a.description;
```

**Semantic — use when the question involves a concept, not a known name.**
Embed the query string client-side (OpenAI `text-embedding-3-small`) and
pass the vector as `$query_vec`:
```cypher
CALL db.index.vector.queryNodes('entity_embedding', 20, $query_vec)
YIELD node AS e, score
RETURN e.title, e.type, score ORDER BY score DESC LIMIT 10;
```

**Hybrid — combine both in one query:**
```cypher
CALL db.index.vector.queryNodes('entity_embedding', 25, $query_vec)
YIELD node AS candidate, score
WHERE candidate.type = 'ADAPTER'
  AND EXISTS {
    MATCH (candidate)-[:FULFILLS_SLOT]->(s:Entity {title: 'INFERENCE'})
  }
RETURN candidate.title, score ORDER BY score DESC LIMIT 5;
```

**Community synthesis — high-level architectural overviews:**
```cypher
CALL db.index.vector.queryNodes('community_report_embedding', 5, $query_vec)
YIELD node AS report, score
RETURN report.title, report.summary, score ORDER BY score DESC;
```

---

## Files and structure

```
00-vision/          Principles, glossary, north star
01-architecture/    ADRs, component contracts, adapter pattern
02-roadmap/         Phase plans
03-research/        Domain research including spec-graph integration notes
graphrag/           GraphRAG project (settings, prompts, output/)
scripts/            spec-graph-rebuild.sh, spec-graph-import.sh, etc.
SPEC.md             Living Spec for the Spec Graph tooling (Component 6)
```

Paired-change rule: changes to the specific files enumerated in the
`SPEC.md §Paired-change rule` section must update `SPEC.md` in the same
commit. Additions to `scripts/` or `graphrag/` that are not in that list
do not require a `SPEC.md` update.

---

## Agent Workflows

### `/modifyef` — Reconcile and apply design changes
Use this workflow when the user provides a description of additions, deletions, or edits to the EposForge architecture.

1.  **Research & Reconcile:**
    *   Query `eposforge-graph` to identify current components, adapters, and relationships affected by the requested change.
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
    *   **Living Spec Contract:** If creating or updating a spec (e.g., `SPEC.md` or `01-architecture/02-components/*.md`), ensure it contains: Purpose, Observable Behavior, Inputs/Outputs, Dependencies, Non-functional Bounds (Metadata Table), and Versioning Policy.
    *   **Metadata Tables:** Ensure every Adapter and Component doc includes a machine-readable metadata table per the [Adapter Pattern](01-architecture/00-adapter-pattern.md).
4.  **Validate & Rebuild:**
    *   Once files are updated, offer to perform the required steps to rebuild the Spec Graph: `bash scripts/spec-graph-rebuild.sh`.

---

## Conventions

- All docs use American English.
- File and heading names are lowercase-hyphenated.
- Never commit internal environment identifiers in docs: private IP
  addresses, internal hostnames, internal DNS zones, machine names,
  VPN details, or user-specific network topology.
- When examples require endpoints, use placeholders like
  `https://<service-host>` and `bolt://<neo4j-host-or-ip>:7688`.
- Do not commit `graphrag/output/`, `graphrag/cache/`, `graphrag/.venv/`,
  `.env`, or any file containing API keys or passwords.
- Never edit generated output under `graphrag/output/`.
- Rebuilding the Spec Graph: `bash scripts/spec-graph-rebuild.sh`
  (requires `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `NEO4J_PASSWORD`).
