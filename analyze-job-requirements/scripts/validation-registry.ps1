# Validation registry resolution. This module only reads and validates the
# action-to-impact registry shape; it contains no Vault artifact rules.

. (Join-Path $PSScriptRoot 'validation-common.ps1')

function Get-ValidationRegistryPath {
    param([Parameter(Mandatory = $true)][string]$ScriptRoot)
    return (Join-Path (Split-Path -Parent $ScriptRoot) 'assets\validation-registry.json')
}

function Get-ValidationRegistry {
    param([Parameter(Mandatory = $true)][string]$RegistryPath)
    if (-not (Test-Path -LiteralPath $RegistryPath -PathType Leaf)) {
        throw "Validation registry not found: $RegistryPath"
    }
    return ([IO.File]::ReadAllText($RegistryPath, [Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Get-ValidationKindRoots {
    param([Parameter(Mandatory = $true)][string]$RegistryPath)
    $registry = Get-ValidationRegistry -RegistryPath $RegistryPath
    $roots = [ordered]@{}
    if ($registry.PSObject.Properties['kind_roots'] -and $null -ne $registry.kind_roots) {
        foreach ($property in $registry.kind_roots.PSObject.Properties) {
            $roots[$property.Name] = @($property.Value)
        }
    }
    return $roots
}

function Test-ValidationPathUnder {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$VaultRoot
    )
    $normalizedPath = ConvertTo-NormalizedPath $Path
    $normalizedRoot = ConvertTo-NormalizedPath $Root
    if ([string]::IsNullOrWhiteSpace($normalizedPath) -or [string]::IsNullOrWhiteSpace($normalizedRoot)) { return $false }
    if (-not [IO.Path]::IsPathRooted($normalizedPath) -and $VaultRoot) { $normalizedPath = Join-Path $VaultRoot $normalizedPath }
    if (-not [IO.Path]::IsPathRooted($normalizedRoot) -and $VaultRoot) { $normalizedRoot = Join-Path $VaultRoot $normalizedRoot }
    try {
        $fullPath = ConvertTo-NormalizedPath ([IO.Path]::GetFullPath($normalizedPath))
        $fullRoot = ConvertTo-NormalizedPath ([IO.Path]::GetFullPath($normalizedRoot))
    }
    catch { return $false }
    return ($fullPath.Equals($fullRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($fullRoot + '\', [StringComparison]::OrdinalIgnoreCase))
}

function Get-ValidationActionDefinition {
    param(
        [Parameter(Mandatory = $true)]$Registry,
        [Parameter(Mandatory = $true)][string]$ActionId
    )
    $found = @($Registry.actions | Where-Object { $_.id -eq $ActionId })
    if ($found.Count -eq 1) { return $found[0] }
    $standalone = @()
    if ($Registry.PSObject.Properties['standalone']) {
        $standalone = @($Registry.standalone | Where-Object { $_.id -eq $ActionId })
    }
    if ($standalone.Count -eq 1) {
        throw "Action '$ActionId' is a standalone validator; run scripts/$($standalone[0].script) directly."
    }
    $allowed = @($Registry.actions | ForEach-Object { $_.id }) -join ', '
    throw "Unknown validation action '$ActionId'; known scoped actions: $allowed"
}

function New-ValidationChange {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Operation = 'update',
        [string]$OldPath,
        [string]$OldIdentity
    )
    return [pscustomobject]@{
        path         = $Path
        operation    = $Operation
        old_path     = $OldPath
        old_identity = $OldIdentity
    }
}

function ConvertTo-ValidationChangeSet {
    param([Parameter(Mandatory = $true)][string[]]$Entries)
    $changes = @()
    foreach ($entry in $Entries) {
        $parts = $entry -split '\|', 4
        if ($parts.Count -lt 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
            throw "change entry must be 'operation|path[|old_path[|old_identity]]': $entry"
        }
        $changes += New-ValidationChange -Path $parts[1].Trim() -Operation $parts[0].Trim() `
            -OldPath ($(if ($parts.Count -ge 3) { $parts[2].Trim() } else { $null })) `
            -OldIdentity ($(if ($parts.Count -ge 4) { $parts[3].Trim() } else { $null }))
    }
    return $changes
}

function Test-ValidationActionSurface {
    param(
        [Parameter(Mandatory = $true)]$Definition,
        [string[]]$Paths = @(),
        [string]$VaultRoot
    )
    $violations = @()
    foreach ($path in $Paths) {
        $allowed = $false
        foreach ($surface in @($Definition.default_paths)) {
            if (Test-ValidationPathUnder -Path $path -Root $surface -VaultRoot $VaultRoot) {
                $allowed = $true
                break
            }
        }
        if (-not $allowed) { $violations += $path }
    }
    return $violations
}
