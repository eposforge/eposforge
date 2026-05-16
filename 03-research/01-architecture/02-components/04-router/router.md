---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Router — Implementation Catalog

> **Snapshot date:** 2026-04. Verify current details before adopting.

Candidate Adapters for the Router slot
([../../01-architecture/02-components/04-router.md](../../01-architecture/02-components/04-router.md)).
A Router Adapter consumes normalized Spec Input, decomposes it into
sub-tasks, picks Dev Product Adapters per sub-task, dispatches via
Tool Transport, and iterates.

This catalog is **not exhaustive** and **not an endorsement**.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — agent framework, full platform, custom.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Decomposition strategy** — LLM-driven, rule-based, hybrid.
- **Capabilities** — what task shapes the Adapter handles well.
- **Notes** — anything notable for Adapter authors.

---

## Candidates

### Microsoft Agent Framework

- **Type:** open-source multi-agent orchestration framework
  (successor to AutoGen).
- **Cost tier:** free OSS (operator brings own model API keys).
- **Decomposition strategy:** LLM-driven; supports group-chat, plan-
  and-execute, and graph-based agent patterns.
- **Capabilities:** strong for in-process .NET / Python orchestration;
  pluggable model providers; growing tool / MCP integration.
- **Notes:** clean fit for instances with a Microsoft-stack
  preference. Adapter wraps the framework's runner and emits the
  audit events the slot requires.

### LangGraph

- **Type:** graph-based agent orchestration library (Python / JS).
- **Cost tier:** free OSS.
- **Decomposition strategy:** explicit graph of nodes and edges;
  decomposition often hand-authored, sometimes LLM-driven within
  nodes.
- **Capabilities:** strong control over state transitions, branching,
  retries, and human-in-the-loop pauses.
- **Notes:** good fit when the operator wants explicit control flow
  rather than free-running agents. Often paired with **Temporal**
  (see below) for durable, long-running orchestration.

### Temporal

- **Type:** durable workflow engine.
- **Cost tier:** free OSS core; commercial cloud option.
- **Decomposition strategy:** workflow-as-code; not a decomposer on
  its own — usually wrapped around an LLM-based decomposer.
- **Capabilities:** durable state, retries, signals, schedules, and
  long-running multi-step workflows that survive process restarts.
- **Notes:** pairs with LangGraph or a custom decomposer to give the
  Router durability guarantees the slot's `escalation_policy` field
  benefits from.

### AutoGen

- **Type:** multi-agent conversation framework (Microsoft Research).
- **Cost tier:** free OSS.
- **Decomposition strategy:** LLM-driven; multi-agent dialog patterns.
- **Capabilities:** rapid prototyping of multi-agent decomposition;
  large community and example library.
- **Notes:** in maintenance mode in favor of Microsoft Agent
  Framework; included for awareness and for instances already
  invested in AutoGen patterns.

### OpenHands

- **Type:** open-source autonomous agent (formerly OpenDevin
  lineage).
- **Cost tier:** free OSS.
- **Decomposition strategy:** LLM-driven autonomous task execution.
- **Capabilities:** self-directed multi-step development workflows.
- **Notes:** also listed in [dev-products.md](../03-dev-product/dev-products.md);
  whether it fits the Router slot or the Dev Product slot depends on
  how the operator scopes its autonomy.

### Custom in-house orchestrator

- **Type:** operator-built.
- **Cost tier:** free (cost of build + maintain).
- **Decomposition strategy:** whatever the instance needs.
- **Capabilities:** unconstrained.
- **Notes:** the floor option. Choose deliberately — building a
  Router is the largest single component effort in a factory
  instance. Adopt a framework first and replace only when no
  framework fits.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
with declared retry / escalation behavior and a clear emission
surface for the audit events the Router slot requires.

