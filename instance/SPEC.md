---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# SPEC.md — EposForge Documentation Maintenance Tooling

> Living Spec for Component 6 (Spec Graph) as implemented in this repo.
> Per the paired-change rule: any change to the tooling behavior in
> `instance/installed/06-spec-graph/` must update this file in the same commit.

---

## Purpose

Maintain the EposForge vision and architecture Markdown corpus as a
queryable knowledge graph. Cognee performs ontology-grounded extraction
from all Markdown files in the docs directories and writes normalized
entities and relationships into its embedded Kuzu graph + LanceDB
vector store, hosted inside the `dkr-cgnee-api` container. Microsoft
GraphRAG is retained only as an archived revival-only snapshot under
`instance/installed/06-spec-graph/graphrag/`; it is not part of the
active path and should not be used to infer current EposForge behavior.
Any MCP-compatible Dev Product (Gemini
CLI, Claude Code, Cursor, Goose, or equivalent) connects to the cognee
MCP server (`dkr-cgnee-mcp`, which proxies to `dkr-cgnee-api`) and gains
structured, graph-augmented memory of the full EposForge architecture
for natural-language-driven consistency checks, spec generation, and
ADR authoring.

This spec also defines conventions that clarify which docs are
architecture contracts versus repo-instance implementations.

---

## Component slot

This tooling implements **Component 6: Spec Graph** for the EposForge
repo itself. This is one of many possible Spec Graph implementations;
the slot contract is defined in
[../01-architecture/02-components/06-spec-graph.md](../01-architecture/02-components/06-spec-graph.md).
It is a concrete reference implementation of the pattern documented in
[../03-research/01-architecture/02-components/06-spec-graph/graphrag-neo4j-integration.md](../03-research/01-architecture/02-components/06-spec-graph/graphrag-neo4j-integration.md).

---

## Adapter metadata

Per [../01-architecture/00-adapter-pattern.md](../01-architecture/00-adapter-pattern.md)
and [../01-architecture/02-components/06-spec-graph.md](../01-architecture/02-components/06-spec-graph.md):

| Field | Value |
|---|---|
| `name` | `cognee-ontology-preprocessor` |
| `component` | `06-spec-graph` |
| `version` | `0.1.1` |
| `privacy_posture` | `local` (embedded Kuzu/LanceDB store inside `dkr-cgnee-api`) / `vendor-default` (inference during indexing) |
| `cost_hint` | free (embedded store) + metered (Azure Foundry default for indexing; Anthropic/OpenAI remain selectable profiles) |
| `capabilities` | ontology-grounded-extraction, entity-normalization, graph-query |
| `invocation_surface` | `cognee-sync` CLI at `instance/installed/06-spec-graph/cognee/sync/` (incremental, HTTP to `dkr-cgnee-api`); GraphRAG opt-in fallback at `instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh` |
| `status` | `experimental` |
| `query_languages` | cognee HTTP API (`/api/v1/recall`, `/api/v1/search`); natural language via cognee MCP (`dkr-cgnee-mcp`) |
| `projection_format` | hybrid (graph nodes/edges in embedded Kuzu + embeddings in LanceDB) |
| `rebuild_target` | per-file via cognee-sync (incremental); 15 minutes for the shelved GraphRAG fallback full-rebuild |
| `incremental_update` | true — `cognee-sync` provides git-diff-driven incremental sync |

---

## Adapter registry (repo instance)

Single source of truth for installed adapter status tracked in this repository.

| Adapter | FULFILLS_SLOT | Status | Invocation surface | Notes |
|---|---|---|---|---|
| `cognee-ontology-preprocessor` | `SPEC_GRAPH` | experimental | `epos-secrets uv run cognee-sync --added <files>` (see `cognee/sync/README.md`) | Default ontology-grounded extraction path (two containers proxy-mode, HTTP API, incremental). Stores KG in cognee's embedded Kuzu graph + LanceDB vector indexes on the `dkr-cgnee-api` volume. |
| `cognee-sync` | `SPEC_GRAPH` | experimental | `epos-secrets uv run cognee-sync --added/--modified/--deleted <files>` | Incremental git-diff-driven sync CLI (Phases 0–5 complete). Drives `dkr-cgnee-api` over HTTP; per-file `add + cognify`. |
| `microsoft-graphrag` | `SPEC_GRAPH` | shelved | `bash instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh` | Archived GraphRAG snapshot retained only for possible revival. Not part of the active path. |
| `neo4j-ce` | `SPEC_GRAPH` | shelved | `instance/installed/06-spec-graph/graphrag/scripts/import.sh` + Neo4j MCP | Archived GraphRAG target store only; not used by the active Cognee path. |
| `file-based-backlog` | `BACKLOG` | implemented, experimental | `bash instance/installed/13-backlog/file-based-backlog/scripts/{new-issue,lint-backlog,sweep-resolved,aggregate}.sh` | Local markdown backlog adapter with cross-repo aggregation and archive indexing |

Candidate adapters remain cataloged in
`../03-research/01-architecture/02-components/06-spec-graph/spec-graph.md` and are non-normative until listed
here as implemented.
These adapters fill Component 6 for THIS repo only. Other instances will pick
differently; see `../03-research/01-architecture/02-components/06-spec-graph/spec-graph.md` for the candidate catalog.

---

## Document classification convention

All architecture, implementation, and research documents should declare a
machine-readable classification block near the top.

Required fields:

- `doc_kind`: `architecture-contract` | `reference-implementation` | `candidate-research` | `operator-runbook`
- `scope`: `eposforge-pattern` | `repo-instance`
- `maturity`: `draft` | `experimental` | `approved` | `deprecated`
- `source_of_truth`: `yes` | `no`

Recommended placement:

- YAML frontmatter at file start, or
- a compact metadata table in the first major section.

Example (YAML frontmatter):

```yaml
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
```

---

## Script placement convention

Adapter scripts — hooks, runners, helpers — must live under:

`instance/installed/<component>/scripts/`

or, when a component has multiple adapters, under:

`instance/installed/<component>/<adapter>/scripts/`

The flat `instance/scripts/` directory is not permitted; nothing may live
there. This convention is enforced by
`instance/installed/09-source-control-ci/github-and-actions/scripts/check-installed-scripts-layout.sh`,
which runs from the `pre-commit` hook fragment owned by `09-source-control-ci`
and from the `installed-scripts-layout` GitHub Actions workflow.

Git hooks themselves follow the same rule: each adapter places per-hook
fragments at
`instance/installed/<component>/scripts/hooks/<git-hook-name>` and a single
composer at
`instance/installed/09-source-control-ci/github-and-actions/scripts/install-hooks.sh`
discovers them and writes dispatchers into `.git/hooks/`.

---

## Observable behavior

1. **Trigger:** operator runs `epos-secrets uv run cognee-sync --added/--modified/--deleted <files>` (default Cognee incremental sync, from `instance/installed/06-spec-graph/cognee/sync/`), or — opt-in only — `bash instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh` for the shelved GraphRAG full-rebuild fallback. CI may trigger cognee-sync via a scheduled post-receive job. At startup, cognee-sync validates routing profile; when `COGNEE_REQUIRE_AZURE_ROUTING=1`, non-Azure providers are rejected before any API calls.

2. **Wipe stage (fallback only):**
   - The GraphRAG fallback's rebuild script clears Neo4j graph projection
     state, prunes Cognee state, and removes generated GraphRAG `output/`
     and `cache/` artifacts.
   - The default Cognee path does **not** wipe — cognee-sync is incremental;
     update = `delete_document` + `add_file` per file.

3. **Indexing / extraction:**
   - Default path: cognee-sync `POST /api/v1/add`s each file to
     `dkr-cgnee-api`, then `POST /api/v1/cognify` runs ontology-grounded
     extraction (seeded by `00-vision/01-ontology.ttl`) and writes normalized
  entities and relationships into cognee's embedded Kuzu graph + LanceDB
  vector store. Before `cognify`, cognee-sync runs the Component 10 budget
  preflight gate; deny exits with status 4. After successful `cognify`,
  cognee-sync records budget usage and emits a Component 11
  `adapter.invoked` token-usage event.
   - Opt-in fallback path (`--graphrag`): GraphRAG reads all `*.md` files
     matching
     `^(00-vision|01-architecture|02-roadmap|03-research|instance/installed|instance/adrs)/.*\.md$`
     from the repo root and produces Parquet outputs under
     `instance/installed/06-spec-graph/graphrag/output/`.

4. **Import / projection to query store:**
   - Default path: cognee writes directly into its own embedded Kuzu/LanceDB
     store on the `dkr-cgnee-api` volume; no separate import step.
   - Opt-in GraphRAG path: the import script reads Parquet files and loads
     all records into the local Neo4j instance at `NEO4J_URI`.
   The default path is incremental (per-file diff). The GraphRAG fallback
   follows full nuke-and-reproject semantics.

5. **Query surface:** Cognee's MCP server (`dkr-cgnee-mcp`, in proxy mode
   to `dkr-cgnee-api`) exposes `recall` / `remember` / `forget` over SSE
   to any MCP-compatible Dev Product. Scripts can hit the HTTP surface
   directly at `https://cognee-api.grace.lan/api/v1/{recall,search,...}`.
   Operators can issue instructions such as:
   - "Find all adapters that fulfill the Spec Graph slot."
   - "List all principles that govern the Router component."
   - "Generate a new ADR for adding a second Dev Product Adapter."

6. **Rebuild flag:** The `instance/installed/06-spec-graph/scripts/hooks/post-commit`
   hook fragment (composed into `.git/hooks/post-commit` by the SCM/CI adapter's
   `install-hooks.sh`) writes `instance/installed/06-spec-graph/.needs-rebuild`
   when doc files change. This is a non-blocking reminder; it does not trigger
   cognee-sync itself.

7. **Layout/policy enforcement in CI:**
   - The doc lint checker validates adapter folder layout under
     `instance/installed/`.
   - The checker enforces script placement so adapter implementation scripts
     live in adapter-local `scripts/` folders.

---

## Inputs / outputs

### Inputs

| Input | Description | Bounds |
|---|---|---|
| Markdown files | `*.md` + `*.ttl` in tracked docs roots | Any valid Markdown / Turtle |
| `COGNEE_API_URL` | Base URL of `dkr-cgnee-api` (default Cognee path) | Required for cognee-sync; injected by `epos-secrets` |
| `COGNEE_API_TOKEN` | Bearer token for `dkr-cgnee-api` | Optional (anonymous if absent) |
| `INFERENCE_PROVIDER` | Active provider profile (`azure-foundry`, `anthropic`, `openai`) | If `COGNEE_REQUIRE_AZURE_ROUTING=1`, must be `azure-foundry` |
| `COGNEE_REQUIRE_AZURE_ROUTING` | Fail-closed routing guardrail for sync startup | Optional (`1` enforces Azure-only) |
| `LLM_MODEL` / `EMBEDDING_MODEL` | Active completion/embedding deployment model names | For Azure profile, both must start with `azure/` |
| `AZURE_API_BASE` / `AZURE_API_VERSION` | Azure Foundry endpoint/version for Azure profile validation | Required when Azure routing is selected/enforced |
| `INFERENCE_BUDGET_ENFORCE` | Toggle for Component 10 budget preflight + usage accounting | Default enabled for cognify runs |
| `LLM_API_KEY` / `ANTHROPIC_API_KEY` | Anthropic API key for extraction | Required on the API container (`dkr-cgnee-api`) for cognify; not consumed by cognee-sync directly |
| `OPENAI_API_KEY` | OpenAI API key for embeddings | Required for GraphRAG fallback (`--graphrag`) only |
| `NEO4J_URI` / `NEO4J_USERNAME` / `NEO4J_PASSWORD` | Neo4j connection | Required for GraphRAG fallback only; not used on the default Cognee path |
| `--graphrag` | Rebuild flag selecting GraphRAG fallback extraction path | Optional |

### Outputs

| Output | Description |
|---|---|
| Cognee embedded store on `dkr-cgnee-api` | Authoritative KG: Kuzu graph (`cognee_graph_ladybug`) + LanceDB vector indexes under `./data/cognee_system/databases/` |
| `instance/installed/06-spec-graph/cognee/sync/.cognee-state.db` | SQLite state store: `file_path → (dataset_id, data_id, content_hash)` committed to source |
| `instance/installed/06-spec-graph/graphrag/output/*.parquet` | Fallback only: Entity / Relationship / Community / TextUnit tables |
| Neo4j graph | Fallback only: target of the opt-in GraphRAG import |
| `instance/installed/06-spec-graph/.needs-rebuild` | Flag file set by post-commit hook |

---

## Dependencies

| Dependency | Version | Role | Path |
|---|---|---|---|
| `dkr-cgnee-api` container | `cognee/cognee:main` + local Dockerfile | Hosts the authoritative KG; runs cognify | default |
| `dkr-cgnee-mcp` container | `cognee/cognee-mcp:main` + `Dockerfile.mcp` | MCP/SSE surface in proxy mode → `dkr-cgnee-api` | default |
| `cognee-sync` (uv project) | local — `instance/installed/06-spec-graph/cognee/sync/` | Incremental git-diff-driven sync CLI | default |
| Anthropic API | current | LLM inference during cognify | default |
| Python | 3.13 (cognee-sync); 3.10–3.12 (GraphRAG) | Runtime | default / fallback |
| `graphrag` (pip) | 3.0.9 | Indexing pipeline | fallback only |
| `neo4j` (pip) | 5.x | Neo4j Python driver | fallback only |
| Neo4j Community Edition | ≥ 5.11 | Graph store + native vector indexes | fallback only |
| APOC plugin | compatible | Neo4j stored procedures | fallback only |
| OpenAI API | current | Embedding generation | fallback only |
| `pandas`, `pyarrow` (pip) | current | Parquet reading | fallback only |
| `lancedb` (pip) | 0.24.3 | Vector store reader (transitively via graphrag) | fallback only |

---

## Non-functional bounds

| Bound | Value |
|---|---|
| Sync target (default) | per-file via cognee-sync; cognify completes in seconds-to-minutes per touched file |
| Rebuild target (fallback) | < 15 minutes full GraphRAG rebuild on the current EposForge corpus |
| Privacy (graph) | `local` — cognee's embedded Kuzu/LanceDB store lives on the API container's volume and is never sent to a vendor (default path); Neo4j on operator's machine (fallback) |
| Privacy (inference) | `vendor-default` for public docs; use Ollama or another local provider for private content |
| Incremental update | Supported on the default path (cognee-sync); not supported by the GraphRAG fallback (full rebuild required) |
| Concurrent operators | Bulk cognify is concurrency-fragile (SQLite contention); serialize bulk operations against `dkr-cgnee-api`. Per-file incremental updates are safe. |

---

## Versioning policy

- `0.x` versions are experimental. Breaking changes (schema changes,
  script renames, settings.yaml key changes) increment the minor
  version and update this spec in the same commit.
- Moving to `1.0` requires successful end-to-end validation on a
  non-trivial corpus and a passing CI job.

---

## Test partitions (black-box)

The following equivalence classes and boundary values can be derived
from this spec without reading implementation code:

| Partition | Input | Expected outcome |
|---|---|---|
| Happy path (default) | `dkr-cgnee-api` healthy, `COGNEE_API_URL` reachable, valid Markdown | cognee-sync uploads + cognifies; exit 0 |
| Happy path (fallback) | All env vars set, Neo4j running, valid Markdown | GraphRAG indexes + imports; exit 0 |
| Unreachable API | `dkr-cgnee-api` down or `COGNEE_API_URL` wrong | cognee-sync raises an HTTP error and exits non-zero |
| Missing Azure route vars | `COGNEE_REQUIRE_AZURE_ROUTING=1` with missing/invalid Azure routing env | cognee-sync exits non-zero before API calls, with validation error |
| Missing extraction key | active provider key unset on `dkr-cgnee-api` | cognify fails on the API container (logged); cognee-sync upload still succeeds but no KG nodes are created. GraphRAG fallback `index.sh` exits 1 with error message |
| Missing embeddings key | `OPENAI_API_KEY` unset | No effect on default path (cognee uses its configured embedder). GraphRAG fallback `index.sh` exits 1 with error message |
| Missing Neo4j vars | `NEO4J_PASSWORD` unset | No effect on default path. GraphRAG fallback `import.sh` exits 1 with error message |
| No output dir | `instance/installed/06-spec-graph/graphrag/output/` absent | GraphRAG fallback `import.sh` exits 1 with error message |
| No venv | `instance/installed/06-spec-graph/graphrag/.venv/` absent | GraphRAG index/import scripts exit 1 with setup instructions |
| Zero matching files | All docs dirs empty | cognee-sync no-ops; GraphRAG produces empty Parquet; Neo4j graph has 0 entities |
| Large corpus | > 500 Markdown files | Default path: per-file incremental keeps each invocation fast. GraphRAG fallback completes within `rebuild_target` (15 min) |

---

## Paired-change rule

Changes to the following files require updating this `SPEC.md` in the
same commit:

- `instance/installed/06-spec-graph/graphrag/settings.yaml` (any key that changes observable behavior)
- `instance/installed/06-spec-graph/graphrag/scripts/rebuild.sh`
- `instance/installed/06-spec-graph/cognee/sync/src/cognee_sync/` (cognee-sync CLI core)
- `instance/installed/06-spec-graph/graphrag/scripts/index.sh`
- `instance/installed/06-spec-graph/graphrag/scripts/import.sh`
- `instance/installed/06-spec-graph/cognee/scripts/cognee.py`
- `instance/installed/09-source-control-ci/github-and-actions/scripts/check-doc-classification.py` (regulated directories, exempt patterns, or required fields)
- `instance/installed/09-source-control-ci/github-and-actions/scripts/generate-installed-index.py` (adapter crawl logic or index schema)
- `.github/workflows/doc-lint.yml` (trigger paths or job behaviour)
- `instance/installed/06-spec-graph/scripts/hooks/post-commit`

