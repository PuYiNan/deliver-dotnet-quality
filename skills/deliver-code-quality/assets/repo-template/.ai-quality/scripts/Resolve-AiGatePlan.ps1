[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RepositoryRoot,
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter(Mandatory)] [ValidateSet('Quick', 'Full')] [string] $Mode,
    [Parameter(Mandatory)] [string] $EvidenceDirectory,
    [string] $TargetOverride
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$configurationMode = 'declarative'

$hasDeclarativeAdapters = $config.gate -and $null -ne $config.gate.adapters -and @($config.gate.adapters).Count -gt 0
$hasLegacyDotnetConfig = $config.PSObject.Properties.Name -contains 'solution' -or $config.PSObject.Properties.Name -contains 'requireFormatCheck'
if ($hasDeclarativeAdapters) {
    $adapters = @($config.gate.adapters)
}
elseif ($hasLegacyDotnetConfig) {
    $configurationMode = 'legacy-dotnet'
    $legacySettings = [ordered]@{
        requireFormatCheck = if ($null -ne $config.requireFormatCheck) { [bool]$config.requireFormatCheck } else { $true }
    }
    $adapters = @([pscustomobject]@{
        id = 'dotnet'
        type = 'dotnet'
        workingDirectory = '.'
        target = if ($config.solution) { [string]$config.solution } else { '' }
        required = $true
        settings = [pscustomobject]$legacySettings
    })
}
else {
    throw 'No gate adapter is configured. Run bootstrap detection or define gate.adapters in .ai-quality/config.json.'
}

if ($TargetOverride) {
    if ($adapters.Count -ne 1 -or $adapters[0].type -ne 'dotnet') {
        throw '-Target is supported only for a single .NET adapter. Configure adapter targets in .ai-quality/config.json for multi-adapter gates.'
    }
    $adapters[0].target = $TargetOverride
}

$adapterRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'adapters'
$resolvedAdapters = [System.Collections.Generic.List[object]]::new()
$seenIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach ($adapter in $adapters) {
    $id = [string]$adapter.id
    $type = [string]$adapter.type
    if ($id -notmatch '^[a-z0-9][a-z0-9-]{1,31}$') { throw "Invalid gate adapter id '$id'." }
    if ($type -notmatch '^[a-z0-9][a-z0-9-]{1,31}$') { throw "Invalid gate adapter type '$type'." }
    if (-not $seenIds.Add($id)) { throw "Duplicate gate adapter id '$id'." }

    $required = if ($null -ne $adapter.required) { [bool]$adapter.required } else { $true }
    $workingDirectory = if ($adapter.workingDirectory) { [string]$adapter.workingDirectory } else { '.' }
    $absoluteWorkingDirectory = if ([IO.Path]::IsPathRooted($workingDirectory)) {
        [IO.Path]::GetFullPath($workingDirectory)
    } else {
        [IO.Path]::GetFullPath((Join-Path $repoRoot $workingDirectory))
    }
    $relativeWorkingDirectory = [IO.Path]::GetRelativePath($repoRoot, $absoluteWorkingDirectory).Replace('\', '/')
    if ($relativeWorkingDirectory -eq '..' -or $relativeWorkingDirectory.StartsWith('../')) {
        throw "Adapter '$id' workingDirectory is outside the repository: $workingDirectory"
    }

    $adapterScript = Join-Path $adapterRoot "$type.ps1"
    if (-not (Test-Path -LiteralPath $adapterScript)) {
        if ($required) { throw "Required gate adapter '$id' has no implementation: $adapterScript" }
        $resolvedAdapters.Add([pscustomobject]@{
            id = $id; type = $type; required = $false; status = 'Skipped'
            target = ''; workingDirectory = $relativeWorkingDirectory
            skipReason = "Adapter implementation not found: $type"; scriptSha256 = ''; steps = @()
        })
        continue
    }

    $settingsJson = if ($null -ne $adapter.settings) { $adapter.settings | ConvertTo-Json -Depth 20 -Compress } else { '{}' }
    try {
        $planJson = & $adapterScript `
            -AdapterId $id `
            -RepositoryRoot $repoRoot `
            -WorkingDirectory $relativeWorkingDirectory `
            -Target ([string]$adapter.target) `
            -Mode $Mode `
            -EvidenceDirectory $EvidenceDirectory `
            -SettingsJson $settingsJson
        if (-not $?) { throw "Adapter '$id' plan generation failed." }
        $plan = $planJson | ConvertFrom-Json
        $steps = @($plan.steps)
        if ($steps.Count -eq 0) { throw "Adapter '$id' produced no executable verification steps." }
        foreach ($step in $steps) {
            if (-not $step.name -or -not $step.filePath) { throw "Adapter '$id' produced an invalid step." }
            if ($step.name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$') { throw "Adapter '$id' produced invalid step name '$($step.name)'." }
        }
        $resolvedAdapters.Add([pscustomobject]@{
            id = $id
            type = $type
            required = $required
            status = 'Ready'
            target = [string]$plan.target
            workingDirectory = $relativeWorkingDirectory
            skipReason = ''
            scriptSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $adapterScript).Hash.ToLowerInvariant()
            steps = $steps
        })
    }
    catch {
        if ($required) { throw }
        $resolvedAdapters.Add([pscustomobject]@{
            id = $id; type = $type; required = $false; status = 'Skipped'
            target = ''; workingDirectory = $relativeWorkingDirectory
            skipReason = $_.Exception.Message; scriptSha256 = ''; steps = @()
        })
    }
}

if (@($resolvedAdapters | Where-Object required).Count -eq 0) {
    throw 'At least one required gate adapter must be configured.'
}

[ordered]@{
    schemaVersion = 1
    configurationMode = $configurationMode
    adapters = $resolvedAdapters
} | ConvertTo-Json -Depth 20
