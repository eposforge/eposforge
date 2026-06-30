# Generate a machine authorization request for sops-age recipients (Windows).
# Thin wrapper that locates and invokes the Python core.

param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# bin -> secrets-key-management -> installed -> instance -> eposforge (4 levels)
$RepoRoot = (Resolve-Path "$ScriptDir\..\..\..\..\" -ErrorAction Stop).Path
$Core = Join-Path $RepoRoot "instance\installed\secrets-key-management\sops-age\scripts\setup_core.py"

if (-not (Test-Path $Core)) {
    Write-Error "Could not find setup_core.py at $Core" -ErrorAction Stop
}

$args = @("request") + $args
& python $Core @args
