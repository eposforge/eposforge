#!/usr/bin/env bash
# setup-signed-commits.sh — Configure local Git for SSH commit signing + DCO.
#
# Turns on cryptographic SSH commit signing (the green "Verified" badge on
# GitHub) and a `git ci` alias that both signs off (DCO, -s) and signs (-S)
# every commit. See CONTRIBUTING.md → "Cryptographically Signed Commits".
#
# Only writes your local `git config --global`. It NEVER contacts a remote,
# pushes, or uploads a key — uploading the public key to GitHub as a Signing
# key is a manual step printed in the closing banner.
#
# Cross-host: pure bash — runs on Linux/macOS and on Windows via Git Bash.
# Re-runnable (idempotent): every step is `git config --global <key> <value>`,
# which simply overwrites the same key with the same value.
#
# Usage (run once per host):
#   bash instance/installed/09-source-control-ci/github-and-actions/scripts/setup-signed-commits.sh

set -euo pipefail

# 1. Locate an SSH public key: prefer ed25519, fall back to RSA.
SSH_KEY=""
if [ -f "${HOME}/.ssh/id_ed25519.pub" ]; then
  SSH_KEY="${HOME}/.ssh/id_ed25519.pub"
elif [ -f "${HOME}/.ssh/id_rsa.pub" ]; then
  SSH_KEY="${HOME}/.ssh/id_rsa.pub"
fi

if [ -z "$SSH_KEY" ]; then
  cat >&2 <<'NOKEY'
==> No SSH public key found.

Expected one of:
  ~/.ssh/id_ed25519.pub   (preferred)
  ~/.ssh/id_rsa.pub

Generate an ed25519 key, then re-run this script:
  ssh-keygen -t ed25519 -C "you@example.com"
NOKEY
  exit 1
fi

echo "==> Using SSH signing key: ${SSH_KEY}"

# 2-11. Configure SSH signing, DCO+sign alias, and quality-of-life rebase/log
#       settings. All --global and idempotent.
git config --global gpg.format ssh
git config --global user.signingkey "$SSH_KEY"
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global alias.ci 'commit -s -S'
git config --global rebase.autosquash true
git config --global rebase.autostash true
git config --global log.showsignature true
git config --global commit.verbose true

cat <<BANNER

==> Local Git is now configured for signed + signed-off commits.

Next steps (manual — this script does not touch any remote):
  1. Add your PUBLIC key to GitHub as a *Signing key* (separate from your
     Authentication key):
       https://github.com/settings/ssh/new
     Key type: Signing key
     Key:      $(cat "$SSH_KEY")
  2. Make a test commit:
       git ci -m "Test signed + DCO commit"
     Then confirm:
       git log --show-signature -1     # should report a good signature
     The commit should show "Verified" on GitHub.
BANNER
