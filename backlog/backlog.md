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
