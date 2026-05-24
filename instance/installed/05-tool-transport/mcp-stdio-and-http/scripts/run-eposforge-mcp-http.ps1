param(
    [string]$AzureApiKey,
    [string]$AnthropicApiKey
)
# Recommended invocation (secrets resolved automatically):
#   python instance/installed/12-secrets-key-management/bin/epos-secrets -- pwsh instance/installed/05-tool-transport/mcp-stdio-and-http/scripts/run-eposforge-mcp-http.ps1

$ErrorActionPreference = "Stop"

if (-not $env:INFERENCE_PROVIDER) {
    $env:INFERENCE_PROVIDER = "azure-foundry"
}

if (-not $env:COGNEE_REQUIRE_AZURE_ROUTING) {
    $env:COGNEE_REQUIRE_AZURE_ROUTING = "1"
}

if (-not $AnthropicApiKey) {
    $AnthropicApiKey = $env:ANTHROPIC_API_KEY
}

if (-not $AzureApiKey) {
    $AzureApiKey = $env:AZURE_API_KEY
}

if (-not $AzureApiKey) {
    $AzureApiKey = $env:OPENAI_API_KEY
}

$missingSettings = @()

$provider = $env:INFERENCE_PROVIDER
$requireAzure = ($env:COGNEE_REQUIRE_AZURE_ROUTING -eq "1")

if ($requireAzure -and $provider -ne "azure-foundry") {
    $missingSettings += "INFERENCE_PROVIDER=azure-foundry (required by COGNEE_REQUIRE_AZURE_ROUTING=1)"
}

if ($provider -eq "azure-foundry") {
    if (-not $env:LLM_MODEL) {
        $env:LLM_MODEL = "azure/mdl-openai-gpt41mini-std-eus2-r1"
    }
    if (-not $env:EMBEDDING_MODEL) {
        $env:EMBEDDING_MODEL = "azure/mdl-openai-textembed3large-std-eus2-r1"
    }
    if (-not $env:AZURE_API_VERSION) {
        $env:AZURE_API_VERSION = "2024-10-01"
    }
    if (-not $env:LLM_PROVIDER) {
        $env:LLM_PROVIDER = "openai"
    }
    if (-not $env:EMBEDDING_PROVIDER) {
        $env:EMBEDDING_PROVIDER = "openai"
    }

    if (-not $env:AZURE_API_BASE) {
        $missingSettings += "AZURE_API_BASE"
    }
    if (-not $AzureApiKey) {
        $missingSettings += "AZURE_API_KEY (or OPENAI_API_KEY fallback) or -AzureApiKey"
    }
    if (-not $env:AZURE_API_VERSION) {
        $missingSettings += "AZURE_API_VERSION"
    }
    if ($env:LLM_MODEL -notlike "azure/*") {
        $missingSettings += "LLM_MODEL must start with azure/ when INFERENCE_PROVIDER=azure-foundry"
    }
    if ($env:EMBEDDING_MODEL -notlike "azure/*") {
        $missingSettings += "EMBEDDING_MODEL must start with azure/ when INFERENCE_PROVIDER=azure-foundry"
    }
} elseif (-not $AnthropicApiKey) {
    $missingSettings += "ANTHROPIC_API_KEY or -AnthropicApiKey"
}

if ($missingSettings.Count -gt 0) {
    Write-Error ("Missing required settings: {0}" -f ($missingSettings -join ", "))
    exit 1
}

$uvx = Get-Command uvx -ErrorAction SilentlyContinue
if (-not $uvx) {
    Write-Error "uvx is required to launch Cognee MCP. Install uv (https://docs.astral.sh/uv/) and retry."
    exit 1
}

$env:ANTHROPIC_API_KEY = $AnthropicApiKey
$env:AZURE_API_KEY = $AzureApiKey

# Point Cognee at the same SQLite metadata DB used during indexing.
# The indexing script (cognee.py) sets system_root_directory to this path;
# the MCP server must read from the same location or list_data returns nothing.
$cogneeRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\06-spec-graph\cognee\.cognee")).Path
$env:SYSTEM_ROOT_DIRECTORY = $cogneeRoot
Write-Host "Cognee root: $cogneeRoot"

Write-Host "Starting local Cognee MCP server over stdio..."
$wrapperScript = Join-Path $PSScriptRoot "cognee-mcp-win-wrapper.py"
& uv run --with "cognee[fastembed]" --with cognee-mcp python $wrapperScript
