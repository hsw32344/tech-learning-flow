[CmdletBinding()]
param(
    [string]$Vault,
    [string]$Path
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

& (Join-Path $PSScriptRoot 'validate-action.ps1') -Vault $Vault -Action 'learning-record' -Path $Path
exit $LASTEXITCODE
