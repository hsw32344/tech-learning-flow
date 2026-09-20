# Shared Vault contract definitions for the tech-learning Vault.
#
# Dot-source this file from every script that parses the mainline or the source
# registry. It owns the canonical declaration / unit-row / registry FORMAT and
# the allowed type and role values, so no two scripts can drift apart. Callers
# decide whether to enforce the enums; they must not redefine these patterns.

. (Join-Path $PSScriptRoot 'validation-common.ps1')

$UnitIdPattern = '[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-\d{2}'
$PrimaryDeclarationPattern = '(?m)^- unit: `(?<unit>[^`]+)` \| primary_source: `(?<source>[^`]+)` \| type: `(?<type>[^`]+)` \| locator: `(?<locator>[^`]+)`(?<extra>.*)$'
$GapDeclarationPattern = '(?m)^- unit: `(?<unit>[^`]+)` \| gap_source: `(?<source>[^`]+)` \| type: `(?<type>[^`]+)` \| locator: `(?<locator>[^`]+)` \| gap: `(?<gap>[^`]+)`(?<extra>.*)$'
$UnitRowPattern = '(?m)^\| `(?<id>' + $UnitIdPattern + ')` \| (?<content>[^|]+) \| (?<prerequisite>[^|]+) \| (?<model>[^|]+) \| (?<output>[^|]+) \| (?<source>[^|]+) \|\s*$'
$RegistryEntryPattern = '(?m)^- `(?<code>[^`]+)` \| role: `(?<role>[^`]+)` \| (?<rest>.+)$'
$RegistryUrlPattern = '(?<label>.+?) — <(?<url>https?://[^>]+)>$'
$RegistryNotePattern = '(?<label>.+?) — (?<note>.+)$'

$SourceTypes = @('user-selected', 'online-tutorial', 'official-docs', 'physical-book', 'agent-fallback')
$GapSourceTypes = @('online-tutorial', 'official-docs', 'physical-book', 'agent-fallback')
$RegistryRoles = @('teaching-open', 'technical-authority', 'physical-book', 'agent-fallback')
$SourceTypeToRole = @{
    'online-tutorial' = 'teaching-open'
    'official-docs'   = 'technical-authority'
    'physical-book'   = 'physical-book'
    'agent-fallback'  = 'agent-fallback'
}

function Resolve-SourceRegistryPath {
    param(
        [Parameter(Mandatory = $true)][string]$VaultRoot,
        [string]$PluginRoot
    )
    return (Join-Path $VaultRoot '20-学习主线\资料来源注册表.md')
}

function Get-TaskRegistryText {
    param([Parameter(Mandatory = $true)][string]$VaultRoot)
    $path = Join-Path $VaultRoot '20-学习主线\20-任务包注册表.md'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Task package registry not found: $path"
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $path
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

# Every strict-result bucket maps to one stable code, category, and severity.
# Thin validators select diagnostics through this table instead of string
# matching, so no bucket can be silently dropped or lose its reason.
$script:VaultIssueMeta = @{
    'missing_required'                = @{ code = 'MISSING_REQUIRED_PATH';    category = 'structure';   severity = 'error' }
    'legacy_paths_present'            = @{ code = 'LEGACY_PATH_PRESENT';       category = 'structure';   severity = 'error' }
    'non_markdown_note_files'         = @{ code = 'NON_MARKDOWN_NOTE_FILE';    category = 'structure';   severity = 'error' }
    'duplicate_root_prefixes'         = @{ code = 'DUPLICATE_ROOT_PREFIX';     category = 'structure';   severity = 'error' }
    'duplicate_basenames'             = @{ code = 'DUPLICATE_BASENAME';        category = 'structure';   severity = 'error' }
    'broken_links'                    = @{ code = 'BROKEN_LINK';               category = 'links';       severity = 'error' }
    'invalid_daily_reviews'           = @{ code = 'INVALID_DAILY_REVIEW';      category = 'daily';       severity = 'error' }
    'daily_template_issues'           = @{ code = 'DAILY_TEMPLATE_ISSUE';      category = 'daily';       severity = 'error' }
    'duplicate_review_dates'          = @{ code = 'DUPLICATE_REVIEW_DATE';     category = 'daily';       severity = 'error' }
    'invalid_weekly_notes'            = @{ code = 'INVALID_WEEKLY_NOTE';       category = 'weekly';      severity = 'error' }
    'weekly_template_issues'          = @{ code = 'WEEKLY_TEMPLATE_ISSUE';     category = 'weekly';      severity = 'error' }
    'homepage_issues'                 = @{ code = 'HOMEPAGE_ISSUE';            category = 'route';       severity = 'error' }
    'mainline_issues'                 = @{ code = 'MAINLINE_ISSUE';            category = 'route';       severity = 'error' }
    'source_contract_issues'          = @{ code = 'SOURCE_CONTRACT_ISSUE';     category = 'sources';     severity = 'error' }
    'review_queue_issues'             = @{ code = 'REVIEW_QUEUE_ISSUE';        category = 'queue';       severity = 'error' }
    'review_template_issues'          = @{ code = 'REVIEW_TEMPLATE_ISSUE';     category = 'queue';       severity = 'error' }
    'job_requirement_template_issues' = @{ code = 'JOB_TEMPLATE_ISSUE';        category = 'jobnote';     severity = 'error' }
    'invalid_job_requirement_notes'   = @{ code = 'INVALID_JOB_NOTE';          category = 'jobnote';     severity = 'error' }
    'invalid_atomic_notes'            = @{ code = 'INVALID_ATOMIC_NOTE';       category = 'atomic';      severity = 'error' }
    'duplicate_atomic_ids'            = @{ code = 'DUPLICATE_ATOMIC_ID';       category = 'atomic';      severity = 'error' }
    'invalid_atomic_term_refs'        = @{ code = 'INVALID_ATOMIC_TERM_REF';   category = 'atomic';      severity = 'error' }
    'atomic_granularity_issues'       = @{ code = 'ATOMIC_GRANULARITY';        category = 'atomic';      severity = 'error' }
    'invalid_review_banks'            = @{ code = 'INVALID_REVIEW_BANK';       category = 'reviewbank';  severity = 'error' }
    'duplicate_atomic_mirrors'        = @{ code = 'DUPLICATE_ATOMIC_MIRROR';   category = 'reviewbank';  severity = 'error' }
    'orphan_review_atomic_refs'       = @{ code = 'ORPHAN_REVIEW_ATOMIC_REF';  category = 'reviewbank';  severity = 'error' }
    'atomic_mirror_gaps'              = @{ code = 'ATOMIC_MIRROR_GAP';         category = 'reviewbank';  severity = 'warning' }
    'terminology_issues'              = @{ code = 'TERMINOLOGY_ISSUE';         category = 'terminology'; severity = 'error' }
    'orphan_parent_terms'             = @{ code = 'ORPHAN_PARENT_TERM';        category = 'terminology'; severity = 'error' }
    'unregistered_term_surfaces'      = @{ code = 'UNREGISTERED_TERM_SURFACE'; category = 'terminology'; severity = 'warning' }
    'deprecated_alias_hits'           = @{ code = 'DEPRECATED_ALIAS_HIT';      category = 'terminology'; severity = 'warning' }
    'legacy_references'               = @{ code = 'LEGACY_REFERENCE';          category = 'legacy';      severity = 'warning' }
    'schema_defects'                  = @{ code = 'SCHEMA_DEFECT';             category = 'structure';   severity = 'error' }
    'missing_change_target'           = @{ code = 'MISSING_CHANGE_TARGET';     category = 'structure';   severity = 'error' }
    'inconsistent_change'             = @{ code = 'INCONSISTENT_CHANGE';       category = 'structure';   severity = 'error' }
    'missing_change_identity'         = @{ code = 'MISSING_CHANGE_IDENTITY';   category = 'structure';   severity = 'error' }
    'write_surface_violation'         = @{ code = 'WRITE_SURFACE_VIOLATION';   category = 'structure';   severity = 'error' }
}
$script:VaultStringPathFields = @(
    'missing_required', 'legacy_paths_present', 'non_markdown_note_files', 'legacy_references'
)

# Field groups for the unified batch entry. A change batch runs one strict
# scan and reports each selected kind separately; the common group is
# vault-level structure and always blocks, regardless of the selected kinds.
$script:VaultKindFields = @{
    'route'       = @{ errorFields = @('mainline_issues', 'homepage_issues', 'source_contract_issues'); warningFields = @() }
    'terminology' = @{ errorFields = @('terminology_issues', 'orphan_parent_terms'); warningFields = @('unregistered_term_surfaces', 'deprecated_alias_hits') }
    'homepage'    = @{ errorFields = @('homepage_issues'); warningFields = @() }
    'topicmap'    = @{ errorFields = @('terminology_issues'); warningFields = @('unregistered_term_surfaces') }
    'daily'       = @{ errorFields = @('invalid_daily_reviews', 'daily_template_issues', 'duplicate_review_dates'); warningFields = @() }
    'weekly'      = @{ errorFields = @('invalid_weekly_notes', 'weekly_template_issues'); warningFields = @() }
    'atomic'      = @{ errorFields = @('invalid_atomic_notes', 'duplicate_atomic_ids', 'invalid_atomic_term_refs', 'atomic_granularity_issues'); warningFields = @() }
    'reviewbank'  = @{ errorFields = @('invalid_review_banks', 'duplicate_atomic_mirrors', 'orphan_review_atomic_refs'); warningFields = @('atomic_mirror_gaps') }
    'queue'       = @{ errorFields = @('review_queue_issues', 'review_template_issues'); warningFields = @() }
    'jobnote'     = @{ errorFields = @('invalid_job_requirement_notes', 'job_requirement_template_issues'); warningFields = @() }
    'links'       = @{ errorFields = @('broken_links'); warningFields = @() }
}
$script:VaultCommonFields = @(
    'schema_defects', 'missing_required', 'legacy_paths_present', 'non_markdown_note_files',
    'duplicate_root_prefixes', 'duplicate_basenames', 'missing_change_target', 'inconsistent_change',
    'missing_change_identity', 'write_surface_violation'
)

# Exact path matching replaced the old "*fragment*" filter: "a.md" must never
# match "extra-a.md", while a directory target still matches its descendants.
function Test-VaultPathMatch {
    param(
        [string]$ItemPath,
        [string]$Target,
        [string]$VaultRoot
    )
    if ([string]::IsNullOrWhiteSpace($ItemPath) -or [string]::IsNullOrWhiteSpace($Target)) { return $false }
    $targetText = ConvertTo-NormalizedPath $Target
    if ([string]::IsNullOrWhiteSpace($targetText)) { return $false }
    if (-not [IO.Path]::IsPathRooted($targetText)) {
        if ([string]::IsNullOrWhiteSpace($VaultRoot)) { return $false }
        $targetText = Join-Path $VaultRoot $targetText
    }
    $itemText = ConvertTo-NormalizedPath $ItemPath
    if (-not [IO.Path]::IsPathRooted($itemText)) {
        if ([string]::IsNullOrWhiteSpace($VaultRoot)) { return $false }
        $itemText = Join-Path $VaultRoot $itemText
    }
    try {
        $targetFull = ConvertTo-NormalizedPath ([IO.Path]::GetFullPath($targetText))
        $itemFull = ConvertTo-NormalizedPath ([IO.Path]::GetFullPath($itemText))
    }
    catch { return $false }
    if ($itemFull.Equals($targetFull, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $itemFull.StartsWith($targetFull + '\', [StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-VaultDiagnostic {
    param(
        [Parameter(Mandatory = $true)]$Item,
        [Parameter(Mandatory = $true)][string]$Field
    )
    $meta = $script:VaultIssueMeta[$Field]
    $severity = if ($meta) { $meta.severity } else { 'error' }
    $category = if ($meta) { $meta.category } else { 'unknown' }
    $code = if ($meta) { $meta.code } else { 'UNKNOWN_ISSUE_FIELD' }
    $messageParts = @()
    $paths = @()
    if ($Item -is [string]) {
        $messageParts += $Item
        if ($Field -in $script:VaultStringPathFields) { $paths += $Item }
    }
    else {
        if ($Item.PSObject.Properties['path'] -and $Item.path) { $paths += [string]$Item.path }
        if ($Item.PSObject.Properties['paths']) {
            $paths += @($Item.paths | ForEach-Object { [string]$_ } | Where-Object { $_ })
        }
        if ($Item.PSObject.Properties['source'] -and $Item.source) { $paths += [string]$Item.source }
        if ($Item.PSObject.Properties['issues']) { $messageParts += (@($Item.issues) -join '; ') }
        elseif ($Item.PSObject.Properties['issue']) { $messageParts += [string]$Item.issue }
        elseif ($Item.PSObject.Properties['message']) { $messageParts += [string]$Item.message }
        foreach ($key in @('atomic_id', 'term_id', 'target', 'prefix', 'basename', 'id', 'parent', 'alias', 'canonical', 'surface', 'value', 'items')) {
            if (-not $Item.PSObject.Properties[$key]) { continue }
            $value = $Item.$key
            if ($value -isnot [string] -and $value -is [System.Collections.IEnumerable]) {
                $value = (@($value) -join ', ')
            }
            if ("$value") { $messageParts += ($key + '=' + $value) }
        }
    }
    $message = @(
        $messageParts | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ }
    ) -join '; '
    if (-not $message) {
        if ($paths.Count -gt 0) { $message = ($paths -join ', ') }
        else {
            $message = 'unrecognized issue structure: ' + ($Item | ConvertTo-Json -Compress -Depth 6)
            $severity = 'error'
            $code = 'UNKNOWN_ISSUE_SHAPE'
            $category = 'unknown'
        }
    }
    return [pscustomobject]@{
        field    = $Field
        code     = $code
        severity = $severity
        category = $category
        paths    = @($paths)
        message  = $message
    }
}

function Get-VaultFieldDiagnostics {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Field
    )
    if (-not $Result.PSObject.Properties[$Field]) {
        $meta = $script:VaultIssueMeta[$Field]
        return @([pscustomobject]@{
            field    = $Field
            code     = 'MISSING_RESULT_FIELD'
            severity = 'error'
            category = if ($meta) { $meta.category } else { 'unknown' }
            paths    = @()
            message  = "validator result lacks expected field: $Field"
        })
    }
    $out = @()
    foreach ($item in @($Result.$Field)) {
        if ($null -eq $item) { continue }
        $out += ConvertTo-VaultDiagnostic -Item $item -Field $Field
    }
    return $out
}

# Diagnostics without a path are global and always survive a -Path filter:
# a selected artifact must never hide a common error.
function Test-DiagnosticPathMatch {
    param(
        [Parameter(Mandatory = $true)]$Diagnostic,
        [Parameter(Mandatory = $true)][string[]]$Targets,
        [string]$VaultRoot
    )
    if ($Diagnostic.paths.Count -eq 0) { return $true }
    foreach ($path in $Diagnostic.paths) {
        foreach ($target in $Targets) {
            if (Test-VaultPathMatch -ItemPath $path -Target $target -VaultRoot $VaultRoot) { return $true }
        }
    }
    return $false
}

function Select-VaultDiagnostic {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [string[]]$Fields = @(),
        [string]$VaultRoot,
        [string]$Path
    )
    $out = @()
    foreach ($field in $Fields) {
        $out += Get-VaultFieldDiagnostics -Result $Result -Field $field
    }
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $out = @($out | Where-Object {
                Test-DiagnosticPathMatch -Diagnostic $_ -Targets @($Path) -VaultRoot $VaultRoot
            })
    }
    return $out
}

function Format-VaultDiagnostic {
    param([Parameter(Mandatory = $true)]$Diagnostic)
    if ($Diagnostic.paths.Count -gt 0) {
        return (($Diagnostic.paths -join ', ') + ': ' + $Diagnostic.message)
    }
    return [string]$Diagnostic.message
}

function New-VaultCheckGroup {
    param([object[]]$Diagnostics = @())
    $errors = @($Diagnostics | Where-Object { $_.severity -eq 'error' })
    $warnings = @($Diagnostics | Where-Object { $_.severity -eq 'warning' })
    return [pscustomobject]@{
        valid       = ($errors.Count -eq 0)
        issues      = @($errors | ForEach-Object { Format-VaultDiagnostic -Diagnostic $_ })
        warnings    = @($warnings | ForEach-Object { Format-VaultDiagnostic -Diagnostic $_ })
        diagnostics = @($Diagnostics)
    }
}
function Invoke-VaultStrict {
    param(
        [Parameter(Mandatory = $true)][string]$Vault,
        [Parameter(Mandatory = $true)][string]$ValidatorPath
    )
    $hostExe = (Get-Process -Id $PID).Path
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $hostExe
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $startInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    foreach ($argument in @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ValidatorPath, '-Vault', $Vault, '-Strict', '-Diagnostics')) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $text = ([string]$stdout).Trim()
    $parsed = $null
    try { $parsed = $text | ConvertFrom-Json } catch { $parsed = $null }
    $failed = [pscustomobject]@{
        valid          = $false
        runtime_error  = $true
        exit_code      = $process.ExitCode
        stdout_excerpt = $text
        stderr_excerpt = ([string]$stderr).Trim()
    }
    if ($null -eq $parsed) { return $failed }
    if (-not $parsed.PSObject.Properties['valid']) { return $failed }
    # A non-zero exit code together with valid=true is contradictory output and
    # must never be interpreted as a pass.
    if ($process.ExitCode -ne 0 -and $parsed.valid) { return $failed }
    Add-Member -InputObject $parsed -NotePropertyName 'runtime_error' -NotePropertyValue $false -Force
    Add-Member -InputObject $parsed -NotePropertyName 'exit_code' -NotePropertyValue $process.ExitCode -Force
    return $parsed
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
