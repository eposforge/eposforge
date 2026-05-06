---
doc_kind: reference-implementation
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# Installed Adapter: sops-age -> Secrets & Key Management (Component 12)

> Living Spec for the SOPS + age encrypted-file secrets adapter.
> Slot contract: [../../../../01-architecture/02-components/12-secrets-key-management.md](../../../../01-architecture/02-components/12-secrets-key-management.md)
> Candidate catalog: [../../../../03-research/12-secrets-key-management/secrets-key-management.md](../../../../03-research/12-secrets-key-management/secrets-key-management.md)

This adapter fulfills the Component 12 (Secrets & Key Management) slot using SOPS with age
recipients as the encryption backend. It is the **primary adapter** for all operator-machine
secrets: API keys and service passwords that must be shared across Linux and Windows
developer machines without a programmatic vault API.

This adapter FULFILLS_SLOT `12-secrets-key-management` as the primary shared-secrets store.
It DEPENDS_ON the `epos-secrets` resolver shim (Component 12 bin layer) to decrypt and
inject at runtime. It MATURES_TO Phase 0 as a foundation-level credential management
mechanism and is GOVERNED_BY the no-plaintext-on-disk principle in this repo's conventions.

## Adapter metadata

### Universal fields

| Field | Value |
|---|---|
| `name` | `sops-age` |
| `component` | `12-secrets-key-management` |
| `version` | `0.1.0` |
| `status` | `experimental` |
| `privacy_posture` | `local` |
| `cost_hint` | `free` |
| `capabilities` | `encrypted-file-store`, `multi-machine-sharing`, `two-state-rotation`, `cross-platform` |
| `invocation_surface` | `sops` CLI + `age` keying; runtime injection via `epos-secrets` resolver |

### Secrets / Key Management required fields

| Field | Value |
|---|---|
| `store_backends` | encrypted file (`secrets.enc.yaml`), age recipients |
| `rotation_supported` | `true (sops --rotate; two-state window via logical_name + _next suffix)` |
| `injection_modes` | `env via epos-secrets resolver shim` |

### Repo-specific fields

| Field | Value |
|---|---|
| `encrypted_file` | `secrets.enc.yaml` (this directory; committed; all values are `ENC[…]` ciphertext) |
| `sops_config` | `.sops.yaml` (this directory) |
| `age_key_path_linux` | `~/.config/sops/age/keys.txt` |
| `age_key_path_windows` | `%APPDATA%\sops\age\keys.txt` |
| `age_key_source_of_truth` | `operator-password-vault:eposforge/age-private-key/<hostname>` |
| `manifest_file` | `secrets.toml` (this directory) |
| `resolver` | `instance/installed/12-secrets-key-management/bin/epos-secrets` |

## Secrets in scope

| Logical name | Runtime name | Rotation owner |
|---|---|---|
| `anthropic_api_key` | `ANTHROPIC_API_KEY` | operator |
| `openai_api_key` | `OPENAI_API_KEY` | operator |
| `neo4j_password` | `NEO4J_PASSWORD` | operator |
| `github_pat_operator_dev` | `GITHUB_PERSONAL_ACCESS_TOKEN` | operator |
| `gemini_api_key` | `GEMINI_API_KEY` | operator |

Note: `github_pat_operator_dev` is the **operator's** dev PAT. The `gemini-runner` sandbox
user's GitHub PAT (`github_pat_sandbox`) is a separate token stored in the
`windows-credential-manager` adapter.

## Observable behavior

- At runtime, the `epos-secrets` resolver runs `sops --decrypt secrets.enc.yaml` once,
  caches the result in process memory, and looks up each secret by `logical_name`.
- The decrypted values are set as environment variables for the child process only. They are
  never written to disk.
- Each resolved secret emits one `secret.accessed` JSON line (no value) to
  `$EPOS_AUDIT_SINK` if set, otherwise `instance/.audit/secret-access.jsonl`.
- After all env vars are populated, the resolver calls `os.execvp` (Linux) or
  `subprocess.run` (Windows) so the shim does not linger holding plaintext in memory.
- Rotation: add `<logical_name>_next` alongside the existing key in `secrets.enc.yaml`,
  run with `EPOS_USE_NEXT=1` to use the next value, then delete the old key after cutover.

## Bootstrap (first machine setup)

### Linux

```sh
sudo apt install age sops          # or: brew install age sops
age-keygen -o ~/.config/sops/age/keys.txt && chmod 600 ~/.config/sops/age/keys.txt
```
Or use the machine request helper:

```sh
bash instance/installed/12-secrets-key-management/sops-age/setup.sh
```

This writes `epos-machine-request.json` and prints a short fingerprint for out-of-band
approval.

### Windows

```powershell
winget install FiloSottile.age Mozilla.SOPS
```

Then generate a machine request payload:

```powershell
python instance/installed/12-secrets-key-management/bin/epos-machine-request
```

Operator-side approval (Linux or Windows):

```sh
python instance/installed/12-secrets-key-management/bin/epos-authorize --request-file epos-machine-request.json
```

After the approval commit is pulled, verify on the target machine:

```sh
python instance/installed/12-secrets-key-management/bin/epos-secrets --check
```

### Initializing a fresh encrypted file

If `secrets.enc.yaml` does not yet contain your machine's encrypted values, or you are
creating it from scratch:

```sh
# From repo root, with SOPS_AGE_KEY_FILE pointing at your keys.txt:
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt   # Linux
# or: $env:SOPS_AGE_KEY_FILE = "$env:APPDATA\sops\age\keys.txt"   # Windows

cd instance/installed/12-secrets-key-management/sops-age
sops secrets.enc.yaml    # opens editor; fill in plaintext values, save → SOPS encrypts
```

## Contract gaps (v1)

| Gap | Impact | Upgrade path |
|---|---|---|
| Requires SOPS + age on PATH | Bootstrap friction on new machines | Document in CONTRIBUTING; add CI check |
| No programmatic rotation enforcement | Rotation is operator-initiated | Add `epos-secrets audit-rotation` subcommand in follow-up |
| No macOS adapter equivalent | Operator is Linux + Windows only | Add macOS Keychain adapter if macOS support added |
| `secret.accessed` written to flat file | No structured audit pipeline yet | Wire to Component 11 (Audit & Observability) in follow-up |
