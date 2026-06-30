<#
.SYNOPSIS
  Configure local Git for SSH commit signing + DCO on Windows.

.DESCRIPTION
  Turns on cryptographic SSH commit signing (the green "Verified" badge on
  GitHub) and a `git ci` alias that both signs off (DCO, -s) and signs (-S)
  every commit. See CONTRIBUTING.md -> "Cryptographically Signed Commits".

  Only writes your local `git config --global`. It NEVER contacts a remote,
  pushes, or uploads a key — uploading the public key to GitHub as a Signing
  key is a manual step printed in the closing banner.

  Re-runnable (idempotent): every step is `git config --global <key> <value>`,
  which simply overwrites the same key with the same value.

.EXAMPLE
  instance\installed\source-control-ci\github-and-actions\scripts\setup-signed-commits.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 1. Locate an SSH public key: prefer ed25519, fall back to RSA.
$ed25519 = Join-Path $env:USERPROFILE '.ssh\id_ed25519.pub'
$rsa     = Join-Path $env:USERPROFILE '.ssh\id_rsa.pub'

$sshKey = $null
if (Test-Path $ed25519) {
    $sshKey = $ed25519
} elseif (Test-Path $rsa) {
    $sshKey = $rsa
}

if (-not $sshKey) {
    Write-Error @"
==> No SSH public key found.

Expected one of:
  $ed25519   (preferred)
  $rsa

Generate an ed25519 key, then re-run this script:
  ssh-keygen -t ed25519 -C "you@example.com"
"@
    exit 1
}

Write-Host "==> Using SSH signing key: $sshKey"

# 2-11. Configure SSH signing, DCO+sign alias, and quality-of-life rebase/log
#       settings. All --global and idempotent.
git config --global gpg.format ssh
git config --global user.signingkey "$sshKey"
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global alias.ci 'commit -s -S'
git config --global rebase.autosquash true
git config --global rebase.autostash true
git config --global log.showsignature true
git config --global commit.verbose true

$pubKey = Get-Content $sshKey -Raw
Write-Host @"

==> Local Git is now configured for signed + signed-off commits.

Next steps (manual — this script does not touch any remote):
  1. Add your PUBLIC key to GitHub as a *Signing key* (separate from your
     Authentication key):
       https://github.com/settings/ssh/new
     Key type: Signing key
     Key:      $pubKey
  2. Make a test commit:
       git ci -m "Test signed + DCO commit"
     Then confirm:
       git log --show-signature -1     # should report a good signature
     The commit should show "Verified" on GitHub.
"@
