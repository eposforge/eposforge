# Platform Factory — Maturity Phases

The Platform Factory is the side of a dark factory that owns the
operational substrate: hardware, network, OS, 3rd-party services,
secrets, observability, and — at the horizon — physical actuators. It
matures along five phases. Each phase is a stable plateau; instances
ship value at every phase, not only at the end.

This roadmap is **generic**. Instances declare their own substrate
choices and adopt phases at their own pace.

---

## Phase 0 — Foundation

**Goal:** Everything-as-Code foundation + observability so agents can
see.

By the end of Phase 0:

- All substrate configuration is in source control. No undocumented
  manual changes.
- Secrets are encrypted at rest and resolved through the Secrets & Key
  Management Adapter (component 12).
- Audit & Observability (component 11) is collecting structured events
  from the substrate.
- Backups are automated and tested for restoration.
- Source Control + CI (component 9) is operational with signed agent
  attribution.

**Done when:** an unfamiliar operator can fully reconstruct the
substrate from source control.

**Skill:** declarative thinking.

---

## Phase 1 — Agent Observation

**Goal:** Agents query state, propose fixes, wait for human approval.

By the end of Phase 1:

- An Agent Policy Adapter (component 8) is installed with at least
  tier 0–2 support.
- A Platform-scoped agent can read the audit log, propose remediations,
  and open them as PRs in Source Control + CI.
- The factory has a dashboard showing pending agent proposals, the
  reasoning behind each, and the diff each would apply.
- No agent action lands without human approval.

**Done when:** an agent detects a real issue → proposes a fix → opens a
PR → human approves → change applies → outcome is recorded.

**Skill:** constraint-based specifications.

---

## Phase 2 — Agent Proposals at Scale

**Goal:** Agents create PRs; humans review; merges flow through CI
automatically.

By the end of Phase 2:

- The Router (component 4) is dispatching Platform-scoped sub-tasks
  alongside Product-scoped ones.
- Agent memory exists (typically as part of the Spec Graph, component
  6, or as a separate store) so agents can recall prior outcomes.
- Approval workflows are tiered by risk class, defined in Agent
  Policy.
- PR throughput is high enough that human review of every diff is no
  longer feasible — humans review outcomes and policies, not lines.

**Done when:** an agent proposes an action → policy auto-approves per
its tier → CI applies → outcome recorded → agent learns for next time.

**Skill:** outcome-driven specifications.

---

## Phase 3 — Supervised Autonomy

**Goal:** Agents execute pre-approved actions in narrow categories;
humans audit summaries.

By the end of Phase 3:

- Agent Policy includes tier-1 (auto-approved) categories with
  comprehensive guardrails: rate limits, dry-run dress rehearsals,
  automatic rollback on failure, retry budgets.
- Audit & Observability provides daily / weekly summaries digestible
  in minutes.
- Tier-1 actions include at least: restart unhealthy services, rotate
  certificates, apply security patches after canary, restart workloads
  for substrate optimization.
- Failure modes are documented and rehearsed.

**Done when:** the factory handles routine ops autonomously, the human
reviews the daily summary, and there are no incidents for 30 days.

**Skill:** safety-oriented specifications.

---

## Phase 4 — Full Autonomy

**Goal:** Agents self-update, coordinate across boundaries, and
optimize against strategic goals; humans set policy and audit
outcomes.

By the end of Phase 4:

- Agents update their own Adapters from signed Git commits.
- Multi-agent coordination handles cross-component actions (event
  bus, locks, distributed workflows).
- Operators write **intent-level specifications** ("increase
  resilience under partial failure"); the factory implements and
  verifies them.
- The factory scales across multiple substrate hosts or zones without
  re-architecture.

**Done when:** a human writes a strategic goal → agents implement and
verify → the factory operates against the goal autonomously for a
month.

**Skill:** strategic specifications.

---

## Adoption Notes

- Phases are **sequential**: each phase's verification criteria gate
  the next.
- Phases are **per-instance**. Two instances may be at different
  phases without difficulty.
- Phases are **per-substrate**. An instance with a heterogeneous
  substrate (containers + GPU + future robotics) may be at different
  phases per substrate type.
- Going **slower than the roadmap** is fine. Skipping phases is not.
