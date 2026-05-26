# Backlog

Active issues (`open`, `in-progress`, `blocked`) for this repo.

## Issue EF-011 — Spec graph recall conflates EposForge components with adopter-side infrastructure
ID: EF-011
Title: Spec graph recall conflates EposForge components with adopter-side infrastructure
Date: 2026-05-23
Status: open
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-009
Verify with: a recall query phrased as "how does an adopter org do <pattern>" returns answers that name the pattern at the adopter's adoption layer rather than embedding EposForge's internal `instance/installed/<NN>-<component>/` paths. Specifically: when an adopter with sibling repos (separate from their EposForge clone) asks how to apply an EposForge-shipped pattern in those sibling repos, the answer must not present `instance/installed/...` paths as if they exist on the adopter's side.
Notes: Surfaced when an adopter querying the graph about secrets handling for a sibling-repo CI workflow got back a recommendation to invoke `instance/installed/12-secrets-key-management/bin/epos-secrets` directly — a path that only exists inside an EposForge clone. The pattern (sops-age with the recipient list managed at the adopter-org level) is correct; the implementation path is EposForge-internal and shouldn't appear in an adopter-side recommendation. EF-009 introduced `ef:adoptsFrom` to express adoption relationships in the ontology, but the recall/answering layer doesn't appear to respect adoption boundaries when phrasing answers. Likely fix lives in the retrieval/answering layer of the spec graph rather than in ontology vocabulary. Related to EF-012 (graph emits design intent as present-tense), which compounds this: even if the conflation were resolved, the recommended invocation today assumes an installable artifact that doesn't yet exist.





## Issue EF-012 — Spec graph emits design intent as present-tense state; recommendations need maturity tagging
ID: EF-012
Title: Spec graph emits design intent as present-tense state; recommendations need maturity tagging
Date: 2026-05-23
Status: open
Effort: M
Fix surface: eposforge-pattern
Verify with: recall queries either (a) return only present-tense, currently-shipped state by default, or (b) tag returned recommendations with their adoption maturity (e.g. `shipped` / `partial` / `intent`) so consumers can distinguish "do this today" from "this is the target." A query about a pattern whose recommended invocation requires a source-tree clone must surface that prerequisite explicitly in the answer.
Notes: Recall results in the field treat aspirational designs as if they have shipped. Two examples surfaced in one session: (1) `epos-secrets` is recommended as the standard runtime invocation for sops-age, but it currently exists only as a script inside `instance/installed/12-secrets-key-management/bin/`, with no stable installable artifact — an adopter in mode-B (consume-without-fork) cannot follow the recommendation as written; (2) the graph characterizes an adopter-side IaC use case as a "future capability" blocked on an upstream tooling gap, when adopters have already implemented the workaround. The common root: the graph fuses design intent and operational state into a single voice. Possible directions: maturity tags on recommendation nodes (`shipped`|`partial`|`intent`), separate "design" vs "operational" recall views, or richer source-of-truth provenance per fact. Related to EF-011 (conflation): together they erode adopter trust in the graph as a recommendation surface.





## Issue EF-017 — Component 10 (Inference): Azure AI Foundry routing backend
ID: EF-017
Title: Component 10 (Inference): Azure AI Foundry routing backend
Date: 2026-05-24
Status: in-progress
Effort: M
Fix surface: eposforge-pattern
Verify with: the inference adapter routes Cognee LLM + embedding calls to an Azure AI Foundry endpoint via LiteLLM (`azure/<deployment>` + AZURE_API_BASE/AZURE_API_KEY/AZURE_API_VERSION); a full Cognee re-graph completes against Foundry; provider is selectable as config. This is the cost gate: once routing is live, cognify bills against a credit-funded Azure subscription rather than direct metered vendor APIs.
Notes: Mechanism only — cloud resource/project provisioning, deployment rate (TPM) caps, and per-repo keys are host/adopter concerns tracked on the host-stack backlog. Cognee uses LiteLLM under the hood, so this is largely an `.env`/config path plus adapter support for an azure backend. Gates the migration's re-cognify steps (EF-019, EF-021). Progress: provider-selectable Azure routing contract and validator are now implemented in repo docs/scripts; full Foundry re-graph verification remains deferred until the cost-gate dependency chain is fully satisfied.




## Issue EF-022 — Make epos-secrets a relocatable resolver (decouple vault location from script location)
ID: EF-022
Title: Make epos-secrets a relocatable resolver (decouple vault location from script location)
Date: 2026-05-24
Status: open
Effort: S
Fix surface: eposforge-pattern
Verify with: a single `epos-secrets` (owned by EposForge, on PATH) resolves secrets against a vault that lives in a *different* repo when `EPOS_SECRETS_HOME` points at that repo's `12-secrets-key-management/` dir; no duplicated copy of the script in the adopter repo; `vault_key` aliasing and the `sensitivity` field still work; with `EPOS_SECRETS_HOME` unset, behavior is unchanged (script-relative discovery, backward compatible).
Notes: Today the resolver discovers its manifests + vault relative to its own script path (`_SCRIPT_DIR.parent` → `sops-age/secrets.enc.yaml`), so it cannot point at a vault elsewhere. During the GraceEnterprises single-vault migration (2026-05-24) this forced copying the whole adapter — including `bin/epos-secrets` — into the adopter repo, producing two divergent copies of the script (the `vault_key` enhancement had to be hand-applied to both). Fix: add an `EPOS_SECRETS_HOME` (or `EPOS_VAULT`) env var / small config that sets the manifest+vault root, defaulting to the current script-relative path. Then one EposForge-owned resolver on PATH serves the adopter's vault, and the adopter repo holds only data (vault + manifests), not code. Directly addresses the "no stable installable artifact" gap called out in EF-012 and the adopter-path conflation in EF-011 (mode-B consume-without-fork adopters need a resolver they can invoke without an EposForge clone). Follow-up after this lands: collapse the duplicated GEA copy back to a symlink/PATH reference.



## Issue EF-023 — Capture cross-IDE agent chat logs inside GEA LAN for semantic memory and future distillation
ID: EF-023
Title: Capture cross-IDE agent chat logs inside GEA LAN for semantic memory and future distillation
Date: 2026-05-25
Status: open
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-017
Verify with: for both Claude Code and GitHub Copilot sessions, chat transcripts (prompts, assistant responses, tool traces metadata, and session identifiers) are persisted to a GEA-LAN-hosted storage target with a documented retention policy; records include stable account identity and machine identity fields so sessions from the same Claude/Copilot account across different dev machines are correlated into one logical timeline; a semantic index job can ingest new transcripts incrementally and answer recall queries over both IDE sources in one result set; access controls enforce LAN-local storage + operator-only retrieval/export; a dry-run dataset can be exported in a training-ready JSONL format for future fine-tuning/distillation experiments without changing source-of-truth raw logs. Implementation bootstrap exists in `.scratchpad/build-unified-chat-index.py` (index build) and `.scratchpad/search-unified-chat-index.py` (semantic prefilter/search scaffolding).
Notes: User-story intent: while EposForge is pre-dark-factory and developers still use heterogeneous IDE adapters, conversation exhaust should not remain fragmented across vendor clouds or local workstation silos. Implement an adapter-agnostic chat capture contract (normalized event schema + source adapter field), then add per-adapter collectors for Claude Code and Copilot. Keep raw immutable logs plus derived semantic chunks as separate layers. Include identity provenance fields (provider account key + machine key + workspace key) to support cross-machine continuity for one developer account. Include privacy/safety guardrails (PII redaction mode, secret-token scrubbing, and explicit opt-in boundaries for any downstream training export). Seed artifacts now live in `.scratchpad/unified-chat-index.jsonl` with extraction support from `.scratchpad/export-claude-session-md.py`. This issue is the observability + memory substrate needed to support semantic search now and potential model distillation later.



## Issue EF-024 — Implement EF-023 in four delivery tracks (schema, collectors, indexing, query/policy)
ID: EF-024
Title: Implement EF-023 in four delivery tracks (schema, collectors, indexing, query/policy)
Date: 2026-05-25
Status: open
Effort: L
Fix surface: eposforge-pattern
Depends on: EF-023
Verify with: all four tracks are implemented and validated end-to-end in staging on GEA LAN: (1) canonical chat-event schema with versioning, source adapter attribution, and account/machine correlation identifiers; (2) collector adapters for Claude Code and GitHub Copilot writing immutable raw logs to LAN-local storage from multiple developer machines under the same account; (3) incremental semantic indexing pipeline that tracks high-water marks and supports replay/rebuild; (4) operator-facing semantic query/retrieval interface with role-based access control, auditable export path, and policy enforcement for redaction/training eligibility tags.
Notes: Delivery split for execution sequencing.
Track 1 (schema contract): define a normalized event model that can represent prompts, assistant responses, tool events, token/cost metadata when available, session/workspace identifiers, adapter provenance, and correlation identity fields (provider account id surrogate + machine id + workspace id). Include schema_version and backward-compatible migration rules.
Track 2 (adapter collectors): implement per-IDE ingestion adapters that map native logs into Track 1 schema and append to immutable raw store. Ensure idempotent ingest (dedupe key), failure-safe retry semantics, and multi-machine ingestion under one provider account without duplicate replay. Current prototype entrypoint: `.scratchpad/build-unified-chat-index.py`.
Track 3 (semantic indexing): build chunking + embedding + index-write pipeline over normalized events, with incremental ingest cursoring, reindex support, and source-level filtering (Claude/Copilot/both). Current local retrieval helper: `.scratchpad/search-unified-chat-index.py`.
Track 4 (query + policy): expose semantic recall over indexed chat memory with strict LAN-only serving, operator authz, export controls, and explicit policy gates separating searchable memory from training-candidate exports.
