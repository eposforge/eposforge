---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Interaction Capture

## Purpose

The durable corpus of what agents were actually asked and what they
actually returned, across heterogeneous [Dev Product] adapters.

This slot holds **what was said** — prompts, tool events, assembled
requests, and model responses — with corpus semantics (provenance,
correlation identity, training eligibility, additive retention) that
[Audit & Observability], the slated Working Memory slot, and
[Spec Graph] do not have vocabulary for.

A factory that wants search, recall, or a training corpus later must
fill this slot first. Those readers are recoverable from a correct
store; the store is not recoverable from the readers.

## Contract

Any Adapter for this slot must:

- Persist records in three separable layers:
  - **Immutable raw** — append-only capture of what was observed.
    Deletion of raw records is non-conformant; archival and compaction
    that preserve every record are allowed.
  - **Derived index** — optional, rebuildable projection of the raw
    store (out of this contract's required surface; a later reader).
  - **Gated export** — any training or off-host extract runs through a
    declared export gate. Redaction happens **at export**, not at
    capture, except for the two capture-time controls below.
- Emit the [Chat Event Schema](../../04-standards/13-chat-event-schema/chat-event-schema.md)
  (`schema_version` required). A second ad-hoc record shape is
  non-conformant.
- Ingest **idempotently**. Re-running a collector, or ingesting the
  same source from a second machine under one account, MUST NOT
  duplicate rows. The `dedupe_key` field is the idempotency token.
- Carry **provenance** (`provider`, `cli`, `capture_layer`, source
  locator) and **correlation identity** (`account_key`, `machine_key`,
  `workspace_id`, `session_id`) on every record.
- Tag every record with `training_eligible` (a tag, not a filter).
  Transcript-layer records MUST be `false` (no reconstructable input
  half: CLI transcripts drop the assembled system prompt and tool
  schemas). Wire-layer records MAY be `true` only when the record
  contains a complete `(system + tools + messages) → response` pair
  **and** the provider's terms are resolved. Unresolved terms ⇒
  `false`. Nothing is dropped because the tag is false.
- Declare the **redaction modes** it supports at export time
  (`raw`, `secrets`, `pii`, `training`). Capture-time controls are
  limited to:
  1. Secret-header scrubbing on the wire (`authorization`, API-key
     headers, cookies) before a record is written.
  2. A capture-time **repo denylist**: sessions whose working
     directory resolves under a declared high-sensitivity tree MUST
     not be captured at all (fail-safe: no interceptor, no record).
     A denylist is a coarse cwd gate, not a content filter; a
     session started elsewhere can still read a denylisted file
     into a captured request. Export-time redaction remains the
     real control.
- Treat retention as **additive**. Rotation that deletes raw records
  is a contract violation. Compaction into an archive that remains
  readable is the allowed ageing path.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `capture_layer` — `wire` | `transcript` | `both`.
- `providers_covered` — provider tags the Adapter can attribute
  (e.g. `anthropic`, `xai`, `github-copilot`, `google-*`).
- `identity_fields_supported` — which of
  `{account_key, machine_key, workspace_id, session_id}` the Adapter
  actually populates (vs. leaving empty).
- `redaction_mode` — the capture-time default (`secrets` for wire
  header scrubbing is the expected floor).
- `retention_policy` — MUST be additive (no deletion). State the
  archival/compaction behaviour.
- `export_gate` — how a training or off-host extract is authorized
  (`none` is allowed while Track 4 is unbuilt; declare it).

## Boundaries

- **Is:** the durable corpus of agent interaction content.
- **Is not:** [Audit & Observability]. That slot records **that**
  things happened — logs, metrics, traces, factory events
  (`adapter.invoked`, `policy.decision`, …). It has no vocabulary
  for conversation content, training eligibility, or
  reconstructable `(input → output)` pairs.
- **Is not:** [Inference Layer]. Inference serves model calls; this
  slot records what those calls contained.
- **Is not:** Working Memory (slated slot). Working Memory is active
  cross-session recall *during* execution. This slot is the
  immutable recording side. Working Memory may later read from
  here; it does not own the raw store.
- **Is not:** [Spec Graph]. Spec Graph projects Living Specs
  (intent). This slot stores what was said, not what is specified.
- **Is not:** [Content Safety]. Content Safety *acts* on live
  payloads (block / warn / escalate). This slot records.

## Reference implementations

Two complementary Adapter shapes; a factory typically installs both:

- **Wire proxy** — a TLS-terminating interceptor in front of the
  model-provider HTTPS call. The only shape that sees the assembled
  system prompt, tool schemas, and re-sent conversation. Required
  for any future training corpus.
- **Transcript collector** — readers over each Dev Product's native
  session store. Covers history the wire never saw (sessions run
  unproxied; stores that predate the proxy). Always
  `capture_layer: transcript`, `training_eligible: false`.

See
[../../03-research/01-architecture/02-components/interaction-capture/interaction-capture.md](../../03-research/01-architecture/02-components/interaction-capture/interaction-capture.md)
for the catalog and trade-offs.

<!-- component-links (generated by check-component-links.py --write-defs) -->
[Dev Product]: ./dev-product.md
[Audit & Observability]: ./audit-observability.md
[Spec Graph]: ./spec-graph.md
[Inference Layer]: ./inference.md
[Content Safety]: ./content-safety.md
