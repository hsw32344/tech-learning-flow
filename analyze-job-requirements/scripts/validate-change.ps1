[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Vault,
    [string[]]$Kinds = @(),
    [string[]]$Paths = @(),
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$AdditionalPaths = @(),
    [string[]]$ChangeSet = @(),
    [string]$Action,
    [ValidateSet('update', 'create', 'delete', 'rename')][string]$Operation = 'update',
    [string]$OldPath,
    [string]$OldIdentity,
    [switch]$FullAudit
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'vault-contract.ps1')
. (Join-Path $PSScriptRoot 'validation-registry.ps1')

function Write-ChangeResult {
    param([Parameter(Mandatory = $true)]$Result)
    $Result | ConvertTo-Json -Depth 20
    if (-not $Result.valid) { exit 1 }
    exit 0
}

function New-ChangeFailure {
    param([string]$Kind, [string]$Vault, [string]$Message, [bool]$RuntimeError)
    return [pscustomobject]@{
        kind          = $Kind
        vault         = $Vault
        valid         = $false
        runtime_error = $RuntimeError
        checks        = [pscustomobject]@{}
        issues        = @($Message)
        warnings      = @()
        diagnostics   = @()
    }
}

$Vault = Resolve-BoundVault -Vault $Vault
# Accept both `-Kinds daily,weekly` (PowerShell array) and one literal argument
# from pwsh -File, so callers cannot silently lose kinds, paths, or change entries.
$Kinds = @($Kinds | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Paths = @(@($Paths) + @($AdditionalPaths) | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
# `|` is not a legal Windows filename character, so extra arguments containing
# it are change entries, not paths (pwsh -File sends extra array values to
# ValueFromRemainingArguments).
$ChangeSet = @($ChangeSet) + @($Paths | Where-Object { $_ -match '\|' })
$Paths = @($Paths | Where-Object { $_ -notmatch '\|' })

if ($FullAudit) {
    if ($Kinds.Count -gt 0 -or $Paths.Count -gt 0 -or $ChangeSet.Count -gt 0 -or
        -not [string]::IsNullOrWhiteSpace($Action)) {
        Write-ChangeResult -Result (New-ChangeFailure -Kind 'full-audit' -Vault $Vault `
                -Message '-FullAudit cannot be combined with -Action, -Kinds, -Paths, or -ChangeSet' -RuntimeError $false)
    }
    $validatorPath = Join-Path $PSScriptRoot 'validate-vault.ps1'
    if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
        Write-ChangeResult -Result (New-ChangeFailure -Kind 'full-audit' -Vault $Vault `
                -Message 'the whole-vault audit is available only from direct-tech-learning' -RuntimeError $true)
    }
    $result = Invoke-VaultStrict -Vault $Vault -ValidatorPath $validatorPath
    if ($null -eq $result -or $result.runtime_error) {
        Write-ChangeResult -Result (New-ChangeFailure -Kind 'full-audit' -Vault $Vault `
                -Message 'the whole-vault audit did not produce a valid result' -RuntimeError $true)
    }
    Add-Member -InputObject $result -NotePropertyName 'kind' -NotePropertyValue 'full-audit' -Force
    Write-ChangeResult -Result $result
}

$definition = $null
if (-not [string]::IsNullOrWhiteSpace($Action)) {
    if ($Kinds.Count -gt 0) {
        Write-ChangeResult -Result (New-ChangeFailure -Kind 'change' -Vault $Vault `
                -Message '-Action already resolves kinds; do not pass -Kinds' -RuntimeError $false)
    }
    $registry = Get-ValidationRegistry -RegistryPath (Get-ValidationRegistryPath -ScriptRoot $PSScriptRoot)
    $definition = Get-ValidationActionDefinition -Registry $registry -ActionId $Action
    $Kinds = @($definition.kinds)
}

$unknownKinds = @($Kinds | Where-Object { -not $script:VaultKindFields.ContainsKey($_) })
if ($unknownKinds.Count -gt 0) {
    $message = "unknown kind(s): $($unknownKinds -join ', '); allowed: $(@($script:VaultKindFields.Keys | Sort-Object) -join ', ')"
    Write-ChangeResult -Result (New-ChangeFailure -Kind 'change' -Vault $Vault -Message $message -RuntimeError $true)
}
if ($ChangeSet.Count -gt 0 -and $Kinds.Count -eq 0) {
    Write-ChangeResult -Result (New-ChangeFailure -Kind 'change' -Vault $Vault `
            -Message '-ChangeSet requires -Kinds or -Action' -RuntimeError $false)
}

$explicitTargets = $true
if ($ChangeSet.Count -gt 0) {
    foreach ($name in @('Operation', 'OldPath', 'OldIdentity')) {
        if ($PSBoundParameters.ContainsKey($name)) {
            Write-ChangeResult -Result (New-ChangeFailure -Kind 'change' -Vault $Vault `
                    -Message "-ChangeSet cannot be combined with -$name; declare each entry as 'operation|path[|old_path[|old_identity]]'" -RuntimeError $false)
        }
    }
    $changes = @(ConvertTo-ValidationChangeSet -Entries $ChangeSet)
}
else {
    if ($null -ne $definition) {
        $explicitTargets = ($Paths.Count -gt 0)
        if (-not $explicitTargets) {
            if ($Operation -ne 'update') {
                Write-ChangeResult -Result (New-ChangeFailure -Kind 'change' -Vault $Vault `
                        -Message "action '$Action' with operation '$Operation' requires explicit -Paths or -ChangeSet" -RuntimeError $false)
            }
            $Paths = @($definition.default_paths)
        }
    }
    if ($Kinds.Count -eq 0 -or $Paths.Count -eq 0) {
        Write-ChangeResult -Result (New-ChangeFailure -Kind 'change' -Vault $Vault `
                -Message 'normal change validation requires -Kinds and -Paths, -ChangeSet, or -Action; use -FullAudit from direct-tech-learning for the whole-vault audit' `
                -RuntimeError $false)
    }
    if ($Operation -eq 'rename' -and $Paths.Count -ne 1) {
        Write-ChangeResult -Result (New-ChangeFailure -Kind 'change' -Vault $Vault `
                -Message "operation 'rename' requires exactly one target path" -RuntimeError $false)
    }
    $changes = @()
    foreach ($entry in $Paths) {
        $changes += New-ValidationChange -Path $entry -Operation $Operation -OldPath $OldPath -OldIdentity $OldIdentity
    }
}

. (Join-Path $PSScriptRoot 'validate-scope.ps1')
if ($null -ne $definition -and $explicitTargets) {
    $violations = @(Test-ValidationActionSurface -Definition $definition -Paths @($changes | ForEach-Object { $_.path }) -VaultRoot $Vault)
    if ($violations.Count -gt 0) {
        $diagnostics = @($violations | ForEach-Object {
                ConvertTo-VaultDiagnostic -Field 'write_surface_violation' -Item "declared path is outside the action write surface: $_"
            })
        Write-ChangeResult -Result (New-ScopeChangeResult -Vault $Vault -Checks ([pscustomobject]@{
                    common = New-VaultCheckGroup -Diagnostics $diagnostics
                }) -Diagnostics $diagnostics)
    }
}
$scopedResult = Invoke-ScopedChangeValidation -Vault $Vault -Kinds $Kinds -Changes $changes
Write-ChangeResult -Result $scopedResult
