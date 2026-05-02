---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# GraphRAG workspace — EposForge Spec Graph

This directory is the Microsoft GraphRAG project that indexes the
EposForge vision and architecture Markdown files and projects them
into a Neo4j knowledge graph (Component 6: Spec Graph).

See [03-research/06-spec-graph/graphrag-neo4j-integration.md](../../03-research/06-spec-graph/graphrag-neo4j-integration.md)
for the full architecture and setup walkthrough.

---

## Quick start

```bash
# 1. Create and activate a Python virtual environment (Python 3.11–3.13)
python -m venv .venv
source .venv/bin/activate        # Linux / macOS
# .venv\Scripts\activate         # Windows

# 2. Install dependencies (pinned to tested version)
pip install 'graphrag==3.0.9' neo4j pandas pyarrow lancedb

# 3. One-time init: generates default prompts in prompts/
#    The custom prompts already in prompts/ override the defaults.
#    --force is required in GraphRAG 3.x to generate the new config layout.
graphrag init --root . --force

# 4. Set your API keys
export ANTHROPIC_API_KEY=your-anthropic-key
export OPENAI_API_KEY=your-openai-key        # used for embeddings
export NEO4J_URI=bolt://localhost:7688  # host port mapped from container's 7687
export NEO4J_USERNAME=neo4j
export NEO4J_PASSWORD=your-neo4j-password

# Alternative: use Gemini for both completion and embeddings by
# uncommenting the Gemini blocks in settings.yaml and setting:
# export GEMINI_API_KEY=your-gemini-key

# 5. Index all Markdown files and import into Neo4j
cd ../..                         # repo root
bash instance/scripts/spec-graph-rebuild.sh
```

> **Note:** The first index run creates `output/lancedb/` (the vector
> store). This directory is gitignored and will be recreated on the next
> rebuild if deleted.

---

## Requirements

| Requirement | Version | Notes |
|---|---|---|
| Neo4j Community Edition | **≥ 5.11** | Required for native vector indexes |
| APOC plugin | compatible | Required; already used for dynamic rels |
| OpenAI API key | current | For `text-embedding-3-small` (1536 dims) |
| `neo4j-genai-plugin` | ≥ 5.18 only | **Optional.** Enables `genai.vector.encode` for in-Cypher query embedding. Not bundled with CE — install separately if needed. |

---

## Hybrid graph + vector queries

After a rebuild, Neo4j holds three vector indexes (`entity_embedding`,
`text_unit_embedding`, `community_report_embedding`). Any MCP-connected
Dev Product can issue hybrid Cypher that combines semantic similarity
with structural graph traversal in a single `read-cypher` call.

### Primary pattern — client-side embedding (all Neo4j CE ≥ 5.11)

Embed the query string with the OpenAI API (or any compatible client)
and pass the vector as a `$query_vec` parameter:

```cypher
// Example 1: Find ADAPTERs semantically near a topic that fulfill a slot
CALL db.index.vector.queryNodes('entity_embedding', 25, $query_vec)
YIELD node AS candidate, score
WHERE candidate.type = 'ADAPTER'
  AND EXISTS {
    MATCH (candidate)-[:FULFILLS_SLOT]->(slot:Entity {title: 'AUDIT_OBSERVABILITY'})
  }
RETURN candidate.title, score
ORDER BY score DESC LIMIT 5;
```

```cypher
// Example 2: Find spec passages (TextUnits) near a topic, then jump to
// the entities that appear in those passages.
CALL db.index.vector.queryNodes('text_unit_embedding', 10, $query_vec)
YIELD node AS tu, score
MATCH (e:Entity)-[:APPEARS_IN]->(tu)
RETURN DISTINCT e.title, e.type, score
ORDER BY score DESC LIMIT 10;
```

```cypher
// Example 3: High-level synthesis — find community reports near a topic
// and return their summaries for broad architectural context.
CALL db.index.vector.queryNodes('community_report_embedding', 5, $query_vec)
YIELD node AS report, score
RETURN report.title, report.summary, score
ORDER BY score DESC;
```

### Optional pattern — in-Cypher embedding (Neo4j ≥ 5.18 + `neo4j-genai-plugin`)

> **Prerequisite:** the `neo4j-genai-plugin` must be installed on the
> Neo4j instance. It is **not bundled with Community Edition**. Without
> it, `genai.vector.encode` throws "unknown function" even on ≥ 5.18.
> Use the client-side pattern above on standard CE installs.

```cypher
// Same as Example 1 but embedding happens inside the Cypher query.
WITH genai.vector.encode(
  'compliance-grade audit logging',
  'OpenAI',
  {token: $openAiKey, model: 'text-embedding-3-small'}
) AS query_vec
CALL db.index.vector.queryNodes('entity_embedding', 25, query_vec)
YIELD node AS candidate, score
WHERE candidate.type = 'ADAPTER'
  AND EXISTS {
    MATCH (candidate)-[:FULFILLS_SLOT]->(slot:Entity {title: 'AUDIT_OBSERVABILITY'})
  }
RETURN candidate.title, score
ORDER BY score DESC LIMIT 5;
```

---

## Verification

After a full rebuild (`bash instance/scripts/spec-graph-rebuild.sh`), confirm
the vector indexes are online and fully populated:

```bash
cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "SHOW VECTOR INDEXES YIELD name, state, populationPercent;"
```

Expected output: three rows (`entity_embedding`, `text_unit_embedding`,
`community_report_embedding`), each with `state=ONLINE` and
`populationPercent=100`.

Confirm embedding counts in Cypher:

```cypher
MATCH (e:Entity) WHERE e.embedding IS NOT NULL RETURN count(e);
MATCH (t:TextUnit) WHERE t.embedding IS NOT NULL RETURN count(t);
MATCH (r:CommunityReport) WHERE r.embedding IS NOT NULL RETURN count(r);
```

Each count should equal the total node count for that label.

---

## Files

| File / Dir | Purpose |
|---|---|
| `settings.yaml` | GraphRAG project configuration |
| `prompts/` | Custom entity/relationship extraction prompts |
| `output/` | Generated Parquet files (gitignored) |
| `cache/` | GraphRAG run cache (gitignored) |

---

## Privacy note

GraphRAG sends text chunks to the inference backend for extraction.
This repo's content is public, so `vendor-default` posture is
acceptable. For private Living Spec content in a factory instance,
use a `vendor-no-training` API key or substitute Ollama as the
backend by updating `api_base` in `settings.yaml`.

