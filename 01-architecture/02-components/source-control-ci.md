---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 9: Source Control + CI

## Purpose

Where artifacts land, where the **paired-change rule is enforced**, and
where deploys originate. Source Control + CI is the durable home for the
factory's output and the **non-bypassable gate** that keeps Product
Living Specs from rotting while code moves.

Without deterministic (fail-closed) enforcement here, Living Specs
become optional prose and code becomes the only accurate description of
product behavior — the failure mode Living Spec exists to prevent.

## Contract

Any Adapter for this slot must:

- Provide source control with branches, pull requests, and signed
  commits.
- Enforce the paired-change rule defined by the Living Spec Adapter
  (component 2) and detailed in
  [Standard 11: Paired-Change Enforcement](../../04-standards/11-paired-change-enforcement/paired-change-enforcement.md).
  In particular:
  - Maintain or consume a **product registry** mapping `product_id` →
    Living Spec paths + code globs.
  - **Fail CI** when product code paths change and the Product's Living
    Spec paths do not, unless a **finite, allowlisted, audited**
    exemption is declared on the change set.
  - Treat free-text “low risk” / “small fix” as **invalid** exemptions.
  - Run **Spec-derived tests** (and recommended Spec lint) as required
    checks on product PRs; pure-refactor exemptions must not pass if
    those tests fail.
  - Make paired-change and product test checks **required** on protected
    branches; agent-authored changes must not dismiss them.
- Run automated tests for each PR; gate merges on test status.
- Run factory-level integration tests as a required PR check where the
  factory chain is in scope. These tests exercise the full component
  chain (Spec Input → Orchestrator → Dev Product → Tool Transport →
  Source Control gate) against real service instances, not mocks of
  factory components. Isolation is provided by Component 7 (Execution
  Sandbox); disposable container environments (e.g., Testcontainers) are
  the reference pattern.
- Derive product acceptance / integration cases from the Living Spec's
  declared observable behavior, inputs/outputs, and non-functional
  bounds using equivalence partitioning and boundary value analysis —
  not from code internals alone. Align with
  [Standard 10: Ungameable Gates](../../04-standards/10-ungameable-gate/ungameable-gate.md)
  when the suite is the definition-of-done gate.
- Consult Agent Policy ([agent-policy.md](./agent-policy.md)) for
  merge tier decisions and which paired-change exemption codes agents
  may use. Tier-1 PRs may auto-merge on green; Tier-2 PRs require human
  approval.
- Trigger Spec Graph re-projection (component 6) on every merge that
  touches a Living Spec path registered for a Product.
- Emit audit events for every PR open, review, merge, deploy,
  **paired-change failure**, and **paired-change exemption** granted.

The Adapter must support **agent attribution**: every commit produced by
an agent identifies which Adapter authored it, under which Spec Input,
under which Agent Policy tier.

### Enforcement stack (summary)

| Layer | Role | Determinism |
| --- | --- | --- |
| **A — Product registry** | Map files → Product; locate Spec HOME | Fully deterministic |
| **B — Paired-change gate** | Code change ⇒ Spec path change or allowlisted exemption | Fully deterministic |
| **C — Spec-derived tests (+ lint)** | Declared product promises still hold | Deterministic checks; not full Spec↔code proof |
| **D — Spec Graph re-project** | Query surface tracks Spec HEAD after merge | Deterministic trigger |
| **E — Prompts / culture alone** | Assist only | **Not** enforcement |

Normative detail, exemption allowlist rules, light vs heavy authoring
paths, and conformance checklist:
[Standard 11](../../04-standards/11-paired-change-enforcement/paired-change-enforcement.md).

### Light path (normative expectation)

A bugfix or clarification that changes product behavior:

1. Edit the **same** Product Living Spec (HEAD) — small delta is enough.  
2. Change fulfillment code and tests.  
3. Pass Layers A–C.  

No new Spec Kit episode folder is required. Heavy authoring Adapters
remain optional for large work; their output must **fold into** the
Product Living Spec before or as part of the gated change set.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `vcs` — the source control system (git, jj, etc.).
- `host` — the hosting / forge (GitHub, Gitea, GitLab, self-hosted).
- `ci_engine` — which CI engine runs (Actions, GitLab CI, custom).
- `signed_commits_required` — whether agent commits must be signed.
- `product_registry_ref` — path or URI of the product registry
  (`product_id`, `spec_paths`, `code_globs`, exemption policy).
- `paired_change_check_id` — identifier of the CI check enforcing the
  paired-change rule (Layer B). Required status check.
- `spec_tests_check_id` — identifier of the CI check running
  Spec-derived product tests (Layer C). Required status check on
  product PRs.
- `integration_test_check_id` — identifier of the CI check running
  factory-level integration tests (when applicable). Must be a required
  status check; cannot be bypassed by auto-merge.
- `ring_promotion_pipeline_refs` — references to the promotion
  pipeline definitions for each ring transition. Each pipeline is a
  required status check on the merge that executes the transition;
  cannot be bypassed. Governed by Release Rings (component 9b) and
  Agent Policy (component 8).

## Boundaries

- **Is:** the durable home of artifacts and the gating layer for
  changes, including Living Spec fidelity.
- **Is not:** the Spec Graph (which is a queryable projection, not a
  source-of-truth store).
- **Is not:** the Living Spec Adapter itself (component 2 defines Spec
  shape and product attachment; this component enforces pairing at
  merge).
- **Is not:** the deploy target. Deploy is downstream and is governed
  by the Release Rings component
  ([release-rings.md](./release-rings.md)). Ring promotion
  pipelines are defined in source control and triggered from CI, but
  the ring governance contract — evidence thresholds, ring-lock rules,
  promotion authority — belongs to that component, not here.
- **Is not:** sufficient if only agent prompts say “update the Spec.”
  Prompts are Layer E; merge gates are A–D.

See also:

- [Standard 11: Paired-Change Enforcement](../../04-standards/11-paired-change-enforcement/paired-change-enforcement.md)
- [Standard 09: Paired Detection](../../04-standards/09-paired-detection/paired-detection.md)
  — ship a check with a fix (sibling of paired-change).
- [Standard 10: Ungameable Gates](../../04-standards/10-ungameable-gate/ungameable-gate.md)
  — how acceptance suites stay ungameable.

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog (GitHub +
Actions, Gitea + Gitea Actions, GitLab, custom self-hosted, etc.).
A conforming instance ships the product registry + `paired-change` +
`spec-tests` jobs described in Standard 11.
