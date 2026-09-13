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
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Tags: backlog-tooling
Validation: `docs/schema.md` documents the three fields plus a "Migration tracking (EF-066)" section describing the asymmetric completeness rule. `lint-backlog.sh` validates kebab-case slugs and unknown-slug references (errors), requires at least one target-shape item per declared migration (error if missing), and only warns (does not error) on a missing legacy-shape item; a `LegacyShapeOf:` item gets a lint advisory ("this shape is being strangled toward `<slug>` — do not invest"); ran clean against this repo: `bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh` → `backlog lint: OK` with the four theme-to-tags legacy advisories (no procedure-skills-to-programs advisory — that migration has no legacy-shape item by design, see below). `aggregate.sh --strangler` ran and printed both migrations (`theme-to-tags`: target EF-044, legacy EF-032/EF-062/EF-063/EF-064; `procedure-skills-to-programs`: target EF-088 only, no legacy-shape item) plus an unlabeled-candidates section. Living Spec `file-based-backlog.md` version bumped `0.4.0` → `0.5.0` (and `scripts/VERSION` to match), command list reads `--strangler`. Two corrections landed during a two-round cross-vendor review (Gemini 3.1 Pro via evie, 2026-09-08), both confirmed and fixed: (1) dogfood proof retargeted from `numbered-to-named-components` to `theme-to-tags` (resolves open question (1)) — the original encoding forced target-side work (EF-059, EF-060) into `LegacyShapeOf:` purely to satisfy completeness, and `theme-to-tags` has a real, non-fabricated legacy side (EF-032/EF-062/EF-063/EF-064, still on the legacy `Theme:` field today); (2) completeness relaxed from "legacy AND target required" to "target required, legacy only a warning" (operator decision) after the same fabrication pressure showed up a second time on EF-091 (`procedure-skills-to-programs`) — EF-091 does execution/target-side work and no longer carries any shape field; that migration's legacy side is diffuse corpus state (unconverted skill files, tracked via file-level `legacy_shape_of` frontmatter per EF-087, not a backlog field). EF-086/EF-088 second-migration rows still stand; EF-086's own `Verify with:` still names EF-091 as a required legacy-shape item and is now stale — flagged on EF-086 itself, left for its own owner to correct (out of this item's scope).
Resolved: 2026-09-07
Verify with: `docs/schema.md` documents three new optional item fields — `Migration:` (a kebab-case migration slug, e.g. `numbered-to-named-components`), `LegacyShapeOf:` and `TargetShapeOf:` (each naming a migration slug), comma-separated in the same style as `Blocks:`; `lint-backlog.sh` validates them (an item carrying `LegacyShapeOf:` or `TargetShapeOf:` names a slug that some other item declares via `Migration:`, unknown-slug references error; a `Migration:` slug resolves to at least one target-shape item, error if missing; a missing legacy-shape item is a warning, not an error, since a migration's legacy side is sometimes diffuse corpus state rather than a single ticket — see the Notes below for why this asymmetry was added mid-build) and passes across all roots; `aggregate.sh --strangler` prints one section per migration slug listing its legacy-shape items and its target-shape items, plus an "unlabeled candidates" hint (items whose text matches migration-shape keywords but carry no `Migration:` field); a debt-visibility surface exists so an agent reading an item flagged `LegacyShapeOf:` sees a one-line "this shape is being strangled toward <slug> — do not invest" marker (agent-grounding doc or a lint advisory, per AGENTS.md conventions); the Living Spec `version` bumps and its command list reads `--strangler`; and one of the framework's own in-flight migrations is encoded end-to-end as the dogfood proof, so `aggregate.sh --strangler` renders it correctly with a genuine (not fabricated) legacy side. Build-time retarget (resolves open question (1) below): the dogfood migration is `theme-to-tags`, not `numbered-to-named-components` — EF-046 (`Migration:`), EF-044 (`TargetShapeOf:`, "first multi-tag beneficiary" per EF-046's own Notes), EF-032/EF-062/EF-063/EF-064 (`LegacyShapeOf:`, all still open on the legacy `Theme:` field today).
Notes: Carved out of EF-056 cross-cutting thread (a) so it ships independently — the schema is a decided design, not an empirical unknown, so per "spike the unknowns, not the knowns" it should be placed directly rather than gated behind the multi-graph/GraphRAG build EF-056/EF-057 own. Motivation: several migrations run concurrently across the framework and its adopters (orchestrator platform re-expression, component-folder rename, backlog schema evolution, source-adapter multi-sourcing, execution-sandbox confinement, autonomous-loop replacement, store-backend swaps), but each one's legacy→target intent lives only in free-text `Notes:`, invisible to building agents and to GraphRAG recall. The observable symptom of that invisibility: effort gets sunk into a legacy shape (e.g. tuning an orchestrator subsystem) while a target shape is actively replacing it, because nothing structured told the agent "this is being strangled." This item ships the create-side contract (fields + lint + `--strangler` view + debt marker); adopters then backfill their own in-flight migrations in their own backlogs (adopter-specific migration IDs stay in the adopter's repo, not here — public/private boundary per EF-047). Field semantics stay strictly distinct from dependency edges: `Migration:`/`LegacyShapeOf:`/`TargetShapeOf:` are associative migration-membership edges, NOT `Depends on:`/`Blocks:` (which continue to drive critical-path ordering). Scope addendum 2026-09-07 (EF-086): this item is also the visibility prerequisite for the `procedure-skills-to-programs` migration and ships three further rows for it — EF-086 as the owner (`Migration:`), EF-088 as the target shape (`TargetShapeOf:`), EF-091 as the legacy shape (`LegacyShapeOf:`); those three fields are added to those items when this item lands the schema, not before. That migration is a SECOND encoded migration, independent of open question (1)'s dogfood retarget below. Public/private boundary: the three rows carry generic text only and none of them points at an adopter's plan file. Stale-note correction (2026-08-15 remark above): `lint-backlog.sh` no longer checks only the FIRST `BACKLOG_ROOTS` entry — adapter `0.4.0` / EF-078 lints every root in one invocation, so do not re-solve that; the remaining gap here is the schema fields, the `--strangler` view, the debt marker, the Living Spec bump and the dogfood encoding. Slice scope and the minimum subset if this item is split: `backlog/plans/EF-066-strangler-tracking-schema.md`. Adjacency: EF-086 (the second encoded migration), EF-056 (parent; this is thread (a)), EF-046 (now doubles as the theme-to-tags migration owner — sibling associative-field schema evolution, mirror its lint/aggregate/schema.md/version surface area), EF-047/048 (keeps adopter migration IDs out of the public backlog), EF-040 (portfolio-review should surface migrations as a class). Open question (1) resolved 2026-09-08 by build-time evidence, not by prior preference: the first dogfood attempt encoded `numbered-to-named-components` (EF-044 owner, EF-060 `TargetShapeOf:`, EF-059 `LegacyShapeOf:`) but a cross-vendor review (Gemini 3.1 Pro via evie) correctly found EF-059/EF-060 both do target-side work — adopting and executing the uniform-container rename — so `LegacyShapeOf:` on either was fabricated to satisfy the lint's completeness rule rather than a real legacy signal; there is no item in this repo that genuinely still invests in the old numbered scheme (EF-044 already retired it end-to-end). Retargeted to `theme-to-tags`, which has a real legacy side today: EF-032/EF-062/EF-063/EF-064 are open items still carrying the legacy `Theme:` field, EF-046 is the open item building the `Tags:` tooling (`Migration:` owner), and EF-044 already fully adopted `Tags:` (`TargetShapeOf:`, "first multi-tag beneficiary" per EF-046's own Notes). Separately: EF-059 is still `Status: open` even though EF-060 (which depends on it) is resolved and describes EF-059's decision as already acted upon ("Follows EF-059 ... Framework: completed") — a likely pre-existing stale-status defect, noted here since it surfaced during this work, but out of this item's scope to fix.












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
LegacyShapeOf: theme-to-tags
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
Migration: theme-to-tags
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












## Issue EF-062 — Anchor script-calling skills to EPOSFORGE_HOME (cwd-independent tooling)
ID: EF-062
Title: Anchor script-calling skills to EPOSFORGE_HOME (cwd-independent tooling)
Date: 2026-07-17
Status: open
Effort: S
Fix surface: eposforge-pattern
Theme: distribution
LegacyShapeOf: theme-to-tags
Depends on: EF-033, EF-090, EF-091
Verify with: every framework skill under `skills/` that invokes Component 13 (or other installed-component) scripts resolves tooling via `${EPOSFORGE_HOME:?}/...` (or installer-injected equivalent), never only via repo-relative paths from the eposforge clone root; after EF-033 lands, invoking `portfolio-review` / `milestone-elicitation` from an arbitrary cwd outside the eposforge tree (with skills installed per EF-032 and `EPOSFORGE_HOME` set or derived) runs `aggregate.sh` / `lint-backlog.sh` successfully against the correct adopter backlog; installer (EF-032) documents that installing a script-calling skill must leave `EPOSFORGE_HOME` set/derivable for the target surface; verify-with for "skill is installed" fails if the skill is discoverable but cannot find its tooling.
Notes: Filed 2026-07-17 from `docs/skill-deployment-and-backlog-relocatability-plan.md` §3 (coupling B). Renumbered from draft EF-053. Without this, EF-032 can green-light "symlink present" while skills still fail with `aggregate.sh: No such file` from non-root cwds. Delivery note 2026-09-07: this item is subsumed by the `procedure-skills-to-programs` migration (EF-086) and is delivered in two halves — EF-090 lands the gate (G3, no cwd-relative invocation, plus the `INSTALL.md` "unset home variable means not installed" rule) and EF-091 lands the remaining skill rewrites. Close this item when both are resolved; do not schedule it separately. Adjacency: EF-086, EF-090, EF-091, EF-032, EF-033, EF-022.












## Issue EF-063 — Fleet skill surfaces: Grok, Antigravity (agy), project-scoped, and `.agents/skills`
ID: EF-063
Title: Fleet skill surfaces: Grok, Antigravity (agy), project-scoped, and `.agents/skills`
Date: 2026-07-17
Status: open
Effort: M
Fix surface: eposforge-pattern
Theme: distribution
LegacyShapeOf: theme-to-tags
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
LegacyShapeOf: theme-to-tags
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
Notes: Filed 2026-07-25. Applies to `04-standards/` the same treatment the components got in the 2026-07 name-based-reference series (catalog + naming rules + lint + proof, then contracts, then a normative-layer sweep, then CI, then the research mirror). The rationale transfers exactly: numbers are opaque to readers, have no decoder, and drift. The standards tree has already drifted three ways — EF-061 shipped `04-standards/03-agent-skills/` (still numbered; this item's rename sweep moves it); `02-` was reused after the vocabulary standard was superseded while 7 references still point at `04-standards/02-vocabulary/`; and `04-mcp/` + `05-canonical-doc-sources/` are now listed in the README roster (2026-08-19) but the numbered-to-named rename remains. Implementation recommendation: generalize the existing `check-component-links.py` to parse two catalogs (components, standards) rather than fork a near-identical script — the definitions-block machinery, reference regexes and `--write-defs` rewrite are identical; if generalized, keep the `<!-- component-links -->` block marker working and add a sibling `<!-- standard-links -->` marker so the two blocks stay independently regenerable. Note the ordering interaction with EF-061: that item ships the Agent Skills standard at `04-standards/03-agent-skills/`; if it lands first it should be created at the unnumbered path directly. Adjacency: EF-061 (would otherwise add a thirteenth numbered dir), EF-066 (once its schema ships, backfill this chain with `Migration: numbered-to-named-standards` — and note that this work reopens EF-066's open question (1), since `numbered-to-named-components` is no longer "nearly complete" as a dogfood candidate but has a live second phase), EF-044 (retired numbered component folders in the adapter layer), EF-030 (lint as companion).












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




## Issue EF-081 — Implementation plans become a lint-enforced contract, and backlog work goes through a backlog subagent
ID: EF-081
Title: Implementation plans become a lint-enforced contract, and backlog work goes through a backlog subagent
Date: 2026-08-18
Status: open
Effort: L
Fix surface: eposforge-pattern
Tags: backlog-tooling
TargetShapeOf: prose-to-contract
Blocks: EF-096, EF-097
Implementation plan: .eposforge/backlog/plans/EF-081-implementation-plans-contract.md
Verify with: (1) Standard — `04-standards/07-adapter-layout-mirror/adapter-layout-mirror.md` carries a normative requirement for implementation plans: a plan lives directly under `<adoption-root>/backlog/plans/` and nowhere else; it is named `<PREFIX>-<NNN>-<slug>.md` after the item it serves, and a plan serving several items is named after the owner item, which carries the pointer like every member; it opens with front matter `doc_kind: plan`, `scope`, `maturity`, `source_of_truth: no`; the item is the concise work contract (`Verify with:`, short `Notes:`, `Implementation plan:` pointer) and the plan holds narrative and design; if the two disagree, the items win. `01-architecture/02-components/backlog.md` §Contract points at that requirement rather than restating it. After the next graph sync, a recall asking where a backlog item's implementation plan lives, and which wins when plan and item disagree, returns that standard. (2) Schema — `.eposforge/backlog/file-based-backlog/docs/schema.md` documents optional `Implementation plan:` (one repository-relative path), the `notes_warn_chars` config key and the `backlog/notes-length-baseline.txt` file with the commands that create and prune it; the Living Spec's file layout shows `plans/`. (3) Scaffolding — the pattern ships `file-based-backlog/scripts/init-backlog.sh <repo-root> --prefix <XX>`, which creates `.eposforge/backlog/` with `config.toml`, the four backlog data files and `plans/.gitkeep`, refuses to overwrite an existing backlog, and is the command the bootstrap hint in `new-issue.sh` and `lint-backlog.sh` names; an adopter's repo-scaffolding tooling can call it instead of hand-listing files. (4) Lint — `lint-backlog.sh` ERRORS when an `Implementation plan:` path is absolute, contains `..`, is not `.md`, is not an existing regular file, or is not directly under the item's own repo `<adoption-root>/backlog/plans/` (a plan anywhere else, including a top-level `plans/`, is rejected); ERRORS when the basename does not match `<PREFIX>-<NNN>-<kebab-slug>.md` with the repo's own prefix, when that ID is not an item in the same repo, or when it names another item that does not carry the same pointer; ERRORS when the plan's front matter lacks `doc_kind: plan` or `source_of_truth: no`; WARNS (never errors) when a file in `backlog/plans/` does not match the naming rule. Notes length is a ratchet: an active or slated item with no `Implementation plan:` whose `Notes:` text (the `Notes:` line plus following lines up to the next line that starts with a field named in `docs/schema.md`, or the next issue header) exceeds `notes_warn_chars` characters — 2000 when the key is absent; a value that is not a positive integer is an error, not an off switch — WARNS only when its ID is not listed in `<adoption-root>/backlog/notes-length-baseline.txt` (one ID per line, `#` comments allowed); lint ERRORS when a baseline ID is no longer over the threshold, has an `Implementation plan:`, or is not an active or slated item in the same repo; `lint-backlog.sh --write-notes-baseline` creates the file from the current over-threshold items and refuses to overwrite an existing one, and `--prune-notes-baseline` only removes IDs that no longer qualify; a missing baseline while any item is over the threshold is an ERROR naming `--write-notes-baseline` (cannot evaluate, never treated as empty), and with no item over the threshold a missing file is fine. (5) `ready.sh` renders `Implementation plan:` in text output and emits `implementation_plan` in `--json`. (6) Delegation — backlog work (filing or amending items, writing plans, maintaining the notes baseline) is done by a subagent, not by the conversing session: the pattern ships one harness-neutral definition, `file-based-backlog/agents/backlog-author.md` (name; a description saying when to delegate; the session chair it sits in, implementer, per Standard 14; the tools it needs; instructions that point at the Standard 07 plans requirement rather than restating it), whose procedure is to run the coverage agent (EF-097) before filing, file through `new-issue.sh`, write any plan to the standard, run lint once per root at the `.eposforge` depth, and return the diff summary and lint output without committing; the definition is projected into each harness's native subagent form (for example a Claude Code `.claude/agents/` file) by the consume-side install used for skills and chairs (`skills/INSTALL.md`: canonical in git, projections are pointers or copies with provenance, never forks), and this repo installs its own projection; `AGENTS.md` and the backlog component contract state that a session delegates backlog edits to that subagent with a brief and reviews what comes back, and that an adopter's harness may enforce it; `init-backlog.sh` finishes by reporting whether the projection is installed and names the install command when it is not; the definition's tool list is a default that an adopter's per-role tool assignment overrides, not a second source of truth (EF-093 phase 3). (7) Every rule above has a fixture case with a paired negative control (in `test-multi-root.sh` or a sibling test), including for notes length: a new long item warns, a grandfathered long item is silent, a fixed item left in the baseline errors, a missing baseline with a long item errors, and `--write-notes-baseline` refuses to overwrite; a replay in a fresh session asked to file an item shows the edit made by `backlog-author`, not the conversing session, and the returned item passing lint; this repo commits its baseline; this item's own pointer passes; the backlog lint passes.
Notes: Filed 2026-08-18. Amended 2026-09-13 at operator request to add the standard, the scaffolding and stricter lint; the execution-unit layer moved unchanged to EF-096, which depends on this item, because both together were too large for one item. Why: the plan-location rule was written only in this item's own `Notes:` — no standard, living spec, template, lint rule or agent instruction said it, and backlog items are kept out of graph ingest (EF-057), so recall never surfaced it. The Living Spec and `docs/schema.md` cannot be the home either: they sit under `.eposforge/backlog/`, which ingest also excludes. As first worded, this item's lint rejected only broken paths and would have accepted a plan kept anywhere; in practice an adopting repository grew a second, top-level `plans/` folder beside its backlog's. No backlog scaffolder exists today: `new-issue.sh` and `lint-backlog.sh` only print a "create config.toml" hint, and `sync-tooling.sh` maintains an existing install and refuses a repo without one. Member of `prose-to-contract` (EF-093): a convention moves from prose to a lint-enforced contract. Plans stay optional for small items. The notes-length check is a ratchet against a committed baseline, because a plain 2000-character warning would flag over a dozen existing items here, and more in adopters, the day it ships. Design choices and the ratchet rationale are in the plan. Amended again 2026-09-13: the operator requires backlog work to be delegated to a subagent, and this item to set that up when implemented rather than only state rules; no pattern home for subagent definitions exists yet, so the backlog's sit beside its adapter and use the skills-and-chairs install until a second component needs one, when that becomes a standard. Adjacency: EF-096 (execution units), EF-097 (the coverage agent `backlog-author` runs before filing), EF-093, EF-057, EF-059 (`.eposforge/` container), EF-047 (adopters file their own counterparts).

## Issue EF-083 — Portfolio importance must see factory-blocking work without a hand-wired product harvest link
ID: EF-083
Title: Portfolio importance must see factory-blocking work without a hand-wired product harvest link
Date: 2026-08-28
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: backlog-tooling, portfolio
Verify with: `aggregate.sh` (or the portfolio-review views it feeds) has a first-class surface for factory-blocking / foundation-trust work that is not "does this `Blocks:` a product harvest anchor?"; a constructed `role=substrate` item that is tagged, has no `Blocks:` to any product ID, and states that the factory cannot add features until a named gate exists, appears on that surface; when that item is open, `portfolio-review` Step 7 / `portfolio-handoff.md` does **not** recommend a product-feature item as implement-next (a one-line "stop if kernels go red" in the pasted prompt does not count); a tagged item with no harvest path is not invisible (today it skips both unanchored triage and critical-path); `file-based-backlog.md` no longer says substrate items earn priority only via `Blocks:` to product anchors; a recall about "why wasn't this substrate work next" or "keep building on a shaky foundation" returns this rule.
Notes: Filed 2026-08-28. Operator-confirmed: the backlog is supposed to *know* that factory-blocking work is important; requiring a human to wire `Blocks:` at a product harvest is a structural defect, not an authoring miss; **it must not advise the operator to keep adding features on a shaky foundation.** The current "stop if kernels go red" line in the implement-next prompt is not that control — it still selected product work, and "shaky" is not the same as a red smoke. The current design is explicit and wrong: `file-based-backlog.md` says substrate repos originate no harvest anchors and items earn priority only by linking toward product anchors; portfolio-review Step 4 only triages items with *empty tags AND no Blocks*; Step 7 picks ready items on the critical path of the top *product* anchor. Capture was sold as low-friction because this pass would recompute importance from structure — the structure it uses is only the product-promotion axis. Foundation-trust (EF-053 kernels / bootstrap) was already named as a distinct axis from product-promotion; priority tooling never grew that axis. Agent-proposed: schema (new field vs `role=substrate` view vs kernel-state) is decided at design; do not "fix" this by enforcing the existing follow-up (flag substrate items with no product `Blocks:`), which would train authors to fake harvest links. Adjacency: EF-039/EF-040/EF-041 (views), EF-043 (anchors live in product repos — keep that; stop using it as the only importance sink), EF-053 (foundation-trust axis), EF-046 (unanchored = empty-tags ∧ no-Blocks).

## Issue EF-084 — AGENTS.md's graph-regeneration section contradicts the update-spec-graph skill, and it is the copy agents actually load
ID: EF-084
Title: AGENTS.md's graph-regeneration section contradicts the update-spec-graph skill, and it is the copy agents actually load
Date: 2026-08-30
Status: open
Effort: S
Fix surface: eposforge-pattern
Tags: spec-graph
Verify with: `AGENTS.md` no longer carries a second, independently-maintained copy of the graph-update procedure that can drift from `skills/update-spec-graph/SKILL.md`; whichever text remains in loaded context states the incremental-vs-full-rebuild split correctly (corpus docs -> incremental; a `00-vision/01-ontology.ttl` change -> KG wipe + full rebuild), tells the agent to EXCLUDE the ontology TTL from `--added`/`--modified` rather than always include it, names `--ontology-key` as required on every incremental run, and names the backlog/plans exclusion (EF-057); an agent working only from loaded context — without opening the skill — cannot arrive at the wrong invocation; `rg -n "always include the ontology" AGENTS.md` returns nothing.
Notes: Filed 2026-08-30 after this defect caused a real mis-run the same day. `AGENTS.md` §"Updated Instructions for Regenerating Graph DB" states that the ontology file "must be updated **before** running cognee-sync" and to "**always** include the ontology file when adding or modifying files", with worked examples passing `00-vision/01-ontology.ttl` to `--added`/`--modified`. `skills/update-spec-graph/SKILL.md` states the opposite and is correct: the TTL is the anchor, not a corpus document, and MUST be excluded — "if it changed, you are on the wrong path" (a TTL change requires the wipe + full-rebuild path, because Cognee resolves the ontology at cognify time, does not re-anchor existing nodes, and content-hash dedup silently skips unchanged docs). The `AGENTS.md` copy also omits `--ontology-key`, which the skill says to always pass, and omits the EF-057 backlog/plans exclusion. Observed consequence: an EF-051 doc sync ran from the `AGENTS.md` text, re-ingested the TTL as a corpus document and cognified with no ontology key (`COGNEE_ONTOLOGY_KEY` is unset in the environment and `cognee-sync` has no default — only `bulk-rebuild.sh` defaults it to `eposforge`), leaving `04-standards/10-ungameable-gate/ungameable-gate.md` and `AGENTS.md` in the graph unanchored. Recall still returns them, so the mistake is invisible to the obvious check. Root-cause shape, worth stating because it recurs: the correct procedure lived in a skill nobody loads unless they go looking, while the always-loaded file carried a stale duplicate — the same loaded-context principle Standard 10 requirement 9 relies on, failing in the other direction. Prefer collapsing the `AGENTS.md` section to a pointer over re-syncing two copies. Adjacency: EF-085 (the sync tool records success on a failed cognify — same incident), EF-057 (backlog exclusion), EF-051 / Standard 10 requirement 9 (loaded context is where a rule has to live), `skills/maintain-ontology` (owns TTL edits and already hands off correctly).

## Issue EF-085 — cognee-sync records a file as synced when cognify never ran, so the graph goes silently stale
ID: EF-085
Title: cognee-sync records a file as synced when cognify never ran, so the graph goes silently stale
Date: 2026-08-30
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: spec-graph
Verify with: with the inference budget gate forced to `deny` (or the cognify call otherwise failing), a `cognee-sync --modified <file>` run leaves the state DB row for `<file>` NOT advanced — the recorded `content_hash` still differs from the file on disk, so a later run re-attempts it — and the command exits non-zero with a message naming the file(s) that did not reach the graph; a subsequent run with the gate restored re-ingests that file rather than skipping it; the same holds for a mid-batch failure, where files cognified before the failure may be recorded and files after it must not be; `--status` distinguishes "synced" from "attempted, not confirmed" rather than showing a timestamp for a run that never cognified.
Notes: Filed 2026-08-30 from an observed instance. A `cognee-sync --modified 00-vision/01-ontology.ttl 04-standards/10-ungameable-gate/ungameable-gate.md` run was denied by the budget gate (`{"decision": "deny", "repo_key": "eposforge", "used_tokens": 3004723, "limit_tokens": 3000000, "reason": "budget exhausted"}`); cognify never ran and no `cognify ... done` line was printed. The state DB row for the standard was nevertheless advanced to the current on-disk `content_hash` with `synced_at` 2026-08-30T20:50:10Z, so the next incremental run sees no change and skips the file permanently — the graph keeps the older text with no signal that it is stale, and only a wipe + full rebuild or a hand-edited state row recovers it. The failure is worse than a plain crash precisely because it is recorded as success: it is the state-tracking instance of a proxy standing in for the outcome (Standard 10 requirement 8), and it defeats the incremental path's only staleness detector. Design question for implementation, not settled here: whether to write the state row only after a confirmed `cognify` completion for that data_id, or to record an explicit `pending`/`unconfirmed` state that `--status` surfaces and the next run retries — the second is friendlier to partial batches. Note the current recovery is manual and awkward, which is itself evidence: correcting the bad row means editing `sync/.cognee-state.db` by hand. Adjacency: EF-084 (the instruction defect in the same incident), EF-057, `.eposforge/spec-graph/cognee/sync` (the tool), `.eposforge/inference/scripts/check-budget-gate.sh` (the gate whose deny surfaced this).

## Issue EF-086 — Named migration `procedure-skills-to-programs`: step-list procedure skills become programs
ID: EF-086
Title: Named migration `procedure-skills-to-programs`: step-list procedure skills become programs
Date: 2026-09-07
Status: open
Effort: L
Fix surface: eposforge-pattern
Tags: skills, agent-policy
Migration: procedure-skills-to-programs
Blocks: EF-087
Verify with: this item declares `Migration: procedure-skills-to-programs` once EF-066 ships the field, and `aggregate.sh --strangler` renders that slug with at least one legacy-shape item (EF-091) and one target-shape item (EF-088); the completion commitment 2027-03-31 is stated on this item and in `backlog/plans/EF-086-procedure-skills-to-programs.md`; each of EF-087, EF-088, EF-089, EF-090, EF-091, EF-092 is resolved or explicitly re-scoped by that date; an agent that opens a marked `SKILL.md` sees the legacy-shape marker without reading this item.
Notes: Filed 2026-09-07. Owner row for the migration; the work is in the children, this item owns visibility, ordering and the completion commitment. Stale-clause flag (2026-09-08, EF-066 cross-check, operator decision — not fixed here, out of this correction's scope): this item's own `Verify with:` names EF-091 as the required legacy-shape item, but EF-091 was found to be target-side (execution) work and now carries no shape field at all — see EF-091's own correction note. `aggregate.sh --strangler` will show `procedure-skills-to-programs` with a target side (EF-088) but no legacy-shape backlog item; its legacy side is diffuse corpus state (unconverted skill files, tracked via file-level `legacy_shape_of` frontmatter, not a backlog field). Whoever next revisits this item's `Verify with:` should drop or reword the EF-091 clause. Problem it names: conversational-first (vision principle 6, Standard 12) was written to stop premature UIs and services, and then got applied to *procedures*, so agents keep known step sequences in `SKILL.md` prose and re-derive them every session while the real code already sits under `.eposforge/**/scripts` and `skills/*/scripts`. The split this migration lands: product UX stays conversational-first; a procedure whose steps are known lives in a program, and the skill wraps it (when, dry-run, human gate, refusals, verify). Judgment stays in prose. Method is strangler fig per `02-roadmap/adoption-strategy.md`, not a new migration pattern; the four obligations map as alignment (touched skills ship Standard 15-shaped), completion commitment (**2027-03-31**), visibility (EF-066 + EF-087, both hard predecessors of EF-088), active balance (opportunistic on touched skills, plus three bounded batches: invocation-path ratchet, the inference-field allowlist, the secrets launcher audit). Scope of "done" at the commitment date: pattern adopted, gates live, known ugly paths strangled, remaining judgment skills still skills — **not** every `.sh` rewritten as a service. Ordering rule that must not be relaxed: do not merge EF-088 (the principle rewrite) until EF-087's markers are on the files, because an always-loaded one-liner is the same class of prose that already failed to stop the misuse. Adjacency: EF-066 (the schema this migration is encoded in), EF-062 (subsumed by EF-090 gate half + EF-091 invocation half), EF-056 (Phase 0 master that carved EF-066 out), EF-022 (adjacent to EF-092).

## Issue EF-087 — Mark step-list procedure skills `legacy_shape_of` at the point of contact
ID: EF-087
Title: Mark step-list procedure skills `legacy_shape_of` at the point of contact
Date: 2026-09-07
Status: resolved
Effort: S
Fix surface: eposforge-pattern
Tags: skills
Depends on: EF-066, EF-086
Blocks: EF-088
Validation: `legacy_shape_of: procedure-skills-to-programs` added to the frontmatter of `skills/update-spec-graph/SKILL.md`, `skills/upstream-bug-report/SKILL.md` and `skills/portfolio-review/SKILL.md`, `name`/`description` unchanged in each; one line added to `AGENTS.md`'s migration-debt-visibility section naming the slug and stating the do-not-invest rule; confirmed no script in this repo strictly parses `SKILL.md` frontmatter (`skills/install.sh` only symlinks/copies the file whole), so the additive key cannot break a consuming surface here; no recipe, invocation path or leak touched; `lint-backlog.sh` exits 0, with a "resolved in active file, run sweep-resolved.sh" advisory (archiving resolved items is a separate, periodic operator action, not part of this item). Cross-vendor review (Gemini via evie, 2026-09-08, 2 rounds): verdict sound-with-caveats both rounds — see Notes.
Resolved: 2026-09-08
Verify with: `skills/update-spec-graph/SKILL.md`, `skills/upstream-bug-report/SKILL.md` and `skills/portfolio-review/SKILL.md` each carry `legacy_shape_of: procedure-skills-to-programs` in frontmatter alongside the required `name` and `description`; `AGENTS.md` carries one line naming that same slug and stating that a step-list skill or a cwd-relative invocation is the legacy shape — do not invest, wrap a program instead; every consuming surface still loads all three skills with the extra key present; no recipe, invocation path or leak is changed by this item; EF-088 is not merged while any of the three files lacks the marker.
Notes: Filed 2026-09-07. Visibility at the moment of contact — the file the agent actually opens — which backlog fields alone do not reach. Adoption strategy obligation 3 (visibility of remaining debt) is what makes this a predecessor rather than a nicety; the operator's report is that visibility has never actually worked, and the observable consequence is agents thickening the legacy skill. Frontmatter keys are additive and optional; unknown keys are tolerated by current agentskills.io consumers, and if a CLI chokes on the extra key, keep the always-loaded line and fix the label rather than dropping the signal. `legacy_shape_of` on a `SKILL.md` is NOT a backlog field and does not satisfy `lint-backlog.sh` — the backlog half is EF-066's three rows. Lint of these keys lands with EF-090; the markers must already be on the files before that. A skill that later wraps a program (EF-091) flips to `target_shape_of` or drops both keys. Judgment-only skills (elicitation, prompt refinement, the portfolio *judgment* steps, the docs-lint semantic half) get neither key. Do not wait for Spec Graph projection of the migration edges; backlog items plus frontmatter plus `AGENTS.md` are the mechanical population, and graph ingest is a later consumer. Plan (scope, boundaries, verification detail): `backlog/plans/EF-087-legacy-shape-markers.md`. Resolved 2026-09-08: added `legacy_shape_of: procedure-skills-to-programs` to all three named SKILL.md files, plus the one-line AGENTS.md rule naming the slug. Confirmed nothing in this repo strictly parses SKILL.md frontmatter as YAML (`skills/install.sh` only symlinks/copies the file), so the added key cannot break a consumer here. Pre-existing, out-of-scope observation made while touching these files (not fixed here — additive-only item, plan says keep `name`/`description` exactly as they are and change nothing else): `skills/portfolio-review/SKILL.md`'s frontmatter block already contained an unindented `**Important**: ...` paragraph between the `---` delimiters before this item touched the file (confirmed via `git show HEAD:...` prior to this change) — that paragraph is not valid YAML (a bare `**` line breaks any strict frontmatter parser) and pre-dates EF-087; this item only adds one line inside the same (already-broken) block and does not introduce or worsen the defect. Whoever next edits this skill's frontmatter should move that paragraph below the closing `---` into the body. Cross-vendor review (Gemini 3.1 Pro via evie, 2026-09-08), 2 rounds, both sound-with-caveats: round 1 found the claim that `lint-backlog.sh` "ran clean" overstated it — the script exits 0 but does emit a "resolved in active/slated file, run sweep-resolved.sh to archive it" advisory, expected state pending the next periodic sweep rather than a defect in this item's own change; accepted-fixed by correcting the Validation wording (not by running the sweep, since that is a separate batch operation across all resolved items, not scoped to this one). Round 2 found the corrected wording had cited EF-066 as already carrying the identical advisory — false against this repo's committed history, where EF-066 is still `Status: open` (its own resolution exists only as uncommitted local state, not yet landed); accepted-fixed by dropping the EF-066 comparison and stating the sweep-is-separate rationale on its own terms. Also noted while touching this file: the reviewer (evie/agy, `--dangerously-skip-permissions`) ran `sweep-resolved.sh` inside the review worktree during round 1 despite the payload's stated read-only ground rule — a real gap in the crosscheck read-only guard for this reviewer, discarded before round 2 (the review worktree is disposable and nothing was committed or pushed), reported to the operator, out of scope to fix here.

## Issue EF-088 — Split vision principle 6 and adopt Standard 15 (program-first procedures + vehicle classification)
ID: EF-088
Title: Split vision principle 6 and adopt Standard 15 (program-first procedures + vehicle classification)
Date: 2026-09-07
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Tags: agent-policy, skills
TargetShapeOf: procedure-skills-to-programs
Depends on: EF-086, EF-087
Blocks: EF-089, EF-090
Validation: `00-vision/00-vision.md` principle 6 replaced verbatim with the split text, citing both Standard 12 and the new Standard 15. `04-standards/15-program-first-procedures/program-first-procedures.md` created in standards-meta order (Status with all six declined options, Scope, the seven MUST requirements, the five-row vehicle-class table, Conformance naming G1-G4, Related) and names no programming language (`rg -in '\b(python|bash|go|rust|typescript|javascript|node|ruby|java|c\+\+|c#|powershell)\b' 04-standards/15-program-first-procedures/program-first-procedures.md` → no hits). `04-standards/12-code-surface-encapsulation/code-surface-encapsulation.md` keeps §1 product-UX conversational-first, adds new §1.5 carving known procedures out to Standard 15, tightens the §2 thin-glue allowance, and adds the declined option "treat a written-down procedure as cheaper to keep in a skill than in a program". `AGENTS.md` no longer contains "There is no application code"; it now admits `.eposforge/**/scripts` and `skills/*/scripts` as code roots and carries three condensed lines on home-variable invocation, `vehicle-class:` before commit, and Living Specs declaring `operating_inference`. `04-standards/README.md` lists 15. A host-name-pattern scan over every file this item touches (vision, Standard 12, Standard 15, AGENTS.md, README.md) returns nothing, and no adopter identifier or host name was introduced by this item's edits (pre-existing, out-of-scope host-name mentions elsewhere in `AGENTS.md`, e.g. `srv-docker-hp`, predate this item — confirmed via `git diff AGENTS.md`, untouched by this change). `bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh` → `backlog lint: OK`. Cross-vendor review (Gemini 3.1 Pro via evie, 2026-09-08): round 1, two majors, both confirmed and fixed; round 2, one major (this Validation field's own regex still lacked `powershell` even after Standard 15 was fixed), confirmed and fixed; round 2 also confirmed all three round-1 fixes hold. Stop rule satisfied round 2 (no open blocker/major introduced by the change) — see Notes.
Resolved: 2026-09-08
Verify with: `00-vision/00-vision.md` principle 6 reads as the split (conversational-first for product UX; program-first for known procedures; skills wrap programs; judgment stays in prose) and cites both Standard 12 and Standard 15; `04-standards/15-program-first-procedures/program-first-procedures.md` exists in standards-meta order (Status incl. declined-options, Scope, Normative requirements, Conformance, Related), carries the seven MUST requirements and the five-row vehicle-class table, and names no programming language anywhere; `04-standards/12-code-surface-encapsulation/code-surface-encapsulation.md` keeps product UX conversational-first, carves known procedures out to Standard 15 explicitly, and adds the declined option "treat a written-down procedure as cheaper to keep in a skill than in a program"; `AGENTS.md` no longer contains "There is no application code" and admits `<container>/**/scripts` and `skills/*/scripts` as code roots; `04-standards/README.md` and the standards index list 15; `rg -n '\.lan\b' ` over every file this item touches returns nothing and no adopter identifier or host name appears in them.
Notes: Filed 2026-09-07. This is the target shape of `procedure-skills-to-programs`; add `TargetShapeOf: procedure-skills-to-programs` once EF-066 lands the field. The standard packs program-first, classification, reuse/home and write-publishable into ONE standard on purpose: two always-loaded rules get treated as an optional menu. Standard 12 is amended, not replaced — it keeps its title domain (product delivery surface and code-surface encapsulation). The seven requirements are program-first; classification before commit; the class boundary (a file/git transform with tests beside it is `in-repo-pipeline` even when a second consumer exists — second consumer decides *home*, not class); one canonical copy via the documented home variable for that program's tree (`EPOSFORGE_HOME` for programs shipped here, SoT `skills/install.sh` + `skills/INSTALL.md`, clone root and overridable, unset meaning the script-calling skill is not installed; a product's procedures use that product's own documented home and MUST NOT be forced onto `EPOSFORGE_HOME`); reuse/home follows subject; write-publishable from day one; and code roots. Invalid reasons for a class, stated in the standard: "it is the default" and "it is quicker". Do not invent a second home variable or a second tree. Do not put a language prior in this repo — an adopter overlay may record one, after the class test. Adjacency: Standard 03 (skill vs tool, extended by EF-090), Standard 08 requirement 5 (public/private), Standard 10 (the gates are shape gates), Standard 11 `code_globs`, the Living Spec contract (EF-089). Plan (scope, boundaries, verification detail): `backlog/plans/EF-088-program-first-standard-15.md`. Resolved 2026-09-08: dropped the write-publishable requirement's literal star-dot-lan example (it would have tripped the item's own host-name-pattern verification as a false positive against the rule text itself) and cited "host names" generically instead, still under Standard 08 requirement 5. `AGENTS.md`'s admitted code roots are instantiated as `.eposforge/**/scripts` (this repo's uniform self-host container name) rather than the literal placeholder `<container>`. Pre-existing, out-of-scope observation made while touching this file (not fixed here): `AGENTS.md` already contained host-name mentions (`srv-docker-hp`, `dkr-cgnee-api`) elsewhere, predating this item and untouched by it — confirmed via `git diff AGENTS.md`; a separate item should scrub those if this repo is meant to stay fully host-name-free. Cross-vendor review (Gemini 3.1 Pro via evie, 2026-09-08), round 1, verdict unsound both majors confirmed and fixed: (1) Standard 15 named PowerShell in a declined-option bullet, contradicting its own "names no programming language" scope line — reworded to "Windows-native-shell" (declined options describe rejected choices, not the standard's own vehicle, but the literal name still violated the stated constraint, and the validation regex the author wrote happened to omit that one word); (2) this item's own Validation/Notes text on this very entry quoted the literal star-dot-lan pattern it had just removed from Standard 15, reintroducing the same false-positive shape one file over — reworded to describe the pattern without quoting it literally. Nit not fixed here (round 1, low severity): the "seven MUST requirements" claim is imprecise since two of the seven items in Standard 15 originally read as declarative rather than using the literal word MUST — corrected in the same commit by adding MUST to those two items rather than rewording the claim, since the standard's own frontmatter section is titled "the MUST list". Round 2 (delta review of the round-1 fix commit): one further major, confirmed and fixed — this Validation field's own recorded regex still omitted `powershell` after Standard 15 itself had already been corrected, so the "no hits" evidence it cited was weaker than the fix actually achieved; the regex here now includes `powershell`. Round 2 also confirmed all three round-1 fixes hold (PowerShell gone, all seven requirements read MUST, the star-dot-lan phrasing fixed). Stop rule satisfied at round 2: no open blocker or major attributed to this change.

## Issue EF-089 — Living Specs declare `operating_inference`
ID: EF-089
Title: Living Specs declare `operating_inference`
Date: 2026-09-07
Status: resolved
Effort: S
Fix surface: eposforge-pattern
Tags: inference
Depends on: EF-088
Blocks: EF-090
Validation: `01-architecture/02-components/living-spec.md`'s "Define minimum content" bullet lists `operating_inference` (`none` | `on-demand-judgment` | `continuous-loop`) as required for every Living Spec, requires `operating_inference_reason` and `operating_inference_budget` when the value is `continuous-loop`, recommends `operating_inference_budget` for `on-demand-judgment`, and states a `continuous-loop` capability that cannot name a budget policy is non-conformant, pointing at the `Inference Layer` slot's reference budget preflight gate at `.eposforge/inference/budget-enforcement.md` (not at the abstract `inference.md` contract, which names no budget concept); its "Required Adapter metadata" section adds that where the Adapter *is* the capability (its metadata table doubles as that capability's Living Spec, e.g. `.eposforge/SPEC.md`), the table also carries `operating_inference` — plus `operating_inference_reason`/`operating_inference_budget` only when `continuous-loop` — alongside `privacy_posture`/`cost_hint`/`invocation_surface`. `01-architecture/00-adapter-pattern/adapter-pattern.md`'s universal Adapter metadata list cross-links the same three fields for that case, pointing back at Living Spec's Required Adapter metadata section. `.eposforge/SPEC.md`'s Adapter metadata table declares `operating_inference: on-demand-judgment` (a program, `cognee-sync`, holds the path; cognify is load-bearing but budgeted) and points `operating_inference_budget` at `.eposforge/inference/budget-policy.json` + `check-budget-gate.sh` plus the already-documented full-rebuild embedding-token envelope in `.eposforge/spec-graph/cognee/scripts/bulk-rebuild.sh` (~180K-200K embedding tokens per 97-file corpus rebuild, checked against `.eposforge/.audit/inference-budget-counters.json`). `.eposforge/backlog/file-based-backlog/file-based-backlog.md`'s Adapter metadata table declares `operating_inference: none` (lint/aggregate/sweep are deterministic). `python3 .eposforge/source-control-ci/github-and-actions/scripts/check-component-links.py --check 01-architecture/00-adapter-pattern/adapter-pattern.md 01-architecture/02-components/living-spec.md` → `component-links: OK`. `bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh` → `backlog lint: OK` (only pre-existing, unrelated warnings).
Resolved: 2026-09-08
Verify with: `01-architecture/02-components/living-spec.md` minimum content lists `operating_inference` (`none` | `on-demand-judgment` | `continuous-loop`) as required, plus `operating_inference_reason` and `operating_inference_budget` as required when the value is `continuous-loop`; the adapter-pattern metadata list cross-links the same fields where the Adapter *is* the capability, alongside `privacy_posture` / `cost_hint` / `invocation_surface`; `.eposforge/SPEC.md` declares `operating_inference: on-demand-judgment` and points at the documented full-rebuild embedding-token budget; `.eposforge/backlog/file-based-backlog/file-based-backlog.md` declares `none`; the contract states that a `continuous-loop` capability which cannot name a budget policy is non-conformant and points at the existing inference budget gate.
Notes: Filed 2026-09-07. Grain is the Living Spec grain — one Product or one platform capability, not every script. Meanings, so the enum is not overloaded: `none` means a program holds the path and no model is consulted to *operate* the procedure (a program may still call a model as a library if the call is bounded, deterministic-in-role and budgeted elsewhere — prefer declaring `on-demand-judgment` when that call is load-bearing); `on-demand-judgment` means a program holds the path and occasionally asks a model for a judgment, or a skill wraps a program and the *choice* of path is the judgment; `continuous-loop` means an agent stays in the loop as the operating path, allowed only with a written reason a program cannot hold the path plus a budget. The missing field is itself the signal — no dashboard is required for v1. Spec Graph indexing is deliberately classed `on-demand-judgment`, not `continuous-loop`: cognify/extraction is load-bearing inference but a program still holds the path; an agent that "keeps recalling until the graph looks right" as the operating path would need a written reason and should be refused. No fourth enum value for batch/index jobs until two such jobs actually need to look different. Gate G4 (EF-090) scans a two-file allowlist only — do not grep for the words "Living Spec", because many adapter docs use the phrase; later expansion is a machine-readable marker, not a prose search. Wire to `.eposforge/inference/budget-enforcement.md`, `check-budget-gate.sh` and the token-usage events. Plan (scope, boundaries, verification detail): `backlog/plans/EF-089-living-spec-operating-inference.md`. Cross-vendor review (Gemini 3.1 Pro via evie, 2026-09-08), round 1, verdict unsound, one major and one nit, both confirmed and fixed: (1) major — `living-spec.md` linked the `[Inference Layer]` component contract (`inference.md`) as the home of the "budget preflight gate", but that file names no budget concept at all (`grep -i budget` returns nothing); reworded to point directly at the actual reference implementation, `.eposforge/inference/budget-enforcement.md`; (2) nit — the "Required Adapter metadata" paragraph on the Adapter-is-the-capability case listed `operating_inference_reason`/`operating_inference_budget` as unconditionally carried, contradicting the `continuous-loop`-only conditional stated two sections above and in `adapter-pattern.md`; reworded to match. Round 2 (delta review of the round-1 fix commit): one major raised (f3, misattributed as introduced-by-change) — the reviewer flagged 8 pre-existing, unrelated uncommitted files (an in-progress EF-092 secrets-launcher audit) as uncovered scope of this change; rejected, since neither EF-089 commit touches those files and round 1's own review had already agreed they were correctly out of scope, and the delta round simply starts each round with an empty out-of-scope list by design. Round 3 (re-declaring the same out-of-scope set): verdict sound, no findings. Stop rule satisfied at round 3: no refuted claim, no failed mechanical check, no uncovered scope, no open blocker or major attributed to this change.

## Issue EF-090 — Skills wrap programs: home-anchored invocation plus the vehicle-class and inference gates
ID: EF-090
Title: Skills wrap programs: home-anchored invocation plus the vehicle-class and inference gates
Date: 2026-09-07
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Tags: skills, agent-policy
Depends on: EF-088, EF-089
Blocks: EF-091
Validation: `04-standards/03-agent-skills/agent-skills.md` gains requirement 9 "Program-first wrapping": when the designation test (requirement 4) picks skill or runbook and the steps are known, the skill/runbook MUST name the program and invoke it via the documented home variable, the skill body is when/dry-run/gate/verify, platform/substrate lifecycle with a human gate MAY remain a skill wrapping a human-run program (the exception is the human gate, not cheaper prose), and judgment skills stay skills unless they have a mechanical half (docs-lint pair as the model); consume checklist item 4 and a new `skills/INSTALL.md` section both state a script-calling skill is not installed when its home variable is unset or the clone cannot be resolved. `check-vehicle-class.sh` (G1), `check-procedure-skills.sh` (G2+G3) and `check-operating-inference.sh` (G4) exist under `.eposforge/source-control-ci/github-and-actions/scripts/`, are composed into the pre-commit hook fragment and into the new required CI workflow `.github/workflows/program-first-gates.yml` (alongside `check-sensitive-literals.sh`/`check-installed-scripts-layout.sh`), and each ships a fixture test script (`test-check-vehicle-class.sh`, `test-check-procedure-skills.sh`, `test-check-operating-inference.sh`, 22 assertions total, no LLM/network) wired into `.eposforge/standing-suite`. G1 scans only files ADDED (`git diff --diff-filter=A`) under `.eposforge/**/scripts/**` and `skills/*/scripts/**`; a fixture run against a throwaway repo confirms a touched-but-not-added file is out of scope while a newly added file with no marker is caught, and staging every new file this item adds with a `# vehicle-class: in-repo-pipeline` marker passes G1 against the real commit. G4 checks only the two-file allowlist (`.eposforge/SPEC.md`, `.eposforge/backlog/file-based-backlog/file-based-backlog.md`) and both pass today (`on-demand-judgment`, `none`, from EF-089). G2 and G3 default to `PROCEDURE_SKILLS_STAGE=warn` (report, do not fail); run against the real repo they surface the pre-existing, known EF-091 debt (cwd-relative `bash .eposforge/` in `AGENTS.md`, `skills/update-spec-graph/SKILL.md`, `skills/upstream-bug-report/SKILL.md`) without failing CI, and `fail-new`/`fail-touched`/`fail-remaining` stages are implemented and fixture-tested for the ratchet's later steps. `bash .eposforge/standing-suite` → all green, including the three new fixture suites and a direct G4 run against real content. `bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh` → OK (only pre-existing, unrelated warnings). `python3 .eposforge/source-control-ci/github-and-actions/scripts/check-component-links.py --check 04-standards/03-agent-skills/agent-skills.md` → OK.
Resolved: 2026-09-08
Verify with: `04-standards/03-agent-skills/agent-skills.md` requires that when the designation test picks skill or runbook AND the steps are known, the skill names the program and invokes it via the documented home variable, and that the skill body is when / dry-run / gate / verify; `skills/INSTALL.md` states that a script-calling skill is not installed when its home variable is unset or the clone cannot be resolved; `check-vehicle-class.sh`, `check-procedure-skills.sh` and `check-operating-inference.sh` exist under `.eposforge/source-control-ci/github-and-actions/scripts/`, are composed into the pre-commit fragment and into a required CI workflow next to `check-sensitive-literals.sh` and `check-installed-scripts-layout.sh`, and each ships its fail/pass fixture pairs; G1 scans only files ADDED under `.eposforge/**/scripts/**` and `skills/*/scripts/**` (`git diff --diff-filter=A`), G4 scans only `.eposforge/SPEC.md` and `file-based-backlog.md`; G2 and G3 land in warn mode with the warn → fail-new → fail-touched → fail-remaining ratchet written down; a Standard 10 conformance note records that these are shape gates and that green G1–G4 is not a claim that any migration is finished.
Notes: Filed 2026-09-07. Gate half of EF-062 (its dependency EF-033 is already resolved). Four gates: G1 classification present (a new file in a declared code root carries a `vehicle-class:` marker); G2 a procedure `SKILL.md` whose body is a numbered executable recipe invokes a program via the documented home variable; G3 no cwd-relative `bash .eposforge/` or `bash skills/` in `SKILL.md` or always-loaded instructions; G4 an allowlisted Living Spec declares `operating_inference`, and `continuous-loop` carries reason + budget. Ungameable per Standard 10: the checkers live in `source-control-ci`, not inside the skill being judged (same same-repo limitation as today's layout check — the durable enforcement is the required CI status check); fixtures derive from the standard's text, not from whatever implementation landed; the gate catches shape, not whether the procedure works (behavioral tests stay with the program, Standard 09). The recipe-vs-judgment discrimination in G2 must NOT ship as a guessed heuristic that fails builds: collect operator-reviewed examples first, then fail new or newly-touched files only — otherwise judgment skills get false-positived and someone disables the gate. Do not confuse the new `vehicle-class:` lint with `check-doc-classification.py`, which validates `doc_kind` / `scope` / `maturity` on Markdown and is unrelated. This item does not rewrite skills; it makes the next touch fail if the touch invests in the legacy shape. Plan (scope, boundaries, verification detail): `backlog/plans/EF-090-skill-program-gates.md`. Cross-vendor review (Gemini 3.1 Pro via evie, 2026-09-08), 3 rounds, round cap reached with one open item — surfaced to the operator rather than auto-continuing (see below). Round 1: verdict sound-with-caveats, all 13 claims confirmed, 3 findings — f1 minor (check-operating-inference.sh's naive `awk -F'|'` value extraction could be tricked by a literal `|` inside a value cell), f2 nit (check-vehicle-class.sh's marker regex recognized only `#`-comments, not `//`/`--`), f3 nit/not-a-defect (G2 correctly flags `skills/maintain-ontology/SKILL.md` in advisory warn-only mode, confirmed as intended). f1 and f2 accepted-fixed, f3 rejected (no defect). Round 2: verdict unsound — the round-1 "fix" for f1 was itself incomplete: a decoy valid-looking backtick token later in a malformed row could still get picked up, letting a bad value through; this became f1 in round 2 (major). Also found f2 (major): the pre-commit fragment called `check-operating-inference.sh` with no `--staged`, so the gate validated the working tree instead of what was about to be committed. Both accepted-fixed and re-verified against the reviewer's own `repro_cmd`s: extraction rewritten as an anchored `grep -oP` with `\K` so a malformed value cell cannot be rescued by a later coincidental token; `--staged` added to the script (reads via `git show ":path"`, mirroring `check-vehicle-class.sh`) and wired into the pre-commit fragment. Round 2 also asserted (in its own uncovered_scope) that 8 pre-existing, unrelated EF-092 secrets-launcher-audit files (dirty in the working tree since before this item started, unrelated `.eposforge/secrets-key-management/**`) were "modified... to add vehicle-class markers" as if that were this item's doing; round 3 disposed that as a rebuttal, but the rebuttal itself overreached by calling the underlying observation false — round 3 correctly caught this (f3, major): those 8 files DO contain `# vehicle-class:` additions in the dirty tree (confirmed: `git diff` on each shows a `+# vehicle-class: ...` line), just not added by this item — they were already dirty before this session touched anything (Standard 15, an EF-090 dependency via EF-088, independently requires the same marker on EF-092's own touched launchers). Disposed accepted-fixed as a correction to the record, not a code change: these 8 files remain outside EF-090's own commit (never staged, never edited by this item). Round cap (3) reached with this one item still open per `crosscheck-decide.sh` ("halt"); per the crosscheck skill's own design this is a stop-and-surface point, not license to keep auto-continuing — reported to the operator alongside this resolution rather than resolved silently. All mechanical/fixture claims held throughout: `bash .eposforge/standing-suite` green (G4 fixture count grew 7→12 across the rounds), `bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh` → OK.

## Issue EF-091 — Dogfood: wrap both Spec Graph runs, home-anchor the remaining skills, strip the public leaks
ID: EF-091
Title: Dogfood: wrap both Spec Graph runs, home-anchor the remaining skills, strip the public leaks
Date: 2026-09-07
Status: resolved
Effort: M
Fix surface: eposforge-pattern
Tags: skills, spec-graph
Depends on: EF-087, EF-089, EF-090
Validation: `skills/update-spec-graph/SKILL.md` now invokes both paths via the home variable: incremental through a new program, `.eposforge/spec-graph/cognee/scripts/sync-incremental.sh` (extracted from the inline git-diff-then-dispatch recipe so the recipe is a program, not prose — same exclusions: the ontology TTL, `backlog/`/`.eposforge/backlog/`/`plans/`), and full rebuild through `bulk-rebuild.sh`, both as `bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}"/.eposforge/...`; the skill body now carries only the path-choice table, preconditions, the two one-line invocations, and the verify steps. The leaked internal `.lan` hostname in its verify section is replaced with `$COGNEE_API_URL` plus a pointer to the private deployment runbook. `skills/upstream-bug-report/SKILL.md` home-anchors its `new-issue.sh` call; `skills/portfolio-review/SKILL.md`'s five `..eposforge` double-dot paths are corrected to `.eposforge`. All three SKILL.md frontmatters flip `legacy_shape_of: procedure-skills-to-programs` to `target_shape_of: procedure-skills-to-programs`. `AGENTS.md`'s cwd-relative Spec Graph and backlog examples (7 call sites) are home-anchored the same way. `rg -n 'bash \.eposforge/|bash skills/' AGENTS.md skills/` still matches six lines in `skills/INSTALL.md` (`bash skills/install.sh ...`) — deliberately left as-is (see Notes). `check-sensitive-literals.sh` gains a `.lan` hostname hard-fail (`\b[a-z0-9][a-z0-9-]*\.lan\b`, the same regex `lint-backlog.sh` already uses) scoped to paths under `skills/` only; `bash .eposforge/source-control-ci/github-and-actions/scripts/check-sensitive-literals.sh` (full-tree default mode) passes clean. `check-procedure-skills.sh` (G2/G3) run against the real repo no longer reports `AGENTS.md`, `skills/update-spec-graph/SKILL.md` or `skills/upstream-bug-report/SKILL.md` — the only remaining G2 advisory is the pre-existing, explicitly out-of-scope `skills/maintain-ontology/SKILL.md`. `bash .eposforge/standing-suite` → all green. The new `sync-incremental.sh` and the edited `check-sensitive-literals.sh` both carry `# vehicle-class:` markers (`in-repo-pipeline`, `host-ci-glue`).
Resolved: 2026-09-08
Verify with: `skills/update-spec-graph/SKILL.md` invokes BOTH the incremental sync program (`sync-incremental.sh`) and the bulk-rebuild program as `bash "${EPOSFORGE_HOME:?set EPOSFORGE_HOME}/.eposforge/..."`, retains only the path-choice table and the verify steps (the inline git-diff recipe is gone), and contains no host name, container name or `*.lan`; `skills/upstream-bug-report/SKILL.md` and `skills/portfolio-review/SKILL.md` resolve their programs the same way and the `..eposforge` double-dot path is gone; `rg -n 'bash \.eposforge/|bash skills/' AGENTS.md skills/ --glob '!skills/INSTALL.md'` returns nothing (INSTALL.md's own bootstrap invocations of `skills/install.sh` are the one deliberate, documented exception — see Notes); `check-sensitive-literals.sh` hard-fails a hostname matching `\b[a-z0-9][a-z0-9-]*\.lan\b` under `skills/` and does NOT fail the rest of the tree; each skill strangled by this item carries `target_shape_of: procedure-skills-to-programs`; every file this item touches that is a program carries a `vehicle-class:` marker; `aggregate.sh --strangler` still shows `procedure-skills-to-programs` with an empty backlog-item legacy list (unchanged — that migration's legacy side was always diffuse corpus state, not a backlog item, per EF-091's own filed Notes); the debt this item actually shrinks is the frontmatter flip checked above, not the strangler view's item list.
Notes: Filed 2026-09-07. Correction 2026-09-08 (EF-066 cross-check, operator decision): this item does execution/target-side work (finishing the migration), not legacy-side work, so it does NOT carry `LegacyShapeOf: procedure-skills-to-programs` — two independent review rounds found that labeling it Legacy made EF-066's own debt marker print a literally-false "do not invest" warning on the exact item required to finish the migration. `procedure-skills-to-programs`' legacy side is diffuse corpus state (the as-yet-unconverted skill files themselves, tracked via `legacy_shape_of` frontmatter per EF-087 — a file-level marker, not a backlog field) rather than a single legacy-shape backlog item; EF-066's lint was relaxed accordingly (see its Notes). It is also the remaining invocation-path half of EF-062. Bounded batch, not a sweep: the classification for the Spec Graph surface is `cognee-sync` = `in-repo-pipeline`, `bulk-rebuild.sh` = host/CI glue, and the skill wraps both — the incremental-vs-full *choice* is the judgment that stays in prose, the runs are the program. Stay-skills, explicitly out of this rewrite: `milestone-elicitation`, `refine-prompt`, the portfolio-review *judgment* steps, the docs-lint *semantic* half, the `maintain-ontology` editorial judgment — if any grows a mechanical half, extract only that half. Stay-glue, classified but not promoted: `bulk-rebuild.sh`, the hook composer, `install-hooks.sh`, `lint-backlog.sh`. The `.lan` regex is the one `lint-backlog.sh` already uses, and the docs-lint skill's `*.lan` rule text is safe under it; the existing leak in `update-spec-graph/SKILL.md` is what proves the checker gap. Do NOT fail-all the rest of the tree here — several historical files under `docs/` are already red and cleaning them is a separate follow-up; fail-on-new outside `skills/` is optional. Secrets launchers are NOT in this item (EF-092): one bad collapse breaks Windows Git Bash or a POSIX PATH, and it must not be able to revert the skill-path fixes. Plan (scope, boundaries, verification detail): `backlog/plans/EF-091-dogfood-home-anchored-skills.md`. Correction 2026-09-08 (implementation): the filed Verify with's `rg` command, run literally with no exclusion, also matches six lines in `skills/INSTALL.md` (`bash skills/install.sh ...`). Left unfixed deliberately, and the acceptance command above amended with `--glob '!skills/INSTALL.md'` to say so explicitly: INSTALL.md documents running the framework's own installer *from inside the framework clone itself* — the case that defines `EPOSFORGE_HOME` in the first place, not a skill wrapper invoking a program from an arbitrary cwd — and Standard 15's own G3 rule already scopes to "SKILL.md or always-loaded instructions," neither of which INSTALL.md is. `skills/INSTALL.md` was also already dirty (staged, uncommitted) from EF-090's own work before this item started; this item does not touch it. Also extracted per the Verify with's explicit "the inline git-diff recipe is gone" requirement: the incremental path's diff-then-dispatch recipe moved out of the skill into a new program, `.eposforge/spec-graph/cognee/scripts/sync-incremental.sh` (`vehicle-class: in-repo-pipeline`), matching "the runs are the program" from this item's own filed Notes above.

## Issue EF-092 — Secrets launcher audit: collapse the write-twice twins, keep the thin launchers
ID: EF-092
Title: Secrets launcher audit: collapse the write-twice twins, keep the thin launchers
Date: 2026-09-07
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: secrets
Verify with: an audit table lists every `.sh`, `.ps1` and Python entrypoint under `.eposforge/secrets-key-management/`, records for each whether it is a thin launcher over a shared core or a second implementation, and names the layout each one resolves; after the change every surviving pair launches ONE write-once core; no `.ps1` launcher is deleted; the same entrypoint invoked from a POSIX shell and from Windows Git Bash reaches the same core and produces the same result; each touched program carries a `vehicle-class:` marker; no plaintext secret value is printed by any path the audit touches.
Notes: Filed 2026-09-07. Follow-up, deliberately independent of EF-091 so a bad collapse cannot revert the skill-path fixes; audit table comes first, before any collapse. Today's pairs already disagree on layout — `setup.sh` and `setup.ps1` both wrap `setup_core.py` (already the right shape), while the machine-request and authorize entrypoints resolve three different trees across their `.sh`, `.ps1` and Python forms. The rule is write once, thin launchers for OS-specific bits; dual POSIX + PowerShell *implementations* are declined because twins drift, which is exactly what these entrypoints demonstrate. Adjacency: EF-022 (relocatable resolver / `EPOS_SECRETS_HOME`) is the vault-location half and stays separate. Plan (scope, boundaries, verification detail): `backlog/plans/EF-092-secrets-launcher-audit.md`.

## Issue EF-093 — Named migration `prose-to-contract`: agent-facing knowledge moves from prose an agent re-reads to contracts a runtime enforces
ID: EF-093
Title: Named migration `prose-to-contract`: agent-facing knowledge moves from prose an agent re-reads to contracts a runtime enforces
Date: 2026-09-12
Status: open
Effort: XL
Fix surface: eposforge-pattern
Tags: skills, agent-policy, distribution
Migration: prose-to-contract
Verify with: `aggregate.sh --strangler` renders `prose-to-contract` with at least one target-shape item; this item states the completion commitment 2027-12-31 and the four phases below; every item filed under the umbrella carries `TargetShapeOf: prose-to-contract` (or `LegacyShapeOf:` where its own work still invests in the prose shape) so the whole programme is one view rather than a scatter of unrelated tickets; an agent that opens any member item can reach this owner row and read the overall direction without being told it exists; the phase ordering below is stated as an ordering, and phase 2 items do not start before the phase 1 declaration items are resolved.
Notes: Filed 2026-09-12. Owner row only — no work happens here. This exists because the programme it names is large enough to fragment: roughly a dozen items across the pattern repo and its adopters that are individually small and collectively one direction, and the failure mode is that six months in nobody can see the shape any more. `procedure-skills-to-programs` (EF-086) is a PHASE of this migration, not a sibling — it does not get re-parented or closed early, but its completion is not this migration's completion.
The direction in one sentence: knowledge an agent needs is currently held as prose the agent re-reads and re-interprets on every use, and it should be held as contracts a runtime enforces — a tool schema, a generated config, a declared root, a queryable graph.
The four phases, in order:
(1) DECLARE — every repo says what it is made of, so the later phases have something to point at. Code roots per repo (Standard 12 requirement 2). This is the cheapest phase and it gates the rest, because a graph or an indexer built before the boundary is declared indexes the wrong tree.
(2) REGISTER — procedures and store verbs become callable things with schemas rather than prose recipes. `procedure-skills-to-programs` (EF-086) is the first half of this: steps move out of `SKILL.md` into a committed program. The second half is the tool hop, filed separately, because a program invoked by shelling out is not yet a contract the runtime enforces.
(3) GENERATE — harness configuration, tool assignment and instruction projection stop being hand-maintained per surface and become emitted from one declaration. The assignment plane already does this for MCP servers; the same plane grows to cover which agent gets which tools.
(4) NAVIGATE — the graph surfaces (contracts, code as-built, instruction topology, host topology, interaction corpus) become the way an agent finds things, replacing whole-corpus prose reads.
Completion commitment: 2027-12-31. That is a commitment to have every member item resolved or explicitly re-scoped by that date, not a promise that the direction is finished — phase 4 in particular will outlive it.
Public/private boundary: adopters file their own phase items in their own backlogs and reference this slug via `TargetShapeOf: prose-to-contract`. Adopter IDs never appear here (EF-047).
Adjacency: EF-086 (phase 2, first half), EF-066 (the schema making this legible), EF-080 (the assignment plane phase 3 extends), Standard 03 (skill vs tool), Standard 04 (MCP two duties), Standard 12 (code-surface encapsulation), Standard 15 (program-first).

## Issue EF-094 — Program-first is not tool-registered: add the second hop to the migration's definition of done
ID: EF-094
Title: Program-first is not tool-registered: add the second hop to the migration's definition of done
Date: 2026-09-12
Status: open
Effort: M
Fix surface: eposforge-pattern
Tags: skills, agent-policy
TargetShapeOf: prose-to-contract
Depends on: EF-088
Verify with: Standard 15 states that moving a procedure's steps into a program is the FIRST of two hops and names the second (registering the program as a Tool Transport tool with a declared schema), so a reader cannot conclude that a program-wrapped skill is finished; Standard 03's designation table gains a row or note distinguishing "a skill that wraps a program the agent shells out to" from "a skill that wraps a registered tool", with the test for when the second hop is required; a decision test exists that an agent can apply without judgement — at minimum, a procedure whose inputs and outputs are structured and whose body no longer contains judgement MUST be registered, and one whose body still contains a human gate or a refusal MAY stay a shelled-out program; EF-086's completion criteria are amended so the migration is not declared done on the program hop alone, or an explicit note records the decision to leave the second hop out of that migration's scope; `docs-lint` or an equivalent check can distinguish the two shapes mechanically (a `SKILL.md` invoking a program via the home variable, versus one naming a registered tool).
Notes: Filed 2026-09-12. The gap this closes: Standard 15 requirement 1 says once the steps are known they live in a program and the skill wraps it. Standard 04 requirement 4 separately says a verb on a factory system of record must be a registered tool. Between them sits every procedure that is NOT a store verb — the majority — for which the current answer is "make it a program" and nothing says "then register it." A program the agent shells out to still loads its invocation prose into the conversation and still costs a round trip; the model does not see a schema, it sees instructions about a command. That is a smaller improvement than the standard implies, and an agent reading Standard 15 today will reasonably mark such a conversion complete.
Do NOT resolve this by declaring every program a tool. The second hop has a real cost — an MCP server to host it, a schema to maintain, a lifecycle owner — and the majority of one-off glue does not earn it. The deliverable is the test that separates the two, not a blanket rule.
Adjacency: EF-086 (the migration whose done-ness this changes), EF-088 (Standard 15 itself), EF-090 (skills wrap programs — the same seam one level down), Standard 03 requirement 4, Standard 04 requirement 4.

## Issue EF-095 — A converted skill leaves a wrapper behind, and nothing says when it dies
ID: EF-095
Title: A converted skill leaves a wrapper behind, and nothing says when it dies
Date: 2026-09-12
Status: open
Effort: S
Fix surface: eposforge-pattern
Tags: skills
TargetShapeOf: prose-to-contract
Depends on: EF-094
Verify with: Standard 03 (or Standard 15, whichever owns the conversion path) states the retirement rule for a wrapper whose body has moved to a program or a tool: the conditions under which the wrapper is deleted rather than kept, who decides, and what happens to its trigger phrases so a user typing the old slash command is not left with nothing; the rule distinguishes a wrapper that still adds chair, order, dry-run or a human gate (keep — that is its job) from one that now only forwards (delete); a converted-but-not-retired wrapper is detectable, either by the file-level `legacy_shape_of` marker EF-087 already introduces or by a lint advisory, so the residue is countable rather than discovered years later; at least one already-converted wrapper in this repo is run through the rule as the worked example.
Notes: Filed 2026-09-12. The observable risk: conversion is additive by default. Each hop leaves the prior shape in place because deleting it is nobody's step, and the estate accumulates wrappers that forward to programs that forward to tools. That is worse than either endpoint — three files to read, three places to drift.
Deliberately small and deliberately AFTER the tool hop test (EF-094): a retirement rule written before the conversion test exists would have to guess what it is retiring.
Adjacency: EF-087 (file-level legacy-shape markers — likely the detection surface), EF-094 (the hop this cleans up after), Standard 03 requirement 4.

## Issue EF-096 — Execution units: hand a coherent group of backlog items to an implementation agent as one unit
ID: EF-096
Title: Execution units: hand a coherent group of backlog items to an implementation agent as one unit
Date: 2026-09-13
Status: open
Effort: L
Fix surface: eposforge-pattern
Tags: backlog-tooling, orchestrator
Depends on: EF-081
Verify with: `.eposforge/backlog/file-based-backlog/docs/schema.md` documents optional `Execution units:` as a comma-separated list of implementation-unit slugs; `ready.sh` renders it in text output and emits `execution_units` in `--json`; a versioned implementation-unit manifest format exists under `.eposforge/backlog/implementation-units/` with a bounded, ordered list of qualified backlog IDs, shared plan path, target orchestrator identifier, and handoff tier; the manifest is canonical, while each member item declares matching `Execution units:` membership; lint validates bidirectional membership, item existence, duplicate membership, plan paths (by the EF-081 rules), same-target eligibility, and dependency ordering; the unit-oriented output includes a human-readable implementation brief and JSON manifest; the portfolio-review handoff can select an implementation unit instead of repeating individual items; the adapter Living Spec documents that an implementation agent loads the unit manifest and plan before working the item group; the integration contract documents that an adopter's orchestrator adapter may consume a unit by retaining one external reference and acceptance record per constituent item; focused tests or fixtures cover valid and invalid units and output; the backlog lint passes.
Notes: Split from EF-081 on 2026-09-13, when that item took on a standard, scaffolding and lint work; this is EF-081's original execution-unit scope, moved without change. A durable execution-unit layer for handing a coherent group of items to an implementation agent. `Bundle hint:` remains advisory co-scheduling metadata; `Depends on:` and `Blocks:` remain dependency edges. An implementation unit is an explicit, bounded work package with a shared design and handoff context, not a replacement for either mechanism. The shared plan a unit names is an EF-081 plan; this item defines no second plan location. The implementation plan records durable operator/spec intent before dispatch; it is not an orchestrator operational plan. An adopter's orchestrator owns its own conversion, dispatch, and runtime behavior; this item only defines the portable input and integration contract. Backlog-graph metadata, not main Spec Graph content (EF-057 boundary). Not labelled `prose-to-contract`: it adds a new handoff contract rather than moving an existing prose convention. Adopter items that cited EF-081 for the execution-unit contract should re-point here. Adjacency: EF-081 (plans), EF-056/EF-057 (independent agent-facing backlog graph), EF-066, portfolio-review Step 7 (implementation handoff).

## Issue EF-097 — Backlog coverage agent: a subagent that runs automatically to check whether the backlog already covers what is being discussed or changed
ID: EF-097
Title: Backlog coverage agent: a subagent that runs automatically to check whether the backlog already covers what is being discussed or changed
Date: 2026-09-13
Status: open
Effort: L
Fix surface: eposforge-pattern
Tags: backlog-tooling, agent-policy
TargetShapeOf: prose-to-contract
Depends on: EF-081
Implementation plan: .eposforge/backlog/plans/EF-097-backlog-coverage-search.md
Verify with: (1) Command — `file-based-backlog/scripts/search-backlog.sh <terms...> [--json] [--limit N]` searches, in every discovered root (same precedence as `aggregate.sh`), the `Title:`, `Verify with:` and `Notes:` text of active, slated and archived items and every `.md` file directly under that root's `backlog/plans/`; matching is case-insensitive per term after a committed stopword list; ranking is computed with no model call (distinct terms matched, then field `Title` > `Verify with` > `Notes` > plan body, then active > slated > archived, then ID). (2) Output — each hit gives repo, item ID (for a plan, its path and the ID its filename names), status or file kind, field, path, line number and the matching line truncated to a fixed length; `--json` adds a `searched` block with each root's resolved path and its counts of active, slated and archived items and plan files; output never contains a verdict such as "covered" or "not covered"; exit 0 on hits, 1 when the search ran and found none, 2 when it could not evaluate. (3) Refusal — exit 2 with a message naming the root when no root is discovered, when a declared root has no `backlog/config.toml` (naming the parent directory when the path ends in `/backlog`), when a backlog file has `## Issue` lines but zero items parse, when all roots together hold zero items, or when every term is a stopword. (4) Coverage agent — the pattern ships a harness-neutral subagent definition, `file-based-backlog/agents/backlog-coverage.md`, projected into each harness's native subagent form by the same install as EF-081's `backlog-author`; it is read-only (the search command and file reads; no edit, write, filing or agent-spawning tools); given the statement, question or proposed change, it runs `search-backlog.sh --json` first, reads the top hits and any plan they point at, runs a bounded number of further searches using wording it derives (synonyms, and the field names the backlog actually uses), and returns a report listing each candidate with repo, ID or plan path, the quoted line, and a label of likely the same idea, related, or different with a one-sentence reason, keeping keyword hits distinguishable from candidates found only by its own rewording, and ending with the `searched` counts; when the command exits 2 the report is one line saying it could not check and why; the agent never files, edits or closes an item, and its report is evidence the conversing session and operator weigh, not a decision. (5) Filing and commit triggers — `new-issue.sh --title "<title>"` runs the search first, prints hits to stderr and does not append while hits exist unless `--after-coverage-check` is also passed; `new-issue.sh` with no title behaves as today and states on stderr that no coverage search ran; the backlog pre-commit hook prints, without blocking, the top hits for each `## Issue` header the commit adds, excluding that item; EF-081's `backlog-author` runs the coverage agent before it files. (6) Trigger contract — `01-architecture/02-components/backlog.md` states that a harness runs the coverage agent automatically, without the conversing agent choosing to, before an agent asserts that a rule, convention or decision does or does not exist and before it files or changes an item; that the gate is deterministic, and nothing runs and no tokens are spent when it does not fire; that the agent's report reaches the conversing session before it replies; and that exit 2 or a timeout is surfaced as "could not check", never dropped or shown as empty; `AGENTS.md` has one line telling a session whose harness has no such trigger to delegate to the coverage agent itself in those cases. (7) Tests — a fixture suite with paired negative controls covers a term found only in an active item's `Notes:`, a term found only in a plan file, slated and archived hits, ranking order, a no-hit search exiting 1 with non-zero `searched` counts, `BACKLOG_ROOTS` set to `<repo>/.eposforge/backlog` exiting 2 while `<repo>/.eposforge` on the same fixture exits 0, the parse-zero case, and the `new-issue.sh` hold and override; an agent eval against a fixture backlog shows a question whose answer sits in one item's `Notes:` under different wording (for example "where do design docs for tickets go" against an item that says "implementation plan") returning that item as a likely match with the quoted line, an idea with no coverage returning no likely match with non-zero `searched` counts, and a wrong-depth root returning "could not check"; the backlog lint passes.
Notes: Filed 2026-09-13. Asked whether a plan-file convention existed, an agent searched standards, architecture and instruction docs and the Spec Graph twice, found nothing, and told the operator the rule was not written down; it was in an open item's `Notes:` (EF-081). Backlog items and plans are excluded from graph ingest by design (EF-057), and nothing prompted a backlog search: about 15 tool calls and one wrong assertion. Existing surfaces miss it: `aggregate.sh --regressions` searches archived items only, for one substring, and exits 0 with "No backlog adapters discovered" when a root is at the wrong depth; EF-057's traversal skill is on-demand and should call this command rather than grow its own search; the portfolio-review redundancy step is periodic. The operator asked for an agent that runs automatically, not only a hook (2026-09-13), so the lookup is a subagent; the computable parts stay computed: the gate decides whether it runs at all, and the deterministic search is its first step and the source of its refusals. Keyword search alone finds the motivating case; the agent earns its tokens on changed wording and on reading the plans that hits point at. Nothing runs or is emitted when the gate does not fire; nothing here files, edits or closes an item. Adopters wire prompt and agent-tool triggers in their own backlogs (EF-047). Member of `prose-to-contract` (EF-093), phase 4: "check the backlog first" moves from something an agent must remember to an agent a trigger runs. Adjacency: EF-057, EF-081 (shared subagent install; its `backlog-author` calls this agent), EF-093.
