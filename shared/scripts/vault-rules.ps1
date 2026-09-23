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

function Get-DailyReviewIssues {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$BaseName
    )
    $issues = @()
    if ($BaseName -notmatch '^(\d{4}-\d{2}-\d{2}) 学习回顾$') {
        $issues += 'filename must be YYYY-MM-DD 学习回顾.md'
    }
    foreach ($heading in @('## 今日学习过程', '## 今日形成的理解', '## 今日知识沉淀', '## 今日遇到的问题')) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    if ($Content -match '(?m)^## (仍待确认|下一次复习)\s*$') {
        $issues += 'legacy ingestion or review-schedule heading'
    }
    return $issues
}

function Test-DailyReviewSourceSection {
    param([Parameter(Mandatory = $true)][string]$Content)
    return ($Content -match '(?m)^## 实际使用的学习资料\s*$')
}

function Get-DailyTemplateIssues {
    param([Parameter(Mandatory = $true)][string]$Content)
    $issues = @()
    foreach ($heading in @('## 今日学习过程', '## 实际使用的学习资料', '## 今日形成的理解', '## 今日知识沉淀', '## 今日遇到的问题')) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    foreach ($field in @('主学习源代码', '实际访问 URL，或实体教材精确版次', '课程/文档章节与小节', '实际起点 → 停留位置', '可访问事实', '缺口补充源', 'Agent 兜底')) {
        if ($Content -notmatch [regex]::Escape($field)) {
            $issues += "missing learning-source field: $field"
        }
    }
    return $issues
}

function Get-WeeklyNoteIssues {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$BaseName,
        [Parameter(Mandatory = $true)][string[]]$Properties,
        [Parameter(Mandatory = $true)][string[]]$Headings,
        [Parameter(Mandatory = $true)][string[]]$StatusEnum
    )
    $issues = @()
    if ($BaseName -notmatch '^\d{4}-W\d{2}$') {
        $issues += 'filename must be YYYY-Www.md'
    }
    foreach ($property in $Properties) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
            $issues += "missing property: $property"
        }
    }
    if ($Content -match '(?m)^status:\s*(.+?)\s*$') {
        $weeklyStatus = $Matches[1].Trim()
        if ($weeklyStatus -notin @($StatusEnum)) {
            $issues += "invalid status: $weeklyStatus"
        }
    }
    foreach ($heading in $Headings) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    # 日志只做字面记录：不绑定计划、配额、排期或预期产物，因此不校验任何计划字段。
    if ($Content -match '(?m)^(focus|focus_status)\s*:' -or
        $Content -match '(?m)^## 本周(唯一)?重点\s*$' -or
        $Content -match '(?m)^## (问题与待验证|里程碑进度)\s*$') {
        $issues += 'legacy weekly progress state'
    }
    return $issues
}

function Get-WeeklyTemplateIssues {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string[]]$Properties,
        [Parameter(Mandatory = $true)][string[]]$Headings
    )
    $issues = @()
    foreach ($heading in $Headings) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    foreach ($property in $Properties) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
            $issues += "missing property: $property"
        }
    }
    if ($Content -match '(?m)^## (问题与待验证|里程碑进度)\s*$') {
        $issues += 'legacy derived-progress heading'
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
    $body = $Content
    $frontmatter = [regex]::Match($Content, '(?ms)\A---\s*\r?\n.*?\r?\n---\s*\r?\n')
    if ($frontmatter.Success) { $body = $Content.Substring($frontmatter.Length) }
    $hasBody = $false
    foreach ($line in @($body -split '\r?\n')) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $hasBody = $true
        break
    }
    if (-not $hasBody) { $findings += 'note body must not be empty' }
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

