[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$upgrade = (Resolve-Path (Join-Path $PSScriptRoot '..\skills\deliver-dotnet-quality\scripts\upgrade-repository.ps1')).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "deliver-upgrade-$([guid]::NewGuid().ToString('N'))"
$repo = Join-Path $testRoot 'repo'

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

New-Item -ItemType Directory -Path (Join-Path $repo '.ai-quality\scripts') -Force | Out-Null
try {
    @'
{
  "schemaVersion": 2,
  "approvalMode": "manual",
  "solution": "src/Legacy.sln",
  "requireFormatCheck": true,
  "requireUiHookWhenUiInScope": true,
  "fullHook": ".ai-quality/hooks/full.ps1",
  "uiHook": ".ai-quality/hooks/ui.ps1"
}
'@ | Set-Content -LiteralPath (Join-Path $repo '.ai-quality\config.json') -Encoding utf8
    '# legacy aq entry' | Set-Content -LiteralPath (Join-Path $repo 'aq.ps1') -Encoding utf8
    '# legacy gate' | Set-Content -LiteralPath (Join-Path $repo '.ai-quality\scripts\Invoke-AiQualityGate.ps1') -Encoding utf8
    $configHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo '.ai-quality\config.json')).Hash

    & $upgrade -RepositoryPath $repo
    Assert-True $? 'Upgrade completes.'
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo '.ai-quality\config.json')).Hash -eq $configHashBefore) 'Legacy config is preserved byte-for-byte.'
    Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $repo 'aq.ps1')) -notmatch 'legacy aq entry') 'Core entry point is upgraded.'
    Assert-True (Test-Path -LiteralPath (Join-Path $repo '.ai-quality\adapters\dotnet.ps1')) 'New .NET adapter is installed.'
    Assert-True (Test-Path -LiteralPath (Join-Path $repo '.ai-quality\scripts\Resolve-AiGatePlan.ps1')) 'Language-neutral resolver is installed.'

    $backup = Get-ChildItem -LiteralPath (Join-Path $repo '.ai-quality\upgrade-backups') -Directory | Select-Object -First 1
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $backup.FullName 'manifest.json') | ConvertFrom-Json
    Assert-True ($manifest.configurationMode -eq 'legacy-dotnet') 'Upgrade reports compatibility mode.'
    & $upgrade -RepositoryPath $repo -Rollback $backup.Name
    Assert-True $? 'Rollback completes.'
    Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $repo 'aq.ps1')) -match 'legacy aq entry') 'Rollback restores the old entry point.'
    Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $repo '.ai-quality\scripts\Invoke-AiQualityGate.ps1')) -match 'legacy gate') 'Rollback restores the old gate.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo '.ai-quality\adapters\dotnet.ps1'))) 'Rollback removes newly added adapter files.'
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo '.ai-quality\config.json')).Hash -eq $configHashBefore) 'Rollback leaves config unchanged.'

    Write-Host 'Repository upgrade and rollback regression passed.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

exit 0
