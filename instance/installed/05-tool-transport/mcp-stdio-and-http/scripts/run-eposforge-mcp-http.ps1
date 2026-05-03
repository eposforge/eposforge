param(
    [string]$AnthropicApiKey,
    [string]$Neo4jUri,
    [string]$Neo4jUsername,
    [string]$Neo4jPassword
)

$ErrorActionPreference = "Stop"

if (-not $AnthropicApiKey) {
    $AnthropicApiKey = $env:ANTHROPIC_API_KEY
}

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

if (-not $AnthropicApiKey) {
    $missingSettings += "ANTHROPIC_API_KEY or -AnthropicApiKey"
}

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

$uvx = Get-Command uvx -ErrorAction SilentlyContinue
if (-not $uvx) {
    Write-Error "uvx is required to launch Cognee MCP. Install uv (https://docs.astral.sh/uv/) and retry."
    exit 1
}

$env:ANTHROPIC_API_KEY = $AnthropicApiKey
$env:NEO4J_URI = $Neo4jUri
$env:NEO4J_USERNAME = $Neo4jUsername
$env:NEO4J_PASSWORD = $Neo4jPassword

# Point Cognee at the same SQLite metadata DB used during indexing.
# The indexing script (cognee.py) sets system_root_directory to this path;
# the MCP server must read from the same location or list_data returns nothing.
$cogneeRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\06-spec-graph\cognee\.cognee")).Path
$env:SYSTEM_ROOT_DIRECTORY = $cogneeRoot
Write-Host "Cognee root: $cogneeRoot"

Write-Host "Starting local Cognee MCP server over stdio..."
$wrapperScript = Join-Path $PSScriptRoot "cognee-mcp-win-wrapper.py"
& uv run --with "cognee[fastembed]" --with cognee-mcp python $wrapperScript
