#!/usr/bin/env bash
# spec-graph-import.sh — Import GraphRAG Parquet output into Neo4j.
#
# Reads Entity, Relationship, Community, CommunityReport, and TextUnit
# Parquet files from graphrag/output/ and batch-imports them into Neo4j.
# Uses MERGE-by-id for idempotent re-imports, APOC for dynamic relationship
# types, and a tombstone sweep to remove stale nodes from prior runs.
#
# Prerequisites:
#   - Neo4j CE running with APOC plugin enabled.
#   - Python venv at graphrag/.venv with neo4j, pandas, pyarrow installed.
#   - NEO4J_URI, NEO4J_USERNAME, NEO4J_PASSWORD environment variables set.
#
# Usage:
#   NEO4J_URI=bolt://localhost:7687 \
#   NEO4J_USERNAME=neo4j \
#   NEO4J_PASSWORD=your-password \
#   bash scripts/spec-graph-import.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRAPHRAG_DIR="${REPO_ROOT}/graphrag"
VENV="${GRAPHRAG_DIR}/.venv"
PYTHON="${VENV}/bin/python"
OUTPUT_DIR="${GRAPHRAG_DIR}/output"

# Verify prerequisites
if [[ ! -d "${VENV}" ]]; then
  echo "ERROR: Python venv not found at ${VENV}" >&2
  exit 1
fi

for var in NEO4J_URI NEO4J_USERNAME NEO4J_PASSWORD; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: ${var} is not set." >&2
    exit 1
  fi
done

if [[ ! -d "${OUTPUT_DIR}" ]]; then
  echo "ERROR: GraphRAG output directory not found: ${OUTPUT_DIR}" >&2
  echo "Run scripts/spec-graph-index.sh first." >&2
  exit 1
fi

echo "==> Importing GraphRAG output into Neo4j (${NEO4J_URI})"

export GRAPHRAG_OUTPUT_DIR="${OUTPUT_DIR}"
"${PYTHON}" - <<'PYEOF'
import os
import glob
import pathlib
import lancedb
import numpy as np
import pandas as pd
from neo4j import GraphDatabase

OUTPUT_DIR = pathlib.Path(os.environ["GRAPHRAG_OUTPUT_DIR"])
NEO4J_URI = os.environ["NEO4J_URI"]
NEO4J_USERNAME = os.environ["NEO4J_USERNAME"]
NEO4J_PASSWORD = os.environ["NEO4J_PASSWORD"]

# EposForge vocabulary keyword map for dynamic relationship type inference.
# Checked in order; first match wins; falls back to RELATED_TO.
REL_TYPE_KEYWORDS = {
    "FULFILLS_SLOT": ["fulfills", "fills slot", "candidate adapter"],
    "DEPENDS_ON": ["depends on", "dependency", "requires"],
    "MATURES_TO": ["matures", "operational at phase", "graduation"],
    "GOVERNED_BY": ["governed", "enforced by", "policy"],
    "IMPLEMENTS": ["implements", "implementation of"],
    "SUPERSEDES": ["supersedes", "replaces", "obsoletes"],
    "PART_OF": ["part of", "sub-component", "belongs to"],
}

def infer_rel_type(description: str) -> str:
    desc_lower = description.lower()
    for rel_type, keywords in REL_TYPE_KEYWORDS.items():
        if any(kw in desc_lower for kw in keywords):
            return rel_type
    return "RELATED_TO"

def read_parquet(pattern):
    files = sorted(glob.glob(str(OUTPUT_DIR / "**" / pattern), recursive=True))
    if not files:
        return pd.DataFrame()
    return pd.concat([pd.read_parquet(f) for f in files], ignore_index=True)

driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USERNAME, NEO4J_PASSWORD))

with driver.session() as session:
    # -----------------------------------------------------------------------
    # Constraints and indexes (idempotent)
    # -----------------------------------------------------------------------
    print("  Creating constraints and indexes...")
    session.run("CREATE CONSTRAINT entity_id IF NOT EXISTS "
                "FOR (e:Entity) REQUIRE e.id IS UNIQUE")
    session.run("CREATE CONSTRAINT community_id IF NOT EXISTS "
                "FOR (c:Community) REQUIRE c.id IS UNIQUE")
    session.run("CREATE CONSTRAINT text_unit_id IF NOT EXISTS "
                "FOR (t:TextUnit) REQUIRE t.id IS UNIQUE")
    session.run("CREATE INDEX entity_title IF NOT EXISTS "
                "FOR (e:Entity) ON (e.title)")
    session.run("CREATE INDEX entity_type IF NOT EXISTS "
                "FOR (e:Entity) ON (e.type)")
    session.run("CREATE CONSTRAINT community_report_id IF NOT EXISTS "
                "FOR (r:CommunityReport) REQUIRE r.id IS UNIQUE")
    # Vector indexes — native Neo4j 5.11+ feature; GDS not required.
    session.run(
        "CREATE VECTOR INDEX entity_embedding IF NOT EXISTS "
        "FOR (e:Entity) ON (e.embedding) "
        "OPTIONS {indexConfig: {"
        "`vector.dimensions`: 1536, "
        "`vector.similarity_function`: 'cosine'}}"
    )
    session.run(
        "CREATE VECTOR INDEX text_unit_embedding IF NOT EXISTS "
        "FOR (t:TextUnit) ON (t.embedding) "
        "OPTIONS {indexConfig: {"
        "`vector.dimensions`: 1536, "
        "`vector.similarity_function`: 'cosine'}}"
    )
    session.run(
        "CREATE VECTOR INDEX community_report_embedding IF NOT EXISTS "
        "FOR (c:CommunityReport) ON (c.embedding) "
        "OPTIONS {indexConfig: {"
        "`vector.dimensions`: 1536, "
        "`vector.similarity_function`: 'cosine'}}"
    )

    # -----------------------------------------------------------------------
    # Entities
    # 3.x column: "title" is the display name (not "name").
    # -----------------------------------------------------------------------
    entities = read_parquet("entities.parquet")
    entity_ids = []
    if not entities.empty:
        print(f"  Importing {len(entities)} entities...")
        rows = [
            {
                "id": str(row["id"]),
                "title": str(row["title"]),
                "type": str(row.get("type", "")),
                "description": str(row.get("description", "")),
                "frequency": int(row.get("frequency", 0)),
                "degree": int(row.get("degree", 0)),
            }
            for _, row in entities.iterrows()
        ]
        entity_ids = [r["id"] for r in rows]
        session.run(
            "UNWIND $rows AS row "
            "MERGE (e:Entity {id: row.id}) "
            "SET e.title = row.title, e.type = row.type, "
            "    e.description = row.description, "
            "    e.frequency = row.frequency, e.degree = row.degree",
            rows=rows,
        )

    # -----------------------------------------------------------------------
    # Relationships
    # 3.x: "source" and "target" are entity titles, not UUIDs.
    # Use apoc.merge.relationship for dynamic, idempotent rel creation.
    # -----------------------------------------------------------------------
    rels = read_parquet("relationships.parquet")
    if not rels.empty:
        print(f"  Importing {len(rels)} relationships...")
        rows = []
        for _, row in rels.iterrows():
            description = str(row.get("description", ""))
            rows.append({
                "id": str(row.get("id", row.get("human_readable_id", ""))),
                "src_title": str(row.get("source", "")),
                "tgt_title": str(row.get("target", "")),
                "description": description,
                "weight": float(row.get("weight", 1.0)),
                "rel_type": infer_rel_type(description),
            })
        session.run(
            "UNWIND $rows AS row "
            "MATCH (src:Entity {title: row.src_title}) "
            "MATCH (tgt:Entity {title: row.tgt_title}) "
            "CALL apoc.merge.relationship(src, row.rel_type, "
            "  {id: row.id}, "
            "  {description: row.description, weight: row.weight}, "
            "  tgt, {}) YIELD rel "
            "RETURN count(rel)",
            rows=rows,
        )

    # -----------------------------------------------------------------------
    # Communities
    # Note: communities.parquet has no "summary" column in 3.x.
    # Summaries live in community_reports.parquet (imported below).
    # Store community_int (Leiden cluster ID) to enable the FK join.
    # -----------------------------------------------------------------------
    communities = read_parquet("communities.parquet")
    community_ids = []
    if not communities.empty:
        print(f"  Importing {len(communities)} communities...")
        rows = [
            {
                "id": str(row["id"]),
                "community_int": int(row.get("community", 0)),
                "title": str(row.get("title", "")),
                "level": int(row.get("level", 0)),
                "size": int(row.get("size", 0)),
            }
            for _, row in communities.iterrows()
        ]
        community_ids = [r["id"] for r in rows]
        session.run(
            "UNWIND $rows AS row "
            "MERGE (c:Community {id: row.id}) "
            "SET c.community_int = row.community_int, "
            "    c.title = row.title, c.level = row.level, "
            "    c.size = row.size",
            rows=rows,
        )

    # -----------------------------------------------------------------------
    # Community Reports — separate table in 3.x, joined to Community
    # via the integer "community" FK field.
    # -----------------------------------------------------------------------
    community_reports = read_parquet("community_reports.parquet")
    community_report_ids = []
    if not community_reports.empty:
        print(f"  Importing {len(community_reports)} community reports...")
        rows = [
            {
                "id": str(row["id"]),
                "community_int": int(row.get("community", 0)),
                "level": int(row.get("level", 0)),
                "title": str(row.get("title", "")),
                "summary": str(row.get("summary", "")),
                "full_content": str(row.get("full_content", "")),
                "rank": float(row.get("rank", 0.0)),
            }
            for _, row in community_reports.iterrows()
        ]
        community_report_ids = [r["id"] for r in rows]
        session.run(
            "UNWIND $rows AS row "
            "MERGE (r:CommunityReport {id: row.id}) "
            "SET r.community_int = row.community_int, "
            "    r.level = row.level, r.title = row.title, "
            "    r.summary = row.summary, "
            "    r.full_content = row.full_content, "
            "    r.rank = row.rank",
            rows=rows,
        )
        session.run(
            "UNWIND $rows AS row "
            "MATCH (c:Community {community_int: row.community_int}) "
            "MATCH (r:CommunityReport {id: row.id}) "
            "MERGE (c)-[:HAS_REPORT]->(r)",
            rows=rows,
        )

    # -----------------------------------------------------------------------
    # TextUnits — enables entity → source-paragraph traceability
    # -----------------------------------------------------------------------
    text_units = read_parquet("text_units.parquet")
    text_unit_ids = []
    if not text_units.empty:
        print(f"  Importing {len(text_units)} text units...")
        rows = [
            {
                "id": str(row["id"]),
                "text": str(row.get("text", "")),
                "n_tokens": int(row.get("n_tokens", 0)),
                "document_id": str(row.get("document_id", "")),
            }
            for _, row in text_units.iterrows()
        ]
        text_unit_ids = [r["id"] for r in rows]
        session.run(
            "UNWIND $rows AS row "
            "MERGE (t:TextUnit {id: row.id}) "
            "SET t.text = row.text, t.n_tokens = row.n_tokens, "
            "    t.document_id = row.document_id",
            rows=rows,
        )

    # -----------------------------------------------------------------------
    # Entity → TextUnit APPEARS_IN relationships (traceability)
    # -----------------------------------------------------------------------
    if not entities.empty and not text_units.empty:
        print("  Linking entities to text units...")
        entity_tu_rows = []
        for _, row in entities.iterrows():
            eid = str(row["id"])
            raw = row.get("text_unit_ids")
            if raw is None:
                tu_ids = []
            else:
                try:
                    tu_ids = list(raw)
                except TypeError:
                    tu_ids = []
            for tuid in tu_ids:
                entity_tu_rows.append({"entity_id": eid, "tu_id": str(tuid)})
        if entity_tu_rows:
            session.run(
                "UNWIND $rows AS row "
                "MATCH (e:Entity {id: row.entity_id}) "
                "MATCH (t:TextUnit {id: row.tu_id}) "
                "MERGE (e)-[:APPEARS_IN]->(t)",
                rows=entity_tu_rows,
            )

    # -----------------------------------------------------------------------
    # Embedding write passes — copy LanceDB vectors into Neo4j node properties.
    # Uses db.create.setNodeVectorProperty for optimised binary storage.
    # Runs after all MERGE blocks (nodes must exist) and before tombstone sweep.
    # -----------------------------------------------------------------------
    print("  Writing embeddings from LanceDB...")
    ldb = lancedb.connect(str(OUTPUT_DIR / "lancedb"))

    if not entities.empty:
        entity_emb = ldb.open_table("entity_description").to_pandas()[["id", "vector"]]
        entities_with_emb = entities.merge(entity_emb, on="id", how="left")
        emb_rows = [
            {"id": str(r["id"]), "embedding": [float(x) for x in r["vector"]]}
            for _, r in entities_with_emb.iterrows()
            if isinstance(r["vector"], np.ndarray)
        ]
        if emb_rows:
            session.run(
                "UNWIND $rows AS row "
                "MATCH (e:Entity {id: row.id}) "
                "CALL db.create.setNodeVectorProperty(e, 'embedding', row.embedding) "
                "RETURN count(*)",
                rows=emb_rows,
            )
            print(f"  Wrote embeddings for {len(emb_rows)} entities.")

    if not text_units.empty:
        tu_emb = ldb.open_table("text_unit_text").to_pandas()[["id", "vector"]]
        text_units_with_emb = text_units.merge(tu_emb, on="id", how="left")
        emb_rows = [
            {"id": str(r["id"]), "embedding": [float(x) for x in r["vector"]]}
            for _, r in text_units_with_emb.iterrows()
            if isinstance(r["vector"], np.ndarray)
        ]
        if emb_rows:
            session.run(
                "UNWIND $rows AS row "
                "MATCH (t:TextUnit {id: row.id}) "
                "CALL db.create.setNodeVectorProperty(t, 'embedding', row.embedding) "
                "RETURN count(*)",
                rows=emb_rows,
            )
            print(f"  Wrote embeddings for {len(emb_rows)} text units.")

    if not community_reports.empty:
        cr_emb = ldb.open_table("community_full_content").to_pandas()[["id", "vector"]]
        cr_with_emb = community_reports.merge(cr_emb, on="id", how="left")
        emb_rows = [
            {"id": str(r["id"]), "embedding": [float(x) for x in r["vector"]]}
            for _, r in cr_with_emb.iterrows()
            if isinstance(r["vector"], np.ndarray)
        ]
        if emb_rows:
            session.run(
                "UNWIND $rows AS row "
                "MATCH (c:CommunityReport {id: row.id}) "
                "CALL db.create.setNodeVectorProperty(c, 'embedding', row.embedding) "
                "RETURN count(*)",
                rows=emb_rows,
            )
            print(f"  Wrote embeddings for {len(emb_rows)} community reports.")

    # Tombstone sweep — remove nodes from previous runs not in current index
    # -----------------------------------------------------------------------
    if entity_ids:
        print("  Tombstone sweep: removing stale entities...")
        session.run(
            "MATCH (e:Entity) WHERE NOT e.id IN $ids DETACH DELETE e",
            ids=entity_ids,
        )
    if community_ids:
        print("  Tombstone sweep: removing stale communities...")
        session.run(
            "MATCH (c:Community) WHERE NOT c.id IN $ids DETACH DELETE c",
            ids=community_ids,
        )
    if text_unit_ids:
        print("  Tombstone sweep: removing stale text units...")
        session.run(
            "MATCH (t:TextUnit) WHERE NOT t.id IN $ids DETACH DELETE t",
            ids=text_unit_ids,
        )
    if community_report_ids:
        print("  Tombstone sweep: removing stale community reports...")
        session.run(
            "MATCH (r:CommunityReport) WHERE NOT r.id IN $ids DETACH DELETE r",
            ids=community_report_ids,
        )

print("  Import complete.")
driver.close()
PYEOF

echo "==> Neo4j import complete."
echo "    Connect to ${NEO4J_URI} and verify:"
echo "      MATCH (e:Entity) RETURN e.type, count(*) ORDER BY count(*) DESC"
