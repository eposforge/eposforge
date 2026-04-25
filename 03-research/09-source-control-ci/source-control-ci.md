# Source Control + CI — Implementation Catalog

> **Snapshot date:** 2026-04. Verify current details before adopting.

Candidate Adapters for the Source Control + CI slot
([../01-architecture/02-components/09-source-control-ci.md](../01-architecture/02-components/09-source-control-ci.md)).
A Source Control + CI Adapter provides the durable home for factory
artifacts, enforces the paired-change rule, runs tests, applies
merge-tier rules from Agent Policy, and triggers Spec Graph
re-projection on merge.

This catalog is **not exhaustive** and **not an endorsement**.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — VCS host, CI engine, or pairing of both.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Hosting model** — self-hosted, SaaS, hybrid.
- **Capabilities** — protected branches, signed commits, paired-
  change checks, agent attribution, tier-gated auto-merge.
- **Notes** — anything notable for Adapter authors.

---

## Candidates

### Gitea + Gitea Actions

- **Type:** self-hosted Git forge with built-in CI.
- **Cost tier:** free OSS.
- **Hosting model:** self-hosted; runs as a container.
- **Capabilities:** PRs, protected branches, signed commit
  enforcement, webhooks, GitHub-Actions-compatible workflow syntax.
- **Notes:** common starting choice for instances that need on-prem
  source control. Adapter wires the paired-change check as a Gitea
  Actions workflow that fails when behavior changes without a
  Living Spec update; consume webhooks for Spec Graph
  re-projection on merge.

### GitHub + GitHub Actions

- **Type:** SaaS Git host with integrated CI.
- **Cost tier:** consumer-paid (free tier available); commercial /
  enterprise tiers.
- **Hosting model:** SaaS (GitHub Enterprise Server is a self-host
  option).
- **Capabilities:** PRs, protected branches, signed commit
  enforcement, fine-grained Actions permissions, code review tooling.
- **Notes:** appropriate for public deliverables or instances that
  prefer SaaS. Pairs naturally with Gitea-hosted private repos in
  hybrid factories. Adapter must ensure agent attribution survives
  GitHub's commit metadata model.

### GitLab + GitLab CI

- **Type:** Git forge with integrated CI / CD.
- **Cost tier:** free OSS Community Edition; commercial tiers.
- **Hosting model:** self-hosted or SaaS.
- **Capabilities:** PRs (merge requests), protected branches, signed
  commits, mature pipeline DSL, role-based access controls.
- **Notes:** strong fit for instances that already standardize on
  GitLab. Adapter maps merge-request-approval rules to Agent Policy
  tiers.

### Hybrid Gitea (private) + GitHub (public)

- **Type:** policy-driven split.
- **Cost tier:** free OSS + GitHub plan costs.
- **Hosting model:** self-hosted private + SaaS public.
- **Capabilities:** keeps private deliverables on-prem while
  publishing OSS components externally.
- **Notes:** common pattern for factories with a public open-source
  posture. Adapter must carry per-repo policy: which forge a repo
  lives on, what merge tiers apply, who reviews.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
with explicit support for signed commits, paired-change checks, and
tier-gated auto-merge.
