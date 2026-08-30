---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---
# Installed Adapter: posix-standing-runner → Source Control + CI (test-runner sub-contract)

> Living Spec for the POSIX standing-suite dispatcher installed in this
> repo as a **worked reference**. It is **example-not-mandate**: no
> document may treat this adapter as a required vendor.
>
> Slot contract:
> [../../../01-architecture/02-components/source-control-ci-test-runner.md](../../../01-architecture/02-components/source-control-ci-test-runner.md)
> (named sub-contract of
> [Source Control + CI](../../../01-architecture/02-components/source-control-ci.md)).

| `status` | `experimental` |
| `example_not_mandate` | `true` |

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `posix-standing-runner` |
| `component` | `source-control-ci` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `local` |
| `cost_hint` | `free` |
| `capabilities` | `standing-suite`, `clone-local`, `held-out`, `gate-write-scope` |
| `invocation_surface` | `CLI scripts` |

### Test-runner sub-contract fields

| Field | Value |
|---|---|
| `standing_runner_command` | `.eposforge/source-control-ci/posix-standing-runner/scripts/run-standing.sh` |
| `standing_suite_path` | `.eposforge/standing-suite` |
| `held_out_supported` | `true` (`--held-out DIR`) |
| `example_not_mandate` | `true` |

## Operator commands

```sh
# Prove standing properties for this tree
.eposforge/source-control-ci/posix-standing-runner/scripts/run-standing.sh

# Same command against several trees (agent-config, platform, product)
.eposforge/source-control-ci/posix-standing-runner/scripts/run-standing.sh DIR1 DIR2 DIR3

# Is this evidence command a repo-local standing check?
.eposforge/source-control-ci/posix-standing-runner/scripts/run-standing.sh --accepts './.eposforge/standing-suite'

# Refuse a mixed gate+code change (net range vs merge-base)
.eposforge/source-control-ci/posix-standing-runner/scripts/run-standing.sh --check-gate

# The suite itself is the clone-local invocation
./.eposforge/standing-suite
```

## What this is not

- Not a pytest/Jest/xUnit mandate.
- Not a second kernel harness. One-command detection is this command.
- Not the cross-agent review payload. Standing checks run with no
  review directory.
