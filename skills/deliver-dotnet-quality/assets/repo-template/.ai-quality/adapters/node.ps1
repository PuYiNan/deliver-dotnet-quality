[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $AdapterId,
    [Parameter(Mandatory)] [string] $RepositoryRoot,
    [Parameter(Mandatory)] [string] $WorkingDirectory,
    [string] $Target,
    [Parameter(Mandatory)] [ValidateSet('Quick', 'Full')] [string] $Mode,
    [Parameter(Mandatory)] [string] $EvidenceDirectory,
    [Parameter(Mandatory)] [string] $SettingsJson
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$workingRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot $WorkingDirectory)).Path
$settings = $SettingsJson | ConvertFrom-Json
$packagePath = if ($Target) { Join-Path $workingRoot $Target } else { Join-Path $workingRoot 'package.json' }
$packagePath = (Resolve-Path -LiteralPath $packagePath).Path
$relativePackagePath = [IO.Path]::GetRelativePath($repoRoot, $packagePath).Replace('\', '/')
if ($relativePackagePath -eq '..' -or $relativePackagePath.StartsWith('../')) { throw "The Node target is outside the repository: $packagePath" }
$package = Get-Content -Raw -LiteralPath $packagePath | ConvertFrom-Json
$packageRoot = Split-Path -Parent $packagePath
$packageWorkingDirectory = [IO.Path]::GetRelativePath($repoRoot, $packageRoot).Replace('\', '/')

$manager = if ($settings.packageManager) { [string]$settings.packageManager } elseif (Test-Path -LiteralPath (Join-Path $packageRoot 'pnpm-lock.yaml')) { 'pnpm' } else { 'npm' }
if ($manager -notin @('npm', 'pnpm')) { throw "Node adapter supports npm or pnpm; received '$manager'." }

$steps = [System.Collections.Generic.List[object]]::new()
$skipInstall = $null -ne $settings.skipInstall -and [bool]$settings.skipInstall
if (-not $skipInstall) {
    $allowUnlockedInstall = $null -ne $settings.allowUnlockedInstall -and [bool]$settings.allowUnlockedInstall
    $installArguments = if ($manager -eq 'npm') {
        if (Test-Path -LiteralPath (Join-Path $packageRoot 'package-lock.json')) { @('ci') }
        elseif ($allowUnlockedInstall) { @('install') }
        else { throw "Node adapter '$AdapterId' requires package-lock.json for deterministic npm install. Set skipInstall only when dependencies are already provisioned." }
    } else {
        if (Test-Path -LiteralPath (Join-Path $packageRoot 'pnpm-lock.yaml')) { @('install', '--frozen-lockfile') }
        elseif ($allowUnlockedInstall) { @('install') }
        else { throw "Node adapter '$AdapterId' requires pnpm-lock.yaml for deterministic pnpm install. Set skipInstall only when dependencies are already provisioned." }
    }
    $steps.Add([pscustomobject]@{ name = 'install'; filePath = $manager; arguments = $installArguments; workingDirectory = $packageWorkingDirectory })
}

$availableScripts = @{}
if ($package.scripts) {
    foreach ($property in $package.scripts.PSObject.Properties) { $availableScripts[$property.Name] = [string]$property.Value }
}
$requiredScripts = if ($null -ne $settings.requiredScripts) { @($settings.requiredScripts | ForEach-Object { [string]$_ }) } else { @('test') }
foreach ($requiredScript in $requiredScripts) {
    if (-not $availableScripts.ContainsKey($requiredScript)) { throw "Node adapter '$AdapterId' requires missing package script '$requiredScript'." }
}
$selectedScripts = if ($null -ne $settings.scripts) {
    @($settings.scripts | ForEach-Object { [string]$_ })
} else {
    @('lint', 'typecheck', 'build', 'test') | Where-Object { $availableScripts.ContainsKey($_) }
}
foreach ($scriptName in $selectedScripts) {
    if (-not $availableScripts.ContainsKey($scriptName)) { throw "Configured Node package script '$scriptName' does not exist." }
    $steps.Add([pscustomobject]@{ name = $scriptName; filePath = $manager; arguments = @('run', $scriptName); workingDirectory = $packageWorkingDirectory })
}

[ordered]@{
    schemaVersion = 1
    id = $AdapterId
    type = 'node'
    target = $relativePackagePath
    steps = $steps
} | ConvertTo-Json -Depth 20
