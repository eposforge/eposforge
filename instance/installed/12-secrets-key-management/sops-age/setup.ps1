#Requires -Version 5.1
# setup.ps1 — Bootstrap sops-age secrets for this machine.
# Run from the REPO ROOT:
#   pwsh instance/installed/12-secrets-key-management/sops-age/setup.ps1
#
# Full instructions: instance/installed/12-secrets-key-management/sops-age/setup.md

$ErrorActionPreference = "Stop"

# Refresh PATH so winget-installed binaries are visible in this session
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")

# Verify required tools
foreach ($tool in @("age-keygen", "sops")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "'$tool' not found on PATH. Run: winget install FiloSottile.age Mozilla.SOPS"
        exit 1
    }
}

# Generate age key only if one does not already exist
$keyFile = "$env:APPDATA\sops\age\keys.txt"
New-Item -ItemType Directory -Force (Split-Path $keyFile) | Out-Null

if (Test-Path $keyFile) {
    Write-Host "[SKIP] Age key already exists at $keyFile"
    $pubKey = (Get-Content $keyFile | Select-String '^# public key: (.+)').Matches[0].Groups[1].Value
} else {
    Write-Host "Generating new age key..."
    $keygenOutput = age-keygen 2>&1  # age-keygen prints pubkey to stderr, writes privkey to stdout
    $pubKey = ($keygenOutput | Select-String '^Public key: (.+)').Matches[0].Groups[1].Value
    age-keygen -o $keyFile
    Write-Host "Age key written to $keyFile"
}

Write-Host "Public key: $pubKey"

# Patch .sops.yaml with the real public key (replaces placeholder if still present)
$sopsYaml = "$PSScriptRoot\.sops.yaml"
$content = Get-Content $sopsYaml -Raw
if ($content -match 'age1<operator-pubkey>') {
    $content = $content -replace 'age1<operator-pubkey>', $pubKey
    $content = $content -replace ',age1<linux-box-pubkey>', ''  # remove linux placeholder; add manually if needed
    Set-Content $sopsYaml $content -NoNewline
    Write-Host "Updated .sops.yaml with your public key."
    Write-Host "Commit .sops.yaml after verifying it looks correct."
} elseif ($content -notmatch [regex]::Escape($pubKey)) {
    $recipientMatches = [regex]::Matches($content, '(?m)^\s*age1[0-9a-z]+\s*$')
    if ($recipientMatches.Count -eq 1) {
        $content = [regex]::Replace($content, '(?m)^(\s*age:\s*>-\s*\r?\n\s*)(age1[0-9a-z]+)(\s*)$', "`$1$pubKey`$3", 1)
        Set-Content $sopsYaml $content -NoNewline
        Write-Host "Updated .sops.yaml to use this machine's public key."
        Write-Host "Commit .sops.yaml after verifying it looks correct."
    } else {
        Write-Warning ".sops.yaml does not include this machine's public key, and it has multiple recipients. Update it manually before rerunning setup.ps1."
        exit 1
    }
} else {
    Write-Host "[SKIP] .sops.yaml already contains a real recipient."
}

# Set key file env var for sops
$env:SOPS_AGE_KEY_FILE = $keyFile

# Write a plaintext template for the user to fill in, then encrypt it.
# This avoids SOPS's editor integration which is unreliable on Windows.
$repoRoot = Resolve-Path "$PSScriptRoot\..\..\..\.."
$encFile   = "$PSScriptRoot\secrets.enc.yaml"
$plainFile = "$PSScriptRoot\secrets.plaintext.yaml"

# If a plaintext file already exists from a previous failed run, preserve it.
if (Test-Path $plainFile) {
    Write-Host "[SKIP] Reusing existing $plainFile from a previous run."
}
# If already encrypted, decrypt to plaintext so user can edit current values.
elseif ((Test-Path $encFile) -and (Select-String -Path $encFile -Pattern "^sops:" -Quiet)) {
    Write-Host "Decrypting existing secrets.enc.yaml for editing..."
    Push-Location $PSScriptRoot
    try {
        sops --decrypt --output $plainFile $encFile
    }
    finally {
        Pop-Location
    }
}
else {
    # Write a fresh template.
    @"
anthropic_api_key: REPLACE_ME
openai_api_key: REPLACE_ME
neo4j_password: REPLACE_ME
github_pat_operator_dev: REPLACE_ME
# gemini_api_key is optional — uncomment and fill in if you have one
# gemini_api_key: REPLACE_ME
"@ | Set-Content $plainFile -Encoding UTF8
}

Write-Host ""
Write-Host "Opening $plainFile in Notepad."
Write-Host "Fill in your secret values, File -> Save, then close Notepad."
Write-Host ""
Start-Process notepad $plainFile -Wait

# Encrypt the plaintext file
Write-Host "Encrypting..."
$workDir = Join-Path $PSScriptRoot ".sops-work"
$workFile = Join-Path $workDir "secrets.enc.yaml"
New-Item -ItemType Directory -Force $workDir | Out-Null
Copy-Item $plainFile $workFile -Force

Push-Location $workDir
try {
    sops --config $sopsYaml --encrypt --in-place "secrets.enc.yaml"
}
finally {
    Pop-Location
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "sops encryption failed. Leaving $plainFile in place so you can fix it and rerun setup.ps1."
    exit $LASTEXITCODE
}

Move-Item $workFile $encFile -Force
Remove-Item $workDir -Force

if (-not (Select-String -Path $encFile -Pattern "^sops:" -Quiet)) {
    Write-Error "$encFile is still not SOPS-encrypted. Leaving $plainFile in place; rerun setup.ps1 after fixing the encryption step."
    exit 1
}

# Delete the plaintext immediately
Remove-Item $plainFile -Force

Write-Host ""
Write-Host "Done. $encFile is encrypted and ready to commit."
Write-Host ""
Write-Host "Verifying secrets..."
python "$repoRoot\instance\installed\12-secrets-key-management\bin\epos-secrets" --check