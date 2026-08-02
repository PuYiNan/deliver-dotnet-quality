[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9][a-z0-9-]{2,63}$')] [string] $WorkItemId,
    [ValidateSet('Quick', 'Full')] [string] $Mode = 'Full',
    [string] $Target
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$qualityRoot = Join-Path $repoRoot '.ai-quality'
$item = Join-Path $qualityRoot "work-items\$WorkItemId"
$statePath = Join-Path $item 'state.json'
$configPath = Join-Path $qualityRoot 'config.json'

if (-not (Test-Path -LiteralPath $statePath)) { throw "Unknown work item: $WorkItemId" }
$state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
if ($state.state -notin @('implementation-authorized', 'verification-failed')) {
    throw "Quality gate requires implementation-authorized or verification-failed; current state is $($state.state)."
}
$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
$gateConfigSha256 = (& (Join-Path $PSScriptRoot 'Get-AiGateConfigFingerprint.ps1') -ConfigPath $configPath).Trim()

function Assert-ApprovalHash([string] $Stage, [string] $Artifact) {
    $approvalPath = Join-Path $item "approvals\$Stage.json"
    if (-not (Test-Path -LiteralPath $approvalPath)) { throw "Missing $Stage approval." }
    $approval = Get-Content -Raw -LiteralPath $approvalPath | ConvertFrom-Json
    $artifactPath = Join-Path $item $Artifact
    $current = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash.ToLowerInvariant()
    if ($approval.artifactSha256 -ne $current) { throw "$Artifact changed after $Stage approval. Return to the appropriate approval stage." }
}

Assert-ApprovalHash 'requirements' 'spec.md'
Assert-ApprovalHash 'plan' 'plan.md'
Assert-ApprovalHash 'tests' 'test-matrix.md'

$evidenceRoot = Join-Path $item 'evidence'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$runDirectory = Join-Path $evidenceRoot "quality-gate-$runId"
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$planJson = & (Join-Path $PSScriptRoot 'Resolve-AiGatePlan.ps1') `
    -RepositoryRoot $repoRoot -ConfigPath $configPath -Mode $Mode -EvidenceDirectory $runDirectory -TargetOverride $Target
if (-not $?) { throw 'Gate plan resolution failed.' }
$plan = $planJson | ConvertFrom-Json

$startedAt = (Get-Date).ToUniversalTime()
$steps = [System.Collections.Generic.List[object]]::new()
$adapterResults = [System.Collections.Generic.List[object]]::new()
$overall = 'Passed'
$failure = $null
$activeAdapter = $null

function Invoke-GateStep([string] $AdapterId, [object] $Step) {
    $stepStart = (Get-Date).ToUniversalTime()
    $qualifiedName = "$AdapterId`:$($Step.name)"
    $safeName = $qualifiedName -replace '[^a-zA-Z0-9-]', '-'
    $logPath = Join-Path $runDirectory "$safeName.log"
    $workingDirectory = if ($Step.workingDirectory) { [string]$Step.workingDirectory } else { '.' }
    $absoluteWorkingDirectory = [IO.Path]::GetFullPath((Join-Path $repoRoot $workingDirectory))
    $relativeWorkingDirectory = [IO.Path]::GetRelativePath($repoRoot, $absoluteWorkingDirectory).Replace('\', '/')
    if ($relativeWorkingDirectory -eq '..' -or $relativeWorkingDirectory.StartsWith('../')) { throw "Step $qualifiedName workingDirectory is outside the repository." }
    Write-Host "==> $qualifiedName"
    $executionError = $null
    $exitCode = 1
    Push-Location $absoluteWorkingDirectory
    try {
        & ([string]$Step.filePath) @($Step.arguments) 2>&1 | Tee-Object -FilePath $logPath
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = if ($?) { 0 } else { 1 } }
    }
    catch {
        $executionError = $_.Exception.Message
        $executionError | Set-Content -LiteralPath $logPath -Encoding utf8
    }
    finally {
        Pop-Location
    }
    $stepEnd = (Get-Date).ToUniversalTime()
    $steps.Add([pscustomobject]@{
        adapterId = $AdapterId
        name = [string]$Step.name
        command = "$($Step.filePath) $(@($Step.arguments) -join ' ')"
        workingDirectory = $relativeWorkingDirectory
        status = if ($exitCode -eq 0) { 'Passed' } else { 'Failed' }
        exitCode = $exitCode
        startedAt = $stepStart.ToString('o')
        finishedAt = $stepEnd.ToString('o')
        log = [IO.Path]::GetRelativePath($repoRoot, $logPath)
    })
    if ($exitCode -ne 0) {
        $suffix = if ($executionError) { " $executionError" } else { '' }
        throw "$qualifiedName failed with exit code $exitCode.$suffix"
    }
}

try {
    foreach ($adapter in @($plan.adapters)) {
        $activeAdapter = [pscustomobject]@{
            id = [string]$adapter.id
            type = [string]$adapter.type
            required = [bool]$adapter.required
            target = [string]$adapter.target
            workingDirectory = [string]$adapter.workingDirectory
            status = [string]$adapter.status
            reason = [string]$adapter.skipReason
            scriptSha256 = [string]$adapter.scriptSha256
        }
        $adapterResults.Add($activeAdapter)
        if ($adapter.status -eq 'Skipped') { continue }
        $activeAdapter.status = 'Running'
        foreach ($step in @($adapter.steps)) { Invoke-GateStep $adapter.id $step }
        $activeAdapter.status = 'Passed'
        $activeAdapter = $null
    }

    if ($Mode -eq 'Full') {
        $fullHook = if ($config.fullHook) { Join-Path $repoRoot $config.fullHook } else { $null }
        if ($fullHook -and (Test-Path -LiteralPath $fullHook)) {
            Invoke-GateStep 'core' ([pscustomobject]@{ name = 'full-hook'; filePath = 'pwsh'; arguments = @('-NoProfile', '-File', $fullHook, '-WorkItemId', $WorkItemId, '-EvidenceDirectory', $runDirectory); workingDirectory = '.' })
        }
        $uiHook = if ($config.uiHook) { Join-Path $repoRoot $config.uiHook } else { $null }
        if ($state.uiScope) {
            $requiresUiHook = $null -eq $config.requireUiHookWhenUiInScope -or [bool]$config.requireUiHookWhenUiInScope
            if ($requiresUiHook -and (-not $config.uiHook -or -not (Test-Path -LiteralPath $uiHook))) { throw "UI scope requires an implemented hook at $($config.uiHook)." }
            if ($uiHook -and (Test-Path -LiteralPath $uiHook)) {
                Invoke-GateStep 'core' ([pscustomobject]@{ name = 'ui-hook'; filePath = 'pwsh'; arguments = @('-NoProfile', '-File', $uiHook, '-WorkItemId', $WorkItemId, '-EvidenceDirectory', $runDirectory); workingDirectory = '.' })
            }
        }
    }
}
catch {
    $overall = 'Failed'
    $failure = $_.Exception.Message
    if ($activeAdapter) { $activeAdapter.status = 'Failed'; $activeAdapter.reason = $failure }
}

try {
    $gateConfigSha256AtFinish = (& (Join-Path $PSScriptRoot 'Get-AiGateConfigFingerprint.ps1') -ConfigPath $configPath).Trim()
}
catch {
    $gateConfigSha256AtFinish = ''
}
if ($gateConfigSha256AtFinish -ne $gateConfigSha256) {
    $overall = 'Failed'
    $failure = 'Gate configuration changed while verification was running.'
}

$finishedAt = (Get-Date).ToUniversalTime()
$specHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $item 'spec.md')).Hash.ToLowerInvariant()
$result = [ordered]@{
    schemaVersion = 2
    workItemId = $WorkItemId
    mode = $Mode
    configurationMode = [string]$plan.configurationMode
    target = (@($adapterResults | ForEach-Object target | Where-Object { $_ }) -join ', ')
    overall = $overall
    failure = $failure
    specSha256 = $specHash
    gateConfigSha256 = $gateConfigSha256
    startedAt = $startedAt.ToString('o')
    finishedAt = $finishedAt.ToString('o')
    adapters = $adapterResults
    steps = $steps
}
$jsonPath = Join-Path $runDirectory 'quality-gate.json'
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $jsonPath -Encoding utf8

$summary = @(
    "# Quality gate: $overall"
    ''
    "- Work item: ``$WorkItemId``"
    "- Mode: ``$Mode``"
    "- Configuration: ``$($result.configurationMode)``"
    "- Targets: ``$($result.target)``"
    "- Started: $($result.startedAt)"
    "- Finished: $($result.finishedAt)"
    if ($failure) { "- Failure: $failure" }
    ''
    '| Adapter | Type | Required | Status | Target |'
    '|---|---|---:|---|---|'
)
foreach ($adapter in $adapterResults) { $summary += "| $($adapter.id) | $($adapter.type) | $($adapter.required) | $($adapter.status) | ``$($adapter.target)`` |" }
$summary += @('', '| Step | Status | Exit | Working directory | Log |', '|---|---|---:|---|---|')
foreach ($step in $steps) { $summary += "| $($step.adapterId):$($step.name) | $($step.status) | $($step.exitCode) | ``$($step.workingDirectory)`` | ``$($step.log)`` |" }
Set-Content -LiteralPath (Join-Path $runDirectory 'quality-gate.md') -Value $summary -Encoding utf8

Copy-Item -LiteralPath $jsonPath -Destination (Join-Path $evidenceRoot 'latest-quality-gate.json') -Force
Copy-Item -LiteralPath (Join-Path $runDirectory 'quality-gate.md') -Destination (Join-Path $evidenceRoot 'latest-quality-gate.md') -Force
$state.state = if ($overall -eq 'Passed' -and $Mode -eq 'Full') { 'verification-passed' } elseif ($overall -eq 'Failed') { 'verification-failed' } else { $state.state }
$state.lastTransitionAt = (Get-Date).ToUniversalTime().ToString('o')
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding utf8

Write-Host "Quality gate: $overall"
Write-Host "Evidence: $runDirectory"
if ($overall -ne 'Passed') { exit 1 }
