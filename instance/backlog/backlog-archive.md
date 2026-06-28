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
Notes: Supersedes EF-005. EposForge dogfoods its own pattern, so the repo is the first adopter and self-consumption is the primary deliverable, with explicit adopter guidance as a derivative section. Runbook should cover: cognee-mcp install/config (stdio for local dev-products; SSE/HTTP variants noted), the `COGNEE_MCP_AGENT_SCOPED=false` + `ENABLE_BACKEND_ACCESS_CONTROL=false` decision for shared-backend single-graph mode vs per-dataset isolation, overlay TTL upload via cognee-sync (Phase 4 ontology behavior already documented in `instance/spec-graph/cognee/cognee.md`), and minimal MCP-client config snippets for supported dev-products (claude-code, cursor, copilot). Call out the `.owl` extension requirement (EF-004 still slated covers automating that on the sync CLI side). For adopter framing, include a section that substitutes their corpus and TTL overlay, including upstream cognee-mcp usage patterns.
Validation: Added `instance/tool-transport/mcp-stdio-and-http/cognee-mcp-self-consume-runbook.md` as the canonical self-consume plus adopter onboarding guide, linked it from Tool Transport and Cognee adapter docs, and scrubbed private hostname usage from canonical tracked MCP server declarations by using a placeholder endpoint.


## Issue EF-015 — Component 11 (Audit & Observability): first adapter — structured event sink
ID: EF-015
Title: Component 11 (Audit & Observability): first adapter — structured event sink
Date: 2026-05-24
Status: resolved
Resolved: 2026-05-24
Effort: M
Fix surface: eposforge-pattern
Verify with: `instance/audit-observability/<adapter>/` exists with a Living Spec; every other component can emit the required event types (`adapter.invoked`, `policy.decision`, `artifact.produced`, `secret.accessed`, `error`) to a durable sink; a query returns recent events. Realizes the constitution tenet "all data captured centrally as AI feedstock" — events land in the central data plane, not a component-local silo.
Notes: Component 11 is an unfilled slot (draft contract at 01-architecture/02-components/audit-observability.md). This adapter is the telemetry/trace/log sink that the inference cost-tracking work (EF-016/EF-018) emits through, rather than the inference adapter writing telemetry directly. Sink backend choice and the cross-repo telemetry rollout are host/adopter config tracked on the host-stack backlog. New-tree mapping: this slot becomes `shared > logging`.
Validation: Added `instance/audit-observability/jsonl-event-sink/` with a Living Spec and scripts that enforce the required event types and append records to a durable JSONL sink (`instance/.audit/events.jsonl` by default), plus a query surface (`query-recent.sh`) that returns recent events with optional type filtering.


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
Validation: Added `instance/inference/scripts/emit-token-usage-event.sh` to emit Component 11 events through the EF-015 sink as `adapter.invoked` records with the required token-usage fields (`repo`, `dataset`, `phase`, `model`, `prompt_tokens`, `completion_tokens`, `total_tokens`, `latency_ms`), and wired the emitter contract into both installed inference adapter Living Specs.

## Issue EF-014 — Formalize Agent Policy (Component 8) — tier-0/1/2 contract with per-adopter generator
ID: EF-014
Title: Formalize Agent Policy (Component 8) — tier-0/1/2 contract with per-adopter generator
Date: 2026-05-23
Status: resolved
Resolved: 2026-05-24
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-010
Verify with: `instance/agent-policy/<adapter>/` exists with a Living Spec naming the chosen scheme (e.g. `tier-yaml`); a YAML contract declares tier-0 (auto), tier-1 (supervised), tier-2 (manual) with predicates over Bash command shapes and MCP tool names; a generator script emits a `.claude/settings.json` permissions allowlist from the YAML contract for tier-0 entries; running the generator against this repo produces a settings file equivalent to a hand-verified baseline; recall of "agent policy" returns the new adapter metadata, not only the AGENTS.md prose.
Notes: The Agent Policy slot (Component 8) is currently filled by ad-hoc prose in AGENTS.md, so every adopter project re-derives the same allowlist judgments in `.claude/settings.json` and operators field per-command permission prompts as one-off decisions during chat sessions — the structural source of the permission-prompt focus drain. A formal tier model — tier-0 (read-only, idempotent reflective tools; safe to auto-approve), tier-1 (writes to working tree or sandbox; auto-approve in alpha ring, supervised elsewhere), tier-2 (destructive, prod-facing, or human-judgment-required) — collapses those repeated decisions into one parseable contract. The adapter governs a generator that emits per-adopter `.claude/settings.json`, Gitea/GitHub Actions gates, and optional pre-commit hook fragments via the existing hook composer at `instance/source-control-ci/github-and-actions/scripts/install-hooks.sh`. Out-of-scope for v0: cross-adopter policy inheritance, dynamic per-PR risk scoring, telemetry-driven policy adaptation. Unblocks Platform Factory Phase 2 (Agent Proposals → Supervised Autonomy) and removes the per-repo allowlist drift that currently emerges from running `/fewer-permission-prompts` independently in each adopter.
Validation: Added `instance/agent-policy/tier-yaml/` with a Living Spec and `policy.tiers.yaml` contract declaring tier-0/tier-1/tier-2 rules with Bash and MCP predicates; added generator `scripts/generate-claude-settings.py` that emits `.claude/settings.json` allowlist from tier-0; and added baseline check tooling (`scripts/check-baseline.sh` + `baseline/settings.expected.json`) confirming generated settings are equivalent to the hand-verified baseline.

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

## Issue EF-017 — Component 10 (Inference): Azure AI Foundry routing backend
ID: EF-017
Title: Component 10 (Inference): Azure AI Foundry routing backend
Date: 2026-05-24
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Verify with: the inference adapter routes Cognee LLM + embedding calls to an Azure AI Foundry endpoint via LiteLLM (`azure/<deployment>` + AZURE_API_BASE/AZURE_API_KEY/AZURE_API_VERSION); a full Cognee re-graph completes against Foundry; provider is selectable as config. This is the cost gate: once routing is live, cognify bills against a credit-funded Azure subscription rather than direct metered vendor APIs.
Validation: Full 97-file corpus rebuild completed 2026-05-26 against Azure AI Foundry (endpoint fp-llm-gateway.openai.azure.com). LLM: azure/mdl-openai-gpt41mini-std-eus2-r1 (100K TPM); Embedding: azure/mdl-openai-textembed3large-std-eus2-r1 (50K TPM). Cognify completed ("cognify eposforge-sync done"); MCP recall queries return accurate graph answers. Provider routing is env-selectable via INFERENCE_PROVIDER=azure-foundry + COGNEE_REQUIRE_AZURE_ROUTING=1. Budget gate enforces per-repo token limit (budget-policy.json). All billing routed through credit-funded Azure subscription.
Notes: Mechanism only — cloud resource/project provisioning, deployment rate (TPM) caps, and per-repo keys are host/adopter concerns tracked on the host-stack backlog. Cognee uses LiteLLM under the hood, so this is largely an `.env`/config path plus adapter support for an azure backend. Gates the migration's re-cognify steps (EF-019, EF-021).
Resolved: 2026-05-26

## 2026-06




## Issue EF-035 — Version-stamped distribution for file-based-backlog tooling: sync command and drift warning for copy-mode installs
ID: EF-035
Title: Version-stamped distribution for file-based-backlog tooling: sync command and drift warning for copy-mode installs
Date: 2026-06-12
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Validation: VERSION file at 0.2.0 in scripts/; sync-tooling.sh copies scripts idempotently and reports per-file drift; lint-backlog.sh warns on version mismatch when BACKLOG_HOME is set; file-based-backlog.md updated with preferred run-from-clone guidance and sync commands.
Resolved: 2026-06-13
Verify with: the scripts directory under `instance/backlog/file-based-backlog/scripts/` carries a version stamp (`VERSION` file or equivalent); a one-command sync copies the current scripts from a framework clone into an adopter's vendored scripts path, is idempotent on re-run, and reports exactly what changed; `lint-backlog.sh` warns when the vendored copy's stamp is missing or older than a discoverable framework clone's stamp; the usage doc names run-from-clone (`BACKLOG_HOME`, per EF-033) as the preferred zero-copy mode and copy-mode as the supported fallback for repos that must vendor tooling.
Notes: Today backlog tooling reaches adopters by unmanaged mechanical copy: an adopter that never re-copies silently runs old behavior, and nothing detects the drift — so every later improvement to the tooling (ready-work query, portfolio views, new lint rules) lands only where someone remembers to re-copy. Same "works in-tree, silently doesn't travel" failure class as EF-022 (secrets resolver) and EF-032 (skills install); EF-033 (relocatable scripts) creates the preferred run-from-clone escape from copying entirely — this item covers the vendored-copy mode that remains, plus the staleness signal. Sequencing intent: land this (or EF-033) before the rest of the backlog-tooling track so subsequent improvements actually propagate. Adjacency: EF-033 (root discovery; preferred mode), EF-032 (per-surface installer precedent — drift detection via provenance header is the same idea), EF-022 (relocatable-artifact precedent), EF-012 (until this lands, backlog tooling distribution is `partial`).


## Issue EF-036 — Add ready.sh: ready-work query listing open items with no unresolved dependencies
ID: EF-036
Title: Add ready.sh: ready-work query listing open items with no unresolved dependencies
Date: 2026-06-12
Status: resolved
Effort: S
Fix surface: eposforge-pattern
Validation: ready.sh implemented; resolves transitive Depends on: chains across all backlog roots; --json flag emits machine-readable output; items with any open transitive dependency are excluded; open blocker records (EF-042 fix surface: external) are treated as gating dependencies.
Resolved: 2026-06-13
Verify with: `ready.sh` lists items whose `Status:` is `open` and whose `Depends on:` chain (followed transitively, across all backlog roots that `aggregate.sh` discovers, including cross-repo prefixed IDs) contains no item that is still `open`, `in-progress`, `blocked`, or `slated`; `--json` emits a machine-readable form an agent can consume in one call; adding an open dependency to a ready item removes it from the output; items gated by an open blocker record (EF-042 convention) do not appear.
Notes: Borrowed from beads' `bd ready` semantics — the single highest-leverage query the file-based backlog lacks. All required data already exists in `Depends on:` fields plus aggregate.sh's multi-root discovery; this is presentation, not schema. Primary consumers: an operator returning after time away ("what is truly workable now"), and agent sessions that today must read `backlog.md` wholesale and resolve dependency chains in-context (token waste and error-prone). Adjacency: EF-042 (blocker records gate readiness), EF-033 (root discovery), EF-039 (portfolio views build on the same resolution pass — share the dependency-resolution code).


## Issue EF-037 — Add optional Theme field with per-repo vocabulary in config.toml
ID: EF-037
Title: Add optional Theme field with per-repo vocabulary in config.toml
Date: 2026-06-12
Status: resolved
Effort: S
Fix surface: eposforge-pattern
Bundle hint: schema-extension pass with EF-038
Validation: themes = [...] vocabulary added to config.toml and parsed by lint-backlog.sh; absent Theme: is accepted; values outside the vocabulary are a lint error; schema.md documents Theme: with capture-time intent; aggregate.sh parses Theme: for --themes mode (EF-039).
Resolved: 2026-06-13
Verify with: `backlog/config.toml` supports a `themes = [...]` vocabulary (same pattern as `fix_surfaces`); `lint-backlog.sh` accepts an absent `Theme:` and any value from the vocabulary, and rejects values outside it; the schema/usage doc defines the field and the capture-time intent (anchor each new item to a theme at creation so grouping is recorded data, not later inference); `aggregate.sh` parses the field without behavior change (grouping itself is EF-039).
Notes: First of two schema extensions that make portfolio-level review computable. Importance in this system is derived from structure (theme membership + dependency proximity to anchor items), not from a per-item priority number — priority fields rot toward "everything is P1," while derived importance recomputes whenever the graph changes. The capture-time discipline this enables: every new item answers one cheap question — which theme or anchor does this serve? — and items that can't answer it are the rot-detection signal (see EF-040 triage pass). Adjacency: EF-038 (sibling schema extension; bundle), EF-039 (consumer), EF-040 (triage rule).


## Issue EF-038 — Add Supersedes relation with bidirectional lint enforcement
ID: EF-038
Title: Add Supersedes relation with bidirectional lint enforcement
Date: 2026-06-12
Status: resolved
Effort: S
Fix surface: eposforge-pattern
Bundle hint: schema-extension pass with EF-037
Validation: Supersedes: field supported; lint fails when referenced ID is unknown; lint fails when superseded item is still open or in-progress; lint fails when a superseded item lacks the Superseded by: back-pointer; schema.md documents the field and when to use it.
Resolved: 2026-06-13
Verify with: an item may declare `Supersedes: <ID>[, <ID>...]`; `lint-backlog.sh` fails when a superseded item is still `open` or `in-progress` (it must move to `resolved` or `slated`), and fails when a superseded item lacks a `Superseded by: <ID>` pointer line to its successor; the sweep/archive flow preserves both pointers so the lineage survives archiving; the schema doc defines when to supersede (newer item contradicts or replaces an older one) versus when to edit in place.
Notes: Captures "newer items contradict or replace older ones" as durable graph data instead of something the architect re-discovers each review. Detection of supersession candidates is semantic work and stays in the review workflow (EF-040, report-only proposals); this item is only the field and the consistency enforcement, so an accepted proposal becomes one mechanical edit. Mirrors beads' `supersedes` graph link. Adjacency: EF-037 (bundle), EF-040 (proposes these edits), EF-030 (docs-lint detects the same class of staleness in the docs corpus; this is the backlog-side equivalent).


## Issue EF-039 — Portfolio view in aggregate.sh: theme grouping and critical-path ordering to a target item
ID: EF-039
Title: Portfolio view in aggregate.sh: theme grouping and critical-path ordering to a target item
Date: 2026-06-12
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-036, EF-037, EF-038
Validation: aggregate.sh --themes groups open items by Theme: across all roots; unanchored items (no Theme:) are surfaced separately; Bundle hint: clusters are shown within themes; --critical-path <ID> prints the longest dependency chain to the target with workable-now markers; both modes support --json; --mermaid writes backlog/portfolio.md with a flowchart.
Resolved: 2026-06-13
Verify with: `aggregate.sh --themes` groups open and slated items by `Theme:` across all discovered roots, surfaces `Bundle hint:` co-scheduling clusters within each theme, and marks unanchored items (no theme and no `Blocks:` path to any designated anchor item); `aggregate.sh --critical-path <ID>` prints the dependency chain(s) from currently-ready items to the named target in longest-path order, marking which steps are workable now and which are gated (including open blocker records per EF-042); both modes work cross-repo with prefixed IDs and offer `--json`.
Notes: The deterministic half of the architect's portfolio review: grouping and path-finding over data the schema now carries (themes per EF-037, supersession per EF-038, readiness per EF-036). The semantic half — judging contradictions, vision alignment, what is worth doing next — deliberately stays out of shell and lives in EF-040, which consumes this output. "Anchor items" are ordinary backlog items an adopter designates as milestones (typically encoding roadmap value-harvest points), so critical-path computation needs no new construct — the path falls out of the existing `Depends on:`/`Blocks:` graph. Builds on the existing `--plan`/`--graph` modes. Adjacency: EF-036 (shared dependency resolution), EF-041 (rendering of these views), EF-040 (primary consumer).


## Issue EF-040 — Add portfolio-review skill: periodic architect review producing conceptual model, triage, and re-entry briefing
ID: EF-040
Title: Add portfolio-review skill: periodic architect review producing conceptual model, triage, and re-entry briefing
Date: 2026-06-12
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-039
Validation: skills/portfolio-review/SKILL.md written; covers portfolio state gathering, conceptual model, supersession proposals, unanchored triage, vision alignment, re-entry briefing, and edit-application workflow; consumes aggregate.sh --themes / --critical-path / --mermaid and ready.sh.
Resolved: 2026-06-13
Verify with: `skills/portfolio-review/SKILL.md` exists following the skills-placement convention (canonical content under `skills/<name>/`, thin wrapper at `.github/skills/`, per AGENTS.md §Conventions); running it consumes `aggregate.sh --themes --json` and `--critical-path` output plus the adopter's vision and roadmap docs, and produces a report with five sections — (1) conceptual model: theme hierarchy and intent groupings across all roots; (2) supersession/contradiction candidates as proposed `Supersedes:` edits (report-only, never auto-applied); (3) triage: items new since the last run that lack a `Theme:` and a `Blocks:` path to an anchor item, each with a proposed disposition (anchor it, or slate it with a `Re-evaluate by:` date); (4) vision-alignment gaps: anchor items with no inbound paths, and active clusters serving no anchor; (5) re-entry briefing: what is ready now, what each ready item unblocks, and the nearest value-harvest milestone on each path; each run appends a parseable entry to a committed run log (`## [YYYY-MM-DD] review | <summary>`, per the EF-030 pattern).
Notes: The semantic garbage-collector that keeps the corpus from rotting into an unwieldy pool: capture stays low-friction (a fuzzy sense of priority at creation time is acceptable) because this pass recomputes importance from structure and catches what capture missed. The convention it enforces, documented in the backlog usage doc: every new item gets a `Theme:` or a `Blocks:` link toward an anchor item, or it gets slated with a re-evaluate date. Designed for the drop-it-for-weeks workflow — the report is the re-entry point, so understanding the portfolio must not require replaying history. Report-only by design (surgical-changes principle); accepted proposals become ordinary edits. Adjacency: EF-039 (input), EF-038 (edit type it proposes), EF-030 (docs-lint sibling — same periodic-semantic-pass pattern, run log format precedent), EF-041 (diagrams belong in or alongside the report).


## Issue EF-041 — Mermaid portfolio rendering: generated critical-path, theme, and health diagrams
ID: EF-041
Title: Mermaid portfolio rendering: generated critical-path, theme, and health diagrams
Date: 2026-06-12
Status: resolved
Effort: S
Fix surface: eposforge-pattern
Depends on: EF-039
Validation: aggregate.sh --mermaid writes backlog/portfolio.md with a do-not-edit header and a Mermaid flowchart grouped by theme subgraphs with dependency edges; ready items are marked; unanchored items appear in a separate subgraph; renders natively in Gitea/GitHub/VS Code.
Resolved: 2026-06-13
Verify with: a `--mermaid` mode (or companion render script) writes an auto-generated `backlog/portfolio.md` carrying a do-not-edit header (same pattern as `backlog-archive-index.md`) containing three diagrams — a critical-path DAG from ready items to anchor items (gated nodes, including open blocker records, visually distinct), a theme-cluster map across roots with `Bundle hint:` groupings, and a health view (item age vs status, unanchored items, slated items past `Re-evaluate by:`); diagrams render natively in Gitea, GitHub, and VS Code markdown preview with no plugins; regeneration from unchanged backlog data is byte-identical.
Notes: The comprehension surface for the portfolio: the subway map to the adopter's north-star milestones, the implemented-together view, and the rot detector made visible. Mermaid-in-generated-markdown keeps the markdown-as-source-of-truth property — diffable, serverless, reviewable in the forge UI. Stays a pure projection of backlog data: anything the diagram needs that the data lacks is a schema gap (EF-037/EF-038 territory), not a place for renderer-side state. Adjacency: EF-039 (data source), EF-040 (report embeds or links these), existing `aggregate.sh --graph` ASCII mode (kept for terminals).


## Issue EF-042 — Blocker records: external fix-surface convention and lint rule that blocked status requires a recorded cause
ID: EF-042
Title: Blocker records: external fix-surface convention and lint rule that blocked status requires a recorded cause
Date: 2026-06-12
Status: resolved
Effort: S
Fix surface: eposforge-pattern
Validation: external added to fix_surfaces in config.toml; lint-backlog.sh fails any Status: blocked item without at least one open Depends on: item; schema.md documents blocker records with re-check cadence and resolution flow.
Resolved: 2026-06-13
Verify with: the schema/usage doc defines blocker records — non-work constraints (budget, vendor dependency, hardware, waiting-on-external-party) filed as ordinary backlog items with an `external` value in the repo's `fix_surfaces` vocabulary, a re-check cadence stated in `Notes:` (or `Re-evaluate by:` when slated), and resolution recorded via the normal `Validation:`/`Resolved:` flow; `lint-backlog.sh` fails any item with `Status: blocked` whose `Depends on:` does not reference at least one still-open item; `ready.sh` (EF-036) and the portfolio views (EF-039/EF-041) treat open external items as gates on everything downstream of them.
Notes: Closes the head-state gap: today `Status: blocked` is an unexplained assertion, so constraints like a token-budget ceiling live only in the operator's memory and a ready-work query would overstate what is workable. Making blockers ordinary items means zero new machinery — dependency links, critical-path rendering, and sweep-to-archive all work unchanged, and the critical-path view shows the true cost of a blocker as the subtree it gates. Same pattern as beads/Gas Town `gt escalate` (blockers tracked as first-class issues in the same graph as work). The lint rule is the enforcement that gets blockers out of heads and into the system: blocked without a recorded cause is a lint failure. Adjacency: EF-036 (readiness consumer), EF-039/EF-041 (gate rendering), EF-037 (blockers may carry themes like any item).


## Issue EF-043 — Add milestone-elicitation skill: guided discovery of milestones and value-harvest points, written back as anchor items
ID: EF-043
Title: Add milestone-elicitation skill: guided discovery of milestones and value-harvest points, written back as anchor items
Date: 2026-06-12
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Validation: skills/milestone-elicitation/SKILL.md written; covers prior-context loading, phase-exit interview, theme interview, anchor proposal/confirmation, prior-deferred-proposal check, anchor backlog item authoring, and elicitation record format; re-run behavior described; elicitation records stored at backlog/elicitation-records/<date>-elicitation.md.
Resolved: 2026-06-13
Verify with: `skills/milestone-elicitation/SKILL.md` exists following the skills-placement convention (canonical content under `skills/<name>/`, thin wrapper at `.github/skills/`, per AGENTS.md §Conventions); invoking it in an agent chat session (a) grounds itself in the adopter's vision and roadmap docs plus the current aggregated backlog, (b) conducts a structured interview proposing candidate milestones framed strictly as value-harvest points — each candidate states what value is realized, for whom, and the observable signal that the value is real (not "progress made" but "benefit usable") — ordered nearest-first, (c) asks the architect to confirm, reorder, merge, or reject candidates with batch questions rather than one-at-a-time, and (d) on explicit confirmation writes each accepted milestone as an anchor backlog item via the standard tooling (`new-issue.sh` where runnable, hand-formatted to schema otherwise), with the harvest rationale recorded in the item's `Notes:`; when an accepted milestone has no home in the roadmap docs, the skill proposes the roadmap edit report-only (surgical-changes principle) instead of editing; each run commits a structured elicitation record under the skill's directory capturing every candidate with its disposition — accepted (with the anchor item ID it became), rejected (with the architect's stated reason), or deferred (with the trigger to revisit) — plus the architect's key interview answers in their own words, headed by a parseable entry (`## [YYYY-MM-DD] elicitation | <summary>`, per the EF-030 pattern); a subsequent run loads prior records and does not re-propose a rejected candidate unless it states what changed since the rejection; nothing is written without the explicit yes (EF-031 confirm-gate precedent).
Notes: Bootstrap counterpart to EF-040: the portfolio-review skill maintains an anchored backlog, but assumes anchors exist; this skill establishes them through guided discovery, because knowing where the milestones and value-harvest opportunities are is itself judgment work the architect does in dialogue, not data sitting in any file. Interview shape (seed, refine in implementation): walk the roadmap's phase exits and ask which represent harvestable value versus internal progress; for each active backlog theme ask "if everything in this cluster landed tomorrow, what could you do that you can't today, and would you bother?"; hunt for nearer harvest points hiding inside far milestones (the smallest increment someone would actually use). Re-runnable: subsequent runs diff against existing anchors *and prior elicitation records* (the rejection/deferral memory — without it, every re-run would re-propose what the architect already declined) and propose additions/supersessions rather than starting over, so the milestone map evolves as the vision does. The elicitation records are the durable home for interview answers: accepted rationale also lands distilled in each anchor item's `Notes:` (graph-visible), while rejections, deferrals, and the architect's own phrasing live only in the records — they are decision data, not chat exhaust, and must not depend on transcript capture (EF-023/EF-024) existing. Anchors written are ordinary items per the EF-039 anchor convention — no new construct. Adjacency: EF-040 (maintenance sibling; its triage rule needs these anchors), EF-039 (critical-path destinations), EF-038 (anchor supersession on re-run), EF-031 (confirmation-gate pattern), EF-030 (run-log format), EF-011 (skill docs speak at the adopter's adoption layer).

## Issue EF-047 — Restore and enforce the public/private backlog boundary (no public→private references)
ID: EF-047
Title: Restore and enforce the public/private backlog boundary (no public→private references)
Date: 2026-06-16
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Theme: backlog-tooling
Validation: Phase 1 — all tabled leaks removed/genericized in the eposforge backlog (the EF-032 `Blocks:` line deleted with the reverse edge preserved on the private side, including a newly-added reverse edge on the second adopter item; host path genericized in EF-026/EF-027/EF-028; EF-022 named-adopter wording generalized; EF-023/EF-024 sanitized in place; prose private-ID references genericized); an independent grep shows zero private markers. Phase 2 — `visibility` declared in all six configs (eposforge=public); `lint-backlog.sh` builds a prefix→visibility map and ERRORs on a public→private/unknown cross-repo edge (single-root degradation documented), plus a blocking whole-file leak scan over active/slated/archive (private-repo item-ID references resolved via the map, host paths, `.lan`, private IPs); `lint-backlog.sh --help` documents the rule + degradation. Verified: eposforge lints clean across all roots; a re-introduced public→private `Blocks:` edge and seed prose/header leaks all fail (exit 1); bare words and non-backlog tokens do not false-positive. Context-aware semantic complement split out as EF-048.
Resolved: 2026-06-16
Verify with: PHASE 1 (restore) — no `^Blocks:`/`^Depends on:` field in any public-repo (framework) item names a private adopter ID (the EF-032 `Blocks:` line pointing at two adopter (private-repo) IDs is removed, losslessly — the adopter side already declares `Depends on: eposforge:EF-032`, and the second adopter item gains the same reverse edge); the absolute private host path to an adopter's reference-architecture diagram in EF-026/EF-027/EF-028 is genericized; the named-adopter example in EF-022 is generalized to adopter-neutral language; the EF-023/EF-024 adopter-LAN-scoped titles are resolved by an explicit recorded decision (sanitize-in-place as a framework pattern OR relocate to the adopter backlog as adopter-prefixed items). PHASE 2 (enforce) — each `config.toml` declares `visibility = "public" | "private"` (eposforge=public; adopters=private; unset treated as private/fail-safe); `lint-backlog.sh`, given multi-root context, builds a prefix→visibility map and ERRORS when a public-repo item carries a cross-repo `Depends on:`/`Blocks:` edge to a private (or unknown) prefix, with a documented single-root degradation (any outbound foreign edge from the sole public repo is flagged); a whole-file leak scan ERRORS (not merely warns — architect directive 2026-06-16: a public repo must leak nothing whatsoever) on any private marker — a reference to a private-repo backlog item (an ID-shaped `PREFIX-NNN` token whose prefix resolves to a private repo via the visibility map, the right level of abstraction rather than guessed adopter-name tokens), or a private host path, `*.lan` hostname, or private IP — found anywhere in a public repo's active/slated/archive files, including file headers and operational notes, not just issue bodies; re-introducing a `Blocks: <private>:<ID>` to a framework item makes lint exit non-zero, and after Phase 1 the lint passes clean across all roots.
Notes: Filed 2026-06-16 during portfolio-review. The publishable framework repo's backlog leaks adopter internals — a structural `Blocks:` edge into adopter (private-repo) IDs (EF-032), an absolute private host path (EF-026/EF-027/EF-028), adopter-LAN item scope (EF-023/EF-024), and a named-adopter example (EF-022). Rule ratified by the architect 2026-06-16: public/publishable repos must never reference non-public backlog items; cross-repo edges are directional, declared on the private side only (`<private> Depends on: <public>:<ID>`). This is the backlog-layer face of EF-011's framework-vs-adopter conflation boundary; see memory `project-public-backlog-no-private-refs`. Two separable halves: Phase 1 restores (mechanical, git-reversible cleanup — EF-023/EF-024 carry an open sanitize-vs-relocate decision and must not be executed blind), Phase 2 enforces via a `visibility` config flag + a lint rule so it can't regress. Discipline modeled in this very item: literal private IDs are kept out of its own formal edge fields and named descriptively instead. Full plan: `backlog/plans/EF-047-public-private-backlog-boundary.md`. Out of scope: a wider audit of the same public→private rule across the rest of the `eposforge` repo (specs, AGENTS.md, runbooks) is a separate, non-backlog-scoped effort. Adjacency: EF-011/EF-012 (same boundary, spec-graph layer), EF-046 (sibling backlog-tooling change; sequence either order), EF-032 (the structural-edge leak this removes).
Resolution (2026-06-16): Phase 1 executed — EF-032's `Blocks:` line removed (the reverse `Depends on: eposforge:EF-032` was already declared on one adopter item and added to the second, so the relationship is preserved on the private side); the absolute host path genericized to "an adopter's reference-architecture diagram" in EF-026/EF-027/EF-028; EF-022's named-adopter wording generalized; and prose private-ID references (an adopter client-side shim in EF-026, an adopter Component-11 backend stack in EF-027) genericized. EF-023/EF-024 decision: **sanitize-in-place** (architect, 2026-06-16) — they are a framework chat-event/observability contract that EF-027 (C14), EF-028 (C15), and EF-034 depend on (EF-028 carries a hard `Depends on: EF-023, EF-024`), so relocating them to an adopter backlog would invert the framework→adopter dependency and create a worse public→private edge; the adopter-LAN scoping in their titles and verify-with was rewritten to vendor-neutral "the adopter's LAN"/"adopter-LAN-hosted" wording. Phase 2 executed — `visibility` declared in all six configs (eposforge=public, adopters=private; unset treated as private/fail-safe); `lint-backlog.sh` builds a prefix→visibility map across roots and ERRORs on a public→private/unknown cross-repo edge (single-root degradation: any outbound foreign-prefix edge from the sole public repo is flagged), plus a blocking whole-file leak scan (ERRORS) over active, slated, AND the also-public archive — file headers/notes included, not just issue bodies — for references to private-repo backlog items (ID-shaped tokens resolved against the visibility map, so it generalizes to any prefix and never false-positives on prose like "UTF-8" or a bare name) plus private host paths / `*.lan` / private IPs (architect directive 2026-06-16: a public repo must leak nothing whatsoever, so this blocks rather than warns; the stale adopter-named header note that this scan caught was genericized); rule + degradation documented in `lint-backlog.sh --help`. The deterministic lint is a FLOOR, not the whole guard: context-aware detection of references to private backlogs/repos in prose (a semantic judgment a regex cannot make) is split out as EF-048.

## Issue EF-053 — Name the stabilization kernel + paired-detection as a first-class pattern primitive (foundation-trust axis, distinct from product-promotion)
ID: EF-053
Title: Name the stabilization kernel + paired-detection as a first-class pattern primitive (foundation-trust axis, distinct from product-promotion)
Date: 2026-06-25
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Theme: resilience
Verify with: a new cross-cutting concept doc under `01-architecture/` (e.g. `04-stabilization-and-kernels.md`, cross-referenced from `01-reference-architecture.md`) defines (1) the two-property KERNEL — an element is a kernel only when it is BOTH *stable* (pinned/source-controlled, does not change under you) AND *detectable* (its continued goodness is confirmable in ONE command — a smoke/hard-gate); stability alone is named explicitly as "code you haven't broken yet", not a kernel; (2) the three states kernel / candidate-kernel / not-a-kernel; (3) the BOOTSTRAP RULE — a complex layer's autonomy may be trusted only once the layers beneath it are kernels (build/trust upward only), with Gall's Law (construction order) and Lehman's Laws (entropy rises without deliberate negentropy work) cited as the two axes this primitive sits at the intersection of; (4) the EXTERNAL-tier carve-out — frontier-model/vendor APIs are inherently un-kernelable (they change under you and cannot be pinned) and must be wrapped by C10/Adapters with their own detection, never trusted as foundation. A new standard under `04-standards/` states the PAIRED-DETECTION rule as a sibling to the existing paired-change rules: every fix ships a cheap, re-runnable, one-command check that proves it (the negentropy input Lehman requires) — and is explicitly framed as the foundation-layer cousin of EF-051's products-layer ungameable gate (same detection principle, different layer/altitude). The concept doc contains a RECONCILIATION section that nets the framework down to exactly TWO orthogonal stability axes and says so: foundation-trust (kernel state + bootstrap order, governs the substrate/control layers) vs product-promotion (maturity phases + release rings, governs C-tier products) — with kernel-state expressed as the maturity model APPLIED to infrastructure layers (gate = detection added), NOT a parallel taxonomy, and any stabilization layer-numbering declared a DERIVED view, never a second mandatory axis stacked on the functional Logical Tiers (the doc must warn these two layerings are routinely confused). `03-autonomy-modes.md` gains the LOOP-A-vs-LOOP-B distinction: adding detection (self-hardening) to ANY layer is valid work NOW and is not gated by bootstrap order; trusting a layer's AUTONOMY (draining the backlog) is gated by the layers beneath being kernels — this is what dissolves the "harden X vs demote X" contradiction. A recall query about "kernel", "what can I build on", "smoke gate", "stable foundation", "why does my self-improving system keep grinding", "Gall's Law", or "Lehman" returns this primitive — and recall distinguishes the foundation-trust axis from release rings rather than conflating the two.
Notes: Surfaced from an adopter's 2026-06-25 dark-factory retrospective: the operator hit a compounding grind ("use a broken tool to fix a broken tool") trying to run an autonomous orchestrator (Loop A) over a substrate that had never been stabilized — premature autonomy with no working-simple system beneath it, i.e. the Gall failure mode, persisted by Lehman drift leaking in unnoticed because nothing detected it. Diagnosis landed on a missing PRIMITIVE: the pattern measures *product* readiness (maturity phases + release rings) but has no name for "what an agent/operator is allowed to build ON" — the foundation. Pinning was already happening; the gap was never stability, it was DETECTION. This item promotes that doctrine from a worked instance (it currently lives buried inside one adopter's C4/orchestrator runbook) up to a reusable, framework-level concept + standard, and — critically — reconciles it with the stability vocabulary the pattern ALREADY has so promotion does not add a third overlapping stabilization story (functional tiers + maturity + rings + a new kernel/layer taxonomy = doc-level entropy, which would be self-refuting given the source). Distinct from neighbors, not duplicative: EF-051 owns the products-layer ungameable definition-of-done gate; EF-053 generalizes the *detection-is-the-missing-half* principle across ALL layers and adds the foundation-trust + bootstrap-order concepts EF-051 does not cover (EF-051 is one instance of EF-053's paired-detection rule at the C-tier). EF-050 (rubrics) is the graded complement to deterministic gates — orthogonal. EF-012 (maturity tagging: shipped/partial/intent) is the precedent the kernel-state should reuse rather than re-invent — candidate→kernel is maturity tags applied to substrate. Keep all guidance at the adopter adoption layer, not framework-internal `instance/...` paths (EF-011). The adopter-side instance work (the host-specific layer assignment table + thinning the origin runbook to a linked worked example) is tracked in that adopter's own (private) backlog and depends on this item shipping the canonical concept. Adjacency: EF-051 (the products-layer ungameable gate — EF-053 is the cross-layer generalization of its detection principle; EF-051 becomes one instance of the paired-detection rule), EF-050 (rubrics — graded complement, orthogonal axis), EF-012 (maturity tagging — kernel-state reuses this, candidate→kernel = maturity applied to substrate; also the why behind "detection prevents acting on confident-wrong state"), EF-029 (compensating-control framing — detection is the negentropy/compensating input when prevention is weak), EF-052 / EF-014 (C7/C8 — the substrate guardrails whose maturity the bootstrap rule reasons about), C4 Orchestrator (Loop A autonomy is the thing the bootstrap rule gates), C9 / C11 (where one-command gates and their audit live), EF-011 (adopter-layer phrasing, not framework-internal paths).
Validation: Shipped + ratified the doctrine as pattern artifacts (committed). Concept doc `01-architecture/04-stabilization-and-kernels/stabilization-and-kernels.md` (two-property kernel + "code you haven't broken yet", three states, bootstrap rule with Gall/Lehman, External-tier carve-out, the two-axes reconciliation) and standard `04-standards/09-paired-detection/paired-detection.md` (7 normative requirements, framed as the foundation-layer cousin of EF-051) both at `maturity: adopted`; `01-architecture/03-autonomy-modes/autonomy-modes.md` gained the Loop-A-vs-Loop-B section; cross-referenced from `01-reference-architecture.md` and listed in `04-standards/README.md`. Verify-with clauses 1–4 satisfied by these docs. Clause 5 (a recall query returns the primitive and distinguishes foundation-trust from release rings) is the operational spec-graph-ingest half — incremental ingest is not wired and the distinguish-not-conflate property is an EF-012-class answer-quality concern — so it is carved out to EF-054 rather than blocking the doc deliverable. Adopter instance landing (host kernel map + runbook thinning) is tracked in that adopter's own private backlog.
Resolved: 2026-06-26

## Issue EF-054 — Ingest the stabilization/kernel docs into the spec graph so recall returns the primitive (EF-053 clause 5)
ID: EF-054
Title: Ingest the stabilization/kernel docs into the spec graph so recall returns the primitive (EF-053 clause 5)
Date: 2026-06-26
Status: resolved
Effort: S
Fix surface: eposforge-pattern
Theme: spec-graph
Depends on: EF-053
Verify with: after a spec-graph refresh (Component 6 / cognee-sync) that ingests `01-architecture/04-stabilization-and-kernels/stabilization-and-kernels.md`, `04-standards/09-paired-detection/paired-detection.md`, and the new Loop-A-vs-Loop-B section of `01-architecture/03-autonomy-modes/autonomy-modes.md`, a recall query for any of "kernel", "what can I build on", "smoke gate", "stable foundation", "why does my self-improving system keep grinding", "Gall's Law", or "Lehman" returns the kernel primitive (two-property definition + bootstrap rule); AND the returned answer distinguishes the foundation-trust axis (kernel state + bootstrap order) from the product-promotion axis (release rings + maturity) rather than conflating them.
Notes: Carved out of EF-053 (its Verify-with clause 5). EF-053 shipped and ratified the doc deliverables; this item tracks the separate operational concern of making them queryable. Two reasons it is its own item, not an EF-053 sub-step: (1) incremental graph ingest is not wired in this stack, so the new files become queryable only on a (currently manual / full) reindex — a different kind of work from authoring the docs; (2) the "distinguish foundation-trust from release rings, don't conflate" requirement is an answer-quality property of recall, the same class EF-012 owns (graph emits design intent / conflates layers), so satisfying clause 5 fully may depend on EF-012 progress rather than on this ingest alone. Keep recommendations at the adopter adoption layer, not framework-internal `instance/...` paths (EF-011). Adjacency: EF-053 (source — the docs this ingests; resolved), EF-012 (the distinguish-not-conflate answer-quality property this leans on), EF-011 (adopter-vs-framework conflation in recall answers), C6 Spec Graph (the ingest target).
Validation: Minted the kernel vocabulary in `00-vision/01-ontology.ttl` (5-term cluster: ef:Kernel, ef:DetectionRatchet, ef:BootstrapRule [Tenet], ef:FoundationTrust, ef:ProductPromotion; Gall/Lehman/Loop-A-B folded into variants+comments per the doc's reduce-don't-grow mandate). Full KG wipe + bulk rebuild (115 docs, two-pass; ontology-anchored, 71 nodes ontology_valid). Recall verified against all clause-5 probes — "kernel"/"what can I build on" returns the two-property definition + candidate-kernel state + bootstrap rule; "why does my self-improving system keep grinding" returns the Gall/Lehman synthesis; and the distinguish-not-conflate clause holds: recall names foundation-trust (kernel state + bootstrap order) and product-promotion (maturity + release rings) as "orthogonal and independent" axes rather than conflating them.
Resolved: 2026-06-26
