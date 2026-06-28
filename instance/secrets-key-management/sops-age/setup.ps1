#Requires -Version 5.1
# setup.ps1 — Windows thin wrapper for sops-age machine request flow.
# Run from the REPO ROOT:
#   pwsh instance/secrets-key-management/sops-age/setup.ps1

$ErrorActionPreference = "Stop"

# Refresh PATH so user- and machine-level installs are visible in this session.
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")

$repoRoot = Resolve-Path "$PSScriptRoot\..\..\..\.."
$coreScript = Join-Path $PSScriptRoot "scripts\setup_core.py"

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    $pythonCmd = Get-Command py -ErrorAction SilentlyContinue
}

if (-not $pythonCmd) {
    Write-Error "Python is required. Install Python 3.11+ and rerun setup.ps1."
    exit 1
}

$requestArgs = @("request") + $args

if ($pythonCmd.Name -eq "py") {
    & py -3 $coreScript @requestArgs
} else {
    & python $coreScript @requestArgs
}

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Next: send epos-machine-request.json and the printed fingerprint to the approving operator."
Write-Host "After approval is committed and pulled, run:"
Write-Host "  python instance/secrets-key-management/bin/epos-secrets --check"