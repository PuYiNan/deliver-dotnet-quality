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
$python = if ($settings.pythonExecutable) { [string]$settings.pythonExecutable } else { 'python' }
$testPath = if ($settings.testPath) { [string]$settings.testPath } else { 'tests' }
$testRoot = Join-Path $workingRoot $testPath
$relativeTestRoot = [IO.Path]::GetRelativePath($repoRoot, [IO.Path]::GetFullPath($testRoot)).Replace('\', '/')
if ($relativeTestRoot -eq '..' -or $relativeTestRoot.StartsWith('../')) { throw "Python testPath is outside the repository: $testPath" }
$installMode = if ($settings.installMode) { [string]$settings.installMode } else { 'auto' }
if ($installMode -notin @('auto', 'none', 'requirements', 'editable')) { throw "Unknown Python installMode '$installMode'." }

$steps = [System.Collections.Generic.List[object]]::new()
$requirements = Join-Path $workingRoot 'requirements.txt'
if ($installMode -eq 'requirements' -or ($installMode -eq 'auto' -and (Test-Path -LiteralPath $requirements))) {
    if (-not (Test-Path -LiteralPath $requirements)) { throw "Python requirements file not found: $requirements" }
    $steps.Add([pscustomobject]@{ name = 'install'; filePath = $python; arguments = @('-m', 'pip', 'install', '-r', $requirements); workingDirectory = $WorkingDirectory })
}
elseif ($installMode -eq 'editable') {
    $steps.Add([pscustomobject]@{ name = 'install'; filePath = $python; arguments = @('-m', 'pip', 'install', '-e', '.'); workingDirectory = $WorkingDirectory })
}

if ($null -ne $settings.requireRuff -and [bool]$settings.requireRuff) {
    $steps.Add([pscustomobject]@{ name = 'ruff-check'; filePath = $python; arguments = @('-m', 'ruff', 'check', '.'); workingDirectory = $WorkingDirectory })
    $steps.Add([pscustomobject]@{ name = 'ruff-format-check'; filePath = $python; arguments = @('-m', 'ruff', 'format', '--check', '.'); workingDirectory = $WorkingDirectory })
}
if ($null -ne $settings.requireMypy -and [bool]$settings.requireMypy) {
    $steps.Add([pscustomobject]@{ name = 'type-check'; filePath = $python; arguments = @('-m', 'mypy', '.'); workingDirectory = $WorkingDirectory })
}
if ($null -eq $settings.compile -or [bool]$settings.compile) {
    $steps.Add([pscustomobject]@{ name = 'compile'; filePath = $python; arguments = @('-m', 'compileall', '-q', '.'); workingDirectory = $WorkingDirectory })
}

$testRunner = if ($settings.testRunner) { [string]$settings.testRunner } else { 'unittest' }
if (-not (Test-Path -LiteralPath $testRoot)) { throw "Python test directory not found: $testRoot" }
if ($testRunner -eq 'pytest') {
    $steps.Add([pscustomobject]@{ name = 'tests'; filePath = $python; arguments = @('-m', 'pytest', $testPath); workingDirectory = $WorkingDirectory })
}
elseif ($testRunner -eq 'unittest') {
    $steps.Add([pscustomobject]@{ name = 'tests'; filePath = $python; arguments = @('-m', 'unittest', 'discover', '-s', $testPath, '-v'); workingDirectory = $WorkingDirectory })
}
else {
    throw "Python adapter supports unittest or pytest; received '$testRunner'."
}

$targetName = if ($Target) { $Target } elseif (Test-Path -LiteralPath (Join-Path $workingRoot 'pyproject.toml')) { 'pyproject.toml' } else { $WorkingDirectory }
[ordered]@{ schemaVersion = 1; id = $AdapterId; type = 'python'; target = $targetName; steps = $steps } | ConvertTo-Json -Depth 20
