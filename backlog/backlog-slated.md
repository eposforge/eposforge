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
Verify with: `instance/installed/04-router/<adapter>/` exists with a Living Spec; the adapter accepts a brief and emits an ordered task list with predicted Tool Transport invocations; a reuse-lookup step queries the Spec Graph (Component 6) for existing adapters that fulfill any decomposed sub-task before dispatching new work, and returned recommendations carry source-of-truth provenance per EF-012; the dispatch step invokes Tool Transport (Component 5) for each sub-task and records the invocation in `.audit/`; outcome aggregation writes per-sub-task results back to `backlog/` under stable IDs; an end-to-end smoke run on a real brief produces an aggregated PR or backlog-update summary without operator intervention between steps.
Notes: Router is the unfilled Phase D blocker for Product Factory and the single largest move toward Phase 3 (Supervised Autonomy) for Platform Factory. The current autonomy gap — operator manually decomposes specs, dispatches sub-tasks across multiple chat windows, and aggregates results in their head — is the structural source of the multi-window focus-fracture problem this work addresses. Router v0 closes that loop. Slated because the reuse-lookup step (the structural differentiator from a thin LLM dispatcher) depends on Spec Graph recall quality, which is gated by EF-011 (recall conflates EposForge-internal with adopter-side paths) and EF-012 (recall emits design intent as present-tense state). Shipping Router v0 against an unreliable graph would dispatch agents against phantom components and erode trust in the very system meant to reduce cognitive load. Re-evaluate once EF-011 and EF-012 are resolved. Interim tactical alternative for the operator: use `/loop` plus background `Agent` invocations from a single Claude Code session to approximate Router-like parallelism without architectural commitment; this does not produce a reusable adapter. Out-of-scope for v0: adaptive Dev Product (Component 3) routing across multiple agent vendors — v0 dispatches to one Tool Transport target. Out-of-scope: cross-repo dispatch — single-repo first. Adjacency: EF-002 (git-based authoritative sync, currently slated through 2026-07-18) materially improves Router decision quality by ensuring recall reflects current state; consider re-evaluating EF-002's slated date alongside Router v0 activation.

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
Verify with: repo directory layout mirrors the canonical tree (constitution / solution architecture / enterprise architecture / portfolio); adapter `component:` fields rewritten to new node names; never-existed nodes authored (portfolio, data architecture, value streams, stakeholders, information flows, orchestrator/agents/skills/tools, etc.); the vocabulary standard retired (folded into ontology) and the maintain-ontology skill's reference re-homed; bulk two-pass re-cognify completes; recall matches the working tree. Follow the 6-step re-cognification order in the knowledge-tree migration context (do not reorder).
Notes: Doubly gated — behind Foundry routing (EF-017, so the bulk re-cognify bills credits) AND behind Router v0 (EF-013, so re-cognify does not destabilize the graph mid-build). Cheap authoring (constitution/EA/portfolio prose, prose renames) can proceed earlier; this epic is the expensive physical re-shelving + re-cognify part. Iterate never-existed node shapes per "plan where known, iterate where unknown." Full design source + migration context: knowledge-tree (working copy in this repo's gitignored `.scratchpad/`).

