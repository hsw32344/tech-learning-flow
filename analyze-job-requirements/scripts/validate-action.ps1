[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Vault,
    [Parameter(Mandatory = $true)][string]$Action,
    [string[]]$Path = @(),
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$AdditionalPaths = @(),
    [string[]]$ChangeSet = @(),
    [ValidateSet('update', 'create', 'delete', 'rename')][string]$Operation = 'update',
    [string]$OldPath,
    [string]$OldIdentity
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'vault-contract.ps1')
. (Join-Path $PSScriptRoot 'validate-scope.ps1')
. (Join-Path $PSScriptRoot 'validation-registry.ps1')

$Vault = Resolve-BoundVault -Vault $Vault
$registry = Get-ValidationRegistry -RegistryPath (Get-ValidationRegistryPath -ScriptRoot $PSScriptRoot)
$definition = Get-ValidationActionDefinition -Registry $registry -ActionId $Action

$paths = @(@($Path) + @($AdditionalPaths) | ForEach-Object { $_ -split ',' } |
    ForEach-Object { $_.Trim() } | Where-Object { $_ })

# `|` is not a legal Windows filename character, so trailing arguments that
# contain it are change entries, not paths (pwsh -File sends extra array
# values to ValueFromRemainingArguments).
$ChangeSet = @($ChangeSet) + @($paths | Where-Object { $_ -match '\|' })
$paths = @($paths | Where-Object { $_ -notmatch '\|' })

if ($ChangeSet.Count -gt 0) {
    foreach ($name in @('Operation', 'OldPath', 'OldIdentity')) {
        if ($PSBoundParameters.ContainsKey($name)) {
            throw "-ChangeSet cannot be combined with -$name; declare each entry as 'operation|path[|old_path[|old_identity]]'."
        }
    }
    $changes = @(ConvertTo-ValidationChangeSet -Entries $ChangeSet)
    $explicitTargets = $true
}
else {
    $explicitTargets = ($paths.Count -gt 0)
    if (-not $explicitTargets) {
        if ($Operation -ne 'update') {
            throw "Action '$Action' with operation '$Operation' requires explicit -Path entries or -ChangeSet."
        }
        $paths = @($definition.default_paths)
    }
    if ($Operation -eq 'rename' -and $paths.Count -ne 1) {
        throw "Action '$Action' with operation 'rename' requires exactly one -Path entry."
    }
    $changes = @()
    foreach ($entry in $paths) {
        $changes += New-ValidationChange -Path $entry -Operation $Operation -OldPath $OldPath -OldIdentity $OldIdentity
    }
}

if ($explicitTargets) {
    $violations = @(Test-ValidationActionSurface -Definition $definition -Paths @($changes | ForEach-Object { $_.path }) -VaultRoot $Vault)
    if ($violations.Count -gt 0) {
        $diagnostics = @($violations | ForEach-Object {
                ConvertTo-VaultDiagnostic -Field 'write_surface_violation' -Item "declared path is outside the action write surface: $_"
            })
        $result = New-ScopeChangeResult -Vault $Vault -Checks ([pscustomobject]@{
                common = New-VaultCheckGroup -Diagnostics $diagnostics
            }) -Diagnostics $diagnostics
        $result | ConvertTo-Json -Depth 20
        exit 1
    }
}

$result = Invoke-ScopedChangeValidation -Vault $Vault -Kinds @($definition.kinds) -Changes $changes
Add-Member -InputObject $result -NotePropertyName 'action' -NotePropertyValue $Action -Force
Add-Member -InputObject $result -NotePropertyName 'skills' -NotePropertyValue @($definition.skills) -Force
$result | ConvertTo-Json -Depth 20
if (-not $result.valid) { exit 1 }
