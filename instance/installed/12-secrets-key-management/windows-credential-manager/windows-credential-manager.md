---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: windows-credential-manager -> Secrets & Key Management (Component 12)

> Living Spec for the Windows Credential Manager secrets adapter.
> Slot contract: [../../../../01-architecture/02-components/12-secrets-key-management.md](../../../../01-architecture/02-components/12-secrets-key-management.md)
> Candidate catalog: [../../../../03-research/01-architecture/02-components/12-secrets-key-management/secrets-key-management.md](../../../../03-research/01-architecture/02-components/12-secrets-key-management/secrets-key-management.md)

This adapter fulfills the Component 12 (Secrets & Key Management) slot using Windows
Credential Manager (`cmdkey` / `CredRead` API) as the store backend. It is explicitly
scoped to the `gemini-runner` sandbox user on Windows and carries the **sandbox-scoped**
copies of `GEMINI_API_KEY` and `GITHUB_PERSONAL_ACCESS_TOKEN`. The operator's own copies
of these secrets live in the `sops-age` adapter.

This adapter FULFILLS_SLOT `12-secrets-key-management` for the sandbox execution context.
It DEPENDS_ON the `windows-acl-user` execution sandbox adapter (Component 7) which seeds
the credentials via `install-gemini-sandbox.ps1`.

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `windows-credential-manager` |
| `component` | `12-secrets-key-management` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `local` |
| `cost_hint` | `free` |
| `capabilities` | `per-user-credential-isolation`, `least-privilege-scoping` |
| `invocation_surface` | Windows Credential Manager via `cmdkey` / PowerShell `Get-StoredCredential` |

### Secrets / Key Management required fields

| Field | Value |
|---|---|
| `store_backends` | Windows Credential Manager |
| `rotation_supported` | `true (manual via cmdkey /add)` |
| `injection_modes` | `per-Windows-user env (seeded at sandbox install time)` |

### Repo-specific fields

| Field | Value |
|---|---|
| `scope` | `gemini-runner` sandbox user only; not the operator's primary Windows session |
| `bootstrap_script` | [../../07-execution-sandbox/windows-acl-user/scripts/install-gemini-sandbox.ps1](../../07-execution-sandbox/windows-acl-user/scripts/install-gemini-sandbox.ps1) |
| `manifest_file` | `secrets.toml` (this directory) |
| `resolver_note` | The `epos-secrets` resolver declares these entries and validates presence; it does not inject them into the operator's process env (they are seeded for `gemini-runner` by the sandbox installer) |

## Purpose

The `gemini-runner` sandbox user requires a `GEMINI_API_KEY` and a scoped
`GITHUB_PERSONAL_ACCESS_TOKEN` (read-only scopes only; this is NOT the operator's dev PAT).
These credentials are stored per-user in Windows Credential Manager by
`install-gemini-sandbox.ps1` so the Gemini CLI process launched as `gemini-runner` can read
them without exposing them to other Windows users or the operator's shell.

The `epos-secrets` resolver honors these manifest entries for validation (`--check` mode)
but does not attempt to read them from the operator's Credential Manager store. The resolver
only validates that the `cmdkey` targets listed in `secrets.toml` are present in the
`gemini-runner` user's store by shelling out to `PowerShell Get-StoredCredential` when
running as `gemini-runner`, or skipping the check with a `[SKIP]` note when running as
any other user.

## Observable behavior

- `epos-secrets --check` as operator: reports `[SKIP]` for windows-credential-manager entries
  with a note that validation must be run as `gemini-runner`.
- `epos-secrets --check` as `gemini-runner`: shells out to `Get-StoredCredential` to verify
  presence of each declared target; reports `[OK]` or `[MISSING]`.
- No decryption step; Windows Credential Manager decrypts using the logged-in user's DPAPI key.
- Rotation: re-run `install-gemini-sandbox.ps1 -RotateCredentials` (future parameter) or
  manually update via `cmdkey /add:<target> /user:<u> /pass:<new>`.

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| Resolver only validates, does not inject | sandbox secrets are seeded externally; resolver has no injection path for this adapter's entries | Acceptable for sandbox scope; resolver injection not needed for `gemini-runner` use case |
| Windows-only | No cross-platform equivalent | Add macOS Keychain adapter if macOS support added |
| No `secret.accessed` audit event | resolver does not emit events for entries it validates but does not inject | Wire audit emit in `--check` validation path as a future improvement |
