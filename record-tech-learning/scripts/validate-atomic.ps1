[CmdletBinding()]
param(
    [string]$Vault,
    [string]$Path
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'vault-contract.ps1')

Write-ArtifactValidation -Kind 'atomic' -Vault $Vault -Path $Path -ValidatorPath (Join-Path $PSScriptRoot 'validate-vault.ps1') -Fields @('invalid_atomic_notes', 'duplicate_atomic_ids', 'invalid_atomic_term_refs', 'atomic_granularity_issues')
