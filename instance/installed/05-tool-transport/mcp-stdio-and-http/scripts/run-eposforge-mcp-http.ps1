param(
    [string]$Neo4jUri,
    [string]$Neo4jUsername,
    [string]$Neo4jPassword,
    [int]$Port = 7788
)

$ErrorActionPreference = "Stop"
$serverHost = "127.0.0.1"
$serverPath = "/mcp/"
$exePath = Join-Path $PSScriptRoot "..\..\06-spec-graph\graphrag\.venv\Scripts\mcp-neo4j-cypher.exe"
$exePath = [System.IO.Path]::GetFullPath($exePath)

if (-not $Neo4jUri) {
    $Neo4jUri = $env:NEO4J_URI
}

if (-not $Neo4jUsername) {
    $Neo4jUsername = $env:NEO4J_USERNAME
}

if (-not $Neo4jPassword) {
    $Neo4jPassword = $env:NEO4J_PASSWORD
}

$missingSettings = @()

if (-not $Neo4jUri) {
    $missingSettings += "NEO4J_URI or -Neo4jUri"
}

if (-not $Neo4jUsername) {
    $missingSettings += "NEO4J_USERNAME or -Neo4jUsername"
}

if (-not $Neo4jPassword) {
    $missingSettings += "NEO4J_PASSWORD or -Neo4jPassword"
}

if ($missingSettings.Count -gt 0) {
    Write-Error ("Missing required Neo4j connection settings: {0}" -f ($missingSettings -join ", "))
    exit 1
}

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
