# Plan: Component 12 (Secrets & Key Management) — split + sops-age + resolver

## Context

The repo's secrets handling today is "set environment variables in your shell rc, hope you got them all right, and copy `.mcp.json.example` → `.mcp.json` to fill in passwords." The single installed adapter at [env-vars-and-os-credstore.md](instance/installed/12-secrets-key-management/env-vars-and-os-credstore/env-vars-and-os-credstore.md) conflates two genuinely different store backends (process env + Windows Credential Manager), declares no manifest, and ships no resolver — so the slot's contractual demands (`logical_name`, `runtime_name`, `source_of_truth`, `injection_path`, `consumers`, `required_environments`, `rotation_owner`, `redaction_rules`, `fallback`, plus `secret.accessed` audit events) are unmet.

The operator works on **Linux + Windows**, has a password vault with **no programmatic API** (so vendor SDKs like 1Password CLI are out), and has ruled out **paid services**. Six secrets are in scope: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `NEO4J_PASSWORD`, `GITHUB_PERSONAL_ACCESS_TOKEN` (operator dev copy), `GITHUB_PERSONAL_ACCESS_TOKEN` (sandbox-user copy), `GEMINI_API_KEY`. `LLM_MODEL` is env-driven config but not a secret.

**Outcome:** one declarative manifest per adapter, one cross-platform Python resolver that decrypts via SOPS+age and exec's the child with the env populated, and adapter docs that actually satisfy the slot contract.

## Approach

Split the existing adapter into three, add a new SOPS-age adapter, and add a slot-level Python resolver that consumes all three manifests.

```
instance/installed/12-secrets-key-management/
  bin/
    epos-secrets                  # NEW — slot-level Python resolver shim
  env-vars/                       # NEW — replaces half of the old adapter
    env-vars.md
    secrets.toml                  # declares LLM_MODEL + any local-only overrides
  windows-credential-manager/     # NEW — replaces other half of the old adapter
    windows-credential-manager.md
    secrets.toml                  # declares sandbox-user GEMINI + GITHUB_PAT
  sops-age/                       # NEW — primary shared-secrets adapter
    sops-age.md
    secrets.toml                  # declares 5 operator-machine secrets
    .sops.yaml                    # recipient/path rules
    secrets.enc.yaml              # encrypted values, keyed by logical_name
  env-vars-and-os-credstore/      # DELETE in same PR after the three replacements land
```

## Step-by-step

### 1. Write the three new adapter Living Spec docs

Each follows the format of [env-vars-and-os-credstore.md](instance/installed/12-secrets-key-management/env-vars-and-os-credstore/env-vars-and-os-credstore.md) — frontmatter + Universal fields table + Component 12 required fields table (`store_backends`, `rotation_supported`, `injection_modes`) + repo-specific fields + Contract gaps. Each links the slot contract at [12-secrets-key-management.md](01-architecture/02-components/12-secrets-key-management.md) and references the candidate catalog at [secrets-key-management.md](03-research/12-secrets-key-management/secrets-key-management.md).

- **`env-vars/env-vars.md`** — `store_backends: process environment`; `rotation_supported: false`; `injection_modes: env`. Carries `LLM_MODEL` and `EPOS_ENV`. The lowest-common-denominator bootstrap.
- **`windows-credential-manager/windows-credential-manager.md`** — `store_backends: Windows Credential Manager`; `rotation_supported: true (manual via cmdkey)`; `injection_modes: per-Windows-user env`. Carries the **sandbox-user** copies of `GEMINI_API_KEY` and `GITHUB_PERSONAL_ACCESS_TOKEN` (least-privilege scopes), seeded by [install-gemini-sandbox.ps1](instance/installed/07-execution-sandbox/windows-acl-user/scripts/install-gemini-sandbox.ps1) which already calls `cmdkey`. Doc explicitly scopes to the `gemini-runner` user.
- **`sops-age/sops-age.md`** — `store_backends: encrypted file (age recipients)`; `rotation_supported: true (sops --rotate, two-state window via _next suffix)`; `injection_modes: env via epos-secrets resolver`. Carries the operator's `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `NEO4J_PASSWORD`, `GITHUB_PERSONAL_ACCESS_TOKEN` (operator dev copy, separate token from sandbox), `GEMINI_API_KEY`.

### 2. Define the manifest schema (`secrets.toml`)

One TOML file per adapter directory, same schema everywhere. Each `[[secret]]` block fills every contractual field. Example for `sops-age/secrets.toml`:

```toml
schema_version = "1"

[manifest]
adapter        = "sops-age"
encrypted_file = "secrets.enc.yaml"
sops_config    = ".sops.yaml"
age_key_path_linux   = "~/.config/sops/age/keys.txt"
age_key_path_windows = "%APPDATA%/sops/age/keys.txt"
age_key_source_of_truth = "operator-password-vault:eposforge/age-private-key"

[[secret]]
logical_name           = "anthropic_api_key"
runtime_name           = "ANTHROPIC_API_KEY"
source_of_truth        = "secrets.enc.yaml#anthropic_api_key"
injection_path         = "process-env via epos-secrets shim"
consumers              = [
  "instance/scripts/spec-graph-rebuild.sh",
  "instance/scripts/spec-graph-index.sh",
  "instance/scripts/spec-graph-cognee.py",
]
required_environments  = ["dev"]
rotation_owner         = "operator"
redaction_rules        = ["never log raw value", "mask sk-ant-* prefix in tracebacks"]
fallback               = "manual export from operator password vault"
```

Same shape repeats for the other four secrets in `sops-age` and the entries in `env-vars` and `windows-credential-manager`. Keying the encrypted file by `logical_name` (not runtime_name) keeps the encrypted file stable across runtime renames.

### 3. Write the resolver shim ([instance/installed/12-secrets-key-management/bin/epos-secrets](instance/installed/12-secrets-key-management/bin/epos-secrets))

**Single Python 3.11+ script. No `.ps1` wrapper.** Linux: shebang + chmod +x. Windows: invoke as `python instance/installed/12-secrets-key-management/bin/epos-secrets -- <child>` (Python is already a hard dep via cognee). Stdlib only (`tomllib`, `subprocess`, `os`, `json`, `sys`); the `sops` binary must be on PATH.

Invocation patterns:

```
epos-secrets -- bash instance/scripts/spec-graph-rebuild.sh
epos-secrets --only ANTHROPIC_API_KEY,OPENAI_API_KEY -- python instance/scripts/spec-graph-cognee.py
python ./instance/installed/12-secrets-key-management/bin/epos-secrets -- pwsh ./instance/scripts/run-eposforge-mcp-http.ps1
epos-secrets --check                 # validate manifests, decrypt-test, list missing/extra entries
```

Resolution flow:
1. Walk `instance/installed/12-secrets-key-management/*/secrets.toml`, merge into one in-memory manifest. Detect collisions on `runtime_name` and fail loudly.
2. Apply `--only` filter, otherwise load every secret whose `required_environments` contains `$EPOS_ENV` (default `dev`). Refuse if a secret's `required_environments` excludes the current env.
3. For `sops-age` entries: `sops --decrypt secrets.enc.yaml` once, cache in process memory, look up by `logical_name`.
4. For `windows-credential-manager` entries: `cmdkey /list:Target` lookup + read via `CredRead` API (Python `keyring` is a single stdlib-adjacent dep we'll avoid; instead shell out to PowerShell `Get-StoredCredential` or skip — these entries are seeded for the sandbox user, not the operator, so the resolver only *declares* them and validates presence, it doesn't inject them into the operator's env).
5. For `env-vars` entries: passthrough from current process env.
6. For each resolved secret, set the env var, then emit one `secret.accessed` JSON line (no value: `{ts, logical_name, runtime_name, consumer_argv0, pid, adapter}`) to `$EPOS_AUDIT_SINK` if set, else `instance/.audit/secret-access.jsonl` (path gitignored).
7. `os.execvp` the child with the augmented environment so the shim doesn't linger holding plaintext.

Rotation: a logical name plus `_next` suffix in `secrets.enc.yaml` is honored when `EPOS_USE_NEXT=1`, satisfying the slot's "two states for a window" clause without touching consumers.

### 4. Encrypted file + .sops.yaml

`sops-age/secrets.enc.yaml` — flat YAML, one key per logical secret, encrypted at the value level only.

`sops-age/.sops.yaml` — pins recipients via path regex:

```yaml
creation_rules:
  - path_regex: instance/installed/12-secrets-key-management/sops-age/secrets\.enc\.yaml$
    age: age1<operator-pubkey>,age1<laptop-pubkey>,age1<linux-box-pubkey>
    encrypted_regex: '^(.*)$'
```

### 5. Repo-wide doc edits

- [AGENTS.md](AGENTS.md) line ~200 — replace the bare `ANTHROPIC_API_KEY, OPENAI_API_KEY, NEO4J_PASSWORD` list with a pointer: "see [secrets.toml](instance/installed/12-secrets-key-management/sops-age/secrets.toml) for the canonical manifest; runtime invocation is `epos-secrets -- bash instance/scripts/spec-graph-rebuild.sh`."
- Header comments in [spec-graph-rebuild.sh](instance/scripts/spec-graph-rebuild.sh), [spec-graph-index.sh](instance/scripts/spec-graph-index.sh), [spec-graph-import.sh](instance/scripts/spec-graph-import.sh), [spec-graph-cognee.py](instance/scripts/spec-graph-cognee.py), [run-eposforge-mcp-http.ps1](instance/scripts/run-eposforge-mcp-http.ps1) — append a "Recommended invocation: `epos-secrets -- <this script>`" line. Do NOT change the scripts' env-var reads; they keep working with raw env, the resolver just pre-populates it.
- [.gitignore](.gitignore) — add `instance/.audit/` and confirm `**/secrets.enc.yaml` is *not* ignored (we want the encrypted file committed) and `**/keys.txt` *is* ignored (we never want the age private key in the repo).

### 6. Delete `env-vars-and-os-credstore/`

After the three replacements are written and the resolver `--check` passes on Linux + Windows. Repo is pre-1.0; redirect-stub adds clutter.

## Critical files

- New: [instance/installed/12-secrets-key-management/bin/epos-secrets](instance/installed/12-secrets-key-management/bin/epos-secrets)
- New: [instance/installed/12-secrets-key-management/env-vars/env-vars.md](instance/installed/12-secrets-key-management/env-vars/env-vars.md), `env-vars/secrets.toml`
- New: [instance/installed/12-secrets-key-management/windows-credential-manager/windows-credential-manager.md](instance/installed/12-secrets-key-management/windows-credential-manager/windows-credential-manager.md), `windows-credential-manager/secrets.toml`
- New: [instance/installed/12-secrets-key-management/sops-age/sops-age.md](instance/installed/12-secrets-key-management/sops-age/sops-age.md), `sops-age/secrets.toml`, `sops-age/.sops.yaml`, `sops-age/secrets.enc.yaml`
- Edit: [AGENTS.md](AGENTS.md) (Conventions section, ~line 200)
- Edit: [.gitignore](.gitignore)
- Edit (header comments only): [spec-graph-rebuild.sh](instance/scripts/spec-graph-rebuild.sh), [spec-graph-index.sh](instance/scripts/spec-graph-index.sh), [spec-graph-import.sh](instance/scripts/spec-graph-import.sh), [spec-graph-cognee.py](instance/scripts/spec-graph-cognee.py), [run-eposforge-mcp-http.ps1](instance/scripts/run-eposforge-mcp-http.ps1)
- Delete: [instance/installed/12-secrets-key-management/env-vars-and-os-credstore/](instance/installed/12-secrets-key-management/env-vars-and-os-credstore/)
- Reference (read-only): [12-secrets-key-management.md](01-architecture/02-components/12-secrets-key-management.md), [00-adapter-pattern.md](01-architecture/00-adapter-pattern.md), [secrets-key-management.md](03-research/12-secrets-key-management/secrets-key-management.md)

## Bootstrap flow (post-implementation)

**Linux:**
1. `git clone … && cd eposforge`
2. `sudo apt install age sops` (or `brew install age sops`)
3. `age-keygen -o ~/.config/sops/age/keys.txt && chmod 600 ~/.config/sops/age/keys.txt`
4. Send the **public** key (printed by `age-keygen`) to the operator. Operator adds it to `sops-age/.sops.yaml` recipients and runs `sops updatekeys sops-age/secrets.enc.yaml`. Commit + pull.
5. Copy the matching **private** key from the operator's password vault into `~/.config/sops/age/keys.txt` (a single existing operator machine produced this; new machines either generate their own and get added as recipients, or copy the existing one).
6. `python instance/installed/12-secrets-key-management/bin/epos-secrets --check`
7. `epos-secrets -- bash instance/scripts/spec-graph-rebuild.sh`

**Windows:**
1. `git clone …`
2. `winget install FiloSottile.age Mozilla.SOPS`
3. Copy age private key from password vault into `%APPDATA%\sops\age\keys.txt`
4. `pwsh instance/installed/07-execution-sandbox/windows-acl-user/scripts/install-gemini-sandbox.ps1 -GeminiApiKey ... -GitHubPat ...` — unchanged. This is the `windows-credential-manager` adapter's bootstrap; the GitHub PAT here is the sandbox-scoped one, separate from the operator's dev PAT in `sops-age`.
5. `python instance/installed/12-secrets-key-management/bin/epos-secrets --check`
6. `python instance/installed/12-secrets-key-management/bin/epos-secrets -- bash instance/scripts/spec-graph-rebuild.sh`

## Verification

End-to-end smoke test after implementation:

1. **Manifest sanity** — `epos-secrets --check` reports zero collisions, decrypts `secrets.enc.yaml` successfully, lists each secret as `present` or `missing`.
2. **Resolver populates env** — `epos-secrets -- env | grep -E '^(ANTHROPIC|OPENAI|NEO4J|GITHUB|GEMINI)'` shows all five values present (redacted in display).
3. **Audit line emitted** — running step 2 appends one JSON line per secret to `instance/.audit/secret-access.jsonl` with no values, just metadata.
4. **Spec-graph rebuild works under resolver** — `epos-secrets -- bash instance/scripts/spec-graph-rebuild.sh` completes a clean run; identical artifacts to running it directly with manually-exported env vars.
5. **MCP launch works under resolver** — wrap the cognee MCP launch with `epos-secrets --only NEO4J_PASSWORD --` in `.mcp.json` and verify the `cognee` server starts and `cognee.search("...")` returns results.
6. **Cross-platform parity** — repeat steps 1–4 on the Linux machine and the Windows machine.
7. **Rotation drill** — add `anthropic_api_key_next` to `secrets.enc.yaml`, run `EPOS_USE_NEXT=1 epos-secrets --check`, confirm the `_next` value wins. Delete it. Confirm fallback to the original.
8. **No plaintext on disk** — `git status` shows `secrets.enc.yaml` as the only "secret" file modified, and its contents are all `ENC[…]` lines.

## Out of scope (deferred to follow-ups)

- **Paired-change rule for Component 12 in [instance/SPEC.md](instance/SPEC.md).** The slot contract gestures at one but the existing SPEC.md scopes paired-change to Component 6 only. Premature codification will churn while these three adapters settle. Add in a follow-up PR once shape is stable.
- **Real `secret.accessed` audit pipeline.** Component 11 (Audit & Observability) has no installed sink yet. Resolver writes to `instance/.audit/secret-access.jsonl` as a placeholder; wiring into Component 11 is its own story.
- **Automated rotation enforcement.** Manifest declares `rotation_owner` per secret but there's no CI policy check or expiry tracker. Future: an `epos-secrets audit-rotation` subcommand reading a sibling `rotation-log.toml`.
- **macOS adapter.** Operator is Linux + Windows only today; manifest leaves room (`age_key_path_*`) but no `macos-keychain/` adapter doc.
- **Sandbox-user secret sync from sops-age.** Teaching `install-gemini-sandbox.ps1` to pull from `sops-age` (operator decrypts, re-stores into Windows Credential Manager for `gemini-runner`) couples two adapters; land separately.
- **`.mcp.json` literal templating.** If `.mcp.json` ever needs string-substitution (rather than env-var passthrough via the resolver), that's a Tool Transport (Component 8) concern.
