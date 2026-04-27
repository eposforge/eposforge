# GraphRAG workspace — EposForge Spec Graph

This directory is the Microsoft GraphRAG project that indexes the
EposForge vision and architecture Markdown files and projects them
into a Neo4j knowledge graph (Component 6: Spec Graph).

See [03-research/06-spec-graph/graphrag-neo4j-integration.md](../03-research/06-spec-graph/graphrag-neo4j-integration.md)
for the full architecture and setup walkthrough.

---

## Quick start

```bash
# 1. Create and activate a Python virtual environment (Python 3.11–3.13)
python -m venv .venv
source .venv/bin/activate        # Linux / macOS
# .venv\Scripts\activate         # Windows

# 2. Install dependencies (pinned to tested version)
pip install 'graphrag==3.0.9' neo4j pandas pyarrow

# 3. One-time init: generates default prompts in prompts/
#    The custom prompts already in prompts/ override the defaults.
#    --force is required in GraphRAG 3.x to generate the new config layout.
graphrag init --root . --force

# 4. Set your API keys
export ANTHROPIC_API_KEY=your-anthropic-key
export OPENAI_API_KEY=your-openai-key        # used for embeddings
export NEO4J_URI=bolt://localhost:7687
export NEO4J_USERNAME=neo4j
export NEO4J_PASSWORD=your-neo4j-password

# Alternative: use Gemini for both completion and embeddings by
# uncommenting the Gemini blocks in settings.yaml and setting:
# export GEMINI_API_KEY=your-gemini-key

# 5. Index all Markdown files and import into Neo4j
cd ..                            # repo root
bash scripts/spec-graph-rebuild.sh
```

> **Note:** The first index run creates `output/lancedb/` (the vector
> store). This directory is gitignored and will be recreated on the next
> rebuild if deleted.

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
