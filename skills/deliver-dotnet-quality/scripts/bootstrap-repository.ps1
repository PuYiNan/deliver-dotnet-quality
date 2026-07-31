[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $RepositoryPath,
    [switch] $Force
)

$source = Join-Path $PSScriptRoot '..\assets\repo-template'
$source = (Resolve-Path -LiteralPath $source).Path
$target = (Resolve-Path -LiteralPath $RepositoryPath).Path

if (-not (Test-Path -LiteralPath (Join-Path $target '.git')) -and
    -not (Get-ChildItem -LiteralPath $target -Filter '*.sln*' -File -ErrorAction SilentlyContinue) -and
    -not (Get-ChildItem -LiteralPath $target -Filter '*.csproj' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    throw "Target does not look like a repository or .NET project: $target"
}

$collisions = [System.Collections.Generic.List[string]]::new()
Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($source, $_.FullName)
    $destination = Join-Path $target $relative
    if ((Test-Path -LiteralPath $destination) -and -not $Force) {
        $collisions.Add($relative)
    }
}

if ($collisions.Count -gt 0) {
    throw "Refusing to overwrite existing files. Re-run with -Force only after review:`n$($collisions -join "`n")"
}

Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($source, $_.FullName)
    $destination = Join-Path $target $relative
    $destinationDirectory = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }
    if ($PSCmdlet.ShouldProcess($destination, 'Install AI quality workflow file')) {
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force:$Force
    }
}

Write-Host "Installed AI quality workflow into $target"
Write-Host "Next: .\.ai-quality\scripts\New-AiWorkItem.ps1 -Title 'Your task' [-UiScope]"
