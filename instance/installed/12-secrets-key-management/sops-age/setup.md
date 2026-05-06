# sops-age Setup Guide

Full reference for bootstrapping, using, and maintaining the sops-age secrets adapter.

## Prerequisites

Install `age` and `sops` (Windows):

```powershell
winget install FiloSottile.age Mozilla.SOPS
```

Linux installs are currently manual (no package-manager-agnostic installer script yet).
Install `age`, install `sops`, and ensure both are on `PATH`.

## First-time setup

Run from the **repo root**:

```powershell
pwsh instance/installed/12-secrets-key-management/sops-age/setup.ps1
```

Linux machine request flow (repo root):

```bash
bash instance/installed/12-secrets-key-management/sops-age/setup.sh
```

Both wrappers call the same Python core and perform the same flow:
1. Ensure an age key exists for this machine.
2. Emit `epos-machine-request.json` with hostname, public key, and short fingerprint.
3. Print the fingerprint for out-of-band verification.

After running, send `epos-machine-request.json` and the fingerprint to the approving operator.

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

## Editing encrypted secret values (operator)

Machine setup does not edit `secrets.enc.yaml`. To add or rotate secret values, use `sops` directly from this directory:

```sh
sops secrets.enc.yaml
```

If you add or remove keys, update [secrets.toml](secrets.toml) to match the `logical_name` manifest.

## Adding a second machine (Linux or Windows)

1. On the new machine, generate a request payload:
   - Linux: `bash instance/installed/12-secrets-key-management/sops-age/setup.sh`
   - Windows: `python instance/installed/12-secrets-key-management/bin/epos-machine-request`
2. Send `epos-machine-request.json` and the printed fingerprint to the operator out-of-band.
3. On an already-authorized operator machine, approve it:
   ```sh
   python instance/installed/12-secrets-key-management/bin/epos-authorize --request-file epos-machine-request.json
   ```
4. Commit and push `.sops.yaml` and `secrets.enc.yaml`.
5. Pull on the new machine, then run `python instance/installed/12-secrets-key-management/bin/epos-secrets --check`.

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
