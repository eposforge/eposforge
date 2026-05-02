$p = 'C:\Users\gemini-runner\.gemini\settings.json'
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
		"allowedDirectories": ["<abs-path-to-repo-root>"]
	},
	"autoAccept": true
}
"@
[System.IO.File]::WriteAllText($p, $newConfig, [System.Text.Encoding]::UTF8)
Write-Host "Done. Gemini runner now uses local cognee MCP wiring."
