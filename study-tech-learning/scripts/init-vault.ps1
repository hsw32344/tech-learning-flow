[CmdletBinding()]
param(
    [string]$VaultRoot,
    [switch]$Force,
    [switch]$Bind
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$scriptDir = $PSScriptRoot
$skillRoot = Split-Path -Parent $scriptDir
$seedRoot = Join-Path $skillRoot 'assets\vault-seed'
$manifestPath = Join-Path $seedRoot '.dirs.txt'
$schemaPath = Join-Path $skillRoot 'assets\vault-schema.json'
$validatorPath = Join-Path $scriptDir 'validate-vault.ps1'
$stateDir = Join-Path $env:USERPROFILE '.agents\tech-learning-flow'
$pointerPath = Join-Path $stateDir 'vault-path.txt'

if (-not (Test-Path -LiteralPath $seedRoot -PathType Container)) {
    throw "Bundled vault seed not found: $seedRoot"
}
if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
    throw "Bundled vault schema not found: $schemaPath"
}
if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
    throw "Vault validator not found: $validatorPath"
}

if ([string]::IsNullOrWhiteSpace($VaultRoot) -and -not [string]::IsNullOrWhiteSpace($env:TECH_LEARNING_VAULT)) {
    $VaultRoot = $env:TECH_LEARNING_VAULT
}
if ([string]::IsNullOrWhiteSpace($VaultRoot) -and (Test-Path -LiteralPath $pointerPath -PathType Leaf)) {
    $tracked = [IO.File]::ReadAllText($pointerPath, [Text.Encoding]::UTF8).Trim()
    if (-not [string]::IsNullOrWhiteSpace($tracked)) { $VaultRoot = $tracked }
}
if ([string]::IsNullOrWhiteSpace($VaultRoot)) {
    throw 'No vault bound. Pass -VaultRoot or create %USERPROFILE%\.agents\tech-learning-flow\vault-path.txt.'
}

$vault = [IO.Path]::GetFullPath($VaultRoot)

if ((Test-Path -LiteralPath $vault) -and -not (Get-Item -LiteralPath $vault).PSIsContainer) {
    throw "Vault target is a file, not a directory: $vault"
}

$markerPath = Join-Path $vault '.tech-vault.json'
$isNew = -not (Test-Path -LiteralPath $markerPath -PathType Leaf)

$schemaText = [IO.File]::ReadAllText($schemaPath, [Text.Encoding]::UTF8)
$schema = $schemaText | ConvertFrom-Json
$schemaVersion = [int]$schema.schema_version

New-Item -ItemType Directory -Force -Path $vault | Out-Null

$dirs = @()
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    $dirs = @([IO.File]::ReadAllLines($manifestPath, [Text.Encoding]::UTF8) | Where-Object { $_.Trim() })
}
foreach ($relativeDir in $dirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $vault $relativeDir) | Out-Null
}

$added = @()
$skipped = @()
if (-not $Bind) {
    foreach ($seedFile in @(Get-ChildItem -LiteralPath $seedRoot -Recurse -File)) {
        $relative = $seedFile.FullName.Substring($seedRoot.Length + 1)
        if ($relative.StartsWith('.')) { continue }
        $destination = Join-Path $vault $relative
        $destinationDir = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destinationDir -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
        }
        if ((Test-Path -LiteralPath $destination) -and -not $Force) {
            $skipped += $relative
            continue
        }
        Copy-Item -LiteralPath $seedFile.FullName -Destination $destination -Force
        $added += $relative
    }
}

# The Vault owns its schema and instance record: create the marker only on first
# use. Re-running init never overwrites an existing .tech-vault.json (created_at,
# schema_version, and the embedded schema are preserved for migrations to handle).
if ($isNew) {
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $marker = [ordered]@{
        schema_version = $schemaVersion
        seed_revision  = 1
        created_at     = $today
        updated_at     = $today
        schema         = $schema
    }
    [IO.File]::WriteAllText($markerPath, ($marker | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
}

New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

$hostExe = (Get-Process -Id $PID).Path
$validationOutput = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $validatorPath -Vault $vault
$validationText = [string]::Join([Environment]::NewLine, @($validationOutput))
$validation = $null
try { $validation = $validationText | ConvertFrom-Json } catch { $validation = $null }

$validFlag = $false
$issueList = @()
if ($null -ne $validation) {
    $validFlag = [bool]$validation.valid
    if ($validation.PSObject.Properties['issues']) { $issueList = @($validation.issues) }
}
else {
    $issueList = @('validator output could not be parsed')
}

# Bind the tracked pointer only to a Vault that passes the core readiness check,
# so a failed init never leaves the pointer on an unusable Vault.
$bound = $false
if ($validFlag) {
    [IO.File]::WriteAllText($pointerPath, $vault, [Text.UTF8Encoding]::new($false))
    $bound = $true
}

$result = [ordered]@{
    vault          = $vault
    created        = $isNew
    schema_version = $schemaVersion
    added          = @($added)
    skipped        = @($skipped)
    pointer        = $pointerPath
    bound          = $bound
    valid          = $validFlag
    issues         = $issueList
}
$result | ConvertTo-Json -Depth 8
if (-not $result.valid) { exit 1 }
