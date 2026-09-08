# Plan: Secrets launcher audit (EF-092)

**Date:** 2026-09-07
**Status:** Open; deliberately independent of EF-091
**Tracking:** EF-092
**Related:** EF-022 (relocatable resolver — the vault-location half, stays separate), EF-086 (migration owner)

## Why this is separate

The secrets entrypoints are the one place in the tree where a wrong "collapse the duplicate"
move has a real blast radius: it can break Windows Git Bash or a POSIX PATH invocation of the
vault tooling. Keeping it out of the skill-path item means a bad collapse cannot force a revert
of work that is already correct.

## Audit first, then collapse

Produce the table before changing anything. One row per `.sh`, `.ps1` and Python entrypoint
under `.eposforge/secrets-key-management/`:

| Entrypoint | Thin launcher or second implementation? | Core it resolves (before) | Layout it assumed (before) |
|---|---|---|---|
| `sops-age/setup.sh` | Thin launcher | `sops-age/scripts/setup_core.py` | Script-relative — already correct, no change |
| `sops-age/setup.ps1` | Thin launcher | `sops-age/scripts/setup_core.py` | Script-relative — already correct, no change |
| `bin/epos-machine-request` (Python) | Thin launcher | `instance/installed/12-secrets-key-management/sops-age/scripts/setup_core.py` | Stale numbered-component tree (`12-secrets-key-management`) that no longer exists |
| `bin/epos-machine-request.sh` | Thin launcher | `.eposforge/secrets-key-management/sops-age/scripts/setup_core.py` | Happened to be correct, but via a redundant repo-root-then-redescend hop that duplicated the relative path a second time |
| `bin/epos-machine-request.ps1` | Thin launcher | `instance\installed\secrets-key-management\sops-age\scripts\setup_core.py` | Stale tree, and disagrees with the Python form by dropping the `12-` prefix |
| `bin/epos-authorize` (Python) | Thin launcher | `instance/installed/12-secrets-key-management/sops-age/scripts/setup_core.py` | Same stale tree as `epos-machine-request` |
| `bin/epos-authorize.sh` | **Broken stub**, not a working second implementation | none — the file computed `REPO_ROOT` and stopped; no `CORE` var, no invocation | N/A — running it did nothing and exited 0 |
| `bin/epos-authorize.ps1` | Thin launcher | `instance\installed\secrets-key-management\sops-age\scripts\setup_core.py` | Stale tree, same drift as `epos-machine-request.ps1` |
| `sops-age/scripts/setup_core.py` | The shared core itself (not an entrypoint) | — | Its own `_repo_root()` was off by one parent (`parents[5]`, should be `parents[4]`), and `_authorize_cmd` hardcoded the same stale `instance/installed/secrets-key-management` subpath for `.sops.yaml`/`secrets.enc.yaml`. Invisible until a launcher called `authorize` without `--repo-root` — which is how every `bin/epos-authorize*` launcher calls it — so the three-way launcher drift above was masking a fourth bug in the thing they all point at |
| `bin/epos-secrets` (Python) | Standalone resolver/shim — not a launcher over `setup_core.py`, no `.ps1` twin, already the "one core invoked via `python` on any OS" shape | its own manifest-walking logic | **Out of scope for this item** (no twin to collapse). Flagged in passing: `_REPO_ROOT` is derived as `_DEFAULT_SECRETS_ROOT.parent.parent.parent`, which is also off by one and resolves the default `EPOS_AUDIT_SINK` path to one directory above the actual repo root when the env var isn't set. Worth its own follow-up; not touched here |

What the audit found, from a read of the tree: the setup pair on both OSes already wrapped one
Python core — that is the target shape, and it needed no change. The machine request and
authorize entrypoints did **not** agree: their shell, PowerShell and Python forms each resolved
a different tree, and `epos-authorize.sh` didn't resolve anything at all — it was an incomplete
stub. Those are the write-twice twins; see "The collapse" below for what changed.

## The collapse

All six `bin/epos-*` launchers (`epos-authorize`, `epos-authorize.sh`, `epos-authorize.ps1`,
`epos-machine-request`, `epos-machine-request.sh`, `epos-machine-request.ps1`) now resolve the
core the same way: purely script-relative, `<script's own dir>/../sops-age/scripts/setup_core.py`
— no repo-root guess, no hardcoded component-numbering tree. This is the same script-relative
principle `setup.sh`/`setup.ps1` already used correctly, applied consistently to the other four
launchers instead of each re-deriving (and disagreeing on) the path independently.
`epos-authorize.sh` was completed rather than just re-pointed, since it previously invoked
nothing. Each touched launcher carries `# vehicle-class: host-ci-glue`.

`setup_core.py` itself was fixed (`_repo_root()`'s off-by-one, and the stale
`instance/installed/secrets-key-management` subpath in `_authorize_cmd`) so that the now-correct
launchers actually reach a working `authorize` implementation — collapsing the launchers onto a
core that couldn't find `.sops.yaml` would not have satisfied "produces the same result." It
carries `# vehicle-class: in-repo-pipeline`.

No `.ps1` launcher was deleted. No path touched prints a secret value — `_request_cmd`'s display
of the freshly generated age private key (an existing, documented, one-time bootstrap prompt so
the operator can save it to their vault) is unchanged and is not a vault-secret read; nothing in
this change adds or alters any print of decrypted secret material.

## The rule being applied

Write once. OS-specific bits are thin launchers over one core. Dual POSIX + PowerShell
*implementations* are declined, because twins drift — and these entrypoints are the evidence.

## Constraints on the change

- **Keep every `.ps1` launcher.** Deleting one is not "collapsing a twin", it is dropping a
  supported surface.
- Collapse only genuine reimplementations, never a launcher.
- A shared program must run on every OS this tooling is used from; verify each surviving
  entrypoint from a POSIX shell and from Windows Git Bash and confirm both reach the same core.
- Mark each touched program with its `vehicle-class:` (these are `host-ci-glue` launchers over
  an `in-repo-pipeline` core).
- No path this item touches may print a secret value. The vault pattern is unchanged: the
  human sets values in a terminal they control; tooling reads them into an environment
  variable and never echoes them.

## Not in this item

Relocatability of the resolver — decoupling the vault location from the script location — is
EF-022 and stays there. This item is only about how many implementations exist behind each
entrypoint.
