[CmdletBinding()]
param(
    [string]$Vault,
    [string]$Path
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'vault-contract.ps1')

Write-ArtifactValidation -Kind 'daily' -Vault $Vault -Path $Path -ValidatorPath (Join-Path $PSScriptRoot 'validate-vault.ps1') -Fields @('invalid_daily_reviews', 'daily_template_issues', 'duplicate_review_dates')
