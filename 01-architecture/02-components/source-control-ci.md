---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 9: Source Control + CI

## Purpose

Where artifacts land, where the paired-change rule is enforced, and
where deploys originate. Source Control + CI is the durable home for the
factory's output. Every Living Spec, every Adapter configuration, every
deliverable lives here.

## Contract

Any Adapter for this slot must:

- Provide source control with branches, pull requests, and signed
  commits.
- Enforce the paired-change rule defined by the Living Spec Adapter
  (component 2). A change that touches behavior without updating the
  Living Spec must fail CI.
- Run automated tests for each PR; gate merges on test status.
- Run factory-level integration tests as a required PR check. These
  tests exercise the full component chain (Spec Input → Orchestrator → Dev
  Product → Tool Transport → Source Control gate) against real service
  instances, not mocks of factory components. Isolation is provided by
  Component 7 (Execution Sandbox); disposable container environments
  (e.g., Testcontainers) are the reference pattern.
- Derive integration test cases from the Living Spec's declared
  observable behavior, inputs/outputs, and non-functional bounds using
  equivalence partitioning and boundary value analysis — not from code
  internals.
- Consult Agent Policy ([agent-policy.md](./agent-policy.md)) for
  merge tier decisions. Tier-1 PRs may auto-merge on green; Tier-2 PRs
  require human approval.
- Trigger Spec Graph re-projection (component 6) on every merge that
  touches a Living Spec.
- Emit audit events for every PR open, review, merge, and deploy.

The Adapter must support **agent attribution**: every commit produced by
an agent identifies which Adapter authored it, under which Spec Input,
under which Agent Policy tier.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `vcs` — the source control system (git, jj, etc.).
- `host` — the hosting / forge (GitHub, Gitea, GitLab, self-hosted).
- `ci_engine` — which CI engine runs (Actions, GitLab CI, custom).
- `signed_commits_required` — whether agent commits must be signed.
- `paired_change_check_id` — identifier of the CI check enforcing the
  paired-change rule.
- `integration_test_check_id` — identifier of the CI check running
  factory-level integration tests. Must be a required status check;
  cannot be bypassed by auto-merge.
- `ring_promotion_pipeline_refs` — references to the promotion
  pipeline definitions for each ring transition. Each pipeline is a
  required status check on the merge that executes the transition;
  cannot be bypassed. Governed by Release Rings (component 9b) and
  Agent Policy (component 8).

## Boundaries

- **Is:** the durable home of artifacts and the gating layer for
  changes.
- **Is not:** the Spec Graph (which is a queryable projection, not a
  source-of-truth store).
- **Is not:** the deploy target. Deploy is downstream and is governed
  by the Release Rings component
  ([release-rings.md](./release-rings.md)). Ring promotion
  pipelines are defined in source control and triggered from CI, but
  the ring governance contract — evidence thresholds, ring-lock rules,
  promotion authority — belongs to that component, not here.

See also [Standard 10: Ungameable Gates](../../04-standards/10-ungameable-gate/ungameable-gate.md) for how integration tests must be structured as the ungameable gate for tasks.

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog (GitHub +
Actions, Gitea + Gitea Actions, GitLab, custom self-hosted, etc.).

