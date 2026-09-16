[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$VaultRoot,
    [string]$UnitId,
    [string]$PluginRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'vault-contract.ps1')

if ([string]::IsNullOrWhiteSpace($PluginRoot)) {
    $packageRootCandidate = Split-Path -Parent $PSScriptRoot
    $pluginRootCandidate = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $PluginRoot = @($packageRootCandidate, $pluginRootCandidate) |
        Where-Object { Test-Path -LiteralPath (Join-Path $_ 'references\curriculum-sources.md') -PathType Leaf } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($PluginRoot)) {
        throw 'Cannot locate references\curriculum-sources.md from the packaged script layout.'
    }
}

$vaultRootResolved = (Resolve-Path -LiteralPath $VaultRoot).Path
$pluginRootResolved = (Resolve-Path -LiteralPath $PluginRoot).Path
$homepagePath = Join-Path $vaultRootResolved '00-首页.md'
$registryPath = Resolve-SourceRegistryPath -VaultRoot $vaultRootResolved -PluginRoot $pluginRootResolved
$fccOperationManualPath = Join-Path $vaultRootResolved '99-附件\FCC学习操作范式.md'
$snapshotGuidePath = Join-Path $vaultRootResolved '25-资源区\学习快照\学习快照使用说明.md'

foreach ($requiredPath in @((Join-Path $vaultRootResolved '20-学习主线'), $homepagePath, $registryPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required path not found: $requiredPath"
    }
}

$homepageContent = Get-Content -LiteralPath $homepagePath -Encoding UTF8 -Raw
if ([string]::IsNullOrWhiteSpace($UnitId)) {
    $currentMatch = [regex]::Match($homepageContent, '(?m)^current_unit:\s*(?<unit>[A-Z][A-Z0-9-]*-\d{2})\s*$')
    if (-not $currentMatch.Success) {
        throw 'Cannot resolve current_unit from 00-首页.md.'
    }
    $UnitId = $currentMatch.Groups['unit'].Value
}

if ($UnitId -cnotmatch ('^' + $UnitIdPattern + '$')) {
    throw "Invalid task-package unit ID: $UnitId"
}

$mainlineText = Get-MainlineText -VaultRoot $vaultRootResolved

$primaryMatches = @([regex]::Matches($mainlineText, $PrimaryDeclarationPattern) | Where-Object { $_.Groups['unit'].Value -ceq $UnitId })
if ($primaryMatches.Count -ne 1) {
    throw "Expected exactly one primary_source declaration for $UnitId; found $($primaryMatches.Count)."
}

$gapMatches = @([regex]::Matches($mainlineText, $GapDeclarationPattern) | Where-Object { $_.Groups['unit'].Value -ceq $UnitId })
if ($gapMatches.Count -gt 1) {
    throw "Expected at most one gap_source declaration for $UnitId; found $($gapMatches.Count)."
}

$taskRows = @(
    [regex]::Matches($mainlineText, $UnitRowPattern) |
        Where-Object { $_.Groups['id'].Value -ceq $UnitId } |
        ForEach-Object {
            [pscustomobject]@{
                unit                  = $_.Groups['id'].Value
                canonical_content     = $_.Groups['content'].Value.Trim()
                prerequisites         = $_.Groups['prerequisite'].Value.Trim()
                causal_model          = $_.Groups['model'].Value.Trim()
                coverage_and_artifact = $_.Groups['output'].Value.Trim()
                source_summary        = $_.Groups['source'].Value.Trim()
            }
        }
)
if ($taskRows.Count -ne 1) {
    throw "Expected exactly one task-package table row for $UnitId; found $($taskRows.Count)."
}

$registryText = Get-Content -LiteralPath $registryPath -Encoding UTF8 -Raw

$primaryMatch = $primaryMatches[0]
$primaryCode = $primaryMatch.Groups['source'].Value
$primaryRegistry = Get-RegistryEntry -RegistryText $registryText -Code $primaryCode
$primary = [ordered]@{
    code              = $primaryCode
    role              = $primaryRegistry.role
    label             = $primaryRegistry.label
    url               = $primaryRegistry.url
    note              = $primaryRegistry.note
    type              = $primaryMatch.Groups['type'].Value
    locator           = $primaryMatch.Groups['locator'].Value
    declaration_extra = $primaryMatch.Groups['extra'].Value.Trim()
}

$gap = $null
if ($gapMatches.Count -eq 1) {
    $gapMatch = $gapMatches[0]
    $gapCode = $gapMatch.Groups['source'].Value
    $gapRegistry = Get-RegistryEntry -RegistryText $registryText -Code $gapCode
    $gap = [ordered]@{
        code              = $gapCode
        role              = $gapRegistry.role
        label             = $gapRegistry.label
        url               = $gapRegistry.url
        note              = $gapRegistry.note
        type              = $gapMatch.Groups['type'].Value
        locator           = $gapMatch.Groups['locator'].Value
        gap               = $gapMatch.Groups['gap'].Value
        declaration_extra = $gapMatch.Groups['extra'].Value.Trim()
    }
}

$positionMatch = [regex]::Match($homepageContent, '(?m)^current_position:\s*(?<position>.+?)\s*$')
$snapshotPath = Join-Path $vaultRootResolved "25-资源区\学习快照\$UnitId 学习快照.md"
$snapshotNextLocator = $null
$snapshotCache = $null
if (Test-Path -LiteralPath $snapshotPath -PathType Leaf) {
    $snapshotContent = Get-Content -LiteralPath $snapshotPath -Encoding UTF8 -Raw
    $snapshotNextMatch = [regex]::Match($snapshotContent, '(?m)^- 下一 locator：\s*(?<locator>.+?)\s*$')
    if ($snapshotNextMatch.Success) {
        $snapshotNextLocator = $snapshotNextMatch.Groups['locator'].Value.Trim()
    }
    $snapshotUnitMatch = [regex]::Match($snapshotContent, '(?m)^unit:\s*(?<value>.+?)\s*$')
    $snapshotPrimaryMatch = [regex]::Match($snapshotContent, '(?m)^primary_source:\s*(?<value>.+?)\s*$')
    $snapshotStatusMatch = [regex]::Match($snapshotContent, '(?m)^source_packet_status:\s*(?<value>.+?)\s*$')
    $snapshotVerifiedAtMatch = [regex]::Match($snapshotContent, '(?m)^source_verified_at:\s*(?<value>.+?)\s*$')
    $snapshotUnit = if ($snapshotUnitMatch.Success) { $snapshotUnitMatch.Groups['value'].Value.Trim() } else { $null }
    $snapshotPrimary = if ($snapshotPrimaryMatch.Success) { $snapshotPrimaryMatch.Groups['value'].Value.Trim() } else { $null }
    $snapshotStatus = if ($snapshotStatusMatch.Success) { $snapshotStatusMatch.Groups['value'].Value.Trim() } else { $null }
    $snapshotVerifiedAt = if ($snapshotVerifiedAtMatch.Success) { $snapshotVerifiedAtMatch.Groups['value'].Value.Trim() } else { $null }
    $snapshotCache = [ordered]@{
        exists                 = $true
        source_packet_status   = $snapshotStatus
        source_verified_at     = $snapshotVerifiedAt
        unit                   = $snapshotUnit
        unit_matches           = ($snapshotUnit -ceq $UnitId)
        primary_source         = $snapshotPrimary
        primary_source_matches = ($snapshotPrimary -ceq $primaryCode)
        status_eligible        = ($snapshotStatus -eq 'verified' -or ($snapshotStatus -eq 'agent-fallback' -and $primaryCode -eq 'AGENT-FALLBACK'))
    }
}

$isFccSource = $primaryCode -cmatch '^FCC-'
if ($isFccSource) {
    foreach ($requiredFccPath in @($fccOperationManualPath, $snapshotGuidePath)) {
        if (-not (Test-Path -LiteralPath $requiredFccPath -PathType Leaf)) {
            throw "Required FCC workflow file not found: $requiredFccPath"
        }
    }
}

$result = [ordered]@{
    unit                  = $UnitId
    current_position      = if ($positionMatch.Success) { $positionMatch.Groups['position'].Value } else { $null }
    task                  = $taskRows[0]
    primary_source        = $primary
    gap_source            = $gap
    fcc_operation_manual  = if ($isFccSource) { $fccOperationManualPath } else { $null }
    snapshot_guide        = if (Test-Path -LiteralPath $snapshotGuidePath -PathType Leaf) { $snapshotGuidePath } else { $null }
    learning_snapshot     = if (Test-Path -LiteralPath $snapshotPath -PathType Leaf) { $snapshotPath } else { $null }
    snapshot_cache        = if ($null -ne $snapshotCache) { $snapshotCache } else { [ordered]@{ exists = $false } }
    snapshot_next_locator = $snapshotNextLocator
}

$result | ConvertTo-Json -Depth 6
