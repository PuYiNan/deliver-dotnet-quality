[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$skillRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\skills\deliver-code-quality')).Path
$bootstrap = Join-Path $skillRoot 'scripts\bootstrap-repository.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "deliver-code-quality-$([guid]::NewGuid().ToString('N'))"

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Native([string] $FilePath, [string[]] $Arguments, [string] $WorkingDirectory) {
    Push-Location $WorkingDirectory
    try {
        & $FilePath @Arguments
        if ($LASTEXITCODE -ne 0) { throw "$FilePath $($Arguments -join ' ') failed with exit code $LASTEXITCODE." }
    }
    finally { Pop-Location }
}

function Invoke-NativeExpectFailure([string] $FilePath, [string[]] $Arguments, [string] $WorkingDirectory) {
    Push-Location $WorkingDirectory
    try {
        & $FilePath @Arguments
        if ($LASTEXITCODE -eq 0) { throw "$FilePath $($Arguments -join ' ') unexpectedly succeeded." }
    }
    finally { Pop-Location }
}

function Set-TrustedConfig([string] $Repository, [scriptblock] $ConfigureGate) {
    $configPath = Join-Path $Repository '.ai-quality\config.json'
    $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
    $config.approvalMode = 'trusted'
    $config.trustAuthorizedBy = 'Regression User'
    $config.trustAuthorizedAt = '2026-08-01T00:00:00.0000000Z'
    & $ConfigureGate $config
    $config | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $configPath -Encoding utf8
}

function Initialize-AuthorizedWorkItem([string] $Repository, [string] $Id) {
    $aq = Join-Path $Repository 'aq.ps1'
    Invoke-Native 'pwsh' @('-NoProfile', '-File', $aq, 'new', '-Title', 'Adapter regression', '-Id', $Id) $Repository
    $item = Join-Path $Repository ".ai-quality\work-items\$Id"
    @'
# Adapter regression
- Work item: `adapter-regression`
- Status: `READY`
## Objective
Execute real language adapters.
## Acceptance criteria
- AC-001: Every configured required adapter produces passing executable evidence.
## Approval readiness checklist
- [x] Every behavior-changing ambiguity is resolved.
- [x] Each criterion is observable and testable.
- [x] Scope and non-goals are explicit.
- [x] UI expectations are not applicable.
'@ | Set-Content -LiteralPath (Join-Path $item 'spec.md') -Encoding utf8
    Invoke-Native 'pwsh' @('-NoProfile', '-File', $aq, 'approve', '-Stage', 'Requirements', '-WorkItemId', $Id) $Repository
    @'
# Plan
| Slice | Acceptance criteria | Verification |
|---|---|---|
| S-01 | AC-001 | Run the configured Full gate. |
'@ | Set-Content -LiteralPath (Join-Path $item 'plan.md') -Encoding utf8
    Invoke-Native 'pwsh' @('-NoProfile', '-File', $aq, 'approve', '-Stage', 'Plan', '-WorkItemId', $Id) $Repository
    @'
# Test contract
| Test ID | Acceptance criterion | Expected result |
|---|---|---|
| T-001 | AC-001 | Required adapters and steps pass with common evidence. |
'@ | Set-Content -LiteralPath (Join-Path $item 'test-matrix.md') -Encoding utf8
    Invoke-Native 'pwsh' @('-NoProfile', '-File', $aq, 'approve', '-Stage', 'Tests', '-WorkItemId', $Id) $Repository
}

function Read-GateEvidence([string] $Repository, [string] $Id) {
    Get-Content -Raw -LiteralPath (Join-Path $Repository ".ai-quality\work-items\$Id\evidence\latest-quality-gate.json") | ConvertFrom-Json
}

function Set-CompleteDelivery([string] $Repository, [string] $Id) {
    $item = Join-Path $Repository ".ai-quality\work-items\$Id"
    @"
# Delivery report
- Overall status: ``COMPLETE``
- Work item: ``$Id``
- Full gate evidence: ``.ai-quality/work-items/$Id/evidence/latest-quality-gate.json``

## Acceptance results
| Criterion | Result | Evidence | Notes |
|---|---|---|---|
| AC-001 | PASS | latest-quality-gate.json | Every required adapter passed. |

## Changes delivered
Adapter regression fixture.

## Verification executed
Full multi-adapter gate passed.

## UI evidence
Not applicable — no UI scope.

## Residual risks and skipped checks
None known.
"@ | Set-Content -LiteralPath (Join-Path $item 'delivery.md') -Encoding utf8
}

New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
try {
    $unknownRepo = Join-Path $testRoot 'unknown-stack'
    New-Item -ItemType Directory -Path $unknownRepo -Force | Out-Null
    Invoke-Native 'git' @('init', '--quiet') $unknownRepo
    try {
        & $bootstrap -RepositoryPath $unknownRepo
        throw 'Bootstrap unexpectedly accepted an unknown stack without an adapter choice.'
    }
    catch {
        Assert-True ($_.Exception.Message -match 'No built-in adapter was detected') 'Unknown stack reports the adapter requirement.'
    }
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $unknownRepo 'aq.ps1'))) 'Failed detection leaves the repository unchanged.'
    & $bootstrap -RepositoryPath $unknownRepo -Adapters command
    $unknownConfig = Get-Content -Raw -LiteralPath (Join-Path $unknownRepo '.ai-quality\config.json') | ConvertFrom-Json
    Assert-True ($unknownConfig.gate.adapters[0].type -eq 'command') 'Unknown stacks can bootstrap an explicit command adapter.'
    Set-TrustedConfig $unknownRepo {
        param($config)
        $config.gate.adapters[0].settings.steps = @([pscustomobject]@{
            name = 'missing-tool'
            filePath = 'definitely-missing-ai-quality-command'
            arguments = @()
            modes = @('Full')
        })
    }
    $unknownId = 'missing-command-gate'
    Initialize-AuthorizedWorkItem $unknownRepo $unknownId
    Invoke-NativeExpectFailure 'pwsh' @('-NoProfile', '-File', (Join-Path $unknownRepo 'aq.ps1'), 'verify', '-WorkItemId', $unknownId, '-Mode', 'Full') $unknownRepo
    $unknownEvidence = Read-GateEvidence $unknownRepo $unknownId
    Assert-True ($unknownEvidence.overall -eq 'Failed') 'Missing command fails the Full gate.'
    Assert-True ($unknownEvidence.steps[0].status -eq 'Failed') 'Thrown command execution is preserved as failed step evidence.'

    $dotnetRepo = Join-Path $testRoot 'dotnet-legacy'
    New-Item -ItemType Directory -Path $dotnetRepo -Force | Out-Null
    Invoke-Native 'git' @('init', '--quiet') $dotnetRepo
    Invoke-Native 'dotnet' @('new', 'xunit', '--no-restore', '--output', 'tests') $dotnetRepo
    & $bootstrap -RepositoryPath $dotnetRepo
    Set-TrustedConfig $dotnetRepo {
        param($config)
        $config.PSObject.Properties.Remove('gate')
        $config | Add-Member -NotePropertyName solution -NotePropertyValue 'tests\tests.csproj'
        $config | Add-Member -NotePropertyName requireFormatCheck -NotePropertyValue $true
    }
    $dotnetId = 'dotnet-legacy-gate'
    Initialize-AuthorizedWorkItem $dotnetRepo $dotnetId
    Invoke-Native 'pwsh' @('-NoProfile', '-File', (Join-Path $dotnetRepo 'aq.ps1'), 'verify', '-WorkItemId', $dotnetId, '-Mode', 'Full') $dotnetRepo
    $dotnetEvidence = Read-GateEvidence $dotnetRepo $dotnetId
    Assert-True ($dotnetEvidence.overall -eq 'Passed') 'Legacy .NET gate passes.'
    Assert-True ($dotnetEvidence.configurationMode -eq 'legacy-dotnet') 'v1.x config uses implicit .NET compatibility mode.'
    Assert-True (@($dotnetEvidence.adapters).Count -eq 1 -and $dotnetEvidence.adapters[0].type -eq 'dotnet') 'Legacy evidence identifies the .NET adapter.'
    Assert-True (@($dotnetEvidence.steps | Where-Object name -eq 'tests').Count -eq 1) 'Legacy .NET tests execute.'

    $polyglotRepo = Join-Path $testRoot 'polyglot'
    $nodeRoot = Join-Path $polyglotRepo 'apps\node'
    $pythonRoot = Join-Path $polyglotRepo 'apps\python'
    New-Item -ItemType Directory -Path (Join-Path $nodeRoot 'test') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $pythonRoot 'tests') -Force | Out-Null
    Invoke-Native 'git' @('init', '--quiet') $polyglotRepo
    @'
{
  "name": "adapter-node-sample",
  "private": true,
  "type": "module",
  "scripts": {
    "lint": "node --check index.mjs",
    "build": "node --check index.mjs",
    "test": "node --test"
  }
}
'@ | Set-Content -LiteralPath (Join-Path $nodeRoot 'package.json') -Encoding utf8
    'export const add = (a, b) => a + b;' | Set-Content -LiteralPath (Join-Path $nodeRoot 'index.mjs') -Encoding utf8
    @'
import test from "node:test";
import assert from "node:assert/strict";
import { add } from "../index.mjs";
test("adds", () => assert.equal(add(2, 3), 5));
'@ | Set-Content -LiteralPath (Join-Path $nodeRoot 'test\add.test.mjs') -Encoding utf8
    @'
[project]
name = "adapter-python-sample"
version = "0.1.0"
requires-python = ">=3.10"
'@ | Set-Content -LiteralPath (Join-Path $pythonRoot 'pyproject.toml') -Encoding utf8
    @'
def add(a: int, b: int) -> int:
    return a + b
'@ | Set-Content -LiteralPath (Join-Path $pythonRoot 'calc.py') -Encoding utf8
    @'
import unittest
from calc import add

class AddTests(unittest.TestCase):
    def test_add(self):
        self.assertEqual(add(2, 3), 5)

if __name__ == "__main__":
    unittest.main()
'@ | Set-Content -LiteralPath (Join-Path $pythonRoot 'tests\test_calc.py') -Encoding utf8

    & $bootstrap -RepositoryPath $polyglotRepo
    Set-TrustedConfig $polyglotRepo {
        param($config)
        foreach ($adapter in @($config.gate.adapters)) {
            if ($adapter.type -eq 'node') { $adapter.settings | Add-Member -NotePropertyName skipInstall -NotePropertyValue $true -Force }
            if ($adapter.type -eq 'python') { $adapter.settings.installMode = 'none' }
        }
        $config.gate.adapters = @($config.gate.adapters) + [pscustomobject]@{
            id = 'repo-check'
            type = 'command'
            workingDirectory = '.'
            target = 'repository'
            required = $true
            settings = [pscustomobject]@{
                steps = @([pscustomobject]@{ name = 'diff-check'; filePath = 'git'; arguments = @('diff', '--check'); modes = @('Full') })
            }
        }
    }
    $polyglotId = 'polyglot-full-gate'
    Initialize-AuthorizedWorkItem $polyglotRepo $polyglotId
    Invoke-Native 'pwsh' @('-NoProfile', '-File', (Join-Path $polyglotRepo 'aq.ps1'), 'verify', '-WorkItemId', $polyglotId, '-Mode', 'Full') $polyglotRepo
    $polyglotEvidence = Read-GateEvidence $polyglotRepo $polyglotId
    Assert-True ($polyglotEvidence.overall -eq 'Passed') 'Polyglot Full gate passes.'
    Assert-True ($polyglotEvidence.configurationMode -eq 'declarative') 'New config uses declarative adapters.'
    Assert-True (@($polyglotEvidence.adapters | Where-Object status -eq 'Passed').Count -eq 3) 'All required adapters pass.'
    Assert-True (@($polyglotEvidence.adapters | Where-Object type -eq 'node').Count -eq 1) 'Node adapter is represented.'
    Assert-True (@($polyglotEvidence.adapters | Where-Object type -eq 'python').Count -eq 1) 'Python adapter is represented.'
    Assert-True (@($polyglotEvidence.adapters | Where-Object type -eq 'command').Count -eq 1) 'Generic command adapter is represented.'
    Assert-True (@($polyglotEvidence.steps | Where-Object adapterId -eq 'node').Count -ge 3) 'Node lint/build/test steps execute.'
    Assert-True (@($polyglotEvidence.steps | Where-Object adapterId -eq 'python').Count -ge 2) 'Python compile/test steps execute.'

    Set-CompleteDelivery $polyglotRepo $polyglotId
    $polyglotAq = Join-Path $polyglotRepo 'aq.ps1'
    Invoke-Native 'pwsh' @('-NoProfile', '-File', $polyglotAq, 'check-delivery', '-WorkItemId', $polyglotId) $polyglotRepo
    $polyglotConfigPath = Join-Path $polyglotRepo '.ai-quality\config.json'
    $polyglotConfig = Get-Content -Raw -LiteralPath $polyglotConfigPath | ConvertFrom-Json
    $polyglotConfig.trustAuthorizedAt = '2026-08-01T01:00:00.0000000Z'
    $polyglotConfig | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $polyglotConfigPath -Encoding utf8
    Invoke-Native 'pwsh' @('-NoProfile', '-File', $polyglotAq, 'check-delivery', '-WorkItemId', $polyglotId) $polyglotRepo

    $pythonAdapterPath = Join-Path $polyglotRepo '.ai-quality\adapters\python.ps1'
    $pythonAdapterOriginal = Get-Content -Raw -LiteralPath $pythonAdapterPath
    Add-Content -LiteralPath $pythonAdapterPath -Value '# tamper regression'
    Invoke-NativeExpectFailure 'pwsh' @('-NoProfile', '-File', $polyglotAq, 'check-delivery', '-WorkItemId', $polyglotId) $polyglotRepo
    Set-Content -LiteralPath $pythonAdapterPath -Value $pythonAdapterOriginal -Encoding utf8 -NoNewline
    Invoke-Native 'pwsh' @('-NoProfile', '-File', $polyglotAq, 'check-delivery', '-WorkItemId', $polyglotId) $polyglotRepo
    Invoke-Native 'pwsh' @('-NoProfile', '-File', $polyglotAq, 'approve', '-Stage', 'Delivery', '-WorkItemId', $polyglotId) $polyglotRepo
    $acceptedState = Get-Content -Raw -LiteralPath (Join-Path $polyglotRepo ".ai-quality\work-items\$polyglotId\state.json") | ConvertFrom-Json
    Assert-True ($acceptedState.state -eq 'accepted') 'Polyglot Node/Python work item completes the full closed loop.'

    Write-Host 'All language adapter regression tests passed.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

exit 0
