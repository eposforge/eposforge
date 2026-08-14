---
doc_kind: standard
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Chat Event Schema

## Status

- draft: 2026-08-14
- supersedes: none
- declined-options:
  - "one schema shared with [Audit & Observability] factory events" —
    declined; factory events record *that* things happened, this
    schema records *what was said*. Collapsing them repeats the
    slot-conflation this standard exists to end.
  - "redact at capture so the raw store is already export-safe" —
    declined; capture-time redaction destroys the only copy of the
    input half. Redaction is an export concern. Capture-time
    controls are limited to secret-header scrubbing and a cwd
    denylist.
  - "drop transcript-layer records because they cannot train" —
    declined; `training_eligible` is a tag, not a filter. Search
    and recall still need the transcripts.
- spec-version: 1.0

## Scope

This standard is the wire format required by the [Interaction Capture]
contract. It defines the normalized event record that every Adapter
for that slot MUST emit, the `dedupe_key` construction that makes
ingest idempotent, the `training_eligible` tagging rules, and the
backward-compatible migration rules for `schema_version`.

It does **not** define the semantic index, the query surface, or the
training-export policy gate. Those are readers of a store that
conforms to this schema.

Machine-readable companion:
[chat-event.schema.json](chat-event.schema.json) (JSON Schema
2020-12). The markdown is authoritative for rules the JSON Schema
cannot express (dedupe-key construction, eligibility tagging,
migration).

## Normative requirements

### 1. Record envelope

Every record MUST be one JSON object on one line (JSONL), and MUST
include:

| Field | Type | Rule |
| --- | --- | --- |
| `schema_version` | string | This document's spec-version (`"1.0"` today). |
| `record_kind` | enum | `event` \| `session.envelope` \| `session.end`. |
| `captured_at` | string | RFC 3339 timestamp, UTC preferred. |
| `dedupe_key` | string | See §3. Unique across re-ingest. |
| `training_eligible` | boolean | See §4. A tag, not a filter. |
| `provenance` | object | See §2. |
| `identity` | object | See §2. |

`record_kind: event` records MUST also include `event`. Wire-layer
event records SHOULD include `request` / `response` / `usage` as
available. Transcript-layer event records MUST include `event` and
MUST NOT invent `request.system` / `request.tools` they did not
observe.

Unknown fields MUST be ignored by readers (forward compatible).
Writers MUST NOT omit a required field.

### 2. Provenance and identity

`provenance`:

| Field | Type | Rule |
| --- | --- | --- |
| `provider` | string | Vendor tag (`anthropic`, `xai`, `github-copilot`, `google-antigravity`, `google-gemini`, `openai`, `azure-openai`, `other`, `unknown`). |
| `cli` | string | Dev Product surface (`claude`, `grok`, `copilot`, `agy`, `other`, `unknown`). |
| `capture_layer` | enum | `wire` \| `transcript`. |
| `source_file` | string | Locator in the source store. Empty string when the record has no file (typical wire). MUST NOT be required to be a host-absolute path in public examples. |
| `source_line` | integer | 1-based line in `source_file`, or `0` when not applicable. |

`identity`:

| Field | Type | Rule |
| --- | --- | --- |
| `account_key` | string | Surrogate for the provider account. Not the raw account id if that is a secret. Empty string if unknown. |
| `machine_key` | string | Surrogate for the capturing host. Empty string if unknown. |
| `workspace_id` | string | Workspace or working-directory surrogate. Empty string if unknown. |
| `session_id` | string | Session correlation id. Empty string if unknown. A wire Adapter SHOULD populate this on every record of one invocation with the same value. |

A `session.envelope` record carries the same identity object plus
`cli`, `cwd`, process id, and start time so a later normalizer can
join wire records that lack `session_id` by `(provider, time window)`.

### 3. `dedupe_key`

The key MUST be a lowercase hex SHA-256 of a canonical UTF-8 string.
Adapters MUST use these constructions so two implementations of the
same source produce the same key:

- **Transcript event:**
  `transcript|<cli>|<source_file>|<source_line>|<captured_at>|<role>|<event_type>|<sha256(text)>`
- **Wire event:**
  `wire|<session_id>|<captured_at>|<request_url>|<sha256(canonical request body)>`
  — if `session_id` is empty, substitute the empty string; do not
  invent one inside the key.
- **Legacy-index backfill** (pre-schema rows):
  `legacy-index|<provider>|<session_id>|<captured_at>|<source_line>|<role>|<sha256(text)>`
- **Session envelope / end:**
  `session|<record_kind>|<session_id>|<captured_at>`

`canonical request body` means JSON serialized with sorted keys and
no insignificant whitespace when the body is JSON; otherwise the
raw UTF-8 bytes (or a stable `_binary_bytes:N` marker).

Re-ingest of a record whose `dedupe_key` is already in the store
MUST be a no-op.

### 4. `training_eligible`

Fail closed:

1. `capture_layer == "transcript"` ⇒ `false`.
2. Provider terms unresolved ⇒ `false`.
3. Wire record missing any of `request.system`, `request.tools`,
   `request.messages`, or a usable `response` ⇒ `false`.
4. Otherwise the Adapter MAY set `true`.

An optional `training_eligible_reason` string SHOULD name which
rule applied when the value is `false`.

Nothing is dropped because the tag is false. Track 4 (export) reads
the tag later.

### 5. Content fields (`event`)

| Field | Type | Rule |
| --- | --- | --- |
| `role` | enum | `user` \| `assistant` \| `system` \| `tool` \| `unknown`. |
| `event_type` | string | Native type from the source (`user`, `assistant.message`, `USER_INPUT`, `tool_result`, …). |
| `text` | string | Best-effort extracted text. Empty string if the event has no text. |
| `cwd` | string | Optional. Working directory if the source recorded one. |

Wire-only object `request` (omit on transcript records unless
actually observed):

| Field | Type | Rule |
| --- | --- | --- |
| `system` | any | Assembled system prompt as sent. |
| `tools` | any | Tool schemas as sent. |
| `messages` | any | Conversation as sent. |
| `raw` | any | Verbatim request body. MUST be retained even when the convenience fields are populated. |

Wire-only object `response`:

| Field | Type | Rule |
| --- | --- | --- |
| `status_code` | integer | HTTP status. |
| `message` | any | Reassembled convenience view. |
| `sse_events` | array | Raw streamed events when the response was SSE. |
| `raw` | any | Non-SSE body, or omit. |

Optional `usage` object: token / cost fields as provided by the
vendor (`input_tokens`, `output_tokens`, cache counters, `model`).
Field names pass through; do not rename vendor counters.

### 6. Migration

- `schema_version` is `MAJOR.MINOR`.
- Adding optional fields, new enum values that readers can treat as
  `unknown`, or new `record_kind` values is a MINOR bump.
- Removing or renaming a required field, changing an existing
  field's type, or changing `dedupe_key` construction is a MAJOR
  bump and MUST ship a documented upgrader.
- Readers MUST accept any MINOR version of the same MAJOR (ignore
  unknown fields).
- A store MAY contain mixed MINOR versions of one MAJOR. A store
  MUST NOT mix MAJORs without an upgrader having rewritten the
  older records.

### 7. Public-repo hygiene

Examples and fixtures committed to a public repository MUST NOT
contain host-absolute paths, private network identifiers, account
secrets, or adopter-specific names. Use placeholders.

## Conformance

- Validate event JSON against [chat-event.schema.json](chat-event.schema.json).
- Confirm every record in a day's file has a non-empty `dedupe_key`
  and a boolean `training_eligible`.
- Confirm every `capture_layer: transcript` record has
  `training_eligible: false`.
- Confirm a wire-layer record of a real model turn yields a
  complete `(system + tools + messages) → response` pair **or** is
  tagged `training_eligible: false` with a reason.
- Re-run an Adapter twice against an unchanged source: row count
  unchanged, high-water mark advanced at most once.

## Related

- [Interaction Capture] contract (this schema is that slot's wire format).
- [Audit & Observability] (factory events; different schema).
- [Inference Layer] (produces the calls this schema records).

<!-- component-links (generated by check-component-links.py --write-defs) -->
[Audit & Observability]: ../../01-architecture/02-components/audit-observability.md
[Interaction Capture]: ../../01-architecture/02-components/interaction-capture.md
[Inference Layer]: ../../01-architecture/02-components/inference.md
