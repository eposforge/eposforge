#Requires -RunAsAdministrator
$path = 'C:\Users\gemini-runner\.gemini\settings.json'
$json = Get-Content $path -Raw | ConvertFrom-Json
foreach ($key in @($json.mcpServers.PSObject.Properties.Name)) {
    $json.mcpServers.$key.trust = $true
}
$json | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
Write-Host "Done. MCP trust=true set for: $($json.mcpServers.PSObject.Properties.Name -join ', ')" -ForegroundColor Green
pause
