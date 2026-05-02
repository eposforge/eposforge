import asyncio
import os
import pathlib
import pandas as pd
import cognee
from neo4j import GraphDatabase

# Configure output directories for GraphRAG compatibility
REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent.parent.parent.parent
GRAPHRAG_OUTPUT_DIR = REPO_ROOT / "instance" / "installed" / "06-spec-graph" / "graphrag" / "output"
GRAPHRAG_OUTPUT_DIR.mkdir(parents = True, exist_ok = True)

async def export_cognee_to_parquet():
    """
    Exports Cognee's normalized graph from Neo4j into the Parquet format 
    expected by Microsoft GraphRAG's community detection pipeline.
    """
    neo4j_url = os.environ.get("NEO4J_URI", "bolt://localhost:7688")
    neo4j_user = os.environ.get("NEO4J_USERNAME", "neo4j")
    neo4j_password = os.environ.get("NEO4J_PASSWORD", "")
    
    driver = GraphDatabase.driver(neo4j_url, auth = (neo4j_user, neo4j_password))
    
    with driver.session() as session:
        # 1. Export Entities
        print("  Exporting entities...")
        # Note: Cognee uses 'Entity' label by default. We map its properties to GraphRAG's expected schema.
        result = session.run("""
            MATCH (e:Entity)
            RETURN e.id AS id, e.name AS title, e.type AS type, e.description AS description
        """)
        entities_df = pd.DataFrame([dict(record) for record in result])
        if not entities_df.empty:
            entities_df.to_parquet(GRAPHRAG_OUTPUT_DIR / "entities.parquet")
            print(f"    Wrote {len(entities_df)} entities to entities.parquet")

        # 2. Export Relationships
        print("  Exporting relationships...")
        result = session.run("""
            MATCH (src:Entity)-[r]->(tgt:Entity)
            RETURN id(r) AS id, src.name AS source, tgt.name AS target, 
                   type(r) AS type, r.description AS description, 
                   coalesce(r.weight, 1.0) AS weight
        """)
        rels_df = pd.DataFrame([dict(record) for record in result])
        if not rels_df.empty:
            rels_df.to_parquet(GRAPHRAG_OUTPUT_DIR / "relationships.parquet")
            print(f"    Wrote {len(rels_df)} relationships to relationships.parquet")
            
    driver.close()

async def main():
    # 1. Setup Cognee configuration
    cognee_root = REPO_ROOT / "instance" / "installed" / "06-spec-graph" / "cognee" / ".cognee"
    cognee_root.mkdir(parents = True, exist_ok = True)
    cognee.config.system_root_directory = str(cognee_root)
    
    cognee.config.set_llm_provider("anthropic")
    cognee.config.set_llm_model("claude-sonnet-4-5")
    cognee.config.set_llm_api_key(os.environ.get("ANTHROPIC_API_KEY"))
    cognee.config.set_llm_config({"llm_args": {"max_tokens": 16384}})
    cognee.config.set_embedding_provider("fastembed")
    cognee.config.set_embedding_model("BAAI/bge-small-en-v1.5")
    cognee.config.set_embedding_dimensions(384)
    
    neo4j_url = os.environ.get("NEO4J_URI", "bolt://localhost:7688")
    neo4j_user = os.environ.get("NEO4J_USERNAME", "neo4j")
    neo4j_password = os.environ.get("NEO4J_PASSWORD", "")
    
    cognee.config.set_graph_database_provider("neo4j")
    cognee.config.set_graph_db_config({
        "graph_database_url": neo4j_url,
        "graph_database_username": neo4j_user,
        "graph_database_password": neo4j_password
    })
    
    print("==> Pruning existing Cognee state...")
    cognee.prune()
    
    # 2. Add and Cognify
    search_roots = [
        REPO_ROOT / "00-vision",
        REPO_ROOT / "01-architecture",
        REPO_ROOT / "02-roadmap",
        REPO_ROOT / "03-research",
        REPO_ROOT / "instance" / "installed",
        REPO_ROOT / "instance" / "adrs",
    ]
    doc_files = []
    for root in search_roots:
        if root.exists():
            doc_files.extend(root.rglob("*.md"))
            doc_files.extend(root.rglob("*.ttl"))
    for f in doc_files:
        await cognee.add(str(f))
    
    ontology_path = REPO_ROOT / "00-vision" / "01-glossary.ttl"
    print(f"==> Running Cognee grounded extraction with: {ontology_path}")
    await cognee.cognify(ontology_file_path = str(ontology_path))
    
    # 3. Export to Parquet for GraphRAG
    print("==> Exporting Cognee graph to Parquet for GraphRAG community detection...")
    await export_cognee_to_parquet()
    
    print("==> Cognee pre-processing complete.")

if __name__ == "__main__":
    asyncio.run(main())
