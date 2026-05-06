# Authorize an sops-age recipient from a machine request or public key (Windows).
# Thin wrapper that locates and invokes the Python core.

param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# bin -> 12-secrets-key-management -> installed -> instance -> eposforge (4 levels)
$RepoRoot = (Resolve-Path "$ScriptDir\..\..\..\..\" -ErrorAction Stop).Path
$Core = Join-Path $RepoRoot "instance\installed\12-secrets-key-management\sops-age\scripts\setup_core.py"

if (-not (Test-Path $Core)) {
    Write-Error "Could not find setup_core.py at $Core" -ErrorAction Stop
}

$args = @("authorize") + $args
& python $Core @args
