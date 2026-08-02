[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path (Join-Path $PSScriptRoot '..\skills\deliver-code-quality\assets\repo-template')).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "deliver-code-quality-$([guid]::NewGuid().ToString('N'))"
$repo = Join-Path $testRoot 'repo'

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Aq([string[]] $Arguments, [int] $ExpectedExit = 0) {
    & pwsh -NoProfile -File (Join-Path $repo 'aq.ps1') @Arguments
    $actual = $LASTEXITCODE
    if ($actual -ne $ExpectedExit) {
        throw "aq.ps1 $($Arguments -join ' ') returned $actual; expected $ExpectedExit."
    }
}

function Invoke-AqWithInput([string[]] $Arguments, [string] $InputLine, [int] $ExpectedExit = 0) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'pwsh'
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @('-NoProfile', '-File', (Join-Path $repo 'aq.ps1')) + $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::Start($start)
    $process.StandardInput.WriteLine($InputLine)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne $ExpectedExit) {
        throw "Interactive aq.ps1 $($Arguments -join ' ') returned $($process.ExitCode); expected $ExpectedExit.`n$stdout`n$stderr"
    }
    return "$stdout`n$stderr"
}

function Set-Artifact([string] $Id, [string] $Name, [string] $Content) {
    Set-Content -LiteralPath (Join-Path $repo ".ai-quality\work-items\$Id\$Name") -Value $Content -Encoding utf8
}

New-Item -ItemType Directory -Path $repo -Force | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $repo -Recurse -Force

try {
    Get-ChildItem -LiteralPath $repo -Recurse -Filter '*.ps1' | ForEach-Object {
        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        Assert-True ($errors.Count -eq 0) "PowerShell parse errors in $($_.FullName): $errors"
    }
    Get-Content -Raw -LiteralPath (Join-Path $repo '.ai-quality\config.json') | ConvertFrom-Json | Out-Null

    $trustedId = 'trusted-regression'
    Invoke-Aq -Arguments @('new', '-Title', 'Trusted regression', '-Id', $trustedId)
    Invoke-Aq -Arguments @('approve', '-Stage', 'Requirements', '-WorkItemId', $trustedId) -ExpectedExit 1
    Invoke-AqWithInput -Arguments @('trust', '-Enable', '-AuthorizedBy', 'Regression User') -InputLine 'ENABLE TRUSTED MODE' | Out-Null
    $enabledConfig = Get-Content -Raw -LiteralPath (Join-Path $repo '.ai-quality\config.json') | ConvertFrom-Json
    Assert-True ([int]$enabledConfig.schemaVersion -eq 3) 'Trust mode does not downgrade the gate configuration schema.'

    Set-Artifact $trustedId 'spec.md' @'
# Trusted regression
- Work item: `trusted-regression`
- Status: `READY`
## Objective
Verify trusted mode.
## Acceptance criteria
- AC-001: Agent approval is audited.
## Approval readiness checklist
- [x] Every behavior-changing ambiguity is resolved.
- [x] Each criterion is observable and testable.
- [x] Scope and non-goals are explicit.
- [x] UI expectations are not applicable.
'@
    Invoke-Aq -Arguments @('approve', '-Stage', 'Requirements', '-WorkItemId', $trustedId)

    Set-Artifact $trustedId 'plan.md' @'
# Plan
| Slice | Acceptance criteria | Verification |
|---|---|---|
| S-01 | AC-001 | regression test |
'@
    Invoke-Aq -Arguments @('approve', '-Stage', 'Plan', '-WorkItemId', $trustedId)

    Set-Artifact $trustedId 'test-matrix.md' @'
# Test contract
| Test ID | Acceptance criterion | Expected result |
|---|---|---|
| T-001 | AC-001 | approvalAuthority is implementing-agent |
'@
    Invoke-Aq -Arguments @('approve', '-Stage', 'Tests', '-WorkItemId', $trustedId)

    $state = Get-Content -Raw -LiteralPath (Join-Path $repo ".ai-quality\work-items\$trustedId\state.json") | ConvertFrom-Json
    Assert-True ($state.state -eq 'implementation-authorized') 'Trusted approvals reach implementation-authorized.'
    $approval = Get-Content -Raw -LiteralPath (Join-Path $repo ".ai-quality\work-items\$trustedId\approvals\tests.json") | ConvertFrom-Json
    Assert-True ($approval.approvalMode -eq 'trusted') 'Trusted mode is recorded.'
    Assert-True ($approval.approvalAuthority -eq 'implementing-agent') 'Agent authority is recorded.'
    Assert-True ($approval.approvedBy -eq 'agent:trusted-mode') 'Agent does not impersonate the user.'
    Assert-True ($approval.trustAuthorizedBy -eq 'Regression User') 'Trust authorizer is recorded.'
    & (Join-Path $repo '.ai-quality\scripts\Assert-AiEditAllowed.ps1') -Path 'src\Product.cs' | Out-Null
    Assert-True $? 'Product edits are allowed after trusted stage approvals.'

    $state.state = 'verification-passed'
    $state.lastTransitionAt = (Get-Date).ToUniversalTime().ToString('o')
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $repo ".ai-quality\work-items\$trustedId\state.json") -Encoding utf8
    @{ mode = 'Full'; overall = 'Passed' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $repo ".ai-quality\work-items\$trustedId\evidence\latest-quality-gate.json") -Encoding utf8
    Set-Artifact $trustedId 'delivery.md' @'
# Delivery
- Overall status: `COMPLETE`
| Criterion | Result | Evidence |
|---|---|---|
| AC-001 | PASS | trusted regression |
## Verification executed
Full gate evidence recorded.
## Residual risks and skipped checks
Independent review not performed because trusted mode is enabled.
'@
    Invoke-Aq -Arguments @('approve', '-Stage', 'Delivery', '-WorkItemId', $trustedId)
    $acceptedState = Get-Content -Raw -LiteralPath (Join-Path $repo ".ai-quality\work-items\$trustedId\state.json") | ConvertFrom-Json
    Assert-True ($acceptedState.state -eq 'accepted') 'Trusted Delivery acceptance is allowed only after delivery validation.'
    $deliveryApproval = Get-Content -Raw -LiteralPath (Join-Path $repo ".ai-quality\work-items\$trustedId\approvals\delivery.json") | ConvertFrom-Json
    Assert-True ($deliveryApproval.approvalAuthority -eq 'implementing-agent') 'Trusted Delivery records Agent authority.'

    $incompleteId = 'trusted-incomplete'
    Invoke-Aq -Arguments @('new', '-Title', 'Incomplete trusted regression', '-Id', $incompleteId)
    Invoke-Aq -Arguments @('approve', '-Stage', 'Requirements', '-WorkItemId', $incompleteId) -ExpectedExit 1
    $incompleteState = Get-Content -Raw -LiteralPath (Join-Path $repo ".ai-quality\work-items\$incompleteId\state.json") | ConvertFrom-Json
    Assert-True ($incompleteState.state -eq 'discovery') 'Incomplete trusted artifact remains blocked.'

    Invoke-Aq -Arguments @('trust', '-Disable')
    $manualId = 'manual-regression'
    Invoke-Aq -Arguments @('new', '-Title', 'Manual regression', '-Id', $manualId)
    Set-Artifact $manualId 'spec.md' @'
# Manual regression
- Work item: `manual-regression`
- Status: `DRAFT`
## Acceptance criteria
- AC-001: Manual approval remains interactive.
'@
    Invoke-Aq -Arguments @('approve', '-Stage', 'Requirements', '-WorkItemId', $manualId) -ExpectedExit 1
    Invoke-AqWithInput -Arguments @('approve', '-Stage', 'Requirements', '-WorkItemId', $manualId, '-ApprovedBy', 'Human Reviewer') -InputLine "APPROVE $manualId REQUIREMENTS" | Out-Null
    $manualApproval = Get-Content -Raw -LiteralPath (Join-Path $repo ".ai-quality\work-items\$manualId\approvals\requirements.json") | ConvertFrom-Json
    Assert-True ($manualApproval.approvalMode -eq 'manual') 'Manual mode is recorded.'
    Assert-True ($manualApproval.approvalAuthority -eq 'external-reviewer') 'Manual approval remains external.'
    Assert-True ($manualApproval.approvedBy -eq 'Human Reviewer') 'Manual approver identity is preserved.'

    Write-Host 'All workflow regression tests passed.'
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($testRoot)
    $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTemp)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

exit 0
