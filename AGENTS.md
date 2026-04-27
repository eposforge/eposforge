# Agent Instructions — EposForge

Shared instructions for AI coding assistants (GitHub Copilot, Claude Code,
and others) working in this repo. `.github/copilot-instructions.md` and
`CLAUDE.md` are thin pointers to this file.

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

## Spec Graph MCP tool (`eposforge-graph`)

The `eposforge-graph` MCP server exposes the Neo4j Spec Graph via Cypher.
**Use it when answering questions about the architecture**, instead of
reading individual Markdown files. It is faster, cross-referenced, and
semantically searchable.

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

Paired-change rule: any change to `graphrag/` or `scripts/` must update
`SPEC.md` in the same commit.

---

## Conventions

- All docs use American English.
- File and heading names are lowercase-hyphenated.
- Do not commit `graphrag/output/`, `graphrag/cache/`, `graphrag/.venv/`,
  `.env`, or any file containing API keys or passwords.
- Never edit generated output under `graphrag/output/`.
- Rebuilding the Spec Graph: `bash scripts/spec-graph-rebuild.sh`
  (requires `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `NEO4J_PASSWORD`).
