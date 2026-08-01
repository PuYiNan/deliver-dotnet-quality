[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath
)

$ErrorActionPreference = 'Stop'
$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$hasDeclarativeAdapters = $config.gate -and $null -ne $config.gate.adapters -and @($config.gate.adapters).Count -gt 0
$hasLegacyDotnetConfig = $config.PSObject.Properties.Name -contains 'solution' -or $config.PSObject.Properties.Name -contains 'requireFormatCheck'
$relevant = if ($hasDeclarativeAdapters) {
    [ordered]@{
        mode = 'declarative'
        gate = $config.gate
        requireUiHookWhenUiInScope = $config.requireUiHookWhenUiInScope
        fullHook = $config.fullHook
        uiHook = $config.uiHook
    }
}
elseif ($hasLegacyDotnetConfig) {
    [ordered]@{
        mode = 'legacy-dotnet'
        solution = $config.solution
        requireFormatCheck = $config.requireFormatCheck
        requireUiHookWhenUiInScope = $config.requireUiHookWhenUiInScope
        fullHook = $config.fullHook
        uiHook = $config.uiHook
    }
}
else {
    throw 'No gate adapter is configured.'
}
$json = $relevant | ConvertTo-Json -Depth 30 -Compress
$bytes = [Text.Encoding]::UTF8.GetBytes($json)
$hash = [Security.Cryptography.SHA256]::HashData($bytes)
[Convert]::ToHexString($hash).ToLowerInvariant()
