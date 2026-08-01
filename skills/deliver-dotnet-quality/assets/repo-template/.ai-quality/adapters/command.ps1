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
$settings = $SettingsJson | ConvertFrom-Json
$steps = [System.Collections.Generic.List[object]]::new()
foreach ($configuredStep in @($settings.steps)) {
    $modes = if ($null -ne $configuredStep.modes) { @($configuredStep.modes | ForEach-Object { [string]$_ }) } else { @('Quick', 'Full') }
    if ($Mode -notin $modes) { continue }
    if (-not $configuredStep.name -or -not $configuredStep.filePath) { throw "Command adapter '$AdapterId' has a step without name or filePath." }
    $stepWorkingDirectory = if ($configuredStep.workingDirectory) { [string]$configuredStep.workingDirectory } else { $WorkingDirectory }
    $absoluteWorkingDirectory = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $stepWorkingDirectory))
    $relativeWorkingDirectory = [IO.Path]::GetRelativePath($RepositoryRoot, $absoluteWorkingDirectory).Replace('\', '/')
    if ($relativeWorkingDirectory -eq '..' -or $relativeWorkingDirectory.StartsWith('../')) { throw "Command step '$($configuredStep.name)' workingDirectory is outside the repository." }
    $steps.Add([pscustomobject]@{
        name = [string]$configuredStep.name
        filePath = [string]$configuredStep.filePath
        arguments = @($configuredStep.arguments | ForEach-Object { [string]$_ })
        workingDirectory = $relativeWorkingDirectory
    })
}
if ($steps.Count -eq 0) { throw "Command adapter '$AdapterId' has no steps for mode $Mode." }
[ordered]@{ schemaVersion = 1; id = $AdapterId; type = 'command'; target = $Target; steps = $steps } | ConvertTo-Json -Depth 20
