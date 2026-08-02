param(
    [Parameter(Mandatory)] [string] $WorkItemId,
    [Parameter(Mandatory)] [string] $EvidenceDirectory
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$packageRoot = Join-Path $repoRoot 'tests\e2e'
$packageJson = Join-Path $packageRoot 'package.json'
if (-not (Test-Path -LiteralPath $packageJson)) { throw "Configure the Playwright package path in $PSCommandPath" }

$results = Join-Path $EvidenceDirectory 'playwright'
New-Item -ItemType Directory -Path $results -Force | Out-Null
$env:AI_QUALITY_EVIDENCE = $results

Push-Location $packageRoot
try {
    npm run test:e2e
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally { Pop-Location }

# Configure Playwright outputDir, tracing, and screenshots to use
# AI_QUALITY_EVIDENCE. Copy this file to .ai-quality/hooks/ui.ps1 after adapting it.
