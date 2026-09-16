[CmdletBinding()]
param(
    [string]$Vault,
    [string]$Path
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'vault-contract.ps1')

Write-ArtifactValidation -Kind 'reviewbank' -Vault $Vault -Path $Path -ValidatorPath (Join-Path $PSScriptRoot 'validate-vault.ps1') -Fields @('invalid_review_banks', 'atomic_mirror_gaps', 'duplicate_atomic_mirrors', 'orphan_review_atomic_refs')
