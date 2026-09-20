# Validates one learning snapshot against the source-neutral contract in
# 25-资源区/学习快照/学习快照使用说明.md. Structural validation is not semantic review.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File validate-snapshot.ps1 `
#     -Snapshot "<vault-root>\25-资源区/学习快照\<unit-id> 学习快照.md"
#   or a vault-relative path (resolved against the default Vault):
#     ... -Snapshot "25-资源区/学习快照\<unit-id> 学习快照.md"
#
# Outputs JSON with `valid`. Exit 1 when invalid, 2 on usage error.
# The snapshot directory is attachment-style and independent of the main
# vault validator; run this explicitly after writing or updating a snapshot.

param(
    [string]$Snapshot
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

if (-not $Snapshot) {
    Write-Output 'Usage: validate-snapshot.ps1 -Snapshot "<任务包ID> 学习快照.md path>"'
    exit 2
}

# Resolve a vault-relative path such as "25-资源区/学习快照/<unit-id> 学习快照.md".
if (-not (Test-Path -LiteralPath $Snapshot -PathType Leaf)) {
    $defaultVault = $env:TECH_LEARNING_VAULT
    if ([string]::IsNullOrWhiteSpace($defaultVault)) {
        $pointerPath = Join-Path $env:USERPROFILE '.agents\tech-learning-flow\vault-path.txt'
        if (Test-Path -LiteralPath $pointerPath -PathType Leaf) {
            $defaultVault = [IO.File]::ReadAllText($pointerPath, [Text.Encoding]::UTF8).Trim()
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($defaultVault)) {
        $candidate = Join-Path $defaultVault $Snapshot
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $Snapshot = $candidate
        }
    }
}

if (-not (Test-Path -LiteralPath $Snapshot -PathType Leaf)) {
    Write-Output "Snapshot file not found: $Snapshot"
    exit 2
}

$resolved = (Resolve-Path -LiteralPath $Snapshot).Path
$name = Split-Path -Leaf $resolved
$content = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolved

$issues = @()
$sliceIds = @()

# 契约 1：快照必须位于 Vault 的 25-资源区/学习快照/ 目录（附件式落地约定）
if ((Split-Path -Leaf (Split-Path -Parent $resolved)) -ne '学习快照') {
    $issues += "snapshot must live in the vault 25-资源区/学习快照/ directory (got folder: '$(Split-Path -Leaf (Split-Path -Parent $resolved))')"
}

function Get-FmScalar {
    param([string]$Body, [string]$Property)
    $match = [regex]::Match(
        $Body,
        "(?m)^$([regex]::Escape($Property))\s*:\s*(?<value>[^#\r\n]*?)(?:\s+#.*)?\s*$"
    )
    if ($match.Success) { return $match.Groups['value'].Value.Trim().Trim('"').Trim("'") }
    return $null
}

function Get-SectionBody {
    param([string]$Content, [string]$Section)
    $pattern = '(?ms)^## ' + [regex]::Escape($Section) + '\s*\r?\n(?<body>.*?)(?=^## |\z)'
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) { return $match.Groups['body'].Value }
    return $null
}

# ---- 契约 1：命名与位置 ----
if ($name -notmatch ' 学习快照\.md$') {
    $issues += "filename must end with ' 学习快照.md': $name"
}
$unitFromName = $name -replace ' 学习快照\.md$', ''

# ---- 契约 2：frontmatter ----
$fmContract = $null
$frontmatterMatch = [regex]::Match($content, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---\s*\r?\n')
if (-not $frontmatterMatch.Success) {
    $issues += 'missing YAML frontmatter'
}
else {
    $fmBody = $frontmatterMatch.Groups['body'].Value
    $fmType = Get-FmScalar $fmBody 'type'
    $fmUnit = Get-FmScalar $fmBody 'unit'
    $fmPrimary = Get-FmScalar $fmBody 'primary_source'
    $fmSourceRole = Get-FmScalar $fmBody 'source_role'
    $fmPacketStatus = Get-FmScalar $fmBody 'source_packet_status'
    $fmVerifiedAt = Get-FmScalar $fmBody 'source_verified_at'
    $fmContract = Get-FmScalar $fmBody 'contract'
    $fmUpdated = Get-FmScalar $fmBody 'updated'

    if ($fmType -ne 'learning-snapshot') {
        $issues += "type must be learning-snapshot (got '$fmType')"
    }
    if (-not $fmUnit) {
        $issues += 'frontmatter missing unit'
    }
    elseif ($unitFromName -and $fmUnit -ne $unitFromName) {
        $issues += "frontmatter unit '$fmUnit' does not match filename unit '$unitFromName'"
    }
    if (-not $fmPrimary) {
        $issues += 'frontmatter missing primary_source'
    }
    $allowedSourceRoles = @('teaching-open', 'technical-authority', 'physical-book', 'agent-fallback')
    if ($fmSourceRole -notin $allowedSourceRoles) {
        $issues += "source_role must be one of: $($allowedSourceRoles -join ' / ') (got '$fmSourceRole')"
    }
    $allowedPacketStatuses = @('verified', 'partial', 'blocked')
    if ($fmPacketStatus -notin $allowedPacketStatuses) {
        $issues += "source_packet_status must be one of: $($allowedPacketStatuses -join ' / ') (got '$fmPacketStatus')"
    }
    elseif ($fmPacketStatus -eq 'verified' -and $fmSourceRole -eq 'agent-fallback' -and $fmVerifiedAt -ne '无/不适用') {
        $issues += "source_verified_at must be 无/不适用 for agent-fallback material (got '$fmVerifiedAt')"
    }
    elseif ($fmPacketStatus -eq 'verified' -and $fmSourceRole -ne 'agent-fallback' -and $fmVerifiedAt -notmatch '^\d{4}-\d{2}-\d{2}$') {
        $issues += "source_verified_at must be YYYY-MM-DD for verified Markdown source packets (got '$fmVerifiedAt')"
    }
    elseif ($fmPacketStatus -in @('partial', 'blocked') -and $fmVerifiedAt -notmatch '^(\d{4}-\d{2}-\d{2}|未知/待核验)$') {
        $issues += "source_verified_at must be YYYY-MM-DD or 未知/待核验 for partial/blocked Markdown source packets (got '$fmVerifiedAt')"
    }
    if ($fmPrimary -eq 'AGENT-FALLBACK' -and $fmSourceRole -ne 'agent-fallback') {
        $issues += "AGENT-FALLBACK primary_source requires source_role agent-fallback (got '$fmSourceRole')"
    }
    elseif ($fmPrimary -ne 'AGENT-FALLBACK' -and $fmSourceRole -eq 'agent-fallback') {
        $issues += "source_role agent-fallback requires primary_source AGENT-FALLBACK (got '$fmPrimary')"
    }
    if (-not $fmUpdated) {
        $issues += 'frontmatter missing updated'
    }
    if ($fmContract -and $fmContract -notin @('source-neutral-v2', 'mixed-v2')) {
        $issues += "contract must be source-neutral-v2 or mixed-v2 when present (got '$fmContract')"
    }
    elseif ($fmUpdated -notmatch '^\d{4}-\d{2}-\d{2}$') {
        $issues += "updated must be YYYY-MM-DD (got '$fmUpdated')"
    }
}

# ---- 契约 3：六大区块固定顺序 ----
$requiredSections = @(
    '来源与定位',
    '已覆盖切片',
    '结构化知识点',
    '面向应聘映射',
    '停止位置与下一 locator',
    '遗留问题与阻塞'
)
$headingTexts = @(
    [regex]::Matches($content, '(?m)^## ([^#\r\n]+?)\s*$') |
        ForEach-Object { $_.Groups[1].Value }
)
foreach ($section in $requiredSections) {
    if ($headingTexts -notcontains $section) {
        $issues += "missing section: ## $section"
    }
}
$lastSectionIndex = -1
foreach ($section in $requiredSections) {
    $index = [array]::IndexOf($headingTexts, $section)
    if ($index -lt 0) { continue }
    if ($index -lt $lastSectionIndex) {
        $issues += "section out of order: ## $section"
    }
    $lastSectionIndex = $index
}

# ---- 契约 4：来源与定位必填字段 ----
$sourceBody = Get-SectionBody $content '来源与定位'
if ($null -ne $sourceBody) {
    foreach ($field in @('任务包', '主源', '来源角色', 'actual_locator', '源锚点')) {
        $fieldMatch = [regex]::Match(
            $sourceBody,
            "(?m)^-\s*$([regex]::Escape($field))\s*：\s*(?<value>.+?)\s*$"
        )
        if (-not $fieldMatch.Success -or -not $fieldMatch.Groups['value'].Value) {
            $issues += "来源与定位 missing required field: $field"
        }
    }
}

# ---- 契约 5：已覆盖切片表 ----
$sliceBody = Get-SectionBody $content '已覆盖切片'
if ($null -ne $sliceBody) {
    $tableLines = @($sliceBody -split '\r?\n' | Where-Object { $_ -match '^\|' })
    $headerLine = @($tableLines | Where-Object { $_ -match '^\|\s*切片\s*\|' } | Select-Object -First 1)
    if ($headerLine.Count -eq 0) {
        $issues += '已覆盖切片 table missing header row'
    }
    else {
        $headerCols = @($headerLine[0].Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        $expectedHeader = @('切片', '源内容单元', '标题', '要点', '源内交互')
        if ($headerCols.Count -ne 5 -or (($headerCols -join '|') -ne ($expectedHeader -join '|'))) {
            $issues += "已覆盖切片 header must be '| 切片 | 源内容单元 | 标题 | 要点 | 源内交互 |' (got: '$($headerCols -join '|')')"
        }
    }
    foreach ($line in $tableLines) {
        if ($line -match '^\|\s*切片\s*\|' -or $line -match '^\|[\s\-:]+\|') { continue }
        $cols = @($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cols.Count -ne 5) {
            $issues += "已覆盖切片 row must have 5 columns: $line"
            continue
        }
        $sliceId = $cols[0]
        $sliceIds += $sliceId
        if ($sliceId -notmatch '^\d+-\d+$') {
            $issues += "已覆盖切片 slice id must be <块序号>-<片序号> (e.g. 2-1), got '$sliceId'"
        }
        if (-not $cols[1]) { $issues += "已覆盖切片 row missing source unit for '$sliceId'" }
        if (-not $cols[2]) { $issues += "已覆盖切片 row missing title for '$sliceId'" }
        if (-not $cols[3]) { $issues += "已覆盖切片 row missing key points for '$sliceId'" }
        $allowedStatuses = @('待用户完成', '用户已完成（有事实依据）', '无/不适用', '未知/待核验')
        if ($cols[4] -notin $allowedStatuses) {
            $issues += "已覆盖切片 source interaction must be one of: $($allowedStatuses -join ' / ') (got '$($cols[4])')"
        }
    }
    $duplicateSliceIds = @(
        $sliceIds | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
    )
    foreach ($duplicate in $duplicateSliceIds) {
        $issues += "duplicate slice id in 已覆盖切片: $duplicate"
    }
    # 块/片编号只用于稳定引用：不要求从 1 连续，也不要求无缝，只要求课程内递增（顺序检查在下方）。
    # 块内片序号连续 + 表内顺序与课程一致
    $lastBlock = -1
    $lastSliceInBlock = @{}
    foreach ($sliceId in $sliceIds) {
        if ($sliceId -notmatch '^(\d+)-(\d+)$') { continue }
        $block = [int]$Matches[1]
        $slice = [int]$Matches[2]
        if ($block -lt $lastBlock) {
            $issues += "已覆盖切片 rows out of course order (block regresses at '$sliceId')"
        }
        elseif ($block -eq $lastBlock -and $lastSliceInBlock.ContainsKey($block) -and $slice -le $lastSliceInBlock[$block]) {
            $issues += "已覆盖切片 slice numbers must increase within block $block (order broken at '$sliceId')"
        }
        $lastBlock = $block
        $lastSliceInBlock[$block] = $slice
    }
    # 片序号只需在同一块内递增（已在上方顺序检查），不要求从 1 连续。
}

# ---- 契约 6：结构化知识点；v2 新写切片使用来源中立条目 ----
$structBody = Get-SectionBody $content '结构化知识点'
if ($null -ne $structBody) {
    $slicePattern = '(?ms)^### 切片\s+(?<id>\S+?)\s*：(?<title>[^\r\n]*)\r?\n(?<body>.*?)(?=^### 切片 |^## |\z)'
    $sliceSections = @([regex]::Matches($structBody, $slicePattern))
    if ($sliceSections.Count -eq 0) {
        $issues += '结构化知识点 has no per-slice subsections (### 切片 <编号>：<标题>)'
    }
    # 表格切片与结构化小节一一对应（双向）
    $structuredSliceIds = @($sliceSections | ForEach-Object { $_.Groups['id'].Value })
    foreach ($sliceId in $sliceIds) {
        if ($structuredSliceIds -notcontains $sliceId) {
            $issues += "slice $sliceId in 已覆盖切片 has no matching 结构化知识点 subsection (### 切片 $sliceId：<标题>)"
        }
    }
    foreach ($section in $sliceSections) {
        $sliceId = $section.Groups['id'].Value
        $sectionBody = $section.Groups['body'].Value
        if ($sliceId -notmatch '^\d+-\d+$') {
            $issues += "slice heading id must be <块序号>-<片序号>: '### 切片 $sliceId'"
        }
        elseif ($sliceIds -notcontains $sliceId) {
            $issues += "slice $sliceId in structured knowledge not listed in 已覆盖切片"
        }

        $entryOrder = @()
        $inCode = $false
        foreach ($line in @($sectionBody -split '\r?\n')) {
            if ($line -match '^\s*```') { $inCode = -not $inCode; continue }
            if ($inCode) { continue }
            if ($line -match '^\s*-\s*(主源内容|机制|底层规则|应用例子|边界/错误|记忆与理解|源内核验|关键例子|核验题答案|易错点/边界)(\s*（[^）]*）)?\s*：') {
                $entryOrder += $Matches[1]
            }
        }
        $v2Fields = @('主源内容', '机制', '底层规则', '应用例子', '边界/错误', '记忆与理解', '源内核验')
        $v2OnlyFields = @('主源内容', '底层规则', '应用例子', '边界/错误', '记忆与理解', '源内核验')
        $isV2Slice = ($entryOrder | Where-Object { $_ -in $v2OnlyFields }).Count -gt 0
        if ($fmContract -eq 'source-neutral-v2') { $isV2Slice = $true }

        if ($isV2Slice) {
            foreach ($kind in $v2Fields) {
                if ($entryOrder -notcontains $kind) { $issues += "slice $sliceId missing v2 entry: $kind" }
            }
            $kindOrder = $v2Fields
        }
        else {
            foreach ($kind in @('机制', '关键例子', '核验题答案', '易错点/边界')) {
                if ($entryOrder -notcontains $kind) { $issues += "legacy slice $sliceId missing entry: $kind" }
            }
            $kindOrder = @('机制', '关键例子', '核验题答案', '易错点/边界')
        }
        # Check actual field bodies outside code fences, not just label presence.
        $fieldName = $null
        $fieldContent = ''
        $insideFence = $false
        foreach ($fieldLine in @($sectionBody -split '\r?\n') + @('- __END__：')) {
            if ($fieldLine -match '^\s*```') { $insideFence = -not $insideFence }
            $isField = (-not $insideFence -and $fieldLine -match '^\s*-\s*(主源内容|机制|底层规则|应用例子|边界/错误|记忆与理解|源内核验|关键例子|核验题答案|易错点/边界|__END__)(\s*（[^）]*）)?\s*：(?<value>.*)$')
            if ($isField) {
                $newName = $Matches[1]
                $newValue = $Matches['value']
                if ($null -ne $fieldName -and [string]::IsNullOrWhiteSpace($fieldContent)) {
                    $issues += "slice $sliceId empty entry: $fieldName"
                }
                $fieldName = $newName
                $fieldContent = $newValue
            } elseif ($fieldLine -notmatch '^\s*###') {
                $fieldContent += $fieldLine.Trim()
            }
        }
        $lastOrderIndex = -1
        foreach ($kind in $kindOrder) {
            $index = [array]::IndexOf($entryOrder, $kind)
            if ($index -lt 0) { continue }
            if ($index -lt $lastOrderIndex) {
                $issues += "slice $sliceId entry order broken at '$kind' (expected: $($kindOrder -join ' → '))"
            }
            $lastOrderIndex = $index
        }
    }
    if ($fmContract -in @('source-neutral-v2', 'mixed-v2') -and $structBody -notmatch '(?m)^### 块级总结\s*$') {
        $issues += 'v2 snapshot missing ### 块级总结'
    }
}

# ---- 契约 7：面向应聘映射收敛清单，禁用增量标签 ----
$mappingBody = Get-SectionBody $content '面向应聘映射'
if ($null -ne $mappingBody) {
    $mappingEntries = @($mappingBody -split '\r?\n' | Where-Object { $_ -match '^\s*-\s+' })
    if ($mappingEntries.Count -eq 0) {
        $issues += '面向应聘映射 must contain at least one entry'
    }
    foreach ($requiredField in @('对应岗位职责', '面试口径')) {
        $fieldMatch = [regex]::Match(
            $mappingBody,
            "(?m)^\s*-\s*$([regex]::Escape($requiredField))\s*：\s*(?<value>.+?)\s*$"
        )
        if (-not $fieldMatch.Success -or -not $fieldMatch.Groups['value'].Value) {
            $issues += "面向应聘映射 missing required entry: $requiredField"
        }
    }
    foreach ($increment in @([regex]::Matches($mappingBody, '[（(][^）)]*新增[）)]'))) {
        $issues += "incremental-change label in 面向应聘映射: '$($increment.Value)' (keep it a converged list)"
    }
}

# ---- 契约 8：停止位置与下一 locator ----
$stopBody = Get-SectionBody $content '停止位置与下一 locator'
if ($null -ne $stopBody) {
    foreach ($field in @('停止位置', '下一 locator')) {
        $fieldMatch = [regex]::Match(
            $stopBody,
            "(?m)^-\s*$([regex]::Escape($field))\s*：\s*(?<value>.+?)\s*$"
        )
        if (-not $fieldMatch.Success -or -not $fieldMatch.Groups['value'].Value) {
            $issues += "停止位置与下一 locator missing required field: $field"
        }
    }
}

# ---- 契约 9：遗留问题与阻塞 ----
$issueBody = Get-SectionBody $content '遗留问题与阻塞'
if ($null -ne $issueBody) {
    $issueEntries = @($issueBody -split '\r?\n' | Where-Object { $_ -match '^\s*-\s+' })
    if ($issueEntries.Count -eq 0) {
        $issues += '遗留问题与阻塞 must contain entries or write 无阻塞'
    }
}

# ---- 契约 10：不写学习时长 / 完成判定 / 预测 / 日期计划 / 无依据掌握结论 ----
foreach ($pattern in @('学习时长', '完成判定', '预计完成', '预计将于', '计划于', '计划在')) {
    if ($content -match $pattern) {
        $issues += "forbidden scheduling/meta content detected: '$pattern'"
    }
}
foreach ($pattern in @('(?m)^\s*-\s*(学习状态|掌握状态)\s*：\s*(已掌握|完全掌握)', '任务包已完成', '能力已证明', '已达到岗位要求')) {
    if ($content -match $pattern) {
        $issues += "unsupported completion/mastery claim detected: '$pattern'"
    }
}

$result = [pscustomobject]@{
    snapshot = $resolved
    slices = $sliceIds.Count
    issues = $issues
    valid = ($issues.Count -eq 0)
}

$result | ConvertTo-Json -Depth 20
if (-not $result.valid) {
    exit 1
}
