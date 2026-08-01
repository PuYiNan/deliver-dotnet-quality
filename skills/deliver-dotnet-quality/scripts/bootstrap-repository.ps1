[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $RepositoryPath,
    [string[]] $Adapters,
    [switch] $Force,
    [switch] $Preflight
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\assets\repo-template')).Path
$target = (Resolve-Path -LiteralPath $RepositoryPath).Path

$Adapters = @($Adapters | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
$unsupportedAdapters = @($Adapters | Where-Object { $_ -notin @('dotnet', 'node', 'python', 'command') })
if ($unsupportedAdapters.Count -gt 0) { throw "Unsupported adapter(s): $($unsupportedAdapters -join ', ')." }

$recognizedNames = @('package.json', 'pyproject.toml', 'requirements.txt', 'setup.py')
$recognizedFiles = @(
    Get-ChildItem -LiteralPath $target -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch '[\\/](\.git|node_modules|\.ai-quality|bin|obj|\.venv|venv)[\\/]' -and
        ($_.Extension -in @('.sln', '.slnx', '.csproj') -or $_.Name -in $recognizedNames)
    }
)
if (-not (Test-Path -LiteralPath (Join-Path $target '.git')) -and $recognizedFiles.Count -eq 0) {
    throw "Target does not look like a source repository: $target"
}

function New-Adapter([string] $Id, [string] $Type, [string] $WorkingDirectory, [string] $TargetPath, [object] $Settings) {
    [pscustomobject]@{
        id = $Id
        type = $Type
        workingDirectory = $WorkingDirectory.Replace('\', '/')
        target = $TargetPath.Replace('\', '/')
        required = $true
        settings = $Settings
    }
}

$detected = [System.Collections.Generic.List[object]]::new()
if ($Adapters) {
    $seenTypes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($type in $Adapters) {
        if (-not $seenTypes.Add($type)) { throw "Duplicate adapter type '$type'." }
        $settings = switch ($type) {
            'dotnet' { [pscustomobject]@{ requireFormatCheck = $true } }
            'node' { [pscustomobject]@{ requiredScripts = @('test') } }
            'python' { [pscustomobject]@{ installMode = 'auto'; testRunner = 'unittest'; compile = $true } }
            'command' { [pscustomobject]@{ steps = @() } }
        }
        $detected.Add((New-Adapter $type $type '.' '' $settings))
    }
}
else {
    $dotnetCandidates = @($recognizedFiles | Where-Object { $_.Extension -in @('.sln', '.slnx') })
    if ($dotnetCandidates.Count -eq 0) { $dotnetCandidates = @($recognizedFiles | Where-Object Extension -eq '.csproj') }
    if ($dotnetCandidates.Count -gt 0) {
        $targetPath = if ($dotnetCandidates.Count -eq 1) { [IO.Path]::GetRelativePath($target, $dotnetCandidates[0].FullName) } else { '' }
        $detected.Add((New-Adapter 'dotnet' 'dotnet' '.' $targetPath ([pscustomobject]@{ requireFormatCheck = $true })))
    }

    $nodePackages = @($recognizedFiles | Where-Object Name -eq 'package.json' | Sort-Object FullName)
    for ($index = 0; $index -lt $nodePackages.Count; $index++) {
        $id = if ($index -eq 0) { 'node' } else { "node-$($index + 1)" }
        $directory = [IO.Path]::GetRelativePath($target, $nodePackages[$index].DirectoryName)
        $detected.Add((New-Adapter $id 'node' $directory '' ([pscustomobject]@{ requiredScripts = @('test') })))
    }

    $pythonRoots = @($recognizedFiles | Where-Object { $_.Name -in @('pyproject.toml', 'requirements.txt', 'setup.py') } | ForEach-Object DirectoryName | Sort-Object -Unique)
    for ($index = 0; $index -lt $pythonRoots.Count; $index++) {
        $id = if ($index -eq 0) { 'python' } else { "python-$($index + 1)" }
        $directory = [IO.Path]::GetRelativePath($target, $pythonRoots[$index])
        $detected.Add((New-Adapter $id 'python' $directory '' ([pscustomobject]@{ installMode = 'auto'; testRunner = 'unittest'; compile = $true })))
    }
}
if ($detected.Count -eq 0) {
    throw 'No built-in adapter was detected. Re-run with -Adapters command, then define reviewed command steps in .ai-quality/config.json.'
}

$collisions = [System.Collections.Generic.List[string]]::new()
Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($source, $_.FullName)
    if ((Test-Path -LiteralPath (Join-Path $target $relative)) -and -not $Force) { $collisions.Add($relative) }
}
if ($collisions.Count -gt 0) { throw "Refusing to overwrite existing files. Re-run with -Force only after review:`n$($collisions -join "`n")" }
if ($Preflight) {
    Write-Host "Bootstrap preflight passed for $target"
    Write-Host "Configured adapters would be: $(@($detected | ForEach-Object id) -join ', ')"
    return
}
if (-not $PSCmdlet.ShouldProcess($target, 'Install AI quality workflow')) { return }

Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($source, $_.FullName)
    $destination = Join-Path $target $relative
    $destinationDirectory = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDirectory)) { New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null }
    Copy-Item -LiteralPath $_.FullName -Destination $destination -Force:$Force
}

$configPath = Join-Path $target '.ai-quality\config.json'
$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
$config.gate.adapters = $detected
$config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding utf8

Write-Host "Installed AI quality workflow into $target"
Write-Host "Configured adapters: $(@($detected | ForEach-Object id) -join ', ')"
if (@($detected | Where-Object type -eq 'command').Count -gt 0) { Write-Warning 'The command adapter has no default steps. Configure reviewed steps before creating a work item.' }
Write-Host "Next: pwsh ./aq.ps1 new -Title 'Your task' [-UiScope]"
