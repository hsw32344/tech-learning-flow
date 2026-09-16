# Shared Vault contract definitions for the tech-learning Vault.
#
# Dot-source this file from every script that parses the mainline or the source
# registry. It owns the canonical declaration / unit-row / registry FORMAT and
# the allowed type and role values, so no two scripts can drift apart. Callers
# decide whether to enforce the enums; they must not redefine these patterns.

$UnitIdPattern = '[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-\d{2}'
$PrimaryDeclarationPattern = '(?m)^- unit: `(?<unit>[^`]+)` \| primary_source: `(?<source>[^`]+)` \| type: `(?<type>[^`]+)` \| locator: `(?<locator>[^`]+)`(?<extra>.*)$'
$GapDeclarationPattern = '(?m)^- unit: `(?<unit>[^`]+)` \| gap_source: `(?<source>[^`]+)` \| type: `(?<type>[^`]+)` \| locator: `(?<locator>[^`]+)` \| gap: `(?<gap>[^`]+)`(?<extra>.*)$'
$UnitRowPattern = '(?m)^\| `(?<id>' + $UnitIdPattern + ')` \| (?<content>[^|]+) \| (?<prerequisite>[^|]+) \| (?<model>[^|]+) \| (?<output>[^|]+) \| (?<source>[^|]+) \|\s*$'
$RegistryEntryPattern = '(?m)^- `(?<code>[^`]+)` \| role: `(?<role>[^`]+)` \| (?<rest>.+)$'
$RegistryUrlPattern = '(?<label>.+?) — <(?<url>https?://[^>]+)>$'
$RegistryNotePattern = '(?<label>.+?) — (?<note>.+)$'

$SourceTypes = @('user-selected', 'online-tutorial', 'official-docs', 'physical-book', 'agent-fallback')
$GapSourceTypes = @('online-tutorial', 'official-docs', 'physical-book', 'agent-fallback')
$RegistryRoles = @('teaching-open', 'technical-authority', 'priority-evidence', 'physical-book', 'agent-fallback')
$SourceTypeToRole = @{
    'online-tutorial' = 'teaching-open'
    'official-docs'   = 'technical-authority'
    'physical-book'   = 'physical-book'
    'agent-fallback'  = 'agent-fallback'
}

function Resolve-SourceRegistryPath {
    param(
        [Parameter(Mandatory = $true)][string]$VaultRoot,
        [Parameter(Mandatory = $true)][string]$PluginRoot
    )
    # The Vault owns its source registry; the packaged file is only the format
    # paradigm and a fallback when the Vault has not registered one yet.
    $vaultRegistry = Join-Path $VaultRoot '20-学习主线\来源注册表.md'
    if (Test-Path -LiteralPath $vaultRegistry -PathType Leaf) { return $vaultRegistry }
    return (Join-Path $PluginRoot 'references\curriculum-sources.md')
}

function Get-MainlineFiles {
    param([Parameter(Mandatory = $true)][string]$VaultRoot)
    $mainlineDir = Join-Path $VaultRoot '20-学习主线'
    $files = @()
    if (Test-Path -LiteralPath $mainlineDir -PathType Container) {
        $files += Get-ChildItem -LiteralPath $mainlineDir -File -Filter '*.md'
        $stageDir = Join-Path $mainlineDir '10-阶段'
        if (Test-Path -LiteralPath $stageDir -PathType Container) {
            $files += Get-ChildItem -LiteralPath $stageDir -File -Filter '*.md'
        }
    }
    return @($files | Sort-Object Name)
}

function Get-MainlineText {
    param([Parameter(Mandatory = $true)][string]$VaultRoot)
    return (@(Get-MainlineFiles -VaultRoot $VaultRoot | ForEach-Object { Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName }) -join "`n")
}

function Get-RegistryEntry {
    param(
        [Parameter(Mandatory = $true)][string]$RegistryText,
        [Parameter(Mandatory = $true)][string]$Code
    )
    $matches = @([regex]::Matches($RegistryText, $RegistryEntryPattern) | Where-Object { $_.Groups['code'].Value -ceq $Code })
    if ($matches.Count -ne 1) {
        throw "Expected exactly one registry entry for $Code; found $($matches.Count)."
    }
    $match = $matches[0]
    $rest = $match.Groups['rest'].Value.Trim()
    $label = $rest
    $url = $null
    $note = $null
    $urlMatch = [regex]::Match($rest, $RegistryUrlPattern)
    $noteMatch = [regex]::Match($rest, $RegistryNotePattern)
    if ($urlMatch.Success) {
        $label = $urlMatch.Groups['label'].Value
        $url = $urlMatch.Groups['url'].Value
    }
    elseif ($noteMatch.Success) {
        $label = $noteMatch.Groups['label'].Value
        $note = $noteMatch.Groups['note'].Value
    }
    return [pscustomobject]@{
        code  = $Code
        role  = $match.Groups['role'].Value
        label = $label
        url   = $url
        note  = $note
    }
}

function Invoke-VaultStrict {
    param(
        [Parameter(Mandatory = $true)][string]$Vault,
        [Parameter(Mandatory = $true)][string]$ValidatorPath
    )
    $hostExe = (Get-Process -Id $PID).Path
    $raw = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $ValidatorPath -Vault $Vault -Strict
    $text = [string]::Join([Environment]::NewLine, @($raw))
    try { return ($text | ConvertFrom-Json) } catch { return $null }
}

# Validate one artifact category by reusing the single strict contract, so the
# per-artifact scripts never duplicate or drift from validate-vault.ps1.
function Invoke-ArtifactValidation {
    param(
        [Parameter(Mandatory = $true)][string]$Vault,
        [Parameter(Mandatory = $true)][string]$ValidatorPath,
        [Parameter(Mandatory = $true)][string[]]$Fields,
        [string[]]$WarningFields = @(),
        [string]$Path
    )
    $result = Invoke-VaultStrict -Vault $Vault -ValidatorPath $ValidatorPath
    if ($null -eq $result) {
        return [pscustomobject]@{ valid = $false; issues = @('strict validator output could not be parsed'); warnings = @() }
    }
    $issues = @()
    $warnings = @()
    foreach ($field in $Fields) { $issues += (Select-VaultIssue -Result $result -Field $field -Path $Path) }
    foreach ($field in $WarningFields) { $warnings += (Select-VaultIssue -Result $result -Field $field -Path $Path) }
    return [pscustomobject]@{ valid = ($issues.Count -eq 0); issues = $issues; warnings = $warnings }
}

function Select-VaultIssue {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Field,
        [string]$Path
    )
    if (-not $Result.PSObject.Properties[$Field]) { return @() }
    $out = @()
    foreach ($item in @($Result.$Field)) {
        if ($item -is [string]) {
            $out += $item
        }
        elseif ($item.PSObject.Properties['path']) {
            $itemPath = [string]$item.path
            if (-not $Path -or $itemPath -like "*$Path*") {
                $detail = if ($item.PSObject.Properties['issues']) { (@($item.issues) -join '; ') } else { '' }
                $out += ($itemPath + ': ' + $detail)
            }
        }
    }
    return $out
}

function Resolve-BoundVault {
    param([string]$Vault)
    if ([string]::IsNullOrWhiteSpace($Vault) -and -not [string]::IsNullOrWhiteSpace($env:TECH_LEARNING_VAULT)) {
        $Vault = $env:TECH_LEARNING_VAULT
    }
    if ([string]::IsNullOrWhiteSpace($Vault)) {
        $pointerPath = Join-Path $env:USERPROFILE '.agents\tech-learning-flow\vault-path.txt'
        if (Test-Path -LiteralPath $pointerPath -PathType Leaf) {
            $Vault = [IO.File]::ReadAllText($pointerPath, [Text.Encoding]::UTF8).Trim()
        }
    }
    if ([string]::IsNullOrWhiteSpace($Vault)) {
        throw 'No vault bound. Pass -Vault or initialize one with init-vault.ps1.'
    }
    return $Vault
}

function Write-ArtifactValidation {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [string]$Vault,
        [string]$Path,
        [Parameter(Mandatory = $true)][string]$ValidatorPath,
        [Parameter(Mandatory = $true)][string[]]$Fields,
        [string[]]$WarningFields = @()
    )
    $Vault = Resolve-BoundVault -Vault $Vault
    $res = Invoke-ArtifactValidation -Vault $Vault -ValidatorPath $ValidatorPath -Fields $Fields -WarningFields $WarningFields -Path $Path
    $out = [pscustomobject]@{ kind = $Kind; vault = $Vault; valid = $res.valid; issues = @($res.issues); warnings = @($res.warnings) }
    $out | ConvertTo-Json -Depth 6
    if (-not $out.valid) { exit 1 }
}
