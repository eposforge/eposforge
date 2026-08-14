---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Working Memory

## Purpose

The factory's shared operational memory. This slot **replaces** each
[Dev Product]'s native memory system (vendor `MEMORY.md` files,
auto-memory, per-CLI recall stores) with one semantic store every
installed Dev Product reads and writes through the [Tool Transport].

The essential characteristic is **displacement**: when this slot is
filled, operational facts, preferences, corrections, and
cross-session distillations live here — not in the CLI. Switching
Dev Product Adapters must not fork or lose that memory.

A Working Memory Adapter **depends on** [Tool Transport] (one
implementation, many CLI consumers) and **depends on** the
[Inference Layer] when extraction or semantic write needs a model.
It may later read [Interaction Capture]; it does not own that
corpus. It does **not** fulfill [Spec Graph].

## Contract

Any Adapter for this slot must:

- Persist operational memory **independently of any single Dev
  Product**. Recall after a CLI swap must return the same facts.
- Expose at least **recall**, **remember**, and **forget** (or
  equivalent) as a [Tool Transport] **working-memory** capability.
  Dev Products consume only that capability; they do not open a
  back door to the store.
- Provide a **semantic layer**. Writes are extracted into entities
  and relations (ontology-grounded, declared schema, or hybrid) —
  not appended as an undifferentiated note pile. Recall is
  queryable by meaning, not only by keyword or filename.
- Keep a **physically separate store** from [Spec Graph], from
  Tool Transport **code-structure**, and from [Interaction Capture].
  The same vendor product MAY fulfill Spec Graph as a *different*
  Adapter; that Adapter **does not** fulfill this slot. A shared
  process is allowed; a shared dataset, index, or default query
  scope is not.
- Refuse to ingest Living Specs, architecture contracts, or source
  trees as if they were memories. Those corpora belong to Spec
  Graph and code-structure.
- When this slot is installed, **displace** each Dev Product's
  native memory: stop writing operational memory to the vendor
  store, and route recall to this Adapter. Leaving native memory
  as a parallel SoT is a contract violation.
- Declare identity scope (factory-wide, per-operator, per-workspace,
  or a stated combination) and honor it on every read and write.
- Emit [Audit & Observability] events for remember and forget.
- Read secrets only via [Secrets & Key Management].
- Honor [Agent Policy] on every write and on any forget.
- Offer export/import of the memory corpus so an instance can
  change Adapters without losing state.

The Working Memory store is the source of truth for operational
memory. Unlike Spec Graph, this graph is **not** a projection of
disk specs. Correct a fact by remembering or forgetting here, not
by editing a Living Spec.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern/adapter-pattern.md](../00-adapter-pattern/adapter-pattern.md):

- `store_isolation` — how this Adapter's store is isolated from any
  sibling Spec Graph Adapter of the same product (dataset name,
  endpoint, process, or equivalent).
- `semantic_model` — `ontology-grounded` | `declared-schema` |
  `embeddings-only` | `hybrid`.
- `identity_scope` — `factory` | `operator` | `workspace` | a
  declared combination.
- `native_memory_displacement` — how installed Dev Products are
  stopped from using vendor memory (settings, hooks, policy, docs).
- `may_read_interaction_capture` — whether this Adapter is allowed
  to distill from [Interaction Capture].
- `retention` — compaction / expiry policy. Deleting raw
  Interaction Capture records remains that slot's concern; this
  field covers *memories* only.

## Boundaries

- **Is:** the shared, semantic replacement for Dev Product native
  memory. Active recall *during* execution, across CLIs and
  sessions.
- **Is not:** [Spec Graph]. Spec Graph projects Living Specs
  (intent / architecture). Working Memory holds operator and agent
  operational facts. An architecture-guidance MCP is Spec Graph
  even when the same product also offers a Working Memory Adapter.
- **Is not:** Tool Transport **code-structure**. Code graphs map
  as-built implementation; they do not remember that the operator
  prefers X.
- **Is not:** federated markdown / product / platform knowledge
  graphs. Those are Scope Spec Graphs or curated domain graphs.
- **Is not:** [Interaction Capture]. That slot is the immutable
  recording side (what was said). This slot is the live memory
  the CLIs consult. Working Memory may later read Interaction
  Capture; it does not own the raw store.
- **Is not:** [Audit & Observability]. Audit records that a write
  happened; it does not answer "what do we remember?"
- **Is not:** in-turn context (the current prompt window). That
  stays inside the Dev Product invocation.

## Reference implementations

See
[../../03-research/01-architecture/02-components/working-memory/working-memory.md](../../03-research/01-architecture/02-components/working-memory/working-memory.md)
for the candidate catalog (Cognee as a distinct-dataset Adapter,
Mem0, Zep, LangMem, Letta). Native per-CLI stores are declined —
they are what this slot replaces.

<!-- component-links (generated by check-component-links.py --write-defs) -->
[Dev Product]: ./dev-product.md
[Tool Transport]: ./tool-transport.md
[Inference Layer]: ./inference.md
[Interaction Capture]: ./interaction-capture.md
[Spec Graph]: ./spec-graph.md
[Audit & Observability]: ./audit-observability.md
[Secrets & Key Management]: ./secrets-key-management.md
[Agent Policy]: ./agent-policy.md
