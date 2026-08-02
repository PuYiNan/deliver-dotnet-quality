[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $RepositoryPath,
    [switch] $IncludeAgentInstructions,
    [string] $Rollback,
    [switch] $Preflight
)

$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\assets\repo-template')).Path
$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
$qualityRoot = Join-Path $repoRoot '.ai-quality'
if (-not (Test-Path -LiteralPath (Join-Path $qualityRoot 'config.json'))) { throw "No existing .ai-quality installation found in $repoRoot" }

function Assert-RepositoryPath([string] $Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    $relative = [IO.Path]::GetRelativePath($repoRoot, $absolute).Replace('\', '/')
    if ($relative -eq '..' -or $relative.StartsWith('../')) { throw "Path is outside repository: $Path" }
    return $absolute
}

if ($Rollback) {
    if ($Rollback -notmatch '^[0-9]{8}-[0-9]{6}$') { throw 'Rollback must be a backup ID in yyyyMMdd-HHmmss form.' }
    $backupRoot = Assert-RepositoryPath (Join-Path $qualityRoot "upgrade-backups\$Rollback")
    $manifestPath = Join-Path $backupRoot 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Unknown upgrade backup: $Rollback" }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ($Preflight) { Write-Host "Rollback preflight passed for $Rollback."; return }
    if (-not $PSCmdlet.ShouldProcess($repoRoot, "Rollback AI quality upgrade $Rollback")) { return }
    foreach ($entry in @($manifest.files)) {
        $destination = Assert-RepositoryPath (Join-Path $repoRoot ([string]$entry.relativePath))
        if ([bool]$entry.existed) {
            $backup = Assert-RepositoryPath (Join-Path $backupRoot ([string]$entry.relativePath))
            $parent = Split-Path -Parent $destination
            if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            Copy-Item -LiteralPath $backup -Destination $destination -Force
        }
        elseif (Test-Path -LiteralPath $destination) {
            Remove-Item -LiteralPath $destination -Force
        }
    }
    Write-Host "Rolled back AI quality upgrade $Rollback."
    return
}

$relativeFiles = [System.Collections.Generic.List[string]]::new()
$legacyAgentSkillFiles = [System.Collections.Generic.List[string]]::new()
$relativeFiles.Add('aq.ps1')
Get-ChildItem -LiteralPath (Join-Path $sourceRoot '.ai-quality\scripts') -File | ForEach-Object {
    $relativeFiles.Add([IO.Path]::GetRelativePath($sourceRoot, $_.FullName))
}
Get-ChildItem -LiteralPath (Join-Path $sourceRoot '.ai-quality\adapters') -File | ForEach-Object {
    $relativeFiles.Add([IO.Path]::GetRelativePath($sourceRoot, $_.FullName))
}
if ($IncludeAgentInstructions) {
    foreach ($relative in @('AGENTS.md', 'CLAUDE.md', '.ai-quality\agent-policy.md', '.agents\skills\deliver-code-quality\SKILL.md', '.claude\skills\deliver-code-quality\SKILL.md', '.cursor\rules\ai-quality.mdc', '.github\copilot-instructions.md')) {
        $relativeFiles.Add($relative)
    }
    foreach ($relative in @('.agents\skills\deliver-dotnet-quality\SKILL.md', '.claude\skills\deliver-dotnet-quality\SKILL.md')) {
        $legacyAgentSkillFiles.Add($relative)
    }
}

$backupId = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Assert-RepositoryPath (Join-Path $qualityRoot "upgrade-backups\$backupId")
$configPath = Join-Path $qualityRoot 'config.json'
$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
$configurationMode = if ($config.gate -and @($config.gate.adapters).Count -gt 0) { 'declarative' } else { 'legacy-dotnet' }
if ($Preflight) { Write-Host "Upgrade preflight passed for $repoRoot"; return }
if (-not $PSCmdlet.ShouldProcess($repoRoot, "Upgrade AI quality workflow; backup $backupId")) { return }
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$manifestEntries = [System.Collections.Generic.List[object]]::new()

foreach ($relative in $relativeFiles) {
    $source = Join-Path $sourceRoot $relative
    $destination = Assert-RepositoryPath (Join-Path $repoRoot $relative)
    $existed = Test-Path -LiteralPath $destination
    if ($existed) {
        $backup = Assert-RepositoryPath (Join-Path $backupRoot $relative)
        $backupParent = Split-Path -Parent $backup
        if (-not (Test-Path -LiteralPath $backupParent)) { New-Item -ItemType Directory -Path $backupParent -Force | Out-Null }
        Copy-Item -LiteralPath $destination -Destination $backup -Force
    }
    $destinationParent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationParent)) { New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null }
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $manifestEntries.Add([pscustomobject]@{ relativePath = $relative.Replace('\', '/'); existed = $existed })
}

foreach ($relative in $legacyAgentSkillFiles) {
    $destination = Assert-RepositoryPath (Join-Path $repoRoot $relative)
    if (-not (Test-Path -LiteralPath $destination)) { continue }
    $backup = Assert-RepositoryPath (Join-Path $backupRoot $relative)
    $backupParent = Split-Path -Parent $backup
    if (-not (Test-Path -LiteralPath $backupParent)) { New-Item -ItemType Directory -Path $backupParent -Force | Out-Null }
    Copy-Item -LiteralPath $destination -Destination $backup -Force
    Remove-Item -LiteralPath $destination -Force
    $manifestEntries.Add([pscustomobject]@{ relativePath = $relative.Replace('\', '/'); existed = $true })
}

[ordered]@{
    schemaVersion = 1
    backupId = $backupId
    createdAt = (Get-Date).ToUniversalTime().ToString('o')
    configurationMode = $configurationMode
    files = $manifestEntries
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $backupRoot 'manifest.json') -Encoding utf8

Write-Host "Upgraded AI quality workflow in $repoRoot"
Write-Host "Configuration mode: $configurationMode"
Write-Host "Rollback: pwsh '$PSCommandPath' -RepositoryPath '$repoRoot' -Rollback '$backupId'"
