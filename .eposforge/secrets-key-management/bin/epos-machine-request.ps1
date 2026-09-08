# Generate a machine authorization request for sops-age recipients (Windows).
# Thin wrapper that locates and invokes the Python core.
# vehicle-class: host-ci-glue

param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Core = Join-Path $ScriptDir "..\sops-age\scripts\setup_core.py"

if (-not (Test-Path $Core)) {
    Write-Error "Could not find setup_core.py at $Core" -ErrorAction Stop
}

$args = @("request") + $args
& python $Core @args
