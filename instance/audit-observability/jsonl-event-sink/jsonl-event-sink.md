---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: jsonl-event-sink -> Audit & Observability (Component 11)

> Living Spec for this repo's first Component 11 adapter.
> Slot contract: [../../../01-architecture/02-components/audit-observability.md](../../../01-architecture/02-components/audit-observability.md)

## Purpose

Provide a minimal, durable, append-only event sink for factory activity so all
components can emit structured telemetry to one central plane.

## Observable behavior

- Accepts required event types from the Component 11 contract:
  - `adapter.invoked`
  - `policy.decision`
  - `artifact.produced`
  - `secret.accessed`
  - `error`
- Appends one JSON record per event to a local sink file.
- Supports recent-event queries with filtering by type and limit.

## Inputs / outputs

- Input surface: shell script invocation via
  `scripts/emit-event.sh <event_type> '<payload_json>'`.
- Query surface: `scripts/query-recent.sh [--event-type <type>] [--limit <n>]`.
- Output format: newline-delimited JSON (JSONL).

## Dependencies

- Shell (`bash`) and Python 3 (stdlib only).
- Writable local filesystem path for the sink file.

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `jsonl-event-sink` |
| `component` | `audit-observability` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `local` |
| `cost_hint` | `free` |
| `capabilities` | `structured-logs`, `append-only-audit`, `recent-event-query` |
| `invocation_surface` | `CLI scripts` |

### Audit & Observability required fields

| Field | Value |
|---|---|
| `log_backend` | `local-jsonl-file` |
| `metrics_backend` | `none` (v0) |
| `trace_backend` | `none` (v0) |
| `retention_default` | `operator-managed` (no automatic expiry in v0) |
| `tamper_detection` | `append-only file semantics + VCS/process controls` |

### Repo-specific fields

| Field | Value |
|---|---|
| `sink_path_default` | `instance/.audit/events.jsonl` |
| `sink_env_override` | `EPOS_AUDIT_SINK` |
| `schema_note` | records include `ts`, `event_type`, and a JSON-object `payload` |

## Non-functional bounds (metadata table)

| Bound | Value |
|---|---|
| Durability target | best-effort local durability via append + flush |
| Throughput target | suitable for repo-instance event volume |
| Availability target | local-only, no network dependency |
| Failure mode | invalid event types or payload schema are rejected |

## Versioning policy

- `0.x`: schema and script interface may evolve while this adapter is
  experimental.
- `1.0`: requires explicit field-level schema stability commitment and migration
  notes for any breaking changes.
