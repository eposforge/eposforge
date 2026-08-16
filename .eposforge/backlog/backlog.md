# Backlog

Active issues (`open`, `in-progress`, `blocked`) for this repo.

> **NEXT BUILD — EF-066** (designated 2026-07-24). Take EF-066 (strangler-tracking
> schema) before other work, so the next things built converge on the target
> architecture instead of diverging. This is an ordering decision by the architect,
> not a dependency: EF-066 carries no `Depends on:` and `ready.sh` sorts only by
> `(Effort, ID)`, so the tooling will keep listing it mid-pack at `[M]` — that is
> expected, this note is the authority. Portfolio-review 2026-07-24 found ~11
> concurrent unlabeled migrations across the roots (the live cost: an adopter has
> slated an orchestrator-platform migration while five of its open items still
> invest in the legacy shape — adopter IDs stay in the adopter's own backlog per
> EF-047).
> Two open questions to settle at build time, not yet decided: (1) whether to
> retarget the dogfood proof from `numbered-to-named-components` (nearly complete)
> to `theme-to-tags` (live, public, exercises the "do not invest" marker); (2) how a
> migration whose legacy shape is diffuse corpus state rather than an item — e.g.
> theme-to-tags' 145 remaining `Theme:` lines — satisfies the "at least one
> legacy-shape item" lint rule. Also note EF-066's "lint passes across all roots"
> criterion needs a per-root loop to evaluate at all: `lint-backlog.sh` only ever
> checks the FIRST entry in `BACKLOG_ROOTS`, so a single invocation reporting
> "backlog lint: OK" says nothing about the other roots. As of 2026-08-15 every
> root in the reference deployment lints clean, but the criterion should be
> restated in terms of the loop before it is used as a gate.

Tooling track EF-035–EF-043 resolved 2026-06-13. Portfolio-review (EF-040) pass executed 2026-06-28 (cross-repo theming, substrate linking to adopter anchors via Depends on:/Blocks:). EF-045 (DCO + SSH signed commits for Phase 0) resolved 2026-06-28. Phase 0 architecture evolution (EF-056 master + children 057/058+) now tracking multi-graph, independent backlog graph, and boundaries (see docs/implementation-plan... and capture). EF-046 (Tags) and EF-047 (public/private) advanced as closely-related backlog-tooling work. EF-059/060 filed for the `.eposforge/` container uniformity correction (replaces `eposforge/` in adopters and `.eposforge/` in framework); public plan at `backlog/plans/EF-059-dot-eposforge-container-uniformity.md` (detailed private execution in primary adopter backlog). This continues the layout-mirror / terminology thread from EF-056/058.

## Issue EF-056 — Multi-graph + independent file-based backlog graph + adopter boundaries evolution (Phase 0 alignment & strangler tracking)
ID: EF-056
Title: Multi-graph + independent file-based backlog graph + adopter boundaries evolution (Phase 0 alignment & strangler tracking)
Date: 2026-06-28
Status: open
Effort: L
Fix surface: eposforge-pattern
Tags: backlog-tooling, spec-graph
Verify with: a top-level EF- item exists in active backlog referencing the four capture/plan files (the adopter architecture implementation plan and discussion capture, boundaries-layers-2026-06.md, adapter-layout-mirror.md); 4–6 child EF- items created for major threads (backlog graph independence/ingestion boundaries, multi-graph foundation for first adopter, targeted layout mirroring, agent grounding + policy, sync reliability/verification, terminology); the capture/plan files are updated with EF- references and "planning only" notes removed or marked "Phase 0 in progress"; portfolio-review run surfaces the evolution as a theme; terminology uses generic "Adopter Platform Spec repo" (no specific adopter identifiers) vs "Platform Instance"; first concrete (EF-057) started (explicit exclusion of raw backlog items from main Spec Graph). All changes tracked via the backlog's own graph.
Notes: Phase 0 of the strangler-fig rollout for the 2026-06 architecture alignment (captured in the four files). Master item owns visibility and sequencing. Cross-cutting: (a) bake strangler/Migration/legacy-shape/target-shape concepts into backlog schema so agents using GraphRAG tooling can drive such evolutions — **carved out to EF-066 for independent delivery** (schema is decided; do not gate it behind the multi-graph GraphRAG work here); (b) any new agent/skills work follows AGENTS.md + 04-standards/08-agent-coding-guidelines and ships SKILL.md; (c) update the four files only for design state. Children will be filed for the threads. Adjacency: EF-011/012 (recall boundaries), EF-046/047/048 (backlog graph quality), EF-040 (portfolio visibility), EF-066 (strangler-tracking schema, carved from cross-cutting (a)).





## Issue EF-066 — Strangler-tracking backlog schema: make in-flight migrations legible to agents (Migration/LegacyShapeOf/TargetShapeOf)
ID: EF-066
Title: Strangler-tracking backlog schema: make in-flight migrations legible to agents (Migration/LegacyShapeOf/TargetShapeOf)
Date: 2026-07-24
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: backlog-tooling
Verify with: `docs/schema.md` documents three new optional item fields — `Migration:` (a kebab-case migration slug, e.g. `numbered-to-named-components`), `LegacyShapeOf:` and `TargetShapeOf:` (each naming a migration slug), comma-separated in the same style as `Blocks:`; `lint-backlog.sh` validates them (an item carrying `LegacyShapeOf:` or `TargetShapeOf:` names a slug that some other item declares via `Migration:`; a `Migration:` slug resolves to at least one legacy-shape AND one target-shape item; unknown-slug references error) and passes across all roots; `aggregate.sh --strangler` prints one section per migration slug listing its legacy-shape items and its target-shape items, plus an "unlabeled candidates" hint (items whose text matches migration-shape keywords but carry no `Migration:` field); a debt-visibility surface exists so an agent reading an item flagged `LegacyShapeOf:` sees a one-line "this shape is being strangled toward <slug> — do not invest" marker (agent-grounding doc or a lint advisory, per AGENTS.md conventions); the Living Spec `version` bumps and its command list reads `--strangler`; and the framework's OWN numbered-component-folder → name-based-component migration is encoded end-to-end as the dogfood proof (the resolved EF-044/EF-059/EF-060 items backfilled with `Migration: numbered-to-named-components` + shapes), so `aggregate.sh --strangler` renders at least that one migration correctly.
Notes: Carved out of EF-056 cross-cutting thread (a) so it ships independently — the schema is a decided design, not an empirical unknown, so per "spike the unknowns, not the knowns" it should be placed directly rather than gated behind the multi-graph/GraphRAG build EF-056/EF-057 own. Motivation: several migrations run concurrently across the framework and its adopters (orchestrator platform re-expression, component-folder rename, backlog schema evolution, source-adapter multi-sourcing, execution-sandbox confinement, autonomous-loop replacement, store-backend swaps), but each one's legacy→target intent lives only in free-text `Notes:`, invisible to building agents and to GraphRAG recall. The observable symptom of that invisibility: effort gets sunk into a legacy shape (e.g. tuning an orchestrator subsystem) while a target shape is actively replacing it, because nothing structured told the agent "this is being strangled." This item ships the create-side contract (fields + lint + `--strangler` view + debt marker); adopters then backfill their own in-flight migrations in their own backlogs (adopter-specific migration IDs stay in the adopter's repo, not here — public/private boundary per EF-047). Field semantics stay strictly distinct from dependency edges: `Migration:`/`LegacyShapeOf:`/`TargetShapeOf:` are associative migration-membership edges, NOT `Depends on:`/`Blocks:` (which continue to drive critical-path ordering). Adjacency: EF-056 (parent; this is thread (a)), EF-046 (sibling associative-field schema evolution — mirror its lint/aggregate/schema.md/version surface area), EF-047/048 (keeps adopter migration IDs out of the public backlog), EF-040 (portfolio-review should surface migrations as a class).





## Issue EF-057 — Explicit ingestion boundaries + minimal GraphRAG layer for independent backlog graph (Phase 1 pilot)
ID: EF-057
Title: Explicit ingestion boundaries + minimal GraphRAG layer for independent backlog graph (Phase 1 pilot)
Date: 2026-06-28
Status: open
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-056
Tags: backlog-tooling, spec-graph
Verify with: bulk-rebuild.sh, update-spec-graph skill, post-commit hook, and cognee.md exclude raw `backlog/*.md` / `.eposforge/backlog/*.md` (and plans/) from main eposforge-sync Spec Graph by default while still allowing ontology-level references to backlog *mechanics*; aggregate.sh + portfolio-review + ready.sh continue to provide GraphRAG-style views (themes, critical path, unanchored, mermaid) over the file-based markup (nodes from issues, edges from Depends/Blocks, communities from Tags); a new or extended skill can be invoked by agents for backlog-specific traversals without raw multi-repo file RAG; pilot on this repo + one adopter; separate from main graph (backlog items never in C6).
Notes: First concrete delivery toward independent file-based backlog graph. Keeps core data pure markdown (portable). Tooling layer provides the RAG/Graph features. See capture for "where the capability lives". Adjacency: EF-056, EF-046/047 (explicit graph quality), EF-030 (lint as companion), EF-011 (conflation fix via boundaries).





## Issue EF-058 — Terminology + repository roles & ownership section (Adopter Platform Spec vs Platform Instance)
ID: EF-058
Title: Terminology + repository roles & ownership section (Adopter Platform Spec vs Platform Instance)
Date: 2026-06-28
Status: open
Effort: S
Fix surface: eposforge-pattern
Depends on: EF-056
Tags: spec-graph
Verify with: a short "Repository roles & ownership" section exists (under 00-vision/ or 01-architecture/02-components/); the model is stated that the adopter has a single primary repo (the Adopter Platform Spec) that contains documentation about the overall eposforge implementation for both product and platform factories plus the `eposforge/` slice, and that portfolio reviews happen there; generic terminology ("Adopter Platform Spec repo") is used consistently (no specific adopter identifiers or private host names); EposForge instructs adopters to set it up this way; Living Spec contract notes the distributed-corpus reality; no change to single SPEC.md rule for ordinary deliverables.
Notes: Reduces conflation. The primary repo (Adopter Platform Spec) is the place for overall documentation and portfolio reviews. Part of Phase 0 alignment. Adjacency: EF-056, boundaries capture, 00-vision/01-ontology.ttl, adapter-layout-mirror.

**Section created**: `00-vision/02-roles-ownership.md` (satisfies the primary verify bullet for EF-058). Terminology and model now documented in dedicated file + propagated to plan/capture/layout/skill. Ready for terminology fixes in ontology (next step before rebuild).





## Issue EF-022 — Make epos-secrets a relocatable resolver (decouple vault location from script location)
ID: EF-022
Title: Make epos-secrets a relocatable resolver (decouple vault location from script location)
Date: 2026-05-24
Status: open
Effort: S
Fix surface: eposforge-pattern
Tags: secrets
Verify with: a single `epos-secrets` (owned by EposForge, on PATH) resolves secrets against a vault that lives in a *different* repo when `EPOS_SECRETS_HOME` points at that repo's `secrets-key-management/` dir; no duplicated copy of the script in the adopter repo; `vault_key` aliasing and the `sensitivity` field still work; with `EPOS_SECRETS_HOME` unset, behavior is unchanged (script-relative discovery, backward compatible).
Notes: Today the resolver discovers its manifests + vault relative to its own script path (`_SCRIPT_DIR.parent` → `sops-age/secrets.enc.yaml`), so it cannot point at a vault elsewhere. During an adopter's single-vault migration (2026-05-24) this forced copying the whole adapter — including `bin/epos-secrets` — into the adopter repo, producing two divergent copies of the script (the `vault_key` enhancement had to be hand-applied to both). Fix: add an `EPOS_SECRETS_HOME` (or `EPOS_VAULT`) env var / small config that sets the manifest+vault root, defaulting to the current script-relative path. Then one EposForge-owned resolver on PATH serves the adopter's vault, and the adopter repo holds only data (vault + manifests), not code. Directly addresses the "no stable installable artifact" gap called out in EF-012 and the adopter-path conflation in EF-011 (mode-B consume-without-fork adopters need a resolver they can invoke without an EposForge clone). Follow-up after this lands: collapse the duplicated adopter copy back to a symlink/PATH reference.












## Issue EF-023 — Capture cross-IDE agent chat logs inside the adopter's LAN for semantic memory and future distillation
ID: EF-023
Title: Capture cross-IDE agent chat logs inside the adopter's LAN for semantic memory and future distillation
Date: 2026-05-25
Status: open
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-017
Tags: observability
Verify with: for both Claude Code and GitHub Copilot sessions, chat transcripts (prompts, assistant responses, tool traces metadata, and session identifiers) are persisted to an adopter-LAN-hosted storage target with a documented retention policy; records include stable account identity and machine identity fields so sessions from the same Claude/Copilot account across different dev machines are correlated into one logical timeline; a semantic index job can ingest new transcripts incrementally and answer recall queries over both IDE sources in one result set; access controls enforce LAN-local storage + operator-only retrieval/export; a dry-run dataset can be exported in a training-ready JSONL format for future fine-tuning/distillation experiments without changing source-of-truth raw logs. Implementation bootstrap exists in `.scratchpad/build-unified-chat-index.py` (index build) and `.scratchpad/search-unified-chat-index.py` (semantic prefilter/search scaffolding).
Notes: User-story intent: while EposForge is pre-dark-factory and developers still use heterogeneous IDE adapters, conversation exhaust should not remain fragmented across vendor clouds or local workstation silos. Implement an adapter-agnostic chat capture contract (normalized event schema + source adapter field), then add per-adapter collectors for Claude Code and Copilot. Keep raw immutable logs plus derived semantic chunks as separate layers. Include identity provenance fields (provider account key + machine key + workspace key) to support cross-machine continuity for one developer account. Include privacy/safety guardrails (PII redaction mode, secret-token scrubbing, and explicit opt-in boundaries for any downstream training export). Seed artifacts now live in `.scratchpad/unified-chat-index.jsonl` with extraction support from `.scratchpad/export-claude-session-md.py`. This issue is the observability + memory substrate needed to support semantic search now and potential model distillation later.
Execution update (2026-08-14): the **capture-contract half** is delivered by EF-073 (Interaction Capture slot) plus EF-024 Track 1 (`04-standards/13-chat-event-schema/`). Search / recall and training-export remain open on this item (they are readers of the store, not the store). Redaction is at export, not capture, with a capture-time repo denylist as the only extra omit-path.












## Issue EF-024 — Implement EF-023 in four delivery tracks (schema, collectors, indexing, query/policy)
ID: EF-024
Title: Implement EF-023 in four delivery tracks (schema, collectors, indexing, query/policy)
Date: 2026-05-25
Status: open
Effort: L
Fix surface: eposforge-pattern
Depends on: EF-023
Tags: observability
Verify with: all four tracks are implemented and validated end-to-end in staging on the adopter's LAN: (1) canonical chat-event schema with versioning, source adapter attribution, and account/machine correlation identifiers; (2) collector adapters for Claude Code and GitHub Copilot writing immutable raw logs to LAN-local storage from multiple developer machines under the same account; (3) incremental semantic indexing pipeline that tracks high-water marks and supports replay/rebuild; (4) operator-facing semantic query/retrieval interface with role-based access control, auditable export path, and policy enforcement for redaction/training eligibility tags.
Notes: Delivery split for execution sequencing.
Track 1 (schema contract): define a normalized event model that can represent prompts, assistant responses, tool events, token/cost metadata when available, session/workspace identifiers, adapter provenance, and correlation identity fields (provider account id surrogate + machine id + workspace id). Include schema_version and backward-compatible migration rules.
Track 2 (adapter collectors): implement per-IDE ingestion adapters that map native logs into Track 1 schema and append to immutable raw store. Ensure idempotent ingest (dedupe key), failure-safe retry semantics, and multi-machine ingestion under one provider account without duplicate replay. Current prototype entrypoint: `.scratchpad/build-unified-chat-index.py`.
Track 3 (semantic indexing): build chunking + embedding + index-write pipeline over normalized events, with incremental ingest cursoring, reindex support, and source-level filtering (Claude/Copilot/both). Current local retrieval helper: `.scratchpad/search-unified-chat-index.py`.
Track 4 (query + policy): expose semantic recall over indexed chat memory with strict LAN-only serving, operator authz, export controls, and explicit policy gates separating searchable memory from training-candidate exports.
Execution update (2026-08-14): **Track 1 delivered** as `04-standards/13-chat-event-schema/` (markdown + JSON Schema 2020-12, `schema_version` 1.0, migration rules, `training_eligible` tagging, `dedupe_key` constructions). Tracks 3–4 stay open (readers). Track 2's public contract is the schema; adopter-side collectors are out of this repo.









## Issue EF-030 — Add docs-lint skill: periodic semantic health check for the Markdown corpus (Karpathy LLM-Wiki "lint" operation)
ID: EF-030
Title: Add docs-lint skill: periodic semantic health check for the Markdown corpus (Karpathy LLM-Wiki "lint" operation)
Date: 2026-06-12
Status: open
Effort: M
Tags: backlog-tooling, skills
Fix surface: eposforge-pattern
Verify with: `skills/docs-lint/SKILL.md` exists following the skills-placement convention (canonical content under `skills/<name>/`, thin wrapper at `.github/skills/docs-lint/SKILL.md` — see AGENTS.md §Conventions); running the skill over the spec layer (`00-vision/` through `04-standards/`) plus `AGENTS.md` and `backlog/` produces a findings report classifying each finding as one of contradiction | stale-claim | orphan-page | missing-cross-reference | broken-pointer; each run appends a parseable entry to a committed run log in the skill's directory (format `## [YYYY-MM-DD] lint | <summary>`, per the upstream pattern) so runs are auditable in git history; the skill detects the seed findings known at filing time — (a) AGENTS.md §Standards points at `04-standards/04-mcp/` and `04-standards/05-canonical-doc-sources/`, neither of which exists on disk; (b) backlog cross-references to EF IDs that have moved to `backlog-archive.md` are flagged with their new location; findings are report-only — the skill MUST NOT auto-edit content (surgical-changes principle, `04-standards/08-agent-coding-guidelines/agent-coding-guidelines.md`).
Notes: Pattern source: Andrej Karpathy's "LLM Wiki" gist, https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f — a three-layer design (immutable raw sources / LLM-maintained Markdown wiki / schema doc) with three operations: ingest, query, lint. EposForge already implements ingest and query via the Spec Graph (Component 6, cognee adapter, `cognee-sync`); **lint is the missing operation**: a periodic agent pass that hunts contradictions, stale claims, orphan pages, and missing cross-references, with append-only parseable log entries (`## [date] lint | <title>`). This skill applies that operation to the file layer, which is the source of truth the graph is built from. Complementary to, not duplicating, `.eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh` — that script is structural (field presence, ID format) and backlog-only; docs-lint is semantic (contradictions, staleness, dangling references) and corpus-wide. Division of labor with the graph: docs-lint runs pre-graph on files; when a finding shows the graph asserting state the files contradict, that divergence feeds EF-011/EF-012 (graph conflation / design-intent-as-present-tense) rather than this skill — docs-lint is the cheap detector for that class of staleness. Live example found 2026-06-12: the spec graph reports an adopted standard at `04-standards/03-agent-skills/agent-skills.md` that does not exist on disk (graph-side fix belongs to EF-012; the file-side detection belongs here). Implementation references: skill layout precedent in `skills/maintain-ontology/` and `skills/update-spec-graph/`; conformance-command style precedent in `04-standards/00-standards-meta/standards-meta.md` §Conformance; frontmatter taxonomy for staleness checks (`doc_kind`, `maturity`, `source_of_truth`) defined in standards-meta; working files go to `.scratchpad/` (gitignored), only the parseable run log is committed. Scheduling: operator-run pre-release initially; CI integration via source-control-ci is a follow-up once the report format is stable. First-iteration scope boundary: spec layer + AGENTS.md + backlog files in scope; `.eposforge/` adapter internals out of scope; graph-side answer-quality fixes out of scope (owned by EF-011/EF-012). Upstream extensions worth reading before implementing (gist comment thread): provenance/conflict tracking and typed contradiction edges — relevant if findings later become graph nodes. Adjacency: EF-011, EF-012 (consume divergence findings), EF-015+ knowledge-tree migration (corpus shape may change; keep target-path config in the SKILL.md, not hardcoded).









## Issue EF-031 — Add refine-prompt skill: technique-driven prompt transformation with slot elicitation and submit confirmation
ID: EF-031
Title: Add refine-prompt skill: technique-driven prompt transformation with slot elicitation and submit confirmation
Date: 2026-06-12
Status: open
Effort: M
Tags: portfolio, skills
Fix surface: eposforge-pattern
Verify with: `skills/refine-prompt/SKILL.md` exists following the skills-placement convention (canonical content under `skills/<name>/`, thin wrapper at `.github/skills/refine-prompt/SKILL.md` — see AGENTS.md §Conventions); at least one technique definition exists under `skills/refine-prompt/techniques/` with the frontmatter contract (`name`, `summary`, `applies-when`, `slots` with required/optional markers) plus a transform shape and worked example in the body; invoking the skill in an agent CLI on an under-specified prompt (a) selects or asks for a technique, (b) asks for all missing required slots in one batch, (c) displays the refined prompt in a fenced block, and (d) acts on it only after an explicit yes — never on the raw prompt and never without confirmation; technique discovery is run-time (adding a `techniques/*.md` file requires no SKILL.md edit).
Notes: User-story intent: a developer types a quick prompt into whichever agent chat they happen to be in; instead of a universal interceptor (no cross-CLI hook exists, and an always-on gate taxes every prompt), the capability ships as an opt-in skill where the chat LLM itself is the transformation engine — it scores the prompt against technique definitions stored as data, elicits what's missing, rewrites, and gates submission behind a yes/no. Design rules baked into the contract: techniques are data, not code (each `techniques/<name>.md` is self-contained and human-applicable); the rewrite must trace entirely to the original prompt plus the user's slot answers (no fabricated requirements); the confirmation gate is mandatory in both directions (refined prompt on yes, nothing on no). Seed technique: `role-task-context` (Role/Task/Context/Constraints/Output-Format restructuring for under-specified asks) — slot spec: `task` (required; the one-sentence imperative with verb + deliverable), `context` (required; facts the agent cannot infer — system, audience, what was tried), `role` (optional; only when perspective changes the answer — drop the persona line entirely if unfilled rather than inventing a generic one), `constraints` (optional; negative space — what a correct answer must not do, not a task restatement), `output-format` (optional; one line). Rewrite rules for any technique: restructure, don't editorialize — preserve the user's intent and terminology; every sentence of the refined prompt must trace to the original prompt or a slot answer (no fabricated requirements/examples); as short as the technique allows. Each technique file should close with a worked example (raw prompt → elicited slots → refined prompt). Follow-ups: skill-distribution/install is split out as EF-032 (per-surface install adapters; not specific to this skill); additional techniques (few-shot scaffolding, plan-then-act decomposition, chain-of-density for summarization asks) are separate tickets when picked up; adopter-side install into containerized agent homes belongs at the adopter's adoption layer, not this repo (per EF-011 boundary). Adjacency: EF-030 (sibling skill addition; same placement convention), EF-032 (distribution), EF-011 (adopter-vs-framework path boundary).









## Issue EF-032 — Per-surface skill install adapters: one-command projection of canonical skills/ into agent-CLI prompt surfaces
ID: EF-032
Title: Per-surface skill install adapters: one-command projection of canonical skills/ into agent-CLI prompt surfaces
Date: 2026-06-12
Status: open
Effort: M
Fix surface: eposforge-pattern
Theme: distribution
Verify with: an installer (script or thin per-surface adapter set) lets an adopter project any canonical `skills/<name>/` into a chosen agent surface with one command, covering at minimum: Claude Code user scope (`~/.claude/skills/` or `~/.claude/commands/`), Copilot workspace prompts (`.github/prompts/` / `.github/skills/`), and Copilot user-scope prompt dirs (including the remote-server variant); the installer supports both adoption modes — fork (in-tree paths) and consume-without-fork (paths into a clone/submodule) — via symlink where the surface tolerates it and copy-with-provenance-header where it does not; re-running is idempotent and reports drift when a copied projection has diverged from canonical; an uninstall/list mode exists; the mechanism is documented generically (no adopter-specific hosts or org names) and a recall query about "installing an EposForge skill into my agent CLI" returns it. **As-built gap (2026-07-17):** `skills/install.sh` already implements a partial surface table (claude-code-user, claude-code-cmd, copilot-workspace, copilot-user) but this item stays open until (1) verify-with passes end-to-end on a clean host, (2) docs + recall describe the installer (not only the script), and (3) sibling gaps below are either closed or explicitly deferred with maturity `partial`. **Sibling scope (do not pretend this item alone is full realization):** EF-061 (Agent Skills standard), EF-062 (script-calling skill anchoring via `EPOSFORGE_HOME`), EF-063 (fleet surfaces: Grok, Antigravity/`agy`, project-scoped dirs), EF-064 (product-repo skill source + create lifecycle). Out of scope remains: runtime skill discovery/registry (C3/C4), containerized agent-home installs (adopter overlay), auto-update watchers.
Notes: Generalizes the gap surfaced while landing EF-031: the framework ships skills as content but has no complete installer story, so every adopter hand-symlinks or hand-copies per surface — the same "no stable installable artifact" failure class EF-012 documents for `epos-secrets` and EF-022 fixes for the secrets resolver (this is the skills-side sibling of EF-022's relocatable-resolver move). `.github/skills/` thin wrappers solve exactly one surface (Copilot workspace in-repo) and only for fork-mode adopters; all other surfaces are undocumented manual steps today. Design constraints: surface list must be data-driven (new agent CLIs appear frequently; adding one should be a table row, not code); symlink-vs-copy per surface is a property of the surface (some tools don't follow symlinks or sandbox their config dirs); copied projections need a provenance header pointing back to the canonical path + version so drift is detectable; no daemon, no watcher — drift detection on re-run is enough at current maturity. **Maturity until siblings land:** skills remain `partial` (shipped content + incomplete install). Closing only the Claude+Copilot user/workspace rows is L2 minimum, not fleet-complete. Adjacency: EF-031 (first consumer), EF-022 (relocatable-artifact precedent), EF-012 (shipped-vs-intent maturity), EF-011 (installer docs speak at the adopter's adoption layer), EF-033 (backlog scripts relocatable — required for script-calling skills after install), EF-061 / EF-062 / EF-063 / EF-064 (create/consume gap pack filed 2026-07-17). Plan notes: `docs/skill-deployment-and-backlog-relocatability-plan.md`.









## Issue EF-034 — Context plane observability: scope manifest, on-demand context-audit viewer, and per-adapter telemetry conformance with a token/cost ledger
ID: EF-034
Title: Context plane observability: scope manifest, on-demand context-audit viewer, and per-adapter telemetry conformance with a token/cost ledger
Date: 2026-06-12
Status: open
Effort: L
Fix surface: eposforge-pattern
Tags: observability
Verify with: three facets verifiable independently. (1) Write side — a launcher wrapper computes the session's widest-allowed scope from the invocation framing (multi-root IDE workspace file → all member repos added to the agent's scope; bare shell → launch directory, unchanged) and, at session start, emits a *discovery manifest* event enumerating: instruction files resolved (with their precedence order), skills directories found and skill count per directory, MCP servers configured and each one's loaded/deferred state, and memory sources in scope; per-prompt hooks append injection events (what a prompt-submit hook added, which tool schemas were loaded on demand, each MCP call) to a per-session append-only event log. (2) Read side — an on-demand viewer (slash-command skill or equivalent) renders that log two ways: grouped by source (instruction files / hooks / skills / MCP / memories, hierarchical, token cost per item where measurable) answering "what does the agent see right now," and as a timeline (event, trigger, turn number) answering "when and why did it load"; nothing is displayed unless invoked — capture is silent. (3) Standardization — the Dev Product adapter metadata contract (C3) gains a `context_telemetry_conformance` field with declared levels (L0 = static manifest from launcher only, filesystem inspection, works for any adapter; L1 = + per-prompt injection events, requires hook surfaces; L2 = + per-tool-call and token-level events, requires transcript/telemetry access); at least two installed adapters declare different levels and the viewer renders both sessions, explicitly marking what is unobservable at the lower level; events carry token counts where measurable and the ledger derives cost via a per-adapter pricing function declared in adapter metadata ($/token for BYOK adapters, quota units for subscription adapters — never assume marginal dollar cost for subscription auth); event envelope conforms to the EF-024 Track 1 schema (extended with a context-event family), not a second schema.
Notes: User-story intent (surfaced 2026-06-12): an operator runs agent CLIs from varying directories on a dev host, and each launch directory yields a different context world — different instruction files, skills discovery, memory, and MCP visibility — with no way to see, before prompting, what the agent actually has, nor to audit, after prompting, what loaded and why. Discovery today is hit-or-miss and untroubleshootable. Three requirements fell out of one conversation: (a) scope should follow the *framing* of the launch (an IDE multi-root workspace declares the intended scope; a bare shell keeps directory scoping), (b) context loading must be auditable on demand — organized with grouping/hierarchy/timeline for the who/what/where/when, but displayed only when asked, never ambient, and (c) the same mechanism must work across heterogeneous agent CLIs to whatever extent each supports, managed in one standardized way. Architectural placement: this is the read/write seam between the Orchestrator (C4, née Router — naming per EF-026) and Audit & Observability (C11). The Orchestrator's prompt-gating hook already decides *when* to inject context; this issue adds the manifest it should have been emitting (write side) and the session-local human lens over the C11 stream (read side). Token counts double as the overload diagnostic (too many skills/tools/memories eroding the window) and as the cost ledger input — once running totals are readable from the stream, cost becomes an input to the Orchestrator's gating decisions (skip an expensive retrieval when the budget says so), closing the C4↔C11 loop. Graceful degradation is the cross-vendor strategy: capture lives as far vendor-neutral as possible (L0 is pure pre-launch filesystem inspection in the launcher, so even hook-less adapters get a manifest), and per-adapter conformance is declared, not probed. Conditional MCP loading (e.g. a domain-scoped knowledge-graph server consulted only for in-domain prompts) stays in the Orchestrator's gating layer — deferred tool schemas plus prompt-domain gating already cover it; do not add a third wrapper layer (e.g. MCP-wrapped-in-skill) without evidence the existing two are insufficient. Adjacency: EF-013 (Orchestrator v0 — this issue's write side is its missing manifest), EF-024 (Track 1 event schema is the envelope to extend; its token/cost metadata fields overlap — reconcile, don't duplicate), EF-026 (use Orchestrator naming in new docs), EF-027 (C14 decisions would appear in the same per-session log), EF-028 (C15 working-memory loads are a manifest line item), EF-011 (describe launcher/viewer install at the adopter's adoption layer, not as framework-internal paths). Out of scope: enforcement (budgets that *block* are Agent Policy/C8 territory), fleet-level dashboards (C11 backend owns aggregation; this is the session-local lens), and any always-on display surface.








## Issue EF-046 — Convert backlog `Theme:` (single-valued) to `Tags:` (multi-valued) across the file-based-backlog tooling
ID: EF-046
Title: Convert backlog `Theme:` (single-valued) to `Tags:` (multi-valued) across the file-based-backlog tooling
Date: 2026-06-16
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: backlog-tooling
Verify with: all repo `config.toml` declare `tags = [...]` with `themes = [...]` accepted as a one-version read alias; an item field `Tags: a, b, c` (comma-separated, same style as `Blocks:`) parses to a list and a legacy `Theme:` line still parses but emits a lint deprecation warning; `lint-backlog.sh` validates each tag in `Tags:` independently against the repo vocab (error per non-vocab tag) and passes across all roots after migration; `aggregate.sh --tags` (with `--themes` retained as an alias) lists each item under EVERY tag it carries, and the unanchored set is exactly the items with empty tags AND no `Blocks:` path to an anchor; `aggregate.sh --mermaid` keeps one subgraph per node using the FIRST tag as the primary (Option A, ratified 2026-06-16) while rendering the remaining tags via `classDef` node styling, and `backlog/portfolio.md` regenerates cleanly; `docs/schema.md` replaces the `Theme:` row with a multi-valued `Tags:` row; the Living Spec `version` bumps to 0.3.0 (reconciled with `scripts/VERSION`) and its command list reads `--tags`; the `portfolio-review` and `milestone-elicitation` skill texts are updated off `Theme:`/`--themes`; and a one-shot migration rewrites every existing `Theme:` line to `Tags:` across active/slated/archive in all repos.
Notes: Filed 2026-06-16 during portfolio-review. Single-valued `Theme:` (added by EF-037) forces a false either/or — real items bridge concerns (EF-044 = backlog-tooling + simplification; EF-027 = agent-policy + content-safety; EF-030/EF-031 = skills + their domain), and the `--themes` view files a bridging item under one cluster lossily. Tags are associative GROUPING edges (item↔tag-node, many per item) and stay strictly distinct from the directional dependency edges (`Depends on:`/`Blocks:`) that drive critical-path ordering — this work does not touch those. Architect decisions (2026-06-16): vocab stays per-repo (not a shared portfolio list); Mermaid uses Option A (first tag = subgraph, extra tags via classDef) since a Mermaid node can sit in only one subgraph. Verified surface area: only `lint-backlog.sh` + `aggregate.sh` reference themes (ready/new-issue/sweep do not); 6 config vocab lists; `docs/schema.md:33`; ~82 `Theme:` lines across 8 backlog files in 4 repos. Full plan + step-by-step: `backlog/plans/EF-046-themes-to-tags.md`. Out of scope (sibling items): the public/private backlog-boundary cleanup + lint is EF-047. Adjacency: EF-037 (added the `Theme:` field whose cardinality this evolves), EF-039/EF-040/EF-041 (portfolio tooling consuming the groupings), EF-044 (first multi-tag beneficiary).









## Issue EF-048 — Context-aware (semantic) public→private boundary check, complementing the deterministic lint floor
ID: EF-048
Title: Context-aware (semantic) public→private boundary check, complementing the deterministic lint floor
Date: 2026-06-16
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: backlog-tooling
Verify with: a semantic (LLM-driven) check exists — implemented as a new finding class in the docs-lint skill (EF-030, e.g. `boundary-leak`) or a dedicated skill under `skills/` — that, run over a `visibility = "public"` repo's backlog files (active/slated/archive, headers + bodies), flags CONTEXTUAL references to any private repo / private backlog / adopter-internal work that the deterministic `lint-backlog.sh` floor (EF-047) cannot detect: references with no literal private item-ID or host path — e.g. naming a private repo's backlog in prose, an adopter org/repo name, or an oblique paraphrase of private work; the check is driven by the visibility map (private repos enumerated from `config.toml`), not a hardcoded name list, so it generalizes to any repo; it distinguishes a genuine private-repo reference (flag) from the sanctioned generic framing ("an adopter", "the adopter's LAN") (no flag), verified on seed cases — the now-genericized operational header note that named a private repo's backlog WOULD have been flagged, while "an adopter's single-vault migration" is NOT; findings are report-only (no auto-edit, per the surgical-changes principle in `04-standards/08-agent-coding-guidelines/`); and the division of labor is documented — deterministic, zero-false-positive classes (private item-ID references via the visibility map, host paths, `*.lan`, private IPs) stay in the blocking `lint-backlog.sh` floor; semantic/contextual detection lives here.
Notes: Filed 2026-06-16 immediately after EF-047. EF-047's lint is the deterministic FLOOR: it blocks in pre-commit/CI, offline, with no false positives, on well-defined leak classes (an ID-shaped `PREFIX-NNN` token whose prefix resolves to a private repo via the visibility map, absolute host paths, `*.lan`, private IPs). That floor cannot "understand context": a reference to a private *backlog/repo* in prose — an org name, a repo name, "the <adopter> backlog", an oblique paraphrase — is an open-ended class that no keyword/alias list can cover without the brittle false positives a keyword check invites. Architect directive 2026-06-16: the boundary guard must also prevent references to private backlogs (not just private item IDs) AND must be context-aware, not a keyword match — which requires a semantic (LLM) pass. Placement decided 2026-06-16: keep EF-047 as the deterministic floor; this item is its semantic complement, sharing the visibility map as the single source of truth for what is private. Natural home is EF-030's docs-lint (the existing LLM "lint" operation for contradictions/staleness) as an added `boundary-leak` finding class; a dedicated skill is the alternative if docs-lint's report-only, corpus-wide framing is a poor fit for a gating boundary check. This is the backlog-scoped slice of the wider public→private audit EF-047 named as out-of-scope (the same semantic scan also belongs over specs / `AGENTS.md` / runbooks — sequence that after this proves out). Adjacency: EF-047 (the deterministic floor this complements; shares the visibility map), EF-030 (docs-lint — the semantic-lint host; likely implementation home), EF-011/EF-012 (framework-vs-adopter boundary at the spec-graph layer).









## Issue EF-049 — AI Question Method elicitor + "when-needed" prompt-quality gate (two-part capability)
ID: EF-049
Title: AI Question Method elicitor + "when-needed" prompt-quality gate (two-part capability)
Date: 2026-06-18
Status: open
Effort: L
Fix surface: eposforge-pattern
Depends on: EF-031
Tags: orchestrator
Verify with: the capability ships in two separable parts. PART A (method) — an elicitor applying the AI Question Method exists, either as a technique under `skills/refine-prompt/techniques/` (EF-031) or as a distinct interactive elicitation skill modeled on `skills/milestone-elicitation/`; invoked on an under-specified prompt it elicits the author's (1) flashlight intent — bullseye center + edges + explicit exclusions, (2) what "good" looks like for the target outcome, and (3) the concrete data artifacts plus the author's opinions across them, then produces a refined prompt where every line traces to the original prompt or the author's answers (no fabricated requirements) and the model is left free to disagree with the author's thesis. PART B (gate) — a prompt intent-clarity check in the Orchestrator (C4, née Router per EF-026) triggers Part A only when a prompt is below bar and passes sharp prompts straight through; the gate's trigger signal is declared (not hardcoded) and a sharp prompt incurs no elicitation. The two parts are independently verifiable: Part A works opt-in with no gate; Part B can route to any elicitor. Cross-references added so a recall query about "prompt sharpening", "the question method", or "when does the orchestrator ask me clarifying questions" returns this capability.
Notes: User-story intent (2026-06-18): a developer types a quick prompt; instead of silently rewriting it (which only pads or mirrors), the system draws out the intent the author hasn't articulated — value is elicitation, not text expansion. Method = Nate B. Jones' "AI Question Method" (senior-partner mental model + the three principles above); full distillation, design detail, source citation, and transcript pointer in `backlog/plans/EF-049-ai-question-method-and-gate.md` (kept out of this item to avoid bloat). Relationship to siblings: Part A most likely a technique under EF-031's refine-prompt skill (run-time technique discovery already supported) — but EF-031's contract is ONE-SHOT (batch slots, rewrite once, single yes/no) while the question method is iterative partnership, so the fit must be decided (design question 4). Part B is the "when-needed" gate EF-031 deliberately deferred: EF-031 rejected an always-on interceptor (no cross-CLI hook; taxes every prompt), but the Orchestrator is a single server-side surface with an existing prompt-gating hook (EF-034), so a gate is feasible THERE. Distribution rides on EF-032 (no new install work). Open design questions (full text in the plan): (1) Trigger model — automatic (Orchestrator gates every prompt) vs opt-in (invoke the skill, à la EF-031) vs adaptive (memory-primed nudge); (2) Gate signal — length/specificity heuristics vs LLM-judge against the three principles vs structured check (states a thesis? names artifacts? bounds scope?); (3) Scope of target — implementer-facing Orchestrator-internal stage vs general capability any Dev Product (C3) can call via a contract; (4) Method-vs-framework fit — does the question method fit EF-031's one-shot slot+confirm contract or need a distinct interactive elicitation skill? Architect recommendation (2026-06-18): build Part A first as an opt-in skill/technique (modeled on milestone-elicitation + EF-031), prove elicitation quality, THEN add Part B's gate — a great gate triggering a mediocre interview is worse than no gate. Adjacency: EF-031 (refine-prompt skill — likely Part A home; one-shot-vs-iterative tension), EF-032 (distribution), EF-013 (Orchestrator v0 — Part B's host), EF-034 (Orchestrator prompt-gating hook + context manifest), EF-026 (Orchestrator naming), EF-011/EF-012 (adopter-vs-framework boundary for any install docs).









## Issue EF-051 — Adopter guidance: highest-altitude, ungameable integration tests wired into the agent iteration loop as the definition of done
ID: EF-051
Title: Adopter guidance: highest-altitude, ungameable integration tests wired into the agent iteration loop as the definition of done
Date: 2026-06-18
Status: open
Effort: L
Fix surface: eposforge-pattern
Tags: source-control
Verify with: a standard/playbook exists (new doc under `04-standards/`, e.g. a verification & definition-of-done standard, cross-referenced from `01-architecture/02-components/source-control-ci.md`) that guides adopters to establish the highest-altitude integration tests as the task-completion gate, declaring as REQUIREMENTS the anti-gaming properties: (1) test definitions and acceptance criteria live OUTSIDE the implementing agent's write scope (enforced via C8 Agent Policy — the agent that writes the code may not edit the gate that judges it); (2) tests are derived from the Living Spec's declared acceptance criteria (C1), not reverse-engineered from the implementation; (3) the gate verifies the real OUTCOME end-to-end (behavioral/integration altitude), not narrow proxies an agent can satisfy trivially or hardcode; (4) test definitions carry tamper-evidence/provenance so edits are detectable (C11 audit); (5) optional held-out assertions the agent cannot see and overfit to. The same doc specifies the ITERATION LOOP: the Orchestrator (C4) runs dispatch -> execute (C3) -> run gate -> expose results + diagnostics to the agent -> fix -> re-run, until the gate passes; a task may be declared DONE only when the ungameable gate passes, never on agent self-report; C9 enforces the same gate as a required PR status check (the durable, post-loop enforcement). The doc resolves the core tension explicitly — the agent must SEE results to iterate, but must not hold mutate rights over the gate, and held-out assertions cover the overfit case. A recall query about "ungameable tests", "definition of done", "reward hacking", or "can agents game the tests" returns this guidance.
Notes: User-story intent (2026-06-18): eposforge should help adopters stand up the highest level of integration tests that agents cannot game, yet that feed the agent's fix loop so it resolves issues before declaring a task complete. Why now / what's missing: C9 already runs factory-level integration tests as a required PR check derived from acceptance criteria, and Standard 08 §4 already says agents must loop until success criteria are verified — but NEITHER addresses (a) anti-gaming (who authors/owns the gate and why the implementing agent must not be able to edit it), nor (b) the explicit loop-visibility-vs-ungameable tension, nor (c) "definition of done = gate-pass, not self-report". This item adds that as adopter-facing guidance. Direct tie to EF-012: an agent that self-declares "done" on confident-but-wrong work is the task-level face of the "graph reports intent as shipped state" hazard — agents don't push back on a confident-wrong signal, so the ungameable external gate is the compensating control (same logic as EF-029 framing backup as a compensating control when prevention is weak). Anti-gaming design palette to develop in the doc: external test authority (C8 write-scope), spec-derived not impl-derived tests (C1), outcome altitude over proxy unit tests, provenance/tamper-evidence (C11), held-out assertion sets. Loop ownership: C4 Orchestrator runs the iterate-until-green loop and only then permits a done declaration; C9 is the durable gate; C3 executes and consumes diagnostics. Keep guidance at the adopter's adoption layer, not framework-internal paths (EF-011). Adjacency: EF-050 (rubrics — the graded/qualitative complement to this deterministic gate; the two halves of honest verification), EF-049 (its Part B gate is the same iterate-until-bar pattern at the prompt layer), EF-012 (self-declared-done = act-on-confident-wrong hazard), EF-029 (compensating-control framing), EF-027 (C14 content-safety is a different gate class — payload safety, not outcome verification), C8 / C9 / C1 / C4 (the components this guidance binds together).




## Issue EF-059 — Adopt uniform `.eposforge/` container folder (EF-059 / EF-060)
ID: EF-059
Title: Adopt uniform `.eposforge/` container folder (EF-059 / EF-060)
Date: 2026-06-30
Status: open
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-056
Tags: distribution, backlog-tooling, simplification
Verify with: the adapter-layout-mirror standard (and 00-vision/02-roles-ownership.md, preferred-mode-adoption-plan.md, etc.) mandate a single container name `.eposforge/` for all eposforge-owned content (adopters and the framework repo); all `.code-workspace` files declare `./.eposforge` (framework also `./.eposforge` instead of `./instance`); framework and adopter trees use `.eposforge/` on disk; scripts, skills, docs, runbooks, docker configs, and generators have been updated (no hard-coded `eposforge/` or `.eposforge/` container paths remain except in historical notes or migration docs); `check-installed-scripts-layout.sh` and layout generators pass against the new name; new-issue / aggregate / portfolio-review etc. continue to work via workspace or BACKLOG_ROOTS pointing at `.../.eposforge`; post-rename cognee recall and portfolio views reflect the structure correctly. See full plan in `backlog/plans/EF-059-dot-eposforge-container-uniformity.md`.
Notes: This corrects the folder structure so all adopting libraries (and the framework itself) use a dot-prefixed `.eposforge/` container. Rationale (from cognee graph + files): previous split (`eposforge/` for pure adopters, `.eposforge/` for framework) existed only to avoid self-duplicate name confusion inside the eposforge repo. Using the conventional dot-prefix (matching .github, .claude, .vscode, etc.) makes the name uniform everywhere and signals "tooling / eposforge-owned data". This is a cross-cutting layout + naming + discovery change. It touches the adapter-layout-mirror standard (primary SSoT), workspaces, all path references in skills/scripts/docs, physical renames via git mv, private mounts/configs in the primary adopter, index generators, and requires coordinated updates + verification. Part of Phase 0 / EF-056 family of architecture alignment and layout work. The (sanitized) public plan and detailed private execution notes capture the full step-by-step. Concrete private adopter details live in the primary adopter repo.





## Issue EF-061 — Ship Agent Skills standard (`04-standards/03-agent-skills/`) as the create-side contract
ID: EF-061
Title: Ship Agent Skills standard (`04-standards/03-agent-skills/`) as the create-side contract
Date: 2026-07-17
Status: open
Effort: M
Fix surface: eposforge-pattern
Theme: agent-policy
Verify with: `04-standards/03-agent-skills/agent-skills.md` (or package dir with README) exists and is listed from `04-standards/README.md` and `AGENTS.md` §Standards; the standard normatively covers (1) agentskills.io-compatible layout (`skills/<name>/SKILL.md` with `name` + `description` frontmatter); (2) thin `.github/skills/<name>/SKILL.md` wrappers pointing at canonical content; (3) skill vs runbook vs prompt-pack boundary (when to create which); (4) optional eposforge Adapter metadata + required `## Eposforge non-conformances` section for product skills that touch future Adapters; (5) create checklist for agents: SoT + wrapper + install projection notes; (6) consume checklist: which surfaces exist (cross-ref EF-032/EF-063) and that bare `skills/` is content SoT not universal auto-discovery; a recall query about "agent skills standard", "where do skills live", or "skill vs runbook" returns this standard; the graph no longer asserts the standard as adopted-without-files (EF-012 / docs-lint ghost at `04-standards/03-agent-skills/` is resolved by shipping the file).
Notes: Filed 2026-07-17 to close the create-side gap: install (EF-032) without a normative create contract leaves every product repo inventing skill placement. Renumbered from draft EF-052 after ID collision with Execution Sandbox slot item. Adapter-pattern and summit docs already point at `04-standards/03-agent-skills/` but the path is **missing on disk**. Adjacency: EF-032 (consume), EF-063 / EF-064 (fleet + product lifecycle), Standard 08, AGENTS.md skills-placement bullet.





## Issue EF-062 — Anchor script-calling skills to EPOSFORGE_HOME (cwd-independent tooling)
ID: EF-062
Title: Anchor script-calling skills to EPOSFORGE_HOME (cwd-independent tooling)
Date: 2026-07-17
Status: open
Effort: S
Fix surface: eposforge-pattern
Theme: distribution
Depends on: EF-033
Verify with: every framework skill under `skills/` that invokes Component 13 (or other installed-component) scripts resolves tooling via `${EPOSFORGE_HOME:?}/...` (or installer-injected equivalent), never only via repo-relative paths from the eposforge clone root; after EF-033 lands, invoking `portfolio-review` / `milestone-elicitation` from an arbitrary cwd outside the eposforge tree (with skills installed per EF-032 and `EPOSFORGE_HOME` set or derived) runs `aggregate.sh` / `lint-backlog.sh` successfully against the correct adopter backlog; installer (EF-032) documents that installing a script-calling skill must leave `EPOSFORGE_HOME` set/derivable for the target surface; verify-with for "skill is installed" fails if the skill is discoverable but cannot find its tooling.
Notes: Filed 2026-07-17 from `docs/skill-deployment-and-backlog-relocatability-plan.md` §3 (coupling B). Renumbered from draft EF-053. Without this, EF-032 can green-light "symlink present" while skills still fail with `aggregate.sh: No such file` from non-root cwds. Adjacency: EF-032, EF-033, EF-022.





## Issue EF-063 — Fleet skill surfaces: Grok, Antigravity (agy), project-scoped, and `.agents/skills`
ID: EF-063
Title: Fleet skill surfaces: Grok, Antigravity (agy), project-scoped, and `.agents/skills`
Date: 2026-07-17
Status: open
Effort: M
Fix surface: eposforge-pattern
Theme: distribution
Depends on: EF-032
Verify with: the installer's data-driven surface table (EF-032) gains rows for at least: (1) Grok user and/or project skills (`~/.grok/skills/<name>/` and/or `<repo>/.grok/skills/<name>/` per Grok Build discovery rules); (2) shared project agents path (`<repo>/.agents/skills/<name>/` — scanned by Grok and aligned with multi-harness practice); (3) Claude **project** scope (`<repo>/.claude/skills/<name>/`, distinct from user `~/.claude/skills/`); (4) Antigravity CLI (`agy`) — documented target path(s) once verified against the CLI's discovery rules, or an explicit "unsupported / manual" maturity tag if the vendor has no skill dir yet; each new row states symlink vs copy method; `install.sh --list` shows the new surfaces; installing one canonical skill onto each supported surface is idempotent; generic docs (no private host names) describe the fleet table; a recall query about "install skill for grok" or "project skills directory" returns this capability.
Notes: Filed 2026-07-17. Renumbered from draft EF-054. EF-032's minimum verify-with only requires Claude user + Copilot workspace/user — insufficient for the adopter fleet that runs claude/copilot/grok/agy. Adjacency: EF-032, EF-061, EF-064.





## Issue EF-064 — Product-repo skill lifecycle: install from product `skills/`, wrappers, and create checklist
ID: EF-064
Title: Product-repo skill lifecycle: install from product `skills/`, wrappers, and create checklist
Date: 2026-07-17
Status: open
Effort: M
Fix surface: eposforge-pattern
Theme: distribution
Depends on: EF-032, EF-061
Verify with: the installer (or a documented product mode) can take `--source <product-repo>/skills/<name>` (not only the framework clone's `skills/`) and project into the same surface table as EF-032/EF-063; product AGENTS template fragment (or standard section) requires: new agent workflows go to `skills/<name>/SKILL.md`, thin `.github/skills/<name>/SKILL.md` wrapper in the same change, and optional project projections for local harness discovery; optional cheap lint/check script or docs-lint class flags a `skills/<name>/` without matching `.github/skills/<name>/` wrapper (report-only ok for v1); a worked example in docs uses a product-style skill (no private product names required — synthetic `example-product-skill` is fine); recall about "product repo skills" or "fork mode product skills" returns this.
Notes: Filed 2026-07-17. Renumbered from draft EF-055 after ID collision with vault-removal item. Framework install alone does not make product skills uniformly discoverable. Adjacency: EF-032, EF-061, EF-063, product AGENTS patterns.





## Issue EF-065 — Context plane observability behavioral implementation (manifest, viewer, envelope)
ID: EF-065
Title: Context plane observability behavioral implementation (manifest, viewer, envelope)
Date: 2026-07-16
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: observability
Depends on: EF-034
Verify with: implement the behavioral facets of context plane observability: launcher write-side manifest, on-demand viewer behavior, multi-level adapter telemetry conformance (at least two adapters at different levels), and event envelope conforming to Track 1 schema.
Notes: Split from EF-034 to separate the metadata contract (EF-034) from the behavioral artifacts (EF-065). Renumbered from EF-061 after ID collision with the Agent Skills standard (EF-061 on mainline).





## Issue EF-067 — Standards Catalog + name-based standard references (create-side contract)
ID: EF-067
Title: Standards Catalog + name-based standard references (create-side contract)
Date: 2026-07-25
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: simplification
Blocks: EF-068, EF-069
Verify with: `04-standards/README.md` carries a canonical **Standards Catalog** roster table (Standard name | file | one-line scope) that is the machine-readable source of truth a lint parses, plus the name-not-number rationale paragraph, and lists every standard on disk (today `04-mcp/` and `05-canonical-doc-sources/` are missing from it); `04-standards/00-standards-meta/standards-meta.md` normative requirement 1 changes `04-standards/<nn>-<slug>/` to `04-standards/<slug>/` (numeric directory prefixes forbidden) with Conformance updated to match; `04-standards/01-naming-conventions/naming-conventions.md` gains normative requirements mirroring its own #7–9 for standards (canonical-name-not-number, shortcut-reference-link form `[Ungameable Gates]`, capitalize-for-standard) plus a `## Standard references` section; a lint resolves standard labels against the catalog and supports `--write-defs` / `--check`, failing on numeric standard identifiers (`Standard 11`, `Standard 09`, `standards 10`), undefined labels, and definitions pointing at missing files; one standard is converted end-to-end as the proof file with `--check` clean on it.
Notes: Filed 2026-07-25. Applies to `04-standards/` the same treatment the components got in the 2026-07 name-based-reference series (catalog + naming rules + lint + proof, then contracts, then a normative-layer sweep, then CI, then the research mirror). The rationale transfers exactly: numbers are opaque to readers, have no decoder, and drift. The standards tree has already drifted three ways — there is no `03-` on disk yet 9 live references point at `04-standards/03-agent-skills/`; `02-` was reused after the vocabulary standard was superseded while 7 references still point at `04-standards/02-vocabulary/`; and `04-mcp/` + `05-canonical-doc-sources/` exist on disk but appear nowhere in the README roster. Implementation recommendation: generalize the existing `check-component-links.py` to parse two catalogs (components, standards) rather than fork a near-identical script — the definitions-block machinery, reference regexes and `--write-defs` rewrite are identical; if generalized, keep the `<!-- component-links -->` block marker working and add a sibling `<!-- standard-links -->` marker so the two blocks stay independently regenerable. Note the ordering interaction with EF-061: that item ships the Agent Skills standard at `04-standards/03-agent-skills/`; if it lands first it should be created at the unnumbered path directly. Adjacency: EF-061 (would otherwise add a thirteenth numbered dir), EF-066 (once its schema ships, backfill this chain with `Migration: numbered-to-named-standards` — and note that this work reopens EF-066's open question (1), since `numbered-to-named-components` is no longer "nearly complete" as a dogfood candidate but has a live second phase), EF-044 (retired numbered component folders in the adapter layer), EF-030 (lint as companion).





## Issue EF-068 — Drop numeric prefixes from standard directories + repo-wide path sweep
ID: EF-068
Title: Drop numeric prefixes from standard directories + repo-wide path sweep
Date: 2026-07-25
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: simplification
Depends on: EF-067
Blocks: EF-070
Verify with: all twelve `04-standards/<nn>-<slug>/` directories are `git mv`-renamed to `04-standards/<slug>/` (standards-meta, naming-conventions, ontology-taxonomy, mcp, canonical-doc-sources, research-mirror, adapter-layout-mirror, agent-coding-guidelines, paired-detection, ungameable-gate, paired-change-enforcement, code-surface-encapsulation); every path reference across the tracked tree is updated (00-vision, 01-architecture, 02-roadmap, 04-standards, 03-research, AGENTS.md, README/CONTRIBUTING, `.github/workflows/doc-lint.yml` path filters, `skills/`, `.eposforge/`, `00-vision/01-ontology.ttl`); the two dangling numeric paths are resolved rather than merely rewritten — `04-standards/03-agent-skills/` (9 refs, no such directory; either point at EF-061's future path or mark as pending) and `04-standards/02-vocabulary/` (7 refs to a superseded standard; retarget to `ontology-taxonomy` or drop); the markdown link check (`.mlc-config.json`) passes with no broken links; `git log --follow` still resolves each standard's history.
Notes: Filed 2026-07-25. Mechanical and scriptable, but it breaks every inbound link at once, so the rename and the path sweep must land in a single change — unlike the component precedent, where only two files carried numeric prefixes and could be renamed inside the catalog commit. Separate from EF-069 because this is *paths*; EF-069 is *citation form*. Do the rename with `git mv` so file history survives, and check the `_index.json` / installed-layout generators do not hardcode numbered standard paths before renaming. Adjacency: EF-067 (contract), EF-069 (citation sweep — can land either order but both before CI enforcement in EF-071), EF-061 (Agent Skills standard placement), EF-044 (same rename shape, adapter layer; note `.eposforge/14-content-safety/` and `.eposforge/16-backup-resilience/` are still numbered leftovers of that thread and are out of scope here).





## Issue EF-069 — Convert standard citations across the normative layer to name-based links
ID: EF-069
Title: Convert standard citations across the normative layer to name-based links
Date: 2026-07-25
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: simplification
Depends on: EF-067
Blocks: EF-070
Verify with: `Standard 10:` is stripped from the `ungameable-gate.md` H1 (the only numbered standard heading) so titles read as names; every inline `Standard NN` citation becomes a resolvable shortcut-reference link on the canonical name — in the component contracts (`living-spec.md` ×4, `source-control-ci.md` ×5, `tool-transport.md` ×1), in the standards' own cross-references (`paired-change-enforcement.md` ×5, `code-surface-encapsulation.md` ×3), and in `AGENTS.md` ×2, `00-vision/00-vision.md` ×1, `02-roadmap/product-factory-phases.md` ×2; verbose `[04-standards/nn-slug/slug.md](path)` sibling links in `04-standards/README.md` and each standard's `Related` section collapse to `[Name]` form; per-file `<!-- standard-links -->` definition blocks are generated by `--write-defs`; `--check` is clean over the normative layer (00-vision, 01-architecture, 02-roadmap, 04-standards, AGENTS.md); no bare unbracketed `Standard N` survives outside fenced code and `03-research/`.
Notes: Filed 2026-07-25. Mirrors the components sweep: the citations are the payload, the numbers are the defect. Two live examples of why — `source-control-ci.md` cites "Standard 09: Paired Detection" and "Standard 10: Ungameable Gates" in the same list, so a reader must hold a number→name table that exists nowhere; `code-surface-encapsulation.md` cites "Standard 11 (paired-change)" inline with no link at all, which is unresolvable and unlintable. Historical backlog `Notes:` in `backlog.md` / `backlog-archive.md` also carry `Standard 08`/`Standard 09` citations — leave archived items alone (immutable record), but the lint scope must exclude the backlog files or they will fail the check. Adjacency: EF-067 (contract + lint), EF-068 (paths), EF-071 (enforcement).





## Issue EF-070 — Sweep the research mirror for name-based standard references
ID: EF-070
Title: Sweep the research mirror for name-based standard references
Date: 2026-07-25
Status: open
Effort: S
Fix surface: eposforge-pattern
Tags: simplification
Depends on: EF-068, EF-069
Verify with: `03-research/04-standards/01-naming-conventions/` and `03-research/04-standards/06-research-mirror/` are renamed to drop their numeric prefixes; every link pointing at the renamed paths is updated (`03-research/README.md`, `03-research/landscape.md`, the `declined-options:` line in `naming-conventions.md` Status, and the `Related` sections of `standards-meta.md` and `research-mirror.md`); numeric standard citations inside the mirror become names; `03-research` is inside the lint's `DEFAULT_SCOPE` for standard references and a full `--check` passes.
Notes: Filed 2026-07-25. Directly mirrors the components research sweep, which folded `03-research` back into the enforced scope once clean. Small because the mirror only carries two standards today. The research-mirror standard itself governs this directory, so its own path moving is a self-referential edit worth doing carefully — the `declined-options:` back-pointers are the links most likely to be missed. Adjacency: EF-068, EF-069, EF-071.





## Issue EF-071 — Enforce name-based standard references in CI and docs-lint
ID: EF-071
Title: Enforce name-based standard references in CI and docs-lint
Date: 2026-07-25
Status: open
Effort: S
Fix surface: eposforge-pattern
Tags: source-control
Depends on: EF-069, EF-070
Verify with: `.github/workflows/doc-lint.yml` runs the standard-reference check over the enforced normative layer plus `03-research` (either by extending the existing `component-links` job or as a sibling job, named to cover both), from the tracked source path; the lint's `DEFAULT_SCOPE` covers the same surface and excludes `.eposforge/backlog/*.md` and `docs/` (historical capture); the docs-lint skill gains a `standard-ref` semantic finding class for bare unbracketed standard names, noting that the deterministic floor already owns numbers, undefined labels and broken links; a deliberately numbered reference introduced in a scratch file makes the job fail, and removing it makes it pass.
Notes: Filed 2026-07-25. Last in the chain by design — the precedent enforced only after the corpus was clean, otherwise CI is red on main while the sweep lands. The one judgment call: whether this is a second job or the existing `component-links` job broadened to "spec reference links". Recommend broadening if EF-067 generalizes the script (one invocation, one catalog parse, one failure surface); keep them separate only if EF-067 ships a sibling script. Adjacency: EF-067 (script shape decides this), EF-069, EF-070, EF-030.





## Issue EF-072 — Backlog file split encodes status as a file boundary; collapse active/slated and keep only hot/cold
ID: EF-072
Title: Backlog file split encodes status as a file boundary; collapse active/slated and keep only hot/cold
Date: 2026-07-25
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: backlog-tooling, simplification
Verify with: `01-architecture/02-components/backlog.md` no longer requires a three-way active/slated/archive file split; the load-rule clause is restated as a requirement that the ADAPTER expose filtered views (`ready`, state filters) rather than that the STORE partition by state, and the "AI context fit" non-functional bound is re-derived from tool output size rather than file size; the file-based adapter reads and writes one active file with `slated` carried as a status value, retaining a separate archive file on cold-storage grounds; `lint-backlog.sh`'s hardcoded file set drops `backlog-slated.md`; `ready.sh` and `aggregate.sh` produce byte-identical output before and after on a fixture root containing open, in-progress, blocked, slated and resolved items; a migration script folds existing `backlog-slated.md` contents into the active file preserving IDs, and all conforming roots pass lint afterward; `sweep` continues to move resolved items to archive unchanged.
Notes: Filed 2026-07-25 after measuring the split against its own rationale. FOUR FINDINGS. (1) It does not achieve its stated goal for its main consumer: `ready.sh` iterates all three files (`for fname in ("backlog.md", "backlog-slated.md", "backlog-archive.md")`) and must, because determining whether a blocking dependency is resolved requires the archive — so the one query the split was designed to serve opens everything anyway. (2) The premise has decayed: measured across every conforming root, median total backlog size is ~15KB and the largest is ~177KB; the split saves meaningful context on two roots and nothing on the rest. (3) The real modeling defect — status is stored TWICE, as a field on the item and as the file the item lives in, giving two sources of truth that can disagree, and making a status change a record MOVE rather than a field edit (write amplification plus a bug class that cannot exist in a single-file design). (4) It contradicts this repo's own agent-access model: the same component contract directs agents to "obtain graph-augmented answers by calling the appropriate tools/skills rather than performing broad raw file RAG", and a state-partitioned store only pays off for agents reading raw files. WHAT SURVIVES: the archive split, on different grounds than originally given — archive is cold and unbounded, which is log rotation, not query optimization. Keep it. WHAT ALSO SURVIVES, and is the property actually responsible for this adapter being the one work-tracking system in the portfolio that never diverged: fixed filenames at a fixed path, so tooling needs no registry and adopters make no naming decisions. Do not lose that while fixing the split. GENERAL PRINCIPLE worth adding to the component contract: a file boundary must be justified by a sharing boundary or by cold storage, never by a query — filtering is a tool concern. That rule is what forbids `backlog-p0.md` or `backlog-<surface>.md` later. Adjacency: EF-066 (schema work — a `Migration:` label fits this change), EF-036 (`ready.sh` borrowed `bd ready` semantics; the filtered-view requirement is the same idea stated at the contract level), EF-046 (backlog graph quality). Note this is a contract change plus an adapter change plus a data migration across all conforming roots, hence M not S.





## Issue EF-073 — Add Interaction Capture component slot — durable corpus of what agents were asked and returned
ID: EF-073
Title: Add Interaction Capture component slot — durable corpus of what agents were asked and returned
Date: 2026-08-14
Status: open
Effort: S
Fix surface: eposforge-pattern
Tags: observability
Verify with: `01-architecture/02-components/interaction-capture.md` exists as a `source_of_truth: yes` slot contract declaring purpose (durable corpus of agent interaction content), layer separation (immutable raw / derived index / gated export), idempotent ingest, provenance and correlation identity, `training_eligible` as a tag not a filter, declared redaction modes, and additive retention; Required Adapter metadata includes `capture_layer`, `providers_covered`, `identity_fields_supported`, `redaction_mode`, `retention_policy`, `export_gate`; Boundaries distinguish the slot from Audit & Observability (factory events), Inference Layer (serves the call), Spec Graph (intent), Content Safety (acts on live payloads), and the slated Working Memory slot (active recall); the Component Catalog roster has an Interaction Capture row; `check-component-links.py --check` passes; reference implementations name the wire-proxy and transcript-collector shapes.
Notes: Filed 2026-08-14. Same carving-out precedent as EF-027 / EF-028 — a slot that resembles Audit & Observability but has a different contract (corpus semantics, training eligibility, reconstructable input half). The contract is public; implementations are adopter infra. Name chosen over "Conversation Capture" because the record includes tool events. EF-024 Track 1 (the schema this contract requires) lives at `04-standards/13-chat-event-schema/`. Search (Track 3) and training export (Track 4) are readers, out of this item. Adjacency: EF-023 (capture-contract half), EF-024 Track 1, EF-028 (depends on this schema; do not copy its stale `15-working-memory.md` filename).

## Issue EF-077 — A schema-invalid review discards a good verdict; re-ask once instead
ID: EF-077
Title: A schema-invalid review discards a good verdict; re-ask once instead
Date: 2026-08-16
Status: open
Effort: S
Fix surface: eposforge-pattern
Tags: agent-policy
Verify with: the rendered reviewer prompt names the required property list for a finding explicitly (not only as an example object), so a reviewer emitting a plausible synonym has been told the exact key; and when a returned findings payload fails validation on schema shape ALONE — no missing claim verdict, no cross-field rule broken — the finalize path re-asks the same reviewer once with the validator's own error text appended, records that a re-ask happened, and only then declares the round unusable; a fixture whose only defect is a renamed property produces a valid findings payload on the second attempt without a human editing the file.
Notes: Filed 2026-08-16. Observed three times in three consecutive rounds across two sessions: the reviewer returned well-reasoned findings using a near-synonym for one property name, and `validate-payload.sh` correctly refused the payload, which the harness then reported as "not a verdict". The refusal is right — a findings payload that does not conform is not a verdict, and a missing claim verdict must never be treated as a pass. What is wrong is the recovery: the only way forward was a human renaming the key by hand, which puts the implementer in the position of editing the reviewer's answer, exactly the laundering the three-payload design exists to prevent. Two changes, both cheap. Naming the required keys in the prompt removes most of the cause; a single bounded re-ask on a shape-only failure removes the rest, and is safe because the reviewer is re-answering the same pinned prompt with an added error string rather than being asked to change its judgment. Bound it to one attempt so a reviewer that cannot conform still terminates the round. The distinction that matters is shape-only versus substantive: a payload missing a claim verdict must keep failing outright, because that is the check that stops an implementer from shipping unreviewed work. Adjacency: EF-075 (the contract these payloads conform to).
