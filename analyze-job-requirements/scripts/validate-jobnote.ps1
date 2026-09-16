[CmdletBinding()]
param(
    [string]$Vault,
    [string]$Path
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'vault-contract.ps1')

Write-ArtifactValidation -Kind 'jobnote' -Vault $Vault -Path $Path -ValidatorPath (Join-Path $PSScriptRoot 'validate-vault.ps1') -Fields @('invalid_job_requirement_notes', 'job_requirement_template_issues')
