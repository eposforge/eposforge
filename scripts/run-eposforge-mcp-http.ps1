param(
    [string]$Neo4jUri = "bolt://<neo4j-host>:7688",
    [string]$Neo4jUsername = "neo4j",
    [string]$Neo4jPassword = "REDACTED",
    [int]$Port = 7788
)

$ErrorActionPreference = "Stop"
$serverHost = "127.0.0.1"
$serverPath = "/mcp/"
$exePath = Join-Path $PSScriptRoot "..\graphrag\.venv\Scripts\mcp-neo4j-cypher.exe"
$exePath = [System.IO.Path]::GetFullPath($exePath)

if (-not (Test-Path $exePath)) {
    Write-Error "MCP executable not found: $exePath"
    exit 1
}

$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listener) {
    $ownerPid = $listener.OwningProcess
    $proc = Get-Process -Id $ownerPid -ErrorAction SilentlyContinue
    $cmdline = (Get-CimInstance Win32_Process -Filter "ProcessId = $ownerPid" -ErrorAction SilentlyContinue).CommandLine

    if ($cmdline -and $cmdline -match "mcp-neo4j-cypher") {
        Write-Host "Stopping existing MCP process on port $Port (PID $ownerPid)."
        Stop-Process -Id $ownerPid -Force
    }
    else {
        $name = if ($proc) { $proc.ProcessName } else { "unknown" }
        Write-Error "Port $Port is already in use by PID $ownerPid ($name). Refusing to stop non-MCP process."
        exit 1
    }
}

$env:NEO4J_URI = $Neo4jUri
$env:NEO4J_USERNAME = $Neo4jUsername
$env:NEO4J_PASSWORD = $Neo4jPassword

& $exePath --transport http --server-host $serverHost --server-port $Port --server-path $serverPath --read-only
