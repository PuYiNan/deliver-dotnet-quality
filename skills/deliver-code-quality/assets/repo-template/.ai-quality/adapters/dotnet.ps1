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

if ($Target) {
    $resolvedTarget = if ([IO.Path]::IsPathRooted($Target)) { $Target } else { Join-Path $workingRoot $Target }
    $resolvedTarget = (Resolve-Path -LiteralPath $resolvedTarget).Path
}
else {
    $candidates = @(Get-ChildItem -LiteralPath $workingRoot -Recurse -File | Where-Object {
        ($_.Extension -in @('.sln', '.slnx')) -and $_.FullName -notlike "*$([IO.Path]::DirectorySeparatorChar).ai-quality$([IO.Path]::DirectorySeparatorChar)*"
    })
    if ($candidates.Count -eq 0) {
        $candidates = @(Get-ChildItem -LiteralPath $workingRoot -Recurse -Filter '*.csproj' -File | Where-Object {
            $_.FullName -notlike "*$([IO.Path]::DirectorySeparatorChar).ai-quality$([IO.Path]::DirectorySeparatorChar)*"
        })
    }
    if ($candidates.Count -ne 1) { throw "Expected exactly one .NET solution/project or an explicit target; found $($candidates.Count) under $WorkingDirectory." }
    $resolvedTarget = $candidates[0].FullName
}

$relativeTarget = [IO.Path]::GetRelativePath($repoRoot, $resolvedTarget).Replace('\', '/')
if ($relativeTarget -eq '..' -or $relativeTarget.StartsWith('../')) { throw "The .NET target is outside the repository: $resolvedTarget" }
$testResults = Join-Path $EvidenceDirectory "test-results\$AdapterId"
$steps = [System.Collections.Generic.List[object]]::new()
$steps.Add([pscustomobject]@{ name = 'restore'; filePath = 'dotnet'; arguments = @('restore', $resolvedTarget); workingDirectory = $WorkingDirectory })
if ($null -eq $settings.requireFormatCheck -or [bool]$settings.requireFormatCheck) {
    $steps.Add([pscustomobject]@{ name = 'format-check'; filePath = 'dotnet'; arguments = @('format', $resolvedTarget, '--verify-no-changes', '--no-restore'); workingDirectory = $WorkingDirectory })
}
$steps.Add([pscustomobject]@{ name = 'release-build'; filePath = 'dotnet'; arguments = @('build', $resolvedTarget, '--configuration', 'Release', '--no-restore', '-warnaserror'); workingDirectory = $WorkingDirectory })
$steps.Add([pscustomobject]@{ name = 'tests'; filePath = 'dotnet'; arguments = @('test', $resolvedTarget, '--configuration', 'Release', '--no-build', '--logger', 'trx', '--results-directory', $testResults); workingDirectory = $WorkingDirectory })

[ordered]@{ schemaVersion = 1; id = $AdapterId; type = 'dotnet'; target = $relativeTarget; steps = $steps } | ConvertTo-Json -Depth 20
