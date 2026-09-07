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

| Entrypoint | Thin launcher or second implementation? | Core it resolves | Layout it assumes |
|---|---|---|---|

What the audit is expected to find, from a read of the tree: the setup pair on both OSes
already wraps one Python core — that is the target shape, and it needs no change. The machine
request and authorize entrypoints do **not** agree: their shell, PowerShell and Python forms
each resolve a different tree. Those are the write-twice twins.

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
