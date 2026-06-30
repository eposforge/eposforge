---
doc_kind: operator-runbook
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# In-Process Budget Enforcement (EF-018)

This profile adds a per-key wallet check in front of inference calls.

## Contract

- Budget policy is loaded from config on every preflight call.
- Persistent usage counters are loaded from disk on every preflight call.
- If requested usage exceeds budget:
  - return `degrade` with `recommended_model` when policy defines one and
    budget remains,
  - otherwise return `deny` with a clear reason.

## Files

- Policy config:
  - `.eposforge/inference/budget-policy.json`
- Preflight checker:
  - `.eposforge/inference/scripts/check-budget-gate.sh`
- Counter updater:
  - `.eposforge/inference/scripts/record-budget-usage.sh`
- Counter store default:
  - `.eposforge/.audit/inference-budget-counters.json`

## Hot reload

No process restart is required. Each script invocation re-reads policy and
counter files from disk.
