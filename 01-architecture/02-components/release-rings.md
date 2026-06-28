---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 9b: Release Rings

## Purpose

A deployment governance model that governs **where artifacts run** and
**how much autonomous authority the factory has** to put them there.
Release Rings complement Component 9 (Source Control + CI), which gates
what lands in the repository. Release Rings govern what leaves the
repository and runs in a target environment.

Rings provide the deployment-side analog of the factory's maturity
phases. As an artifact earns operational confidence — measured by
evidence thresholds — it graduates through rings, and the authority
model governing it tightens. By General Availability, the artifact is
fully shielded from direct agent deployment; only the automated
promotion pipeline may touch it.

A factory without explicit ring governance has no principled boundary
between "agents freely deploy" and "humans must intervene." That
boundary is the entire purpose of this component.

---

## Ring Model

The four standard rings, in graduation order:

### Alpha

- **Who deploys:** agents, autonomously (Agent Policy tier-1).
- **Who uses:** factory-internal consumers; invited early adopters
  operating under explicit risk acknowledgment.
- **Stability expectation:** none. Breaking changes, rollbacks, and
  environment resets are routine.
- **Protection:** minimal. Agents may open, merge, and deploy PRs
  targeting alpha infrastructure without human approval.
- **Purpose:** fastest possible feedback loop. The factory proves the
  artifact works at all before expanding its reach.

### Beta

- **Who deploys:** agents, with human review at the promotion gate
  (Agent Policy tier-2 for deploy actions).
- **Who uses:** known external early adopters operating under a beta
  agreement.
- **Stability expectation:** breaking changes are announced in advance;
  rollback is possible within one release cycle.
- **Protection:** medium. Agent commits to beta infrastructure require
  a human-approved PR; auto-merge is disabled for deploy-class changes.
- **Purpose:** validate correctness and usability against real external
  load before wider exposure.

### Preview

- **Who deploys:** the automated promotion pipeline only, triggered
  after beta evidence thresholds are met. Agents cannot deploy directly
  (Agent Policy tier-0 for direct deploy actions; tier-2 for pipeline
  invocation).
- **Who uses:** the full user population under documented limitations;
  "use in production at your own risk."
- **Stability expectation:** backward-compatible changes only; breaking
  changes require a major version bump and a parallel migration path.
- **Protection:** high. Direct agent access to preview infrastructure is
  forbidden. The promotion pipeline is the only authorized deploy path.
- **Purpose:** final hardening before GA. Incident rate and MTTR in
  preview gate the GA promotion decision.

### General Availability (GA)

- **Who deploys:** the automated promotion pipeline only, after all GA
  evidence thresholds are satisfied and a human operator authorizes
  the promotion run. Agents are forbidden from any direct interaction
  with GA infrastructure (Agent Policy tier-0).
- **Who uses:** all users, under full support commitments.
- **Stability expectation:** semantic versioning strictly enforced;
  deprecations follow the published deprecation policy.
- **Protection:** maximum. Ring-lock is enforced at the Agent Policy
  layer; the promotion pipeline is signed and its integrity is verified
  before every run. No override path exists for agents.
- **Purpose:** the artifact is in the hands of the full user base.
  Every change carries the full cost of a support commitment.

---

## Contract

Any Adapter for this slot must:

- Define the four standard rings (alpha, beta, preview, GA) or a
  documented superset. Fewer rings than four are not permitted; the
  graduation sequence may not be shortened.
- Declare **evidence thresholds** for each ring transition:
  - Minimum time-in-ring.
  - Maximum error rate over a trailing window.
  - Minimum usage volume (requests or unique users) demonstrating real
    exercise, not just health checks.
  - Required CI checks that must remain green for the trailing window.
- Expose a **promotion pipeline**: a fully automated, agent-executable
  workflow that evaluates evidence thresholds, collects or requests
  required approvals, and executes the ring promotion as a versioned,
  audited transaction.
- Enforce **ring-lock** through Agent Policy (component 8). Ring-lock
  rules must be:
  - Expressed declaratively in source control.
  - Scoped by ring and by action class (deploy, config change, secret
    rotation, etc.).
  - Fail-closed: if the ring-lock decision point is unreachable, the
    action is denied.
- Record every promotion as an immutable audit event (component 11)
  including: ring transition, evidence snapshot at decision time,
  approver identity (human or pipeline), timestamp, and artifact
  version.
- Support **rollback promotion**: demoting an artifact from a higher
  ring to a lower ring must be possible, must be audited, and must be
  at least as protected as forward promotion at that ring level.
- Integrate with Audit & Observability (component 11) to emit
  ring-scoped telemetry. The promotion decision must be reproducible
  from the audit log alone.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `rings` — ordered list of ring names the Adapter implements.
- `evidence_schema` — format of the evidence threshold declarations
  (YAML, JSON, OPA Rego, etc.).
- `promotion_pipeline_id` — reference to the pipeline definition in
  Source Control + CI (component 9).
- `ring_lock_policy_ref` — reference to the Agent Policy rule set
  (component 8) that enforces ring-scoped access restrictions.
- `rollback_supported` — whether demotion promotion is supported, and
  to which rings.

---

## Relationship to Other Components

| Component | Relationship |
|---|---|
| **08 Agent Policy** | The primary enforcement point for ring-lock. Agent Policy declares which agent actions are permitted per ring; Release Rings declares *what the rings are* and *what the evidence thresholds are*. Policy consults ring membership as a required input dimension. |
| **09 Source Control + CI** | The promotion pipeline is defined here and triggered from CI. Ring promotion evidence thresholds map directly to required CI status checks. Tier-1 auto-merge (Phase F) applies only to alpha ring; higher rings enforce promotion-pipeline-only transitions. |
| **11 Audit & Observability** | Every ring promotion — forward or rollback — is an immutable audit event. The promotion decision must be reproducible from the audit log alone. |
| **07 Execution Sandbox** | Artifact execution in alpha and beta rings runs in sandboxed environments. The sandbox provides the isolation boundary that makes alpha autonomous deployment safe. |
| **02 Living Spec** | The Living Spec for each artifact must declare its current ring and its target ring at each version. Paired-change enforcement (component 9) ensures ring membership is never out of sync with the deployed artifact. |

---

## Boundaries

- **Is:** the governance model for where artifacts run and who may put
  them there.
- **Is not:** the deployment engine itself. Deployment tooling is an
  Adapter implementation detail.
- **Is not:** a branching strategy. Ring membership tracks running
  artifacts, not source branches — though the two may be correlated by
  convention.
- **Is not:** a feature flag system. Release Rings govern full artifact
  versions, not feature subsets within a version. Feature flags within a
  GA artifact are an application-level concern.

---

## Maturity Alignment

Release Rings become relevant at different factory maturity levels:

| Factory Phase | Ring applicability |
|---|---|
| Platform Phase 2 / Product Phase D | Alpha ring only. Agents deploy freely to alpha. No formal ring model required yet. |
| Platform Phase 3 / Product Phase E | Alpha + Beta. Beta promotion gate formalized. Agent Policy ring-lock active for beta and above. |
| Platform Phase 4 / Product Phase F | All four rings. Fully automated promotion pipeline operational. GA ring-lock fully enforced. |

An instance that has not reached Platform Phase 3 / Product Phase E
should document alpha as its only ring and revisit this component when
it promotes to Phase 3.

---

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog
(environment-per-ring with Kubernetes namespaces, Argo Rollouts canary,
GitHub Environments with required reviewers, custom YAML ring manifests,
etc.).

