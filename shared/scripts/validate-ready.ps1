[CmdletBinding()]
param([string]$Vault)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'vault-contract.ps1')

$Vault = Resolve-BoundVault -Vault $Vault
$issues = @()
if (-not (Test-Path -LiteralPath $Vault -PathType Container)) {
    $issues += "vault directory not found: $Vault"
}
else {
    $vaultPath = (Resolve-Path -LiteralPath $Vault).Path
    $markerPath = Join-Path $vaultPath '.tech-vault.json'
    $marker = $null
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        $issues += 'vault marker missing: .tech-vault.json'
    }
    else {
        try { $marker = [IO.File]::ReadAllText($markerPath, [Text.Encoding]::UTF8) | ConvertFrom-Json }
        catch { $issues += 'vault marker is unreadable' }
    }
    $required = if ($marker -and $marker.PSObject.Properties['schema'] -and $marker.schema.PSObject.Properties['paths']) {
        @($marker.schema.paths.required)
    }
    else { @() }
    if ($required.Count -eq 0) { $issues += 'vault schema lacks paths.required' }
    foreach ($relative in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $vaultPath $relative))) { $issues += "missing required path: $relative" }
    }
    $homepagePath = Join-Path $vaultPath '00-首页.md'
    $mainlinePath = Join-Path $vaultPath '20-学习主线\00-总览.md'
    $taskRegistryPath = Join-Path $vaultPath '20-学习主线\20-任务包注册表.md'
    if ((Test-Path -LiteralPath $homepagePath -PathType Leaf) -and (Test-Path -LiteralPath $mainlinePath -PathType Leaf)) {
        $homepage = Get-Content -Raw -Encoding UTF8 -LiteralPath $homepagePath
        $mainline = Get-Content -Raw -Encoding UTF8 -LiteralPath $mainlinePath
        foreach ($property in @('type', 'current_stage', 'current_unit', 'current_position')) {
            if ($homepage -notmatch "(?m)^$([regex]::Escape($property))\s*:") { $issues += "homepage missing property: $property" }
        }
        foreach ($property in @('type', 'current_unit')) {
            if ($mainline -notmatch "(?m)^$([regex]::Escape($property))\s*:") { $issues += "mainline overview missing property: $property" }
        }
        $unitMatch = [regex]::Match($mainline, "(?m)^current_unit:\s*(?<unit>$UnitIdPattern)\s*$")
        if (-not $unitMatch.Success) { $issues += 'mainline current_unit not declared' }
        elseif (Test-Path -LiteralPath $taskRegistryPath -PathType Leaf) {
            $tasks = Get-Content -Raw -Encoding UTF8 -LiteralPath $taskRegistryPath
            $declared = @([regex]::Matches($tasks, '(?m)^- unit: `(?<unit>[^`]+)`') | ForEach-Object { $_.Groups['unit'].Value })
            if ($declared -notcontains $unitMatch.Groups['unit'].Value) {
                $issues += "current_unit is not declared: $($unitMatch.Groups['unit'].Value)"
            }
        }
        else { $issues += 'task package registry missing' }
    }
}

$result = [pscustomobject]@{ kind = 'ready'; vault = $Vault; valid = ($issues.Count -eq 0); issues = @($issues) }
$result | ConvertTo-Json -Depth 6
if (-not $result.valid) { exit 1 }
