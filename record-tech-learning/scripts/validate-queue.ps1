[CmdletBinding()]
param(
    [string]$Vault,
    [string]$Path
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'vault-contract.ps1')

Write-ArtifactValidation -Kind 'queue' -Vault $Vault -Path $Path -ValidatorPath (Join-Path $PSScriptRoot 'validate-vault.ps1') -Fields @('review_queue_issues', 'review_template_issues')
