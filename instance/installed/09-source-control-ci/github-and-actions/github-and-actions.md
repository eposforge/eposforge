---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---
# Installed Adapter: github-and-actions -> Source Control / CI (Component 9)

> Living Spec for Source Control / CI in this repo instance.
| `status` | `approved` |
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
| `layout_workflow` | `.github/workflows/installed-scripts-layout.yml` |
| `hook_composer` | `scripts/install-hooks.sh` |
| `layout_check` | `scripts/check-installed-scripts-layout.sh` |

## Git hooks — component-owned, composed

This adapter owns repo-wide Git hook composition. Each installed adapter that
needs hook behaviour drops a fragment at
`instance/installed/<component>/scripts/hooks/<git-hook-name>` (or
`<component>/<adapter>/scripts/hooks/<git-hook-name>`). The composer at
`scripts/install-hooks.sh` discovers all fragments and writes a single
dispatcher into `.git/hooks/<name>` that runs every fragment in order. The
dispatcher exits with the highest non-zero status seen, so blocking hooks
(`pre-commit`, `pre-push`, …) still block when any fragment fails.

### Operator commands

```sh
# Install or refresh dispatchers (run once per clone, per host)
bash instance/installed/09-source-control-ci/github-and-actions/scripts/install-hooks.sh

# Verify dispatchers are up to date with discovered fragments
bash instance/installed/09-source-control-ci/github-and-actions/scripts/install-hooks.sh --check

# Remove all managed dispatchers
bash instance/installed/09-source-control-ci/github-and-actions/scripts/install-hooks.sh --uninstall
```

### Cross-host portability

Hook fragments and the composer are `#!/usr/bin/env bash`. They run on
Linux (srv-docker-hp) natively and on Windows (ws-dev-1) via Git Bash. No
host-absolute paths are committed — fragments derive the repo root from
`git rev-parse --show-toplevel`.

### Fragments currently owned by this adapter

| Hook | Fragment | Purpose |
|---|---|---|
| `pre-commit` | `scripts/hooks/pre-commit` | Run `check-sensitive-literals.sh --staged` and `check-installed-scripts-layout.sh` |
| `commit-msg` | `scripts/hooks/commit-msg` | Append exact DCO trailer (Dialedin2014) when no Signed-off-by present |

### Adapter-script layout enforcement

`scripts/check-installed-scripts-layout.sh` fails the commit (and the CI job)
if any files exist under `instance/scripts/`. The rule is: adapter scripts
must live under `instance/installed/<component>/scripts/`. The same check is
run in CI by `.github/workflows/installed-scripts-layout.yml`, catching
direct pushes from clones that have not installed the local hooks.

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| Branch protection details are configured in GitHub UI | Not fully represented as repo-as-code | Add policy-as-code export or documented baseline |
| CI coverage is docs-focused | Non-doc automation checks are limited | Add component-specific validation jobs as adapters mature |
