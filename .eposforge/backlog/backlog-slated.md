# Backlog Slated

Deferred issues (`slated`) with mandatory re-evaluation dates.

## Issue EF-002 — Git-based authoritative sync from server-side post-receive or CI workflow
ID: EF-002
Title: Git-based authoritative sync from server-side post-receive or CI workflow
Date: 2026-05-17
Status: slated
Slated: 2026-05-18
Re-evaluate by: 2026-07-18
Effort: L
Fix surface: infrastructure
Depends on: EF-001
Verify with: post-receive or CI trigger updates graph on merge to default branch

## Issue EF-003 — Add --reconcile-from-disk mode on cognee-sync CLI
ID: EF-003
Title: Add --reconcile-from-disk mode on cognee-sync CLI
Date: 2026-05-17
Status: slated
Slated: 2026-05-18
Re-evaluate by: 2026-07-18
Effort: M
Fix surface: repo-instance
Depends on: EF-001
Verify with: reconcile mode removes stale graph entities not present in source docs

## Issue EF-004 — Automate ontology re-upload path for .owl extension requirement
ID: EF-004
Title: Automate ontology re-upload path for .owl extension requirement
Date: 2026-05-17
Status: slated
Slated: 2026-05-18
Re-evaluate by: 2026-06-18
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-001
Notes: client.py `upload_ontology` already renames `.ttl` → `.owl` in the multipart form, but the CLI routes all files (including TTL) through `add_file`. The grounding ontology upload path (`/api/v1/ontologies`) is never called during normal sync; only used in test fixtures. Fix: CLI should detect `.ttl`/`.owl` files and dispatch to `upload_ontology` + `cognify` with `ontologyKey`.
Verify with: ontology upload step runs from CLI without manual extension workaround

## Issue EF-013 — Implement Router (Component 4) v0 — spec decomposition, agent dispatch, outcome aggregation
ID: EF-013
Title: Implement Router (Component 4) v0 — spec decomposition, agent dispatch, outcome aggregation
Date: 2026-05-23
Status: slated
Slated: 2026-05-23
Re-evaluate by: 2026-07-23
Effort: L
Fix surface: eposforge-pattern
Depends on: EF-010, EF-011, EF-012
Verify with: `.eposforge/router/<adapter>/` exists with a Living Spec; the adapter accepts a brief and emits an ordered task list with predicted Tool Transport invocations; a reuse-lookup step queries the Spec Graph (Component 6) for existing adapters that fulfill any decomposed sub-task before dispatching new work, and returned recommendations carry source-of-truth provenance per EF-012; the dispatch step invokes Tool Transport (Component 5) for each sub-task and records the invocation in `.audit/`; outcome aggregation writes per-sub-task results back to `backlog/` under stable IDs; an end-to-end smoke run on a real brief produces an aggregated PR or backlog-update summary without operator intervention between steps.
Notes: Router is the unfilled Phase D blocker for Product Factory and the single largest move toward Phase 3 (Supervised Autonomy) for Platform Factory. The current autonomy gap — operator manually decomposes specs, dispatches sub-tasks across multiple chat windows, and aggregates results in their head — is the structural source of the multi-window focus-fracture problem this work addresses. Router v0 closes that loop. Slated because the reuse-lookup step (the structural differentiator from a thin LLM dispatcher) depends on Spec Graph recall quality, which is gated by EF-011 (recall conflates EposForge-internal with adopter-side paths) and EF-012 (recall emits design intent as present-tense state). Shipping Router v0 against an unreliable graph would dispatch agents against phantom components and erode trust in the very system meant to reduce cognitive load. Re-evaluate once EF-011 and EF-012 are resolved. Interim tactical alternative for the operator: use `/loop` plus background `Agent` invocations from a single Claude Code session to approximate Router-like parallelism without architectural commitment; this does not produce a reusable adapter. Out-of-scope for v0: adaptive Dev Product (Component 3) routing across multiple agent vendors — v0 dispatches to one Tool Transport target. Out-of-scope: cross-repo dispatch — single-repo first. Adjacency: EF-002 (git-based authoritative sync, currently slated through 2026-07-18) materially improves Router decision quality by ensuring recall reflects current state; consider re-evaluating EF-002's slated date alongside Router v0 activation. Client-side facet: the Router's prompt-augmentation responsibility can be prototyped adopter-side as an IDE-resident hook that classifies the prompt's domain, gates per domain, and deterministically pre-fetches from multiple MCP adapters (spec graph + product docs + code host) before the agent responds — injecting labeled context rather than relying on the agent to choose to call a tool. This validates the augmentation contract early and exposes recall-quality gaps (EF-011/EF-012) under real load, but produces no reusable server-side adapter; track such work at the adopter-instance layer.

## Issue EF-020 — Validate authoritative KG sync via EposForge dogfooding
ID: EF-020
Title: Validate authoritative KG sync via EposForge dogfooding
Date: 2026-05-24
Status: slated
Slated: 2026-05-24
Re-evaluate by: 2026-07-23
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-002, EF-003, EF-010
Verify with: across >=4 weeks of normal commit volume under the post-receive/CI sync path (EF-002) plus reconcile-from-disk (EF-003), recall results match the working tree (no stale entities from deleted files, no missing entities from added files); a drift-injection test (mutate the graph, run reconcile) restores correctness without operator intervention.
Notes: The gate that converts "sync mechanism exists" into "sync mechanism is trustworthy enough to amplify." Cross-repo KG rollout (host-stack backlog) is blocked on this — amplifying unproven sync across N repos multiplies divergence. Telemetry from EF-016 quantifies drift rate / staleness lag for this gate.

## Issue EF-021 — Knowledge-tree physical migration: re-shelve to the canonical tree + bulk re-cognify
ID: EF-021
Title: Knowledge-tree physical migration: re-shelve to the canonical tree + bulk re-cognify
Date: 2026-05-24
Status: slated
Slated: 2026-05-24
Re-evaluate by: 2026-08-31
Effort: XL
Fix surface: eposforge-pattern
Depends on: EF-017, EF-013, EF-019
Verify with: repo directory layout mirrors the canonical tree (constitution / solution architecture / enterprise architecture / portfolio); adapter `component:` fields rewritten to new node names; never-existed nodes authored (portfolio, data architecture, value streams, stakeholders, information flows, orchestrator/agents/skills/tools, etc.); the vocabulary standard retired (folded into ontology) and the maintain-ontology skill's reference re-homed; bulk two-pass re-cognify completes; recall matches the working tree. Component-slot directories whose names are industry-misaligned are renamed in this same pass — e.g. `01-architecture/02-components/router.md` and `.eposforge/router/` → orchestrator — with adopter symlinks / back-compat path aliases preserved so existing adopter references don't break (this is the directory rename EF-026 deferred to a later phase). Follow the 6-step re-cognification order in the knowledge-tree migration context (do not reorder).
Notes: Doubly gated — behind Foundry routing (EF-017, so the bulk re-cognify bills credits) AND behind Router v0 (EF-013, so re-cognify does not destabilize the graph mid-build). Cheap authoring (constitution/EA/portfolio prose, prose renames) can proceed earlier; this epic is the expensive physical re-shelving + re-cognify part. Iterate never-existed node shapes per "plan where known, iterate where unknown." Full design source + migration context: knowledge-tree (working copy in this repo's gitignored `.scratchpad/`). Absorbs the component-directory rename EF-026 deferred: EF-026 does the doc/prose renames (C4 Router→Orchestrator) now; the physical directory moves land here in the single re-cognify pass to avoid a second credit-billing run. Preserve adopter symlinks / back-compat aliases when moving any slot dir. Related: EF-026.

## Issue EF-025 — One KG or many? Factory-design guidance KG vs. per-product source-code KG
ID: EF-025
Title: One KG or many? Factory-design guidance KG vs. per-product source-code KG
Date: 2026-05-26
Status: slated
Slated: 2026-05-26
Re-evaluate by: 2026-07-26
Effort: M
Fix surface: eposforge-pattern
Verify with: a recorded decision in the Component 6 (Spec Graph) docs stating whether the EposForge pattern uses a single knowledge graph or distinct graphs — specifically whether each product repo gets its own KG scoped solely to that repo's source code, separate from the cognee Spec Graph that guides dark-factory development/design. The decision must state its rationale (graph boundary, query patterns, drift/cost isolation, tooling) and, if multi-KG, how the graphs relate (full isolation, cross-links, or federation) and which tool fills the per-repo source-code-KG slot.
Notes: Open architecture question raised 2026-05-26 while adding the BYOK / autonomy-ToS axes to the Dev Product catalog. Today the cognee Spec Graph (Component 6) is a single graph projecting Living Specs across the factory — i.e. a graph about *how the factory is built and governed*. A code-knowledge-graph / semantic-search layer (Sourcegraph Cody/Amp, Augment Code Context Engine, Code-Graph-RAG) is a different animal: a graph/index of a *product repo's source code*, for an agent working in that repo. These may be two distinct concerns that should not share one graph: the factory-design graph is cross-repo and spec-centric; a source-code graph is repo-scoped and code-centric, and arguably one-per-product-repo. Question to settle: do we keep one KG, or split into (a) the factory Spec Graph and (b) per-repo source-code KGs — and if split, are the code KGs fully isolated or cross-linked to the Spec Graph for reuse/impact analysis? Relates to the Component-6 context-provider note in `03-research/01-architecture/02-components/dev-product/dev-products.md` (Sourcegraph/Augment/Code-Graph-RAG flagged as Spec Graph / Tool Transport providers, not Dev Products) and to the strangler-fig spec-graph work (EF-002/EF-020). Decision should also state whether per-repo source-code KGs are an EposForge-pattern concern at all, or purely an adopter/instance choice.

## Issue EF-028 — Add Working Memory component slot (provisional C15) — cross-session agent memory distinct from C6 Spec Graph
ID: EF-028
Title: Add Working Memory component slot (provisional C15) — cross-session agent memory distinct from C6 Spec Graph
Date: 2026-05-28
Status: slated
Slated: 2026-05-28
Re-evaluate by: 2026-08-31
Effort: L
Fix surface: eposforge-pattern
Depends on: EF-023, EF-024
Verify with: `01-architecture/02-components/15-working-memory.md` exists as a `source_of_truth: yes` slot contract declaring scope (cross-session / cross-turn agent working memory: conversation state, scratchpad state, decision rationale, partial-work checkpoints) and explicit non-scope (KG / ontology — stays in C6; per-call vector RAG inside C6's cognee implementation — stays inside C6; immutable raw chat capture for distillation — stays in EF-023/EF-024); declares a recall / write / decay / eviction API consumed by Dev Product (C3) and optionally Router/Orchestrator (C4); declares correlation identifiers (provider account, machine, workspace) compatible with the EF-023 chat-event schema; the candidate-implementations catalog lists at minimum Mem0, Zep, LangMem, Letta as adapter options; cross-references in C3 and C6 docs name C15 as the working-memory slot and clarify the boundary against C6 (KG only).
Notes: Industry-standard agentic factories typically have a memory layer distinct from the knowledge graph: short-term / working / cross-session conversational memory (Mem0, Zep, LangMem, Letta). Cognee (the current C6 Spec Graph implementation) confirms — and the spec-graph contract supports — that vector indexing and short-term/working/conversational memory are "separate and out of scope" for C6. Each Dev Product (C3, e.g., Claude Code, Copilot) keeps its own native per-session memory, but nothing in the EposForge contract gives an adopter a deterministic place to plug a cross-session / cross-IDE memory service for agents. Slated rather than open because EF-023 / EF-024 (chat capture) are already producing the *recording* side of the memory pipeline — until those ship and the *read-side* gap becomes concrete (do agents actually need active recall during execution, or is post-hoc operator query sufficient?), a top-level component slot would be speculative. Re-evaluation criterion: once EF-024 is in staging and operators can query indexed chat memory, observe whether agents would benefit from in-loop recall of prior decisions/scratchpads — if yes, promote C15 to open; if no, fold the contract into EF-023's schema as a read-side capability. Adjacency: EF-023 / EF-024 (capture is the storage side; C15 is the active-recall side), EF-025 (one-KG-vs-many decision — affects whether per-repo memory mirrors the per-repo source-code-KG question), C6 (Spec Graph, hard boundary — KG only). Discovered 2026-05-28 during a dark-factory architecture mapping against industry conventions (see an adopter's reference-architecture diagram).

