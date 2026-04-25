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

## Integration Test Harness — Container Tooling

The factory-level integration check requires real, disposable service
instances — no mocks of factory components. The following products are
the primary candidates for implementing this isolation.

### Testcontainers (multi-language)

- **Website:** https://testcontainers.com
- **Language SDKs:** Java, .NET, Go, Python, Node.js, Rust (and more).
- **Cost tier:** free OSS (Apache 2.0); Testcontainers Cloud is a
  paid SaaS option for CI runners without local Docker.
- **Hosting model:** local Docker daemon or Testcontainers Cloud.
- **Capabilities:** programmatic container lifecycle (start, wait,
  stop), dynamic port assignment, per-test isolation, automatic
  cleanup via reaper, pre-built modules for common services (Postgres,
  Redis, Kafka, LocalStack, Kubernetes via kind, etc.).
- **Notes:** reference pattern for the integration harness. Each
  integration test run spins up the required factory components
  (Source Control, Tool Transport endpoint, etc.) as fresh containers,
  runs assertions against the full chain, and discards them. Reusable
  mode accelerates local dev by keeping containers alive between runs.
  Testcontainers Cloud removes the need for local Docker in restricted
  CI environments.

### Testcontainers Cloud (AtomicJar / Docker)

- **Website:** https://testcontainers.com/cloud
- **Cost tier:** commercial SaaS.
- **Hosting model:** cloud-hosted container execution.
- **Capabilities:** same Testcontainers API, containers run remotely;
  no Docker required on the CI runner.
- **Notes:** useful when the CI environment (e.g., a rootless runner)
  cannot run Docker. Drop-in replacement — no code changes needed.

### LocalStack

- **Website:** https://localstack.cloud
- **Cost tier:** free community edition; Pro tier for advanced
  services.
- **Hosting model:** self-hosted container or SaaS.
- **Capabilities:** emulates AWS services (S3, SQS, Secrets Manager,
  etc.) locally.
- **Notes:** relevant when the factory's Secrets & Key Management or
  Audit & Observability Adapter targets AWS. Use via the Testcontainers
  LocalStack module for lifecycle management.

### kind (Kubernetes in Docker)

- **Website:** https://kind.sigs.k8s.io
- **Cost tier:** free OSS (Apache 2.0).
- **Hosting model:** local Docker.
- **Capabilities:** full Kubernetes cluster inside Docker containers;
  Testcontainers has a first-class kind module.
- **Notes:** relevant for factories deployed on Kubernetes substrate.
  Allows integration tests to exercise real scheduler and networking
  behavior.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
with explicit support for signed commits, paired-change checks, and
tier-gated auto-merge. For integration harness entries, document the
isolation strategy and which factory components the harness exercises.
