# EposForge / GEA Architecture Discussion Capture (2026-06)

**Purpose**: Self-contained summary of the full conversation for persistence across chats, fresh starts, or handoff. Captures problems, insights, models, decisions, and open threads.

**Date of capture**: 2026-06-28 (conversation evolved over multiple turns starting from spec-graph confusion).

## 1. Original Trigger (Spec Graph & Living Spec Confusion)
User flagged issues with `01-architecture/02-components/spec-graph.md`:
- Is the live Cognee "eposforge graph" (via MCP, `eposforge-sync` dataset) the reference implementation of Component 6 (Spec Graph)?
- The graph ingests a broad corpus (architecture contracts, research, instance docs, etc.) via ontology-grounded extraction (Kuzu + LanceDB).
- Does it contain "more than the spec"? Yes — rich entities/relations/summaries, not raw Living Specs only.
- Is the Living Spec (Component 2) properly implemented? Contract exists (durable per-deliverable spec with paired-change rule, projectable to graph), but practice is distributed (component contracts + adapter cards). No formal Living Spec Adapter yet (Phase C territory). Paired-change is selective.
- For adopters like GEA: How to use the upstream EposForge Cognee graph (for pattern) while maintaining its own graph (for current implementation state)? Should GEA implement Living Spec first?

Key contract reminder (from spec-graph.md): Living Specs on disk are source of truth. Graph is a **projection**. "If the graph and the specs ever disagree, the specs win and the graph is re-projected." Indexing post-merge via Source Control + CI. Must be rebuildable. `incremental_update` is a required adapter metadata field.

## 2. User's Deeper "Smells" (Systemic Issues)
User listed 7 core problems:
1. Backlog *system structure* (schema, load rules, aggregation, roles) belongs in the Spec Graph. Individual backlog *items* (EF-/GEA- text) should not.
2. Backlog should be a first-class KG (even if file-based backend). Agents should use GraphRAG-style tooling over it for traversal/dependencies (not just file RAG).
3. GEA (adopter) needs to leverage the same projection system for grounding dev on EposForge + GEA's current state.
4. Smell: EposForge Cognee graph includes far more than Living Specs.
5. Smell: Living Spec contract assumes single `SPEC.md` per deliverable, but EposForge and GEA are effectively entire distributed living specs.
6. Layering failure: GEA and IAC are for *eposforge platform factory implementation*. Product repos are for product factory. No single repo should "implement EposForge in its entirety." This is underspecified.
7. GEA conflation: GEA is "kind of like the platform factory spec." The actual implementation is srv-docker-hp + other grace.lan components/config/IaC. "EposForge adopter's implementation" mixes the two.

Additional context:
- EposForge = pattern + reference implementations (in `instance/`).
- GEA = adopter platform factory (with GEA- backlog items, private visibility in aggregation).
- Existing partials: backlog adapter has `role = "substrate"` vs "product"; `aggregate.sh` handles private roots (writes to first private like GEA); ontology distinguishes PlatformFactory/ProductFactory; platform vs product phase roadmaps.

## 3. Encapsulation & Layout Problems (GEA's eposforge/ Folder)
Detailed inspection:
- GEA repo root has `eposforge/` (intended single container per Adapter Layout Mirror standard): backlog/, router/gastown/ (config+scripts), secrets-key-management/, backup-resilience/.
- But implementation bleeds heavily:
  - GEA top-level: `00-north-star/`, `01-reference-architecture/`, `03-standards/`, `04-runbooks/`, `07-project-portfolio/`, `hardware/`, `servers/containers/` (actual docker-compose, Dockerfile, entrypoints for dkr-gstwn-01/Gas Town, cognee, gitea, etc.), `skills/` (gastown-*), `services/`, `instance/`.
  - GEA README positions the *whole repo* as source of truth for servers/containers/networks/storage.
  - Runtime bleed: ~30 scattered `eposforge/` copies in docker volume mounts (under dkr-gstwn-01/deacon/dogs/{alpha,bravo,...}, iac/, refinery, events/, runtime/, etc.). Mostly minimal (backlog mounts for agents/mayor).
- Both EposForge and GEA use numbered folders for knowledge org (EposForge: 00-vision, 01-architecture, 02-roadmap, 03-research, 04-standards + subs; GEA: 00-north-star, 01-reference-architecture, 03-standards, 04-runbooks, 07-project-portfolio, 99-archive + subs).
- Inside `eposforge/` bucket: clean stable names (no numbers), per standard.
- Existing standard (04-standards/07-adapter-layout-mirror/adapter-layout-mirror.md): Mandates `eposforge/` container for adopters (framework uses `instance/` to avoid self-dupe). Uses stable node names from knowledge tree. Explicitly: "This standard does not govern an adopter's own application source layout." Prescribes backlog data location and .code-workspace for discovery. Purpose: tooling uniformity (aggregate, Spec Graph).

Adapter Layout Mirror is too narrow for full single-repo platform adopters like GEA.

## 4. Key Proposals & Evolution of Thinking
- **Broader adopter repo layout standard needed**: For "single repo like GEA." Current mirror only covers the adopted slice. Need guidance on overall shape while distinguishing platform vs product.
- **Targeted (not total) symmetry/mirroring**:
  - Strong inside `eposforge/` bucket (stable component names).
  - Light for high-level knowledge (similar `NN-` prefixes where natural for humans).
  - Runtime/LAN elements (container names, mounts) for human recognition.
  - Do *not* force full repo isomorphism (different purposes: framework = pattern docs + refs; GEA = full platform factory + IaC + own decisions).
- **Mapping layer**:
  - Initially separate idea.
  - Refined: The **Spec Graph + ontology/taxonomy *is* the mapping**.
  - Ontology (ef:fulfillsSlot, ef:adoptsFrom, ef:implements, etc.) provides shared vocabulary/schema.
  - Graphs contain instantiated relationships (e.g., GEA gastown adoptsFrom EposForge reference).
  - Already partials: adoption-links.ttl, reference-implementations.ttl, adopter-recall.py (sanitizes paths per EF-011, adds maturity tags per EF-012).
- **Multi-graph architecture** (core model):
  - One graph per scope: EposForge (pattern + references), GEA (adoption + implementation), IAC, each product repo.
  - Agents get access to whichever graph(s) needed for the task (via MCP / datasets).
  - Benefits: graphrag (entities/relations/communities) per scope, over pure file RAG.
  - Connection mechanism: Shared ontology (common language) + explicit mappings ingested + agent orchestration (query relevant graph(s), synthesize using ontology relations).
  - Not automatic federation; deliberate scoping + synthesis.
  - Cognee supports `datasets` param in recall/search. Current deployment: one instance, `eposforge-sync` dataset (adopters use wrappers). Future: per-scope datasets or instances.
  - Adopter-recall.py pattern generalizes.
- **Agent access model** (critical clarification):
  - Ideal: Agents route primarily/exclusively through Cognee MCP / relevant Spec Graphs. No broad raw file access to EposForge, GEA, or other repos (security, isolation, control via sandbox + agent policy + tool transport).
  - Current reality: Agents often have wide filesystem access (causes bleed, path leaks, dual search).
  - This contradicts "make disk great for file-based RAG" if it implies agents browse freely.
  - File-based RAG: Useful in narrow scopes or for humans/operators. Disk layout should support it for quality projection and human navigation.
  - Agents: Graph-first for knowledge. Instructed to prefer MCP recall for discovery/relationships. Direct file tools limited/narrow.
  - "Don't search twice": Solve via reliable graph + mappings, not by giving agents broad disk access.
- **Disk vs Graph canonicality**:
  - Disk/Living Specs (structured files, frontmatter, etc.) = source of truth.
  - Graph = derived projection for reasoning.
  - Problem: Incremental sync (`cognee-sync`) not fully reliable → inconsistencies. Bulk rebuild is safety net.
  - Agents must not rely on graph for "does X exist on disk?" — disk wins.
  - Layout on disk must be discoverable (for sync quality, humans, narrow file access).
- **Physical mirroring on disk + LAN**:
  - Helps human operators match implementation to EposForge model.
  - Improves extraction quality into local graphs (recognizable structure → better entities/relations).
  - Complements (does not replace) semantic mapping in graphs.
  - Examples: `eposforge/` bucket structure, numbered sections, component-flavored container names/mounts.
  - Scattered runtime copies (in docker volumes) are often minimal data mounts for agents — intentional for isolation/performance, not full mirrors.
- **Overall target layering** (from boundaries note, extended):
  1. **Pattern + References** (EposForge framework repo) → feeds canonical EposForge graph.
  2. **Backlog System Mechanics** → projected into Spec Graph.
  3. **Backlog Items** → own KG. Use an independent **file-based** backlog graph so agents can apply GraphRAG techniques directly. No Cognee dependency — the core is parseable markdown + a lightweight graph layer (explicit links become edges). This enables portability (can be extracted as a standalone open-source project with minimal/no heavy deps for others to adopt for any tracking use case).

   **Effectiveness vs full Cognee GraphRAG**: The backlog schema is deliberately semi-structured (explicit `## Issue ID — Title`, `ID:`, `Status:`, `Depends on:`, `Blocks:`, `Theme:`, etc.). Markup provides a high-quality, deterministic skeleton graph for free (nodes = issues with attributes, directed edges from dependencies/blocks). You then layer GraphRAG on top:
   - Graph algorithms on the explicit structure (traversal, critical path, community detection by Theme).
   - Vector embeddings + LLM summarization on item text or clusters (thematic reports, blocking analysis, "what's this related to?").
   - This can be *as effective or better* than Cognee for backlog-specific needs because links are explicit and intended, not LLM-inferred (less hallucination on structure). Cognee excels on unstructured narrative docs; here the structure reduces the need for heavy extraction. It is not "solely via markup" — markup gives the reliable graph backbone; GraphRAG adds intelligence where needed. Trade-off: less automatic discovery of purely implicit relations in free-text notes, but gains determinism, lower cost, and zero Cognee lock-in.

   **Where the actual GraphRAG capability lives**: The MD files contain the data and explicit graph structure (via markup). The capability lives in **separate tooling, skills, or processors** that read the files:
   - Parsing logic turns the structured markdown into a real graph (nodes, edges, attributes, communities).
   - Graph algorithms + optional LLM calls provide the RAG features (summarization, semantic search over the graph, thematic insights).
   - This is exposed to agents as callable tools/skills (e.g., a dedicated "backlog-graph" skill or extension of existing aggregate/portfolio tools).
   - Agents (which don't have GraphRAG built-in) invoke these tools to get graph-augmented answers.
   - For portability: the data stays pure markdown files; the GraphRAG layer is optional, pluggable tooling that can live in a small independent package or skill.

  4. **Adopter Implementation**:
     - GEA repo: living spec of platform adoption (adopted components, custom adapters, decisions, GEA- items).
     - Concrete substrate: srv-docker-hp IaC, compose, volumes, Gas Town, host config.
     - Product repos: separate.
  - Spec Graphs (and the separate backlog graph) are *tools used by* the factories.

Existing partial mechanisms:
- Platform vs Product roadmaps and ontology classes.
- Substrate/product roles in backlog.
- Private root handling in aggregation (EF-047).
- adopter-recall.py for controlled upstream access.
- Research-mirror and adapter-layout-mirror standards.

## 5. Current Pain Points & Contradictions
- GEA `eposforge/` encapsulation fails (bleed everywhere + LAN).
- Graph vs disk drift (incremental sync incomplete; unclear canonical for agents).
- Agents often have broad file access today (violates ideal isolation; contradicts Cognee MCP routing).
- Layout not yet optimized for both human discoverability *and* high-quality projection without relying on agents having raw files.
- No full multi-graph + mapping practice codified.
- Terminology overload around "GEA" and "adopter implementation."

## 6. Open Decisions & Next Actions (from discussion)
**Open**:
- Exact corpus for main EposForge Spec Graph (exclude backlog items, research?, plans?).
- Backlog items as dedicated KG (GraphRAG revival? separate cognee dataset? Beads integration?).
- Agent grounding instructions: "upstream first for pattern, local for state"; which MCPs/datasets per task.
- Deployment for multi-graphs: single cognee with many datasets vs per-scope instances.
- How much mapping data in upstream graph vs only in adopter graphs.
- Living Spec contract updates for distributed corpora.
- Terminology: "Adopter Platform Spec (GEA repo)" vs "Platform Instance (concrete LAN)".
- Sync reliability: verification steps, easy agent-triggered rebuilds, "graph knows about disk" checks.
- Precise layout guidelines for adopter repos (bucket + knowledge sections + runtime naming).

**Prioritized capture/implementation ideas** (from turns):
1. Explicit ingestion boundaries (update bulk-rebuild.sh, update-spec-graph skill, post-commit hook, CORPUS section in cognee.md). Exclude backlog items by default from main graph.
2. "Repository roles & ownership" section (in 00-vision or 01-architecture). Leverage existing substrate/product language.
3. Backlog-KG prototype.
4. Update Living Spec docs for distributed reality.
5. Terminology fixes in ontology, vision, EF-011/EF-012 notes.
6. Generalize adopter-recall wrappers; update runbooks for multi-graph access.
7. Strengthen Adapter Layout Mirror (or companion) with targeted mirroring levels + file-RAG discoverability principles.
8. Codify agent policy/grounding: graph/MCP primary; disk canonical but accessed via projection or narrow tools.
9. Improve cognee-sync: better validation, staleness detection, full rebuild UX.
10. Persist physical mirroring recommendations for humans + extraction (in layout standard).
11. Ontology enhancements for clearer cross-scope mappings.
12. Per-scope dataset/instance bootstrap for GEA/IAC/products.
13. Validation via recall probes, portfolio review, operator walkthroughs.

See also: EF-011, EF-012 (recall quality), backlog component, platform/product phases, instance/backlog/file-based-backlog.md, aggregate.sh, cognee.md, adopter-recall.py, 04-standards/07-adapter-layout-mirror, 00-vision/01-ontology.ttl, boundaries-layers-2026-06.md (this evolved from), preferred-mode-adoption-plan.md.

## 7. References to Key Existing Files
- `01-architecture/02-components/spec-graph.md` (projection contract).
- `04-standards/07-adapter-layout-mirror/adapter-layout-mirror.md` (narrow bucket standard).
- `00-vision/01-ontology.ttl` + adoption-links.ttl (mapping vocabulary).
- `instance/spec-graph/cognee/` (cognee.md, sync/, adopter-recall.py, bulk-rebuild.sh).
- `docs/boundaries-layers-2026-06.md` (early capture; this file supersedes/extends it).
- GEA-specific: `GraceEnterprisesArchitecture/eposforge/`, servers/, hardware/, etc. (examples of bleed).
- Backlog: `instance/backlog/`, `backlog/file-based-backlog/scripts/aggregate.sh`.

**Phase 0 status (tracked by EF-056)**: Design captured; Phase 0 items created and first related backlog-tooling work (EF-046/047) advanced. Draft edits to component/adapter docs have been resolved into clean target-shape language (see the three maintained files + this capture). The four files remain the SSoT for the evolution state. Existing pieces (file-based schema + aggregate/portfolio-review) are foundation and are being incrementally enhanced via the EF- items.

## 8. Status & Usage
This file + `docs/boundaries-layers-2026-06.md` + the standards above contain the captured thinking. Use for:
- Fresh chat handoff.
- Implementation plan (see open actions above).
- Updating standards (e.g., expand layout mirror, add multi-graph guidance).
- Agent policy / skill development.

**Model is not final** — discussion evolved from "narrow fixes" to "multi-graph + ontology-as-mapping + targeted mirroring + graph-first agent access."

**Forward plan (zoomed out)**: See `docs/implementation-plan-eposforge-gea-architecture.md` (updated to use the repo's own strangler fig pattern for incremental rollout). This avoids losing track of the large scope by treating the evolution itself as a tracked strangler migration in the backlog + regular portfolio reviews. Track via EF- items, the four files, and visibility mechanisms.

Cross-cutting: Follow EposForge's AGENTS.md / SKILL.md / agent-coding-guidelines patterns for all agent/skills design work on the backlog graph. Plan to fill gaps in that guidance. Bake strangler fig concepts (Migration, LEGACY_SHAPE_OF, TARGET_SHAPE_OF, visibility of debt, etc.) into the backlog semantic layer (schema/fields) so agents can use the GraphRAG to implement strangler migrations especially well.

Next practical step (recommended): Merge key sections into a living design doc under 01-architecture or 04-standards, then break actions into EF- backlog items. Start with Phase 0 in the actual backlog.

**AGENTS.md pattern (applicable to backlog graphrag)**:
EposForge uses root `AGENTS.md` as the single source of truth for agent instructions in this repo and (by design) in adopting repos. Tool-specific files are thin pointers. Behavioral principles are formalized in the adopted standard `04-standards/08-agent-coding-guidelines/`.

Unlike SKILLS.md (which is a per-skill structured descriptor with "when to use / steps"), AGENTS.md provides repo-level global guidance + pointers to standards.

For the independent file-based backlog graph: Directly applicable. AGENTS.md can (and should) instruct agents on proper usage:
- Prefer dedicated backlog graph tools/skills over raw multi-repo file reads.
- Use the explicit markup for graph access.
- Reference the independent graph (separate from main Spec Graph / Cognee).
- How to invoke GraphRAG capabilities provided by the tooling layer.

For a portable standalone "backlog graphrag" project: Including an AGENTS.md (or minimal equivalent) would make it agent-friendly out of the box, telling adopters' agents how to interact cleanly with the graph tools. This complements the SKILL.md format for any specific GraphRAG skills. It aligns with EposForge's pattern for adopters. The standard already contemplates adopting repos following the AGENTS.md SSoT model.