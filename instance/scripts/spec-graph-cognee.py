import asyncio
import os
import pathlib
import pandas as pd
import cognee
from neo4j import GraphDatabase

# Configure output directories for GraphRAG compatibility
REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
GRAPHRAG_OUTPUT_DIR = REPO_ROOT / "instance" / "graphrag" / "output"
GRAPHRAG_OUTPUT_DIR.mkdir(parents = True, exist_ok = True)

async def export_cognee_to_parquet():
    """
    Exports Cognee's normalized graph from Neo4j into the Parquet format 
    expected by Microsoft GraphRAG's community detection pipeline.
    """
    neo4j_url = os.environ.get("NEO4J_URI", "bolt://localhost:7687")
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
    cognee_root = REPO_ROOT / "instance" / "graphrag" / ".cognee"
    cognee_root.mkdir(parents = True, exist_ok = True)
    cognee.config.system_root_directory = str(cognee_root)
    
    cognee.config.set_llm_provider("litellm")
    cognee.config.set_llm_model("anthropic/claude-3-5-sonnet-20240620") 
    cognee.config.set_llm_api_key(os.environ.get("ANTHROPIC_API_KEY"))
    cognee.config.set_embedding_provider("openai")
    cognee.config.set_embedding_model("text-embedding-3-small")
    cognee.config.set_embedding_api_key(os.environ.get("OPENAI_API_KEY"))
    
    neo4j_url = os.environ.get("NEO4J_URI", "bolt://localhost:7687")
    neo4j_user = os.environ.get("NEO4J_USERNAME", "neo4j")
    neo4j_password = os.environ.get("NEO4J_PASSWORD", "")
    
    cognee.config.set_graph_database_provider("neo4j")
    cognee.config.set_graph_db_config({
        "url": neo4j_url,
        "username": neo4j_user,
        "password": neo4j_password
    })
    
    print("==> Pruning existing Cognee state...")
    await cognee.prune()
    
    # 2. Add and Cognify
    targets = [
        REPO_ROOT / "00-vision",
        REPO_ROOT / "01-architecture",
        REPO_ROOT / "02-roadmap",
        REPO_ROOT / "03-research",
        REPO_ROOT / "instance" / "installed",
        REPO_ROOT / "instance" / "adrs",
    ]
    for target in targets:
        if target.exists():
            await cognee.add(str(target))
    
    ontology_path = REPO_ROOT / "00-vision" / "01-glossary.ttl"
    print(f"==> Running Cognee grounded extraction with: {ontology_path}")
    await cognee.cognify(ontology_file_path = str(ontology_path))
    
    # 3. Export to Parquet for GraphRAG
    print("==> Exporting Cognee graph to Parquet for GraphRAG community detection...")
    await export_cognee_to_parquet()
    
    print("==> Cognee pre-processing complete.")

if __name__ == "__main__":
    asyncio.run(main())
