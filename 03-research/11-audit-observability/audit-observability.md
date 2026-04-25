# Audit & Observability — Implementation Catalog

> **Snapshot date:** 2026-04. Verify current details before adopting.

Candidate Adapters for the Audit & Observability slot
([../01-architecture/02-components/11-audit-observability.md](../01-architecture/02-components/11-audit-observability.md)).
An Audit & Observability Adapter accepts structured events from
every other component and exposes log, metric, and trace surfaces.
A factory without this slot installed is uncontrolled.

This catalog is **not exhaustive** and **not an endorsement**.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — log store, metrics store, trace store, shipper, app
  logging library, full stack.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Backend role** — which of `log_backend`, `metrics_backend`, or
  `trace_backend` the entry fills.
- **Capabilities** — query surfaces, retention, tamper-detection
  posture.
- **Notes** — anything notable for Adapter authors.

---

## Log backends

### Loki

- **Type:** log store.
- **Cost tier:** free OSS; Grafana Cloud commercial tier.
- **Backend role:** `log_backend`.
- **Capabilities:** label-indexed log storage, LogQL, cheap retention
  versus full-text indexes; pairs natively with Grafana.
- **Notes:** common choice for instances that already run Prometheus
  and Grafana. Adapter ships structured JSON events with stable
  labels.

### Vector

- **Type:** log / metric / event shipper and processor.
- **Cost tier:** free OSS.
- **Backend role:** shipper (no role in the contract directly);
  feeds Loki, Elasticsearch, or another sink.
- **Capabilities:** filter, transform, enrich, route at the edge;
  reduces backend ingest cost and decouples app shape from storage
  shape.
- **Notes:** strong fit between application logging libraries and
  the chosen `log_backend`. Place Vector on each host shipping
  events.

---

## Metric backends

### Prometheus

- **Type:** metrics store and scrape engine.
- **Cost tier:** free OSS.
- **Backend role:** `metrics_backend`.
- **Capabilities:** pull-based scraping, PromQL, alert rules; broad
  exporter ecosystem.
- **Notes:** default metric backend for self-hosted instances.
  Adapter declares scrape targets per component; the Adapter's
  retention policy maps to Prometheus retention configuration.

### Grafana

- **Type:** dashboards + alerting front-end.
- **Cost tier:** free OSS; commercial Cloud / Enterprise tiers.
- **Backend role:** query / dashboard surface (not a backend in the
  contract).
- **Capabilities:** unified pane over Prometheus, Loki, Tempo, and
  many other backends; alert routing.
- **Notes:** typically paired with Prometheus / Loki / Tempo.
  Dashboards become the human query surface required by the slot.

---

## Trace backends

### Tempo

- **Type:** trace store.
- **Cost tier:** free OSS; Grafana Cloud commercial tier.
- **Backend role:** `trace_backend`.
- **Capabilities:** scalable trace storage, OpenTelemetry-native,
  Grafana integration.
- **Notes:** appropriate when the factory needs causal chains
  across component boundaries — particularly Router → Dev Product
  → Tool Transport → Sandbox traces.

### Jaeger

- **Type:** trace store + UI.
- **Cost tier:** free OSS.
- **Backend role:** `trace_backend`.
- **Capabilities:** OpenTelemetry-native, mature Span query UI.
- **Notes:** an alternative to Tempo for instances that prefer
  Jaeger's UI or already operate it.

---

## Application logging

### Serilog

- **Type:** structured logging library for .NET.
- **Cost tier:** free OSS.
- **Backend role:** application emitter (feeds the chosen
  `log_backend` via a sink — Loki, Elasticsearch, etc.).
- **Capabilities:** structured event logging, sinks for most stores,
  enrichment pipeline, low overhead.
- **Notes:** strong fit when factory components or deliverables are
  written in C# / .NET. Ship via Vector to Loki for the canonical
  Adapter wiring.

---

## Full-stack patterns

A common self-hosted stack:

- **App emitter:** Serilog (or language-equivalent structured logger).
- **Shipper:** Vector on each host.
- **Logs:** Loki.
- **Metrics:** Prometheus.
- **Traces:** Tempo.
- **Front-end:** Grafana.

The Adapter encapsulates this stack as one slot fill — components
emit events through the Adapter, which routes them to the right
backend and exposes the contract's required query surfaces.

Other valid full-stack patterns: ELK / OpenSearch + OpenTelemetry,
proprietary observability suites, hosted offerings (Datadog, New
Relic). Choose by privacy posture and cost; all must satisfy the
slot's contract for tamper detection and retention.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
with explicit tamper-detection posture (hash chains, signed
segments, append-only WORM) and declared retention defaults.
