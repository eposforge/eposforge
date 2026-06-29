# Implementation Plan: EposForge / GEA Architecture & Multi-Graph (2026-06) — Zoomed Out

**Source**: Consolidated from full discussion capture in `docs/eposforge-gea-architecture-discussion-capture.md`.

**Goal**: Clarify boundaries so that an adopter maintains a single primary repo (the "Adopter Platform Spec", e.g. GEA) that documents the overall eposforge implementation for both product and platform factories and contains the `eposforge/` adopted slice. Enable multi-graph + ontology-as-mapping, targeted mirroring, reliable projection, and graph-first agent access while keeping disk canonical. Portfolio reviews happen from that primary repo. Use strangler fig pattern (see 02-roadmap/adoption-strategy.md) for incremental rollout so we don't lose track.

**Tracking to avoid losing the thread**:
- Create EF- backlog items for each phase/milestone (use the file-based backlog itself).
- Update this plan file and the master capture after each step.
- Use existing mechanisms: portfolio-review, aggregate.sh --themes, visibility markers.
- Regular checkpoints in the backlog (e.g., "strangler progress on multi-graph").
- The four files (this plan, capture, boundaries-layers, layout-mirror) are the single source for discussion state.

**Strangler fig approach** (opportunistic + commitment):
- Align ongoing work with the target (e.g., when touching a graph, adopter layout, or agent access, move it toward the model).
- Visibility of debt (document in backlog what is legacy vs target).
- Completion commitment with dated milestones.
- Balance with active management (don't let it stall).

**High-level phases** (incremental per scope/component to control complexity):

**Phases** (prioritized by risk/impact; small effective steps first).

## Overall Approach: Strangler Fig (to avoid losing track)
Follow the repo's own adoption strategy (02-roadmap/adoption-strategy.md):
- Opportunistic alignment: When touching related work (a graph, layout, agent access, or backlog item), deliver against the target model.
- Visibility of debt: Every related EF- item or doc marks "legacy shape" vs "target shape".
- Completion commitment: Dated milestones per phase/scope.
- Active balance: Use portfolio-review and themes to keep momentum.

This prevents the "lot here + strangler config" risk by treating the architecture evolution itself as a strangler migration tracked in the backlog system.

**Cross-cutting requirements (must be part of all phases)**:
- **Follow existing agent and skills guidance**: All design and planning for agent-facing parts (especially the backlog GraphRAG tooling and multi-graph access) must follow EposForge's established patterns. Use AGENTS.md as the single source of truth for global agent instructions (with thin pointers from CLAUDE.md etc.), the adopted 04-standards/08-agent-coding-guidelines for behavioral principles, and the SKILL.md format for describing any skills/tools. The guidance explicitly supports adopting repos.
  - Plan to discover/follow this guidance in all future design work.
  - Plan item: Identify gaps in the current AGENTS.md / SKILL.md guidance needed to support the independent file-based backlog graph, GraphRAG tooling, multi-graph queries, and strangler concepts (e.g., instructions for agents on preferring graph tools, using explicit markup, tracking migrations via backlog). Fill those gaps as part of the plan (design the content now; do not edit the guidance files until approved in later phase).
- **Bake strangler fig concepts into the backlog semantic layer**: So that the strangler fig pattern (opportunistic alignment, visibility of debt via Migration/LEGACY_SHAPE_OF/TARGET_SHAPE_OF from ontology and adoption-strategy.md, completion commitment, active balance) can be implemented especially well when agents use the backlogs via the GraphRAG/tools.
  - Extend the backlog schema and file conventions (fields in backlog.md, config.toml, etc.) to natively support strangler tracking: e.g., "Migration:" field, "LegacyShapeOf:", "TargetShapeOf:", or conventions using existing fields (Theme for migration debt, DependsOn/Blocks for legacy vs target links).
  - This allows agents to query the graph for migration progress, propose strangler edits, maintain visibility of debt, etc., as first-class backlog work.
  - Plan item: Design the schema extensions for strangler support as part of the backlog graph independence work. Prototype using the backlog's own items to track this architecture migration (strangler in action on itself).

**Phased rollout (incremental per scope or component)**:
Start narrow (one adopter + one area), prove, then expand. Track everything as EF- items in the backlog (the thing we're improving).

## Phase 0: Alignment & Tracking (Now, 1-2 weeks)
- Finalize and reference this plan + master capture in the backlog (create top-level EF- item for "Multi-graph + boundaries evolution").
- Create EF- items for each major thread (multi-graph, backlog independence, layout mirroring, agent access, sync reliability).
- Update the 4 maintained files only (no open docs yet).
- Align terminology in capture (Adopter Platform Spec vs Instance).
- Explicitly document that adopters designate one primary repo as the Adopter Platform Spec containing overall implementation docs (product + platform factories) + the eposforge/ slice; this is where portfolio reviews are performed.
- Checkpoint: portfolio-review run that surfaces this as a theme (run from the primary repo when possible).

**Milestone**: Clear, visible backlog of the work. No drift in our own tracking.

## Phase 1: Backlog Graph Independence (Pilot, narrow scope)
- Treat backlog as its own file-based graph (parse markup to explicit graph).
- Build minimal GraphRAG tooling layer (skills/tools, not Cognee) for agent access.
- Separate ingestion: backlog items stay out of main Spec Graph.
- Pilot on EposForge's own backlog + GEA as one adopter.
- Add simple cross-mapping in ontology (adoptsFrom style for backlog mechanics).
- Use existing aggregate.sh and portfolio-review as starting point for the tooling layer.

**Strangler angle**: Keep the current file-based-backlog running. Incrementally enhance the GraphRAG side in tools. Measure (e.g., agent token usage on backlog queries).

**Milestone**: Backlog items have their own queryable graph. Agents get graph benefits via tools. Portable proof-of-concept.

## Phase 2: Multi-Graph Foundation (Core, one adopter first)
- Choose deployment (start with single Cognee instance + datasets for isolation).
- Stand up GEA's graph (ingest its Living Specs/adoption docs).
- Shared ontology as mapping layer (add/ use adoptsFrom, fulfillsSlot for realizations).
- Agent grounding rules: "pattern graph for EposForge model, local graph for GEA state".
- Update adopter-recall style wrappers.
- Pilot mappings between graphs.

**Strangler angle**: Run in parallel with current single-graph usage. Gradually migrate agent prompts and tools to use the right graph.

**Milestone**: GEA can ground on both graphs cleanly. Ontology bridges them.

## Phase 3: Targeted Mirroring & Layout Guidelines (Human + quality)
- Document levels of mirroring (inside adoption bucket, high-level sections, runtime/LAN names).
- Apply lightly to GEA filesystem and containers (for discoverability and better extraction).
- Update layout mirror standard (design only first).
- Ensure disk layout supports file-based RAG for humans/narrow scopes while graph remains primary for agents.

**Strangler angle**: When touching servers/, hardware/, or docs, align naming/structure opportunistically.

**Milestone**: Operators and extraction both benefit from clearer mirroring without forcing full symmetry.

## Phase 4: Sync Reliability & Agent Access Tightening (Quality gate)
- Make incremental sync verifiable (coverage checks, easy rebuild).
- Disk = canonical; graph = projection. Agents instructed accordingly.
- Tighten agent file access (policy, sandbox) so they rely on graphs/MCPs.
- Generalize per-scope recall.

**Strangler angle**: Improve sync on existing graphs first, then apply to new ones.

**Milestone**: No more "search twice" or staleness surprises. Agents use graph-first by default.

## Phase 5: Broader Rollout & Polish
- Expand to IAC and product repos (strangler per adopter).
- Terminology cleanup and Living Spec updates (if/when ready).
- Full multi-graph agent experience with mappings.
- Extract backlog as potential standalone if desired (after proving portability).

**Tracking throughout**: All phases create/ update EF- items. Use themes, --mermaid, and portfolio reviews to surface progress and prevent loss of visibility. Revisit this plan file after each phase.

**Risk mitigation for "losing track"**:
- The backlog system itself is the tracker (ironic but effective).
- Small phases with clear "done when".
- Opportunistic + committed (per existing strategy).
- Regular visibility in GEA/EF backlogs.

Update this plan and the capture after every phase or significant discussion. Start with Phase 0 items in the actual backlog.

## Phase 3: Layout Standard & Physical Mirroring (Human + Extraction Quality)
1. Expand or companion to Adapter Layout Mirror:
   - Define levels of mirroring:
     - Strong: inside `eposforge/` bucket (stable names).
     - Light: high-level knowledge sections (`NN-` prefixes).
     - Runtime: container/service/mount naming for discoverability.
   - Add file-RAG discoverability principles (self-describing dirs, index/README files per section, frontmatter that aids extraction).
   - Update for single-repo platform adopters (GEA-style) while preserving "does not govern own application layout" where appropriate.
2. Apply to GEA (targeted):
   - Align `eposforge/` more closely where it makes sense.
   - Improve naming in `servers/`, `hardware/`, container defs.
   - Keep GEA's natural numbering for its knowledge but document mappings.
3. Document in 00-vision or new "Repository roles & ownership" section (see boundaries capture).

**Success**: Operators can match disk/LAN to EposForge model at a glance. Projection quality improves. Agents using file tools (narrow scopes) find things easily.

## Phase 4: Agent Access Model & Policy (Isolation)
1. Codify in agent policy / skills:
   - Graph/MCP primary for knowledge (pattern + state).
   - Direct file access limited (sandbox, per-repo narrow mounts, explicit grants).
   - Instructions: Prefer MCP for discovery/relationships; use graph for mapping across scopes.
2. Update tooling:
   - Generalize sanitization (path rewriting, maturity tags).
   - Runbooks for "how GEA agents ground".
3. Address current reality: Gradually restrict broad cross-repo file access (via policy, mounts, execution sandbox).

**Success**: Agents do not need (and ideally cannot) do broad file RAG across EposForge/GEA. No contradiction with Cognee routing. "Search twice" eliminated via reliable graphs + mappings.

**AGENTS.md applicability (to backlog graphrag)**: EposForge uses root AGENTS.md as SSoT for agent guidance (with adopted standard in 04-standards/08 for behaviors). Unlike per-skill SKILL.md, this is global instructions. For the independent file-based backlog graph: AGENTS.md (or adopter equivalent) should instruct agents to use dedicated graph tools/skills (vs raw files), leverage explicit markup, reference the separate graph. Useful for portable standalone versions. Add to agent policy work in Phase 4.

## Phase 5: Living Spec & Terminology Polish
- Update Living Spec contract + research catalog for distributed corpora / pattern-scale work.
- Terminology: Introduce "Adopter Platform Spec (GEA repo)" vs "Platform Instance (srv-docker-hp + IaC)" in ontology, vision, EF notes.
- Validate via existing checks (check-doc-classification, etc.).

## Phase 6: Validation & Rollout
- Update `skills/portfolio-review`, `skills/update-spec-graph`, etc.
- Probes: Recall quality tests, "graph vs disk" diffs, operator walkthroughs.
- Backlog items for remaining (e.g., EF-0xx for specific pieces).
- Apply to GEA + IAC first, then products.

**Overall Success Criteria**:
- Clear boundaries (no more "bleed" confusion).
- Reliable, multi-graph access with ontology as mapping.
- Agents get graphrag benefits without dual searches or broad file access.
- Disk layout supports humans + high-quality projections.
- Terminology and layering match reality (platform vs product, spec vs impl).

**References**:
- Master capture: `docs/eposforge-gea-architecture-discussion-capture.md`
- Early boundaries: `docs/boundaries-layers-2026-06.md`
- Key standards: `04-standards/07-adapter-layout-mirror/`, `00-vision/01-ontology.ttl`
- Tooling: `instance/spec-graph/cognee/`, backlog scripts.

This plan is derived directly from the captured discussion. Prioritize Phases 0-2 for quickest impact on agent experience and consistency. 

**Phase 0 status (2026-06-29)**: Complete. 
- EF-056 master + children EF-057 (ingestion boundaries + GraphRAG layer pilot), EF-058 (terminology + repository roles + primary Adopter Platform Spec model) created with full verify criteria in backlog.
- Four maintained files (this plan, capture, boundaries-layers-2026-06.md, 04-standards/07-adapter-layout-mirror) + related docs (backlog component, file-based-backlog.md, preferred-mode-adoption-plan.md) updated: EF refs, "planning only" language removed, explicit primary-repo model (single Adopter Platform Spec repo holds overall product+platform docs + eposforge/ slice; portfolio reviews run there; GEA example). 
- Terminology aligned (Adopter Platform Spec vs Platform Instance, multi-graph, independent backlog graph) in docs, ontology (new ef:MultiGraphArchitecture + ef:IndependentBacklogGraph), skills (portfolio-review, update-spec-graph), and standards.
- Ontology enhanced pre-review.
- Portfolio-review executed as checkpoint (initially in framework; clarified real view from primary adopter repo).
- Related tooling advanced (EF-046 Tags full migration, EF-047 visibility/private roots).
- EF-057 starter: explicit exclusion of raw backlog items added to bulk-rebuild.sh, update-spec-graph skill, and documented in cognee.md (main Spec Graph excludes raw items; mechanics via ontology OK).
- All changes tracked via the backlog's own graph + four files as SSoT.

Implementation edits now proceed only against the backlog items and the four files (or as explicitly called for by a child EF-). Update this plan (and the capture) after each significant step or portfolio checkpoint. Phase 0 milestone achieved; entering execution of children starting with EF-057.