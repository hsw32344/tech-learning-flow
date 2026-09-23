# Domain artifact rules for the tech-learning Vault.
#
# These rules encode Vault business meaning (logs, atomic notes, review banks,
# queue, templates, wiki links). Infrastructure helpers live in
# validation-common.ps1; format and registry parsing live in vault-contract.ps1.

. (Join-Path $PSScriptRoot 'validation-common.ps1')


function Get-VaultContentFiles {
    param([Parameter(Mandatory = $true)][string]$Root)
    $stack = [Collections.Generic.Stack[string]]::new()
    $stack.Push($Root)
    while ($stack.Count -gt 0) {
        foreach ($item in Get-ChildItem -LiteralPath $stack.Pop() -Force) {
            if ($item.PSIsContainer) {
                if ($item.Name -in @('.venv', 'venv', 'node_modules', '__pycache__', '.git', '.obsidian', '.study-state', 'exports', '97-临时') -or
                    $item.Name -like '.tmp*' -or $item.Name -like '.codex*' -or
                    ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
                $stack.Push($item.FullName)
            }
            else { $item }
        }
    }
}

function Test-WikiTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$VaultRoot,
        [Parameter(Mandatory = $true)]$FileNames,
        [Parameter(Mandatory = $true)]$ContentPaths,
        [Parameter(Mandatory = $true)][object[]]$ContentFiles
    )
    $targetText = [Uri]::UnescapeDataString($Target.Trim())
    $variants = @($targetText)
    if (-not $targetText.EndsWith('.md', [StringComparison]::OrdinalIgnoreCase)) { $variants += $targetText + '.md' }
    foreach ($variant in $variants) {
        foreach ($base in @((Split-Path -Parent $Source), $VaultRoot)) {
            try { $candidate = [IO.Path]::GetFullPath((Join-Path $base $variant)) } catch { continue }
            if ($ContentPaths.ContainsKey($candidate)) { return $true }
        }
        # Obsidian short filenames resolve within the Vault, not only the note's folder.
        if ($variant -notmatch '[\\/]' -and $FileNames.ContainsKey($variant) -and $FileNames[$variant].Count -eq 1) { return $true }
        # A shortened folder-qualified link must resolve to one suffix match.
        $suffix = [IO.Path]::DirectorySeparatorChar + $variant.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $matches = @($ContentFiles | Where-Object { $_.FullName.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase) })
        if ($matches.Count -eq 1) { return $true }
    }
    return $false
}

function Test-NoteBodyNonEmpty {
    param([Parameter(Mandatory = $true)][string]$Content)
    $body = $Content
    $frontmatter = [regex]::Match($Content, '(?ms)\A---\s*\r?\n.*?\r?\n---\s*\r?\n')
    if ($frontmatter.Success) { $body = $Content.Substring($frontmatter.Length) }
    foreach ($line in @($body -split '\r?\n')) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        return $true
    }
    return $false
}

$script:LogKindTypes = @{
    'learning' = 'learning-log'
    'work'     = 'work-log'
    'decision' = 'decision-log'
}

function Get-LogNoteIssues {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$BaseName,
        [Parameter(Mandatory = $true)][string]$Kind
    )
    $issues = @()
    $expectedType = $script:LogKindTypes[$Kind]
    $dateMatch = [regex]::Match($BaseName, '^(?<date>\d{4}-\d{2}-\d{2})-(?<topic>.+)$')
    if (-not $dateMatch.Success -or -not $dateMatch.Groups['topic'].Value.Trim()) {
        $issues += 'filename must be YYYY-MM-DD-<topic>.md'
    }
    $type = Read-FrontmatterScalar -Content $Content -Key 'type'
    if ($type -ne $expectedType) {
        $issues += "type must be $expectedType (got '$type')"
    }
    $date = Read-FrontmatterScalar -Content $Content -Key 'date'
    if ($date -notmatch '^\d{4}-\d{2}-\d{2}$') {
        $issues += 'missing or invalid date: must be YYYY-MM-DD'
    }
    elseif ($dateMatch.Success -and $date -ne $dateMatch.Groups['date'].Value) {
        $issues += "date '$date' does not match the filename date '$($dateMatch.Groups['date'].Value)'"
    }
    if ($Kind -eq 'decision') {
        if ($Content -match '(?m)^duration_minutes\s*:') {
            $issues += 'decision log must not declare duration_minutes'
        }
    }
    else {
        $duration = Read-FrontmatterScalar -Content $Content -Key 'duration_minutes'
        if (-not $duration) {
            $issues += 'missing property: duration_minutes'
        }
        elseif ($duration -ne '时间缺失' -and $duration -notmatch '^[1-9][0-9]*$') {
            $issues += "duration_minutes must be a positive integer or 时间缺失 (got '$duration')"
        }
    }
    if (-not (Test-NoteBodyNonEmpty -Content $Content)) {
        $issues += 'note body must not be empty'
    }
    return $issues
}

function Get-ReviewQueueIssues {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string[]]$Headings
    )
    $issues = @()
    if ($Content -notmatch '(?m)^type:\s*review-queue\s*$') {
        $issues += 'type must be review-queue'
    }
    foreach ($heading in $Headings) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    return $issues
}

function Get-ReviewTemplateIssues {
    param([Parameter(Mandatory = $true)][string]$Content)
    $issues = @()
    foreach ($heading in @('## 题库类型与关联', '## 复习记录')) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    foreach ($property in @('review_kind', 'primary_atomic', 'related_atomics', 'task_units')) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
            $issues += "missing property: $property"
        }
    }
    if ($Content -match '(?m)^## 建议复习日期\s*$') {
        $issues += 'review dates belong in the derived queue'
    }
    return $issues
}

function Get-AtomicNoteIssues {
    param([Parameter(Mandatory = $true)][string]$Content)
    $issues = @()
    $codeBlocks = [regex]::Matches($Content, '(?ms)^```[^\r\n]*\r?\n(?<code>.*?)^```\s*$')
    for ($blockIndex = 0; $blockIndex -lt $codeBlocks.Count; $blockIndex++) {
        if (-not $codeBlocks[$blockIndex].Groups['code'].Value.Trim()) {
            $issues += "empty code block $($blockIndex + 1)"
        }
    }
    return $issues
}

function Get-AtomicGranularityFindings {
    param([Parameter(Mandatory = $true)][string]$Content)
    $findings = @()
    if (-not (Test-NoteBodyNonEmpty -Content $Content)) {
        $findings += 'note body must not be empty'
    }
    return $findings
}

function Get-ReviewBankAnalysis {
    param([Parameter(Mandatory = $true)][string]$Content)
    $issues = @()
    if ($Content -notmatch '(?m)^## 复习记录\s*$') {
        $issues += 'missing heading: ## 复习记录'
    }
    $reviewKind = Read-FrontmatterScalar -Content $Content -Key 'review_kind'
    $primaryAtomic = Read-FrontmatterScalar -Content $Content -Key 'primary_atomic'
    $relatedAtomics = @(Read-FrontmatterList -Content $Content -Key 'related_atomics')
    $taskUnits = @(Read-FrontmatterList -Content $Content -Key 'task_units')
    $allowedExtraReviewKinds = @('boundary-comparison', 'error-diagnosis', 'integration-transfer', 'task-performance', 'retention')
    if ($reviewKind -eq 'atomic-mirror') {
        if (-not $primaryAtomic) { $issues += 'atomic-mirror requires primary_atomic' }
        if ($relatedAtomics.Count -ne 0) { $issues += 'atomic-mirror requires related_atomics: []' }
    }
    elseif ($reviewKind -notin $allowedExtraReviewKinds) {
        $issues += 'review_kind must be atomic-mirror or a permitted extra kind'
    }
    elseif ($relatedAtomics.Count -eq 0 -and $taskUnits.Count -eq 0) {
        $issues += 'extra review requires related_atomics or task_units'
    }
    return [pscustomobject]@{
        issues          = @($issues)
        review_kind     = $reviewKind
        primary_atomic  = $primaryAtomic
        related_atomics = @($relatedAtomics)
        task_units      = @($taskUnits)
    }
}

function Get-JobNoteIssues {
    param([Parameter(Mandatory = $true)][string]$Content)
    $issues = @()
    if ($Content -notmatch '(?m)^type:\s*job-requirement-analysis\s*$') {
        $issues += 'type must be job-requirement-analysis'
    }
    foreach ($heading in @('## 来源与边界', '## 原始要求', '## 结构化需求', '## 主线映射', '## 差距与优先级', '## 变更建议', '## 写入状态')) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    return $issues
}

function Get-JobTemplateIssues {
    param([Parameter(Mandatory = $true)][string]$Content)
    $issues = @()
    foreach ($heading in @('## 来源与边界', '## 原始要求', '## 结构化需求', '## 主线映射', '## 差距与优先级', '## 变更建议', '## 写入状态')) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    return $issues
}

