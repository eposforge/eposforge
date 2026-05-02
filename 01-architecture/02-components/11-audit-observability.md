---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Component 11: Audit & Observability

## Purpose

The factory's immutable record of what happened. Every agent action,
every Adapter invocation, every policy decision, every artifact
produced — all of it is logged here. Audit & Observability is what
makes the factory trustworthy: humans who set policy can verify that
the factory operates within it, and agents can learn from past
outcomes.

A factory without Audit & Observability is uncontrolled. Even minimal
instances must install at least a basic Adapter.

## Contract

Any Adapter for this slot must:

- Accept structured events from every other component. The required
  event types:
  - `adapter.invoked` (component, adapter name, inputs hash, caller).
  - `policy.decision` (rule, subject, outcome).
  - `artifact.produced` (deliverable, change ref, author adapter).
  - `secret.accessed` (logical name, consumer; values must not be
    logged).
  - `error` (component, adapter, classification, diagnostic).
- Persist events durably with append-only semantics. Tampering must be
  detectable.
- Provide query and metric surfaces:
  - **Logs** — structured, time-indexed, filterable.
  - **Metrics** — quantitative aggregates (rate, latency, cost).
  - **Traces** — causal chains across component boundaries.
- Support retention policies declared by Agent Policy.
- Be queryable by both humans (dashboards) and agents (RAG over the
  audit log to learn from prior outcomes).

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern.md](../00-adapter-pattern.md):

- `log_backend` — log store (Loki, Elasticsearch, OpenSearch, custom).
- `metrics_backend` — metrics store (Prometheus, etc.).
- `trace_backend` — trace store (Tempo, Jaeger, etc.) or `none`.
- `retention_default` — default retention window.
- `tamper_detection` — how tamper detection works (hash chains, signed
  segments, append-only WORM, etc.).

## Boundaries

- **Is:** the immutable record of factory activity.
- **Is not:** the policy decision point (that is Agent Policy); Audit
  & Observability records what the policy decided, not the rules.
- **Is not:** application observability. A deliverable's own metrics
  and logs are separate; this slot covers the factory itself.

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog (Loki +
Prometheus + Tempo, ELK, OpenTelemetry stacks, custom append-only
stores, etc.).

