# Component 8: Agent Policy

## Purpose

Declarative, machine-enforceable bounds on what agents may do. Agent
Policy encodes what is allowed, what requires approval, what is
forbidden, and how violations are handled. Every other component
enforces the policy; the Agent Policy slot is where the policy is
defined.

A factory without explicit Agent Policy is unsafe by definition. Even
the simplest instance must install at least a minimal Adapter.

## Contract

Any Adapter for this slot must:

- Express policies declaratively (as files in source control, not as
  imperative code).
- Support **tiered approval**:
  - Tier 0: forbidden — agents cannot perform.
  - Tier 1: auto-approved — agents proceed, audit-only.
  - Tier 2: human review — agents propose; humans approve or reject.
  - Tier 3: human approval gate at completion — agents may proceed with
    work but final apply requires human sign-off.
  - (Adapters may add finer tiers; these four are the minimum.)
- Scope policies by domain (Platform vs Product), by Adapter type, and
  by resource class.
- Provide a decision API the Router and Tool Transport call before any
  action.
- Be versioned with audit history. Policy changes are auditable like
  code changes.
- Fail closed: if the policy decision point is unreachable, the action
  is denied.

## Required Adapter metadata

In addition to the universal fields in
[../00-adapter-pattern.md](../00-adapter-pattern.md):

- `policy_format` — file format the Adapter consumes (e.g., YAML, OPA
  Rego, JSON, custom DSL).
- `tiers_supported` — full tier list, beyond the required minimum.
- `decision_latency_target` — declared p99 latency for policy decisions.

## Boundaries

- **Is:** the slot where bounds and approval gates are declared and
  decided.
- **Is not:** the enforcement point. Other components (Tool Transport,
  Router, CI) are enforcement points; they consult Agent Policy for
  decisions.
- **Is not:** a runtime monitor. Audit & Observability handles
  observation; Agent Policy handles permission.

## Reference implementations

See [../../03-research/](../../03-research/) for the catalog (OPA /
Rego, custom YAML policy engines, hand-rolled per-instance, etc.).
