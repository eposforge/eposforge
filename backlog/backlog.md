# Backlog

Active issues (`open`, `in-progress`, `blocked`) for this repo.

## Issue EF-010 — Self-consume cognee-mcp in this repo; runbook doubles as adopter onboarding
ID: EF-010
Title: Self-consume cognee-mcp in this repo; runbook doubles as adopter onboarding
Date: 2026-05-18
Status: open
Effort: S
Fix surface: repo-instance
Depends on: EF-001
Verify with: in this repo, `claude mcp list` shows cognee connected AND `recall` against the eposforge dataset returns expected entities from an MCP-capable dev product (claude-code at minimum). The same runbook, with a "for adopters: substitute your corpus and TTL overlay" section, satisfies what EF-005 originally tried to spec.
Notes: Supersedes EF-005. EposForge dogfoods its own pattern, so the repo is the first adopter and self-consumption is the primary deliverable, with explicit adopter guidance as a derivative section. Runbook should cover: cognee-mcp install/config (stdio for local dev-products; SSE/HTTP variants noted), the `COGNEE_MCP_AGENT_SCOPED=false` + `ENABLE_BACKEND_ACCESS_CONTROL=false` decision for shared-backend single-graph mode vs per-dataset isolation, overlay TTL upload via cognee-sync (Phase 4 ontology behavior already documented in `instance/installed/06-spec-graph/cognee/cognee.md`), and minimal MCP-client config snippets for supported dev-products (claude-code, cursor, copilot). Call out the `.owl` extension requirement (EF-004 still slated covers automating that on the sync CLI side). For adopter framing, include a section that substitutes their corpus and TTL overlay, including upstream cognee-mcp usage patterns.

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

## Issue EF-014 — Formalize Agent Policy (Component 8) — tier-0/1/2 contract with per-adopter generator
ID: EF-014
Title: Formalize Agent Policy (Component 8) — tier-0/1/2 contract with per-adopter generator
Date: 2026-05-23
Status: open
Effort: M
Fix surface: eposforge-pattern
Depends on: EF-010
Verify with: `instance/installed/08-agent-policy/<adapter>/` exists with a Living Spec naming the chosen scheme (e.g. `tier-yaml`); a YAML contract declares tier-0 (auto), tier-1 (supervised), tier-2 (manual) with predicates over Bash command shapes and MCP tool names; a generator script emits a `.claude/settings.json` permissions allowlist from the YAML contract for tier-0 entries; running the generator against this repo produces a settings file equivalent to a hand-verified baseline; recall of "agent policy" returns the new adapter metadata, not only the AGENTS.md prose.
Notes: The Agent Policy slot (Component 8) is currently filled by ad-hoc prose in AGENTS.md, so every adopter project re-derives the same allowlist judgments in `.claude/settings.json` and operators field per-command permission prompts as one-off decisions during chat sessions — the structural source of the permission-prompt focus drain. A formal tier model — tier-0 (read-only, idempotent reflective tools; safe to auto-approve), tier-1 (writes to working tree or sandbox; auto-approve in alpha ring, supervised elsewhere), tier-2 (destructive, prod-facing, or human-judgment-required) — collapses those repeated decisions into one parseable contract. The adapter governs a generator that emits per-adopter `.claude/settings.json`, Gitea/GitHub Actions gates, and optional pre-commit hook fragments via the existing hook composer at `instance/installed/09-source-control-ci/github-and-actions/scripts/install-hooks.sh`. Out-of-scope for v0: cross-adopter policy inheritance, dynamic per-PR risk scoring, telemetry-driven policy adaptation. Unblocks Platform Factory Phase 2 (Agent Proposals → Supervised Autonomy) and removes the per-repo allowlist drift that currently emerges from running `/fewer-permission-prompts` independently in each adopter.
