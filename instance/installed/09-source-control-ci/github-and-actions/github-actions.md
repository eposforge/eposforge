---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: github-and-actions -> Source Control / CI (Component 9)

> Living Spec for Source Control / CI in this repo instance.
> Slot contract: [../../../../01-architecture/02-components/09-source-control-ci.md](../../../../01-architecture/02-components/09-source-control-ci.md)

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `github-and-actions` |
| `component` | `09-source-control-ci` |
| `version` | `0.1.0` |
| `status` | `approved` |
| `privacy_posture` | `vendor-default` |
| `cost_hint` | `free + metered` (depends on Actions usage) |
| `capabilities` | `version-control`, `pr-review`, `workflow-runs` |
| `invocation_surface` | `github.com + GitHub Actions` |

### Source Control / CI required fields

| Field | Value |
|---|---|
| `scm_model` | `git` |
| `review_gate` | PR-based review on protected branches |
| `pipeline_trigger_modes` | pull_request, workflow_dispatch |
| `artifact_lineage` | commit history + PR timeline + workflow logs |

### Repo-specific fields

| Field | Value |
|---|---|
| `default_branch` | `main` |
| `dco_policy` | commit sign-off required (DCO) per README contributing section |
| `branch_protection` | required on main for review + checks (repo setting) |
| `doc_lint_workflow` | `.github/workflows/doc-lint.yml` |

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| Branch protection details are configured in GitHub UI | Not fully represented as repo-as-code | Add policy-as-code export or documented baseline |
| CI coverage is docs-focused | Non-doc automation checks are limited | Add component-specific validation jobs as adapters mature |
