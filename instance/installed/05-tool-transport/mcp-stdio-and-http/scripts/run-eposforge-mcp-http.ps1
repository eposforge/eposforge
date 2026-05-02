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

Write-Host "Starting local Cognee MCP server over stdio..."
& uvx cognee-mcp
