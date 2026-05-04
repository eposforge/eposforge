# sops-age Setup Guide

Full reference for bootstrapping, using, and maintaining the sops-age secrets adapter.

## Prerequisites

Install `age` and `sops` (Windows):

```powershell
winget install FiloSottile.age Mozilla.SOPS
```

## First-time setup

Run from the **repo root**:

```powershell
pwsh instance/installed/12-secrets-key-management/sops-age/setup.ps1
```

The script:
1. Refreshes `PATH` so winget-installed binaries are visible in the current session
2. Generates an age keypair at `%APPDATA%\sops\age\keys.txt` (skips if one already exists)
3. Patches `.sops.yaml` with your real age public key (replaces the `age1<operator-pubkey>` placeholder)
4. Opens `secrets.plaintext.yaml` in Notepad — fill in your values, File → Save, close Notepad
5. Encrypts the plaintext to `secrets.enc.yaml` and deletes the plaintext file immediately

After running, commit `.sops.yaml` and `secrets.enc.yaml`.

## What to put in the plaintext file

```yaml
anthropic_api_key: sk-ant-...
openai_api_key: sk-proj-...
neo4j_password: your-neo4j-password
github_pat_operator_dev: ghp_...
# gemini_api_key is optional — uncomment if you have one
# gemini_api_key: AIza...
```

Key names must match the `logical_name` fields in [secrets.toml](secrets.toml). Do not rename them.

## Changing, adding, or removing secrets

Re-run the setup script:

```powershell
pwsh instance/installed/12-secrets-key-management/sops-age/setup.ps1
```

Because `secrets.enc.yaml` already exists, the script decrypts it to plaintext, opens it in Notepad, and re-encrypts after you save and close. The plaintext file is deleted immediately after encryption.

If you add or remove a key, also update [secrets.toml](secrets.toml) to match — that's where the resolver learns what to inject and what to validate.

## Verifying secrets are resolved correctly

```powershell
python instance/installed/12-secrets-key-management/bin/epos-secrets --check
```

This decrypts `secrets.enc.yaml`, looks up each declared secret, and reports `[OK]`, `[MISSING]`, or `[SKIP]` for each entry.

## Using secrets at runtime

Wrap any command that needs secrets:

```powershell
python instance/installed/12-secrets-key-management/bin/epos-secrets -- <command>
```

Examples:

```powershell
# Rebuild the Spec Graph
python instance/installed/12-secrets-key-management/bin/epos-secrets -- bash instance/installed/06-spec-graph/scripts/rebuild.sh

# Run a specific script with only the secrets it needs
python instance/installed/12-secrets-key-management/bin/epos-secrets --only ANTHROPIC_API_KEY,NEO4J_PASSWORD -- python my-script.py
```

The MCP servers (cognee, github) are already configured to use the resolver via the generated `.mcp.json` and `.vscode/mcp.json`. After running setup, reload your IDE.

## Adding a second machine (Linux or Windows)

1. Generate a new age keypair on the new machine:
   - Linux: `age-keygen -o ~/.config/sops/age/keys.txt`
   - Windows: `age-keygen -o "$env:APPDATA\sops\age\keys.txt"`
2. Send the printed public key (`age1...`) to the operator
3. Operator adds it to `.sops.yaml` recipients and runs:
   ```sh
   sops updatekeys instance/installed/12-secrets-key-management/sops-age/secrets.enc.yaml
   ```
4. Commit and push `.sops.yaml` and the re-keyed `secrets.enc.yaml`
5. Pull on the new machine, then run `epos-secrets --check` to verify

## Key storage

| Location | What |
|---|---|
| `%APPDATA%\sops\age\keys.txt` (Windows) | Age private key — never commit, store in password vault |
| `~/.config/sops/age/keys.txt` (Linux) | Age private key — never commit, store in password vault |
| `secrets.enc.yaml` | Encrypted secrets — safe to commit |
| `.sops.yaml` | Recipient public keys — safe to commit |
| `secrets.toml` | Secret manifest (no values) — safe to commit |

## Rotation

To rotate a single secret without downtime:

1. Add `<logical_name>_next: <new-value>` to `secrets.enc.yaml` via the setup script
2. Test with `EPOS_USE_NEXT=1 python epos-secrets --check`
3. Once confirmed working, rename `_next` to the primary key and delete the old one
