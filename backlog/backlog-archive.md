# Backlog Archive

Resolved issues are grouped by month (`## YYYY-MM`).

## 2026-05








## Issue EF-007 — Resolve component-slot kind-class symmetry
ID: EF-007
Title: Resolve component-slot kind-class symmetry
Date: 2026-05-18
Status: resolved
Effort: S
Fix surface: eposforge-pattern
Verify with: ontology has either 0 or 14 component-slot kind-classes (currently 5 of 14: DevProduct, Router, ToolTransport, SpecGraph, ExecutionSandbox); whichever direction is taken, the result is uniform and documented.
Validation: Added the missing nine adapter kind-classes so ontology slot-kind symmetry is now 14 of 14 and uniformly modeled in `00-vision/01-ontology.ttl`.
Resolved: 2026-05-18

## Issue EF-008 — Create 04-standards/02-vocabulary/ standard
ID: EF-008
Title: Create 04-standards/02-vocabulary/ standard
Date: 2026-05-18
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Verify with: `04-standards/02-vocabulary/` exists, frontmatter matches existing standards (meta, naming-conventions, research-mirror); the `maintain-ontology` skill and AGENTS.md defer to it for editorial workflow.
Validation: Added `04-standards/02-vocabulary/vocabulary.md`, listed it in `04-standards/README.md`, and updated AGENTS plus the maintain-ontology skill to defer editorial workflow to that standard.
Resolved: 2026-05-18

## Issue EF-006 — Add instance-scoped TTL files for installed adapters
ID: EF-006
Title: Add instance-scoped TTL files for installed adapters
Date: 2026-05-18
Status: resolved
Resolved: 2026-05-18
Effort: M
Fix surface: repo-instance
Verify with: SPARQL `?a rdf:type ef:ReferenceImplementation` against the merged graph returns each installed adapter with metadata; efi: namespace used consistently for instance individuals.
Validation: cognee-sync --added ingested ontology + reference-implementations.ttl without errors; state DB confirms 12 efi: adapter individuals tracked (data_id 25449d0a); efi: namespace used consistently, ef: reserved for ontology terms.


## Issue EF-009 — Model the adoption relationship in the ontology
ID: EF-009
Title: Model the adoption relationship in the ontology
Date: 2026-05-18
Status: resolved
Resolved: 2026-05-18
Effort: S
Fix surface: eposforge-pattern
Depends on: EF-006
Verify with: ef:adoptsFrom object property defined with domain/range; at least one adapter declares ?adapter ef:adoptsFrom ?ref linking to an ef:ReferenceImplementation; SPARQL returns expected pairs.
Validation: cognee-sync --added ingested adoption-links.ttl without errors; ef:adoptsFrom defined in ontology with efi:acme-copilot-adapter ef:adoptsFrom efi:copilot as verification triple; state DB confirms tracking (data_id 790fab00).

## Issue EF-001 — Initial corpus seed via cognee-sync against live backend
ID: EF-001
Title: Initial corpus seed via cognee-sync against live backend
Date: 2026-05-17
Status: resolved
Resolved: 2026-05-18
Effort: M
Fix surface: repo-instance
Verify with: `cognee-sync --added` ingests current corpus and query returns expected entities
Validation: cognee-sync --added seeded all 79 git-tracked .md files plus ontology and 2 instance TTL files (82 documents total); all reported `add` without errors; state DB confirms full tracking.

## Issue EF-005 — Self-hosted MCP server with adopter-extensible ontology and cognee KG
ID: EF-005
Title: Self-hosted MCP server with adopter-extensible ontology and cognee KG
Date: 2026-05-18
Status: resolved
Resolved: 2026-05-18
Effort: XL
Fix surface: eposforge-pattern
Depends on: EF-001
Verify with: an adopter can (a) supply a custom .ttl file that is merged with the canonical ontology on upload, (b) ingest their own markdown/specs into a named adopter dataset in cognee, and (c) issue an MCP query that returns entities from both the base EposForge KG and their adoption-specific KG
Validation: Scope superseded by upstream cognee-mcp (topoteretes/cognee-mcp). Cognee-mcp already exposes `remember`/`recall`/`forget` plus workspace tools (`cognify_file`, `list_datasets_json`, `create_dataset_json`, `visualize_graph_ui`) — sufficient to cover EF-005 bullets (a)–(c) when pointed at the existing dkr-cgnee-api backend with `COGNEE_MCP_AGENT_SCOPED=false` and the eposforge corpus already seeded via cognee-sync (EF-001). Bullet (a) overlay-merge is not an MCP-time workflow; handled by cognee API / cognee-sync upload path. Bullet (c) cross-dataset retrieval comes for free under shared-backend mode (`ENABLE_BACKEND_ACCESS_CONTROL=false`) since GraphRAG traversal crosses dataset boundaries at the graph layer. Replaced by EF-010 (adopter-onboarding docs). Pattern-semantic tool wrappers can be revisited if/when a concrete agent task surfaces that `recall` can't answer well.

## Issue EF-010 — Self-consume cognee-mcp in this repo; runbook doubles as adopter onboarding
ID: EF-010
Title: Self-consume cognee-mcp in this repo; runbook doubles as adopter onboarding
Date: 2026-05-18
Status: resolved
Resolved: 2026-05-24
Effort: S
Fix surface: repo-instance
Depends on: EF-001
Verify with: in this repo, `claude mcp list` shows cognee connected AND `recall` against the eposforge dataset returns expected entities from an MCP-capable dev product (claude-code at minimum). The same runbook, with a "for adopters: substitute your corpus and TTL overlay" section, satisfies what EF-005 originally tried to spec.
Notes: Supersedes EF-005. EposForge dogfoods its own pattern, so the repo is the first adopter and self-consumption is the primary deliverable, with explicit adopter guidance as a derivative section. Runbook should cover: cognee-mcp install/config (stdio for local dev-products; SSE/HTTP variants noted), the `COGNEE_MCP_AGENT_SCOPED=false` + `ENABLE_BACKEND_ACCESS_CONTROL=false` decision for shared-backend single-graph mode vs per-dataset isolation, overlay TTL upload via cognee-sync (Phase 4 ontology behavior already documented in `instance/installed/06-spec-graph/cognee/cognee.md`), and minimal MCP-client config snippets for supported dev-products (claude-code, cursor, copilot). Call out the `.owl` extension requirement (EF-004 still slated covers automating that on the sync CLI side). For adopter framing, include a section that substitutes their corpus and TTL overlay, including upstream cognee-mcp usage patterns.
Validation: Added `instance/installed/05-tool-transport/mcp-stdio-and-http/cognee-mcp-self-consume-runbook.md` as the canonical self-consume plus adopter onboarding guide, linked it from Tool Transport and Cognee adapter docs, and scrubbed private hostname usage from canonical tracked MCP server declarations by using a placeholder endpoint.


## Issue EF-015 — Component 11 (Audit & Observability): first adapter — structured event sink
ID: EF-015
Title: Component 11 (Audit & Observability): first adapter — structured event sink
Date: 2026-05-24
Status: resolved
Resolved: 2026-05-24
Effort: M
Fix surface: eposforge-pattern
Verify with: `instance/installed/11-audit-observability/<adapter>/` exists with a Living Spec; every other component can emit the required event types (`adapter.invoked`, `policy.decision`, `artifact.produced`, `secret.accessed`, `error`) to a durable sink; a query returns recent events. Realizes the constitution tenet "all data captured centrally as AI feedstock" — events land in the central data plane, not a component-local silo.
Notes: Component 11 is an unfilled slot (draft contract at 01-architecture/02-components/11-audit-observability.md). This adapter is the telemetry/trace/log sink that the inference cost-tracking work (EF-016/EF-018) emits through, rather than the inference adapter writing telemetry directly. Sink backend choice and the cross-repo telemetry rollout are host/adopter config tracked on the host-stack backlog. New-tree mapping: this slot becomes `shared > logging`.
Validation: Added `instance/installed/11-audit-observability/jsonl-event-sink/` with a Living Spec and scripts that enforce the required event types and append records to a durable JSONL sink (`instance/.audit/events.jsonl` by default), plus a query surface (`query-recent.sh`) that returns recent events with optional type filtering.


## Issue EF-016 — Component 10 (Inference): emit Component 11 events with per-call token usage
ID: EF-016
Title: Component 10 (Inference): emit Component 11 events with per-call token usage
Date: 2026-05-24
Status: resolved
Resolved: 2026-05-24
Effort: S
Fix surface: eposforge-pattern
Depends on: EF-015
Verify with: every inference call through the adapter emits one structured event to the Component 11 sink capturing { repo, dataset, phase (extract|embed|cognify), model, prompt_tokens, completion_tokens, total_tokens, latency_ms }; a one-week Cognee re-graph produces a query-able trail attributing tokens to dataset/phase.
Notes: Pure in-process change; no cloud dependency. The token baseline this produces is the prerequisite for sizing the credit-funded inference deployments (tracked on the host-stack backlog) defensibly. New-tree mapping: `shared > ai systems > inference`.
Validation: Added `instance/installed/10-inference/scripts/emit-token-usage-event.sh` to emit Component 11 events through the EF-015 sink as `adapter.invoked` records with the required token-usage fields (`repo`, `dataset`, `phase`, `model`, `prompt_tokens`, `completion_tokens`, `total_tokens`, `latency_ms`), and wired the emitter contract into both installed inference adapter Living Specs.

## Issue EF-014 — Formalize Agent Policy (Component 8) — tier-0/1/2 contract with per-adopter generator
ID: EF-014
Title: Formalize Agent Policy (Component 8) — tier-0/1/2 contract with per-adopter generator
Date: 2026-05-23
Status: resolved
Resolved: 2026-05-24
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-010
Verify with: `instance/installed/08-agent-policy/<adapter>/` exists with a Living Spec naming the chosen scheme (e.g. `tier-yaml`); a YAML contract declares tier-0 (auto), tier-1 (supervised), tier-2 (manual) with predicates over Bash command shapes and MCP tool names; a generator script emits a `.claude/settings.json` permissions allowlist from the YAML contract for tier-0 entries; running the generator against this repo produces a settings file equivalent to a hand-verified baseline; recall of "agent policy" returns the new adapter metadata, not only the AGENTS.md prose.
Notes: The Agent Policy slot (Component 8) is currently filled by ad-hoc prose in AGENTS.md, so every adopter project re-derives the same allowlist judgments in `.claude/settings.json` and operators field per-command permission prompts as one-off decisions during chat sessions — the structural source of the permission-prompt focus drain. A formal tier model — tier-0 (read-only, idempotent reflective tools; safe to auto-approve), tier-1 (writes to working tree or sandbox; auto-approve in alpha ring, supervised elsewhere), tier-2 (destructive, prod-facing, or human-judgment-required) — collapses those repeated decisions into one parseable contract. The adapter governs a generator that emits per-adopter `.claude/settings.json`, Gitea/GitHub Actions gates, and optional pre-commit hook fragments via the existing hook composer at `instance/installed/09-source-control-ci/github-and-actions/scripts/install-hooks.sh`. Out-of-scope for v0: cross-adopter policy inheritance, dynamic per-PR risk scoring, telemetry-driven policy adaptation. Unblocks Platform Factory Phase 2 (Agent Proposals → Supervised Autonomy) and removes the per-repo allowlist drift that currently emerges from running `/fewer-permission-prompts` independently in each adopter.
Validation: Added `instance/installed/08-agent-policy/tier-yaml/` with a Living Spec and `policy.tiers.yaml` contract declaring tier-0/tier-1/tier-2 rules with Bash and MCP predicates; added generator `scripts/generate-claude-settings.py` that emits `.claude/settings.json` allowlist from tier-0; and added baseline check tooling (`scripts/check-baseline.sh` + `baseline/settings.expected.json`) confirming generated settings are equivalent to the hand-verified baseline.

## Issue EF-018 — Component 10 (Inference): in-process per-key budget enforcement
ID: EF-018
Title: Component 10 (Inference): in-process per-key budget enforcement
Date: 2026-05-24
Status: resolved
Resolved: 2026-05-24
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-016, EF-017
Verify with: a per-key (per-repo) token budget loads from config; the adapter consults a persistent counter before forwarding each call and refuses (or degrades to a cheaper model) when the budget is exhausted, with a clear error; budget config is hot-reloadable without restart. Mechanism only.
Notes: The synchronous in-process wallet that complements cloud deployment rate caps (burn rate) and cloud budget alerts (slow backstop). Per-repo budget values are host/adopter config (host-stack backlog).
Validation: Added budget policy + gate scripts (`budget-policy.json`, `scripts/check-budget-gate.sh`, `scripts/record-budget-usage.sh`, and `budget-enforcement.md`) and verified local behavior: allow when within budget, degrade when request exceeds remaining budget with a configured fallback model, deny with exit code 4 when exhausted, and hot-reload by editing policy config between invocations without restart.

## Issue EF-019 — Knowledge-tree schema delta: node kinds + Concept/Guidance/Tenet + lifecycle status
ID: EF-019
Title: Knowledge-tree schema delta: node kinds + Concept/Guidance/Tenet + lifecycle status
Date: 2026-05-24
Status: resolved
Resolved: 2026-05-24
Validation: 00-vision/01-ontology.ttl carries ef:NodeKind discriminator (pillar|group|component|concept|guidance|tenet) with individuals, ef:LifecycleStatus (proposed|adopted|retired), ef:Concept/Guidance/Tenet classes with schema properties (adoptedDefinition, statement, variants, relationshipEdge, lifecycleStatus); vocabulary.md updated with new reserved types and KIND/LIFECYCLE_STATUS keywords; maintain-ontology skill re-homed from vocabulary.md to TTL; AGENTS.md /modifyef updated. TTL structural check clean (570 lines). Re-cognify deferred behind EF-017 cost gate per design.
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-017
Verify with: 00-vision/01-ontology.ttl carries a `kind` discriminator (pillar|group|component|concept|guidance|tenet) on nodes, a Concept schema (adopted_definition, status, variants, relationship_edges), Guidance (status, prose body), and Tenet (statement, status); component nodes keep the Adapter schema; recall returns kind-typed nodes and status-tagged recommendations. Authored via the maintain-ontology skill.
Notes: This is the data model EF-011 (kind clarifies adopter-vs-internal) and EF-012 (status = shipped/partial/intent maturity) need — it accelerates those. Authoring the TTL is cheap and can start now; the re-cognify step is the inference-cost event, so it is gated behind Foundry routing (EF-017) to bill against credits. Re-home the maintain-ontology skill's vocabulary.md workflow reference (vocabulary folds into the ontology). Full design source: knowledge-tree (working copy in this repo's gitignored `.scratchpad/`).
