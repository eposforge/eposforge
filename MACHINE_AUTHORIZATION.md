# Machine Authorization Workflow

## Overview

Add a new machine to the SOPS age recipients list with a simple two-step interactive workflow.

## Workflow

### Step 1: Request Authorization (on the machine being added)

```bash
epos-machine-request
```

**Output:**
```
======================================================================
MACHINE AUTHORIZATION REQUEST
======================================================================

Machine:    srv-docker-hp
Fingerprint: 3eb687d82dc8c048
Public key: age15rktdsez8gdphuz2htk0l8yd2fzysq4t0s55qmn35s42kzmyvv6sh0c6jk

⚠️  SAVE THIS PRIVATE KEY TO YOUR SECRETS VAULT:

Private key (copy entire file):
----------------------------------------------------------------------
# created: 2026-05-06T02:41:18Z
# public key: age15rktdsez8gdphuz2htk0l8yd2fzysq4t0s55qmn35s42kzmyvv6sh0c6jk
AGE-SECRET-KEY-1V3GLD3QNWA7SUKM4NA9FF7Q9AAE634N4NLY4D62HEGUJCADHLHHSAKN8HK
----------------------------------------------------------------------

✅ Once saved, press Enter to proceed...
```

**What to do:**
1. Copy the private key (entire block) to your secrets vault
2. Press Enter to proceed
3. Copy the displayed command to share with your approver

### Step 2: Approve Authorization (on an authorized machine with git access)

Copy and run the command displayed by the requesting machine:

```bash
epos-authorize srv-docker-hp 3eb687d82dc8c048 age15rktdsez8gdphuz2htk0l8yd2fzysq4t0s55qmn35s42kzmyvv6sh0c6jk
```

**Interactive prompts:**
```
======================================================================
AUTHORIZATION CONFIRMATION
======================================================================

Machine:    srv-docker-hp
Fingerprint: 3eb687d82dc8c048

Approve this machine? (y/n): y
```

The script will:
1. Validate the fingerprint matches the public key
2. Add the recipient to `.sops.yaml`
3. Re-key `secrets.enc.yaml` with `sops updatekeys`
4. Automatically commit both files
5. Offer to push changes

### Step 3: Receive Authorization (back on the requesting machine)

```bash
git pull
epos-secrets --check
```

The requesting machine will now be able to decrypt secrets.

## Implementation Details

- **`epos-machine-request`:** Generates age key pair, displays private key with vault save prompt
- **`epos-authorize`:** Accepts machine name, fingerprint, and public key as positional arguments
- **Fingerprint verification:** Short SHA256 digest used for out-of-band confirmation
- **Auto-commit:** No manual `git add/commit` needed
- **No file passing:** All data passed via command-line arguments (fingerprint challenge verified)

## Recovery

To revoke a machine, remove its public key from `.sops.yaml` and run:

```bash
sops updatekeys .eposforge/secrets-key-management/sops-age/secrets.enc.yaml
git add -A && git commit -m "sops: revoke machine <hostname>"
git push
```
