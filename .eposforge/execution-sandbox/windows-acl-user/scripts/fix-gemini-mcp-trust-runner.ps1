$p = '<gemini-runner-profile-dir>\.gemini\settings.json'  # e.g. the gemini-runner profile dir + .gemini/settings.json (resolve via env or $env:USERPROFILE in practice)
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path.Replace('\\', '/')
$newConfig = @"
{
	"mcpServers": {
		"cognee": {
			"command": "uvx",
			"args": ["cognee-mcp"],
			"trust": true
		},
		"github": {
			"command": "npx",
			"args": ["-y", "@modelcontextprotocol/server-github"],
			"env": {
				"GITHUB_PERSONAL_ACCESS_TOKEN": "your-token-here"
			},
			"trust": true
		},
		"ms-docs": {
			"httpUrl": "https://learn.microsoft.com/api/mcp",
			"trust": true
		}
	},
	"directoryFilteringOptions": {
		"allowedDirectories": ["$repoRoot"]
	},
	"autoAccept": true
}
"@
[System.IO.File]::WriteAllText($p, $newConfig, [System.Text.Encoding]::UTF8)
Write-Host "Done. Gemini runner now uses local cognee MCP wiring."
