# Boundaries & Layers (Spec Graph, Backlog, Adopters) — 2026-06 capture

**Note**: This was an early capture. The full, evolved discussion (including multi-graph architecture, mapping as ontology/graph, agent access model, disk vs graph canonicality, targeted mirroring, and the primary adopter encapsulation details) is now in the comprehensive file:

`docs/adopter-architecture-discussion-capture.md`

This file is the recommended starting point for handoff or fresh chats. It supersedes and extends this note.

---

Short note to externalize the smells and proposed model. Source of the discussion: user + spec-graph.md confusion.

## Condensed problems

1. Backlog *mechanics* (schema, load rules, aggregation, roles, how file-based works) belong in the eposforge Spec Graph. Individual EF- (or adopter-scoped ID) item text does not.
2. Backlog needs to be a first-class queryable KG for agents (file-based backend is acceptable). GraphRAG (or equivalent) is the natural tool for traversing the work-item corpus + dependencies.
3. Adopters (e.g. the primary adopter) must be able to run the identical projection machinery against (a) upstream EposForge pattern + (b) their local adoption state docs.
4. Current cognee "eposforge graph" ingests far more than Living Specs (research, plans, backlog items via bulk-rebuild, etc.).
5. Living Spec contract example ("SPEC.md at the repo root") does not match reality for pattern-scale or adopter-scale work: EposForge and the primary adopter repo are distributed collections of contracts, adapter cards, ontology, instance docs, and backlogs.
6. Layering is underspecified: EposForge framework repo owns the *pattern* + reference adapters only. The primary adopter + its IaC (e.g. compose, volumes, host config) owns *this adopter's platform factory implementation*. Product repos own product factory implementations. No single repo "implements EposForge".
7. "primary adopter" (or its short code used privately) is overloaded: it names both the adopter's platform-factory living spec / backlog repo *and* the concrete running platform. This conflates spec with implementation.

Already some good partial language exists (backlog adapter has `role = "substrate"` vs `"product"`; aggregate.sh respects private roots and writes primary adopter portfolios to the private side; platform vs product phase docs; ontology distinguishes PlatformFactory / ProductFactory).

## Current state snapshot (facts)

- **Spec Graph active path**: cognee-ontology-preprocessor. `cognee-sync` + cognify on `eposforge-sync` dataset. Bulk-rebuild ingests *all* tracked `*.md` + `*.ttl` except ontology. Incremental post-commit hook is narrower (excludes `backlog/`, `.eposforge/backlog/` currently).
- **Backlog adapter**: file-based (split active/slates/archive + index for context load rules). Cross-repo aggregation with visibility (public EF vs private primary adopter roots). Already records substrate vs product roles. Beads/Dolt via Gas Town mentioned as complementary.
- **GraphRAG**: shelved fallback for Spec Graph. Still present in research/.
- **Living Spec practice here**: distributed (component contracts in 01-architecture/, per-adapter `*.md` cards under .eposforge/, .eposforge/SPEC.md for certain tools, ontology). Paired-change is selective, not universal. No formal Living Spec *Adapter* installed yet (Phase C).
- **Platform / Product**: Explicitly split in 00-vision, two roadmap files, ontology classes. Substrate repos (IaC, platform) link via backlog deps toward product anchors.
- **Recall quality issues** already tracked (EF-011 conflation of internals with adopter paths; EF-012 design-intent presented as shipped; adopter-recall.py wrapper with sanitization + maturity tags).

The graph's *structural knowledge* says backlog items do not belong in Spec Graph. The implementation (bulk) sometimes puts them there.

## Target model (tight)

Four layers with clear ownership:

1. **Pattern + References (EposForge framework repo)**  
   Contracts, ontology, reference adapter living specs (the `*.md` cards), "how the slot works", research that informs contracts.  
   → Feeds the canonical eposforge Spec Graph (cognee). This is the "living spec of the pattern".

2. **Backlog System Mechanics**  
   Schema, file layout, load rules, aggregation rules, role=substrate/product, dependency linking.  
   → Belongs in Backlog component contract + its adapter Living Spec → projected into Spec Graph (as "how backlog works").

3. **Backlog Items (the work)**  
   Individual issues with text, state, effort, verifies. Per-repo (or Beads).  
   → Not in Spec Graph. Use an independent **file-based** backlog graph (parse explicit markup into nodes/edges + GraphRAG layers). The GraphRAG capability lives in separate tooling/skills that process the files (not embedded in the MD). No Cognee dep for portability. See master capture for details on where the capability lives and effectiveness vs Cognee.

4. **Adopter Implementation**  
   - primary adopter repo (or equivalent): the adopter's *living spec of its platform adoption* (which EF components adopted, custom adapters, substrate decisions, adopter-prefixed items, links to EF). Can run its own cognee/GraphRAG instance(s) on its corpus + selective upstream pulls.  
   - Concrete substrate (srv-docker-hp IaC, compose, volumes, host config, Gas Town, etc.): the actual Everything-as-Code implementation of the platform factory.  
   - Product repos: separate, role=product, their own Living Specs + backlogs.

Spec Graph (and any backlog KG) are tools *used by* the factories; they are not the factories.

## Open decisions to resolve

- Exact inclusion list or exclusion list for "Spec Graph corpus" (pattern contracts + adapter cards + component docs only?).
- Backlog items as KG: revive GraphRAG as "backlog-rag" adapter? Or dedicated cognee dataset + separate MCP surface? Or rely on markdown + future Beads + graph queries over deps?
- How primary adopter agents are told to ground: "always consult upstream eposforge MCP first for pattern, then local adoption graph for our state".
- Living Spec contract update: allow "declared corpus of contracts + cards" for pattern and large adopters instead of mandating single root SPEC.md.

**Superseded**: Full evolved discussion is in `adopter-architecture-discussion-capture.md`. This note is retained for history. Phase 0 alignment complete (EF-056 master + children); see implementation plan and current backlog items for status. Terminology, primary-repo model (portfolio reviews in the Adopter Platform Spec repo), and initial ingestion boundary work (EF-057) documented in the main files.

This early note is kept only for historical context. Current SSoT is the capture + plan + the four maintained files.

**Forward plan (2026-06)**: See the dedicated implementation-plan file. Uses strangler fig (opportunistic + visibility + commitment) for the full scope to prevent losing track. All phases tracked as EF- items in the backlog itself + regular portfolio reviews. Start small per scope/component.

Cross-cutting plan items: Follow AGENTS.md and SKILL.md patterns for agent/skills work. Plan to fill gaps in guidance. Bake strangler fig (Migration, legacy/target shapes, debt visibility) into the backlog semantic layer (fields/schema) for excellent support when agents use the GraphRAG.

**AGENTS.md**: EposForge has AGENTS.md as SSoT (with 04-standards/08-agent-coding-guidelines). Applicable to backlog graphrag for global agent instructions on using the dedicated tools vs raw files. Contrast to SKILL.md (per-skill). See capture for details.
