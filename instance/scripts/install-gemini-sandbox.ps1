<#
.SYNOPSIS
    Idempotent setup of the gemini-runner OS-user sandbox for Gemini CLI.

.DESCRIPTION
    Creates a standard (non-admin) local Windows user account "gemini-runner",
    sets NTFS ACLs so it can modify the repo workspace but cannot read the
    operator's profile, installs Gemini CLI under that account, stages the
    MCP settings file from the committed example, configures required secrets
    in Windows Credential Manager, verifies connectivity to all required
    endpoints, and prints the daily operator launch command.

    This script implements the windows-acl-user Execution Sandbox Adapter
    declared in:
      01-architecture/02-components/07-execution-sandbox/installed/windows-acl-user.md

    Safe to run multiple times. Each step checks existing state before acting.

.PARAMETER GeminiApiKey
    Optional paid Gemini API key to store in Windows Credential Manager for
    gemini-runner. If omitted, Gemini can still run via free-tier Google
    account auth.

.PARAMETER GitHubPat
    Optional GitHub Personal Access Token for the github MCP server.
    If omitted, credential storage is skipped and can be configured later.

.PARAMETER OperatorUsername
    The operator's Windows username (default: current user).
    Used to set the deny ACL on the operator's profile directory.
#>
param(
    [string]$GeminiApiKey,
    [string]$GitHubPat,
    [string]$OperatorUsername = $env:USERNAME,
    [switch]$ElevatedRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RunnerAccount  = 'gemini-runner'
$WorkspaceRoot  = 'D:\src\git\gh\eposforge\eposforge'
$OperatorProfile = "C:\Users\$OperatorUsername"
$GeminiSettingsExample = Join-Path $WorkspaceRoot '.gemini\settings.json.example'
$RunnerPasswordPlain = $null
$RunnerPasswordSecure = $null
$LogPath = Join-Path $env:TEMP ("eposforge-install-gemini-sandbox-{0}.log" -f $PID)
$LatestLogPath = Join-Path $env:TEMP 'eposforge-install-gemini-sandbox.latest.txt'
$TranscriptStarted = $false

"=== install-gemini-sandbox start: $(Get-Date -Format o) ===" | Out-File -FilePath $LogPath -Append -Encoding utf8
Set-Content -Path $LatestLogPath -Value $LogPath -Encoding utf8

try {
    Start-Transcript -Path $LogPath -Append -ErrorAction Stop | Out-Null
    $TranscriptStarted = $true
    Write-Host "Transcript log: $LogPath" -ForegroundColor DarkGray
} catch {
    Write-Warning "Unable to start transcript at '$LogPath': $($_.Exception.Message)"
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Warning 'Script is not elevated. Attempting self-elevation via UAC...'

    if ($ElevatedRun) {
        throw 'Self-elevation was requested but admin token is still unavailable.'
    }

    $argList = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $PSCommandPath,
        '-OperatorUsername',
        $OperatorUsername,
        '-ElevatedRun'
    )

    $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -PassThru -ArgumentList $argList
    if ($TranscriptStarted) {
        try { Stop-Transcript | Out-Null } catch {}
        $TranscriptStarted = $false
    }

    $p.WaitForExit()

    "self-elevated child exit code: $($p.ExitCode)" | Out-File -FilePath $LogPath -Append -Encoding utf8
    if ($TranscriptStarted) {
        try { Stop-Transcript | Out-Null } catch {}
    }
    exit $p.ExitCode
}

trap {
    Write-Error ("Fatal error: {0}" -f $_)
    if ($TranscriptStarted) {
        try {
            Stop-Transcript | Out-Null
        } catch {
            # Ignore transcript stop failures in trap.
        }
    }
    exit 1
}

# ---------------------------------------------------------------------------
# Helper: write a section header
# ---------------------------------------------------------------------------
function Write-Step([string]$msg) {
    Write-Host "`n=== $msg ===" -ForegroundColor Cyan
}

function New-RandomPassword([int]$Length = 24) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}'
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)

    $result = New-Object System.Text.StringBuilder
    foreach ($b in $bytes) {
        [void]$result.Append($chars[$b % $chars.Length])
    }
    return $result.ToString()
}

# ---------------------------------------------------------------------------
# Step 1: Create gemini-runner local account (idempotent)
# ---------------------------------------------------------------------------
Write-Step '1/8  Create local user gemini-runner'

if (-not (Get-LocalUser -Name $RunnerAccount -ErrorAction SilentlyContinue)) {
    $password = New-RandomPassword -Length 24
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $RunnerPasswordPlain = $password
    $RunnerPasswordSecure = $securePassword
    New-LocalUser -Name $RunnerAccount `
                  -Password $securePassword `
                  -FullName 'Gemini CLI runner' `
                  -Description 'Sandboxed Gemini CLI runner account' `
                  -PasswordNeverExpires `
                  -UserMayNotChangePassword | Out-Null
    Write-Host "  Created account '$RunnerAccount'." -ForegroundColor Green
} else {
    Write-Host "  Account '$RunnerAccount' already exists - skipping creation." -ForegroundColor Yellow
    Write-Host "  Existing account password is not requested during installer run." -ForegroundColor DarkGray
    Write-Host "  Credential-store steps that require runner credentials will be skipped unless available." -ForegroundColor DarkGray
}

# Confirm not in Administrators group
$isAdmin = (Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*\$RunnerAccount" })
if ($isAdmin) {
    Write-Error "  '$RunnerAccount' is in the Administrators group. Remove it before proceeding."
}

# ---------------------------------------------------------------------------
# Step 2: Grant Modify on workspace root to gemini-runner
# ---------------------------------------------------------------------------
Write-Step '2/8  Grant Modify on workspace to gemini-runner'

if (-not (Test-Path $WorkspaceRoot)) {
    Write-Error "  Workspace root '$WorkspaceRoot' does not exist."
}

$acl = Get-Acl $WorkspaceRoot
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $RunnerAccount,
    [System.Security.AccessControl.FileSystemRights]::Modify,
    [System.Security.AccessControl.InheritanceFlags]'ObjectInherit,ContainerInherit',
    [System.Security.AccessControl.PropagationFlags]::None,
    [System.Security.AccessControl.AccessControlType]::Allow
)
$acl.AddAccessRule($rule)
Set-Acl -Path $WorkspaceRoot -AclObject $acl
Write-Host "  Granted Modify on '$WorkspaceRoot' to '$RunnerAccount'." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 3: Deny read on sensitive user-data paths (defense-in-depth)
# ---------------------------------------------------------------------------
Write-Step '3/8  Harden read-deny ACLs for user-data paths'

$DeniedPaths = New-Object System.Collections.Generic.List[string]

function Add-DenyReadAcl([string]$TargetPath, [string]$Label) {
    if (-not (Test-Path $TargetPath)) {
        Write-Host "  [$Label] Path not found - skipping: $TargetPath" -ForegroundColor Yellow
        return
    }

    try {
        $acl = Get-Acl $TargetPath
        $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $RunnerAccount,
            [System.Security.AccessControl.FileSystemRights]::Read,
            [System.Security.AccessControl.InheritanceFlags]'ObjectInherit,ContainerInherit',
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Deny
        )
        $acl.AddAccessRule($denyRule)
        Set-Acl -Path $TargetPath -AclObject $acl
        Write-Host "  [$Label] Denied Read on '$TargetPath' to '$RunnerAccount'." -ForegroundColor Green
        $DeniedPaths.Add($TargetPath)
    } catch {
        Write-Host "  [$Label] Failed to apply deny ACL on '$TargetPath': $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 3a. Operator profile (primary protection)
Add-DenyReadAcl -TargetPath $OperatorProfile -Label 'operator-profile'

# 3b. Additional local user profiles (excluding system defaults and runner)
$usersRoot = 'C:\Users'
if (Test-Path $usersRoot) {
    $excluded = @('Public', 'Default', 'Default User', 'All Users', $RunnerAccount)
    Get-ChildItem -Path $usersRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $excluded -notcontains $_.Name } |
        ForEach-Object {
            Add-DenyReadAcl -TargetPath $_.FullName -Label 'other-profile'
        }
}

Write-Host "  Harden summary:" -ForegroundColor Cyan
if ($DeniedPaths.Count -gt 0) {
    $DeniedPaths | Select-Object -Unique | ForEach-Object {
        Write-Host "    - $_" -ForegroundColor DarkCyan
    }
} else {
    Write-Host "    No deny ACL changes applied in this run." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Step 4: Verify Node.js and install Gemini CLI under gemini-runner
# ---------------------------------------------------------------------------
Write-Step '4/8  Verify Node.js and install Gemini CLI'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "  Node.js is not in PATH. Install Node.js (https://nodejs.org/) and re-run."
}

$nodeVersion = node --version
Write-Host "  Node.js $nodeVersion found." -ForegroundColor Green

$npmCmd = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
if (-not $npmCmd) {
    Write-Error "  npm.cmd is not in PATH. Ensure Node.js/npm are installed correctly and re-run."
}

$npmExe = $npmCmd.Source

# Install globally - package is available to all users including gemini-runner
$alreadyInstalled = $false
try {
    $pkgJson = & $npmExe list -g @google/gemini-cli --depth=0 --json 2>$null | Out-String
    if ($pkgJson -match '"@google/gemini-cli"') {
        $alreadyInstalled = $true
    }
} catch {
    $alreadyInstalled = $false
}

if (-not $alreadyInstalled) {
    Write-Host '  Installing @google/gemini-cli globally...'
    & $npmExe install -g @google/gemini-cli
    Write-Host '  Gemini CLI installed.' -ForegroundColor Green
} else {
    Write-Host '  @google/gemini-cli already installed globally - skipping.' -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Step 5: Stage .gemini/settings.json for gemini-runner from example
# ---------------------------------------------------------------------------
Write-Step '5/8  Stage .gemini/settings.json for gemini-runner'

$runnerProfile = "C:\Users\$RunnerAccount"
$runnerGeminiDir = Join-Path $runnerProfile '.gemini'

if (-not (Test-Path $runnerGeminiDir)) {
    New-Item -ItemType Directory -Path $runnerGeminiDir | Out-Null
}

$targetSettings = Join-Path $runnerGeminiDir 'settings.json'

if (-not (Test-Path $targetSettings)) {
    if (Test-Path $GeminiSettingsExample) {
        Copy-Item $GeminiSettingsExample $targetSettings
        Write-Host "  Staged settings.json for gemini-runner from example." -ForegroundColor Green
        Write-Host "  IMPORTANT: Edit '$targetSettings' to replace all <placeholder> values." -ForegroundColor Yellow
    } else {
        Write-Host "  Example not found at '$GeminiSettingsExample' - skipping settings stage." -ForegroundColor Yellow
    }
} else {
    Write-Host "  '$targetSettings' already exists - ensuring MCP trust flags are set." -ForegroundColor Yellow
}

# Ensure trust=true for all MCP servers regardless of how the file got there
if (Test-Path $targetSettings) {
    try {
        $settingsJson = Get-Content $targetSettings -Raw | ConvertFrom-Json
        if ($settingsJson.mcpServers) {
            foreach ($key in @($settingsJson.mcpServers.PSObject.Properties.Name)) {
                $settingsJson.mcpServers.$key.trust = $true
            }
            $settingsJson | ConvertTo-Json -Depth 10 | Set-Content $targetSettings -Encoding UTF8
            Write-Host "  MCP server trust flags set to true." -ForegroundColor Green
        }
    } catch {
        Write-Host "  Warning: could not patch trust flags in settings.json: $_" -ForegroundColor Yellow
    }
}

# Also deploy workspace-level settings.json (gitignored) so Gemini CLI picks up MCP servers
$workspaceGeminiDir = Join-Path $WorkspaceRoot '.gemini'
$workspaceSettings  = Join-Path $workspaceGeminiDir 'settings.json'
if (-not (Test-Path $workspaceSettings)) {
    if (Test-Path $GeminiSettingsExample) {
        Copy-Item $GeminiSettingsExample $workspaceSettings
        # Set trust=true in workspace copy too
        $wsJson = Get-Content $workspaceSettings -Raw | ConvertFrom-Json
        if ($wsJson.mcpServers) {
            foreach ($key in @($wsJson.mcpServers.PSObject.Properties.Name)) { $wsJson.mcpServers.$key.trust = $true }
            $wsJson | ConvertTo-Json -Depth 10 | Set-Content $workspaceSettings -Encoding UTF8
        }
        Write-Host "  Staged workspace .gemini/settings.json (gitignored)." -ForegroundColor Green
    }
} else {
    Write-Host "  Workspace .gemini/settings.json already exists - skipping." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Step 6: Store secrets in Windows Credential Manager for gemini-runner
# ---------------------------------------------------------------------------
Write-Step '6/8  Store secrets in Windows Credential Manager'

function Invoke-AsRunner([string]$RunnerCmd) {
    if ($RunnerPasswordSecure -and $RunnerPasswordSecure.Length -gt 0) {
        $cred = New-Object System.Management.Automation.PSCredential($RunnerAccount, $RunnerPasswordSecure)
        Start-Process -FilePath 'powershell.exe' `
                      -Credential $cred `
                      -ArgumentList '-NoProfile', '-Command', $RunnerCmd `
                      -Wait -NoNewWindow
        return $true
    } else {
        Write-Warning "Runner credentials unavailable in this session; skipping command as '$RunnerAccount'."
        return $false
    }
}

# Collect secrets interactively if not passed as parameters
# Gemini key is optional; GitHub PAT is required for github MCP.
if (-not $PSBoundParameters.ContainsKey('GeminiApiKey')) {
    $GeminiApiKey = Read-Host 'Enter paid Gemini API key (optional; press Enter to skip)'
}

# cmdkey stores generic credentials in the current user's (admin) Credential Manager.
# The gemini-runner account needs these in its own Credential Manager store.
# We use runas to store them in gemini-runner's store via a one-liner.
if (-not [string]::IsNullOrWhiteSpace($GeminiApiKey)) {
    Write-Host "  Storing GEMINI_API_KEY in gemini-runner's Credential Manager..."
    $storeGemini = "cmdkey /generic:GEMINI_API_KEY /user:gemini-runner /pass:$GeminiApiKey"
    [void](Invoke-AsRunner $storeGemini)
} else {
    Write-Host "  No Gemini API key provided. Skipping GEMINI_API_KEY credential." -ForegroundColor Yellow
}

if (-not [string]::IsNullOrWhiteSpace($GitHubPat)) {
    Write-Host "  Storing GITHUB_PERSONAL_ACCESS_TOKEN in gemini-runner's Credential Manager..."
    $storeGithub = "cmdkey /generic:GITHUB_PERSONAL_ACCESS_TOKEN /user:gemini-runner /pass:$GitHubPat"
    [void](Invoke-AsRunner $storeGithub)
} else {
    Write-Host "  No GitHub PAT provided. Skipping GITHUB_PERSONAL_ACCESS_TOKEN credential." -ForegroundColor Yellow
}

Write-Host '  Secrets stored.' -ForegroundColor Green

# Scrub secret variables from memory
$GeminiApiKey = $null
$GitHubPat = $null

# ---------------------------------------------------------------------------
# Step 7: Verify outbound connectivity
# ---------------------------------------------------------------------------
Write-Step '7/8  Verify outbound connectivity'

$endpoints = @(
    @{ Label = 'eposforge-graph (loopback)'; Host = '127.0.0.1';          Port = 7777 },
    @{ Label = 'GitHub API';                 Host = 'api.github.com';      Port = 443  },
    @{ Label = 'Microsoft Docs MCP';         Host = 'learn.microsoft.com'; Port = 443  },
    @{ Label = 'Gemini API';                 Host = 'generativelanguage.googleapis.com'; Port = 443 }
)

$allOk = $true
foreach ($ep in $endpoints) {
    $result = Test-NetConnection -ComputerName $ep.Host -Port $ep.Port -WarningAction SilentlyContinue
    if ($result.TcpTestSucceeded) {
        Write-Host ("  [OK] {0} ({1}:{2})" -f $ep.Label, $ep.Host, $ep.Port) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL] {0} ({1}:{2})" -f $ep.Label, $ep.Host, $ep.Port) -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host "`n  One or more connectivity checks failed. Ensure the Neo4j MCP server" -ForegroundColor Yellow
    Write-Host "  is running (bolt://localhost:7688) and internet access is available." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Step 8: Print daily launch command
# ---------------------------------------------------------------------------
Write-Step '8/8  Setup complete'

Write-Host @"

Daily launch (from a non-admin shell):

    runas /user:$RunnerAccount /savecred "gemini chat --workspace $WorkspaceRoot"

The /savecred flag caches the account password after first use.
Note: /savecred may be restricted by enterprise group policy on some machines.

Sandbox Living Spec:
    $WorkspaceRoot\01-architecture\02-components\07-execution-sandbox\installed\windows-acl-user.md

"@ -ForegroundColor Cyan

try {
    if ($TranscriptStarted) {
        Stop-Transcript | Out-Null
    }
} catch {
    # Ignore if transcript was never started.
}
