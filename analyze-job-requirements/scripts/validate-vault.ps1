param(
    [Alias('VaultRoot')][string]$Vault,
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'vault-contract.ps1')

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
    throw 'No vault bound. Pass -Vault (or -VaultRoot) or initialize one with init-vault.ps1.'
}

$warnings = @()

$vaultPath = (Resolve-Path -LiteralPath $Vault).Path

$defaultSchemaPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\vault-schema.json'
if (-not (Test-Path -LiteralPath $defaultSchemaPath -PathType Leaf)) {
    throw "Bundled default vault schema not found: $defaultSchemaPath"
}
$defaultSchema = [IO.File]::ReadAllText($defaultSchemaPath, [Text.Encoding]::UTF8) | ConvertFrom-Json

# The Vault owns the outermost schema. Prefer its own .tech-vault.json, which
# carries the schema plus the instance version; the bundle only supplies a default.
$markerPath = Join-Path $vaultPath '.tech-vault.json'
$schema = $null
$vaultSchemaVersion = $null
$schemaSource = 'bundled-default'
if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
    try {
        $marker = [IO.File]::ReadAllText($markerPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
        if ($marker.PSObject.Properties['schema_version'] -and $marker.schema_version) {
            $vaultSchemaVersion = [int]$marker.schema_version
        }
        if ($marker.PSObject.Properties['schema'] -and $null -ne $marker.schema) {
            $schema = $marker.schema
            $schemaSource = 'vault'
        }
    }
    catch {
        $warnings += "vault marker unreadable: $($_.Exception.Message)"
    }
}
if ($null -eq $schema) {
    $schema = $defaultSchema
    $warnings += 'vault schema missing; falling back to the bundled default schema'
}
if ($null -ne $vaultSchemaVersion -and $vaultSchemaVersion -ne [int]$defaultSchema.schema_version) {
    $warnings += "vault schema_version $vaultSchemaVersion differs from the supported $($defaultSchema.schema_version); reconcile before writing"
}

# Default mode is the core check: every prescribed path must exist and the
# routing content must be present, so routing and writes are never blocked.
# It never judges freeform content. Run -Strict for the full structural contract.
if (-not $Strict) {
    $core = $schema.core
    $coreRequired = @($schema.paths.required)
    $coreMissing = @($coreRequired | Where-Object { -not (Test-Path -LiteralPath (Join-Path $vaultPath $_)) })
    $coreHomepagePath = Join-Path $vaultPath '00-首页.md'
    $coreOverviewPath = Join-Path $vaultPath '20-学习主线\00-总览.md'
    $coreHomepage = if (Test-Path -LiteralPath $coreHomepagePath -PathType Leaf) { Get-Content -Raw -Encoding UTF8 -LiteralPath $coreHomepagePath } else { '' }
    $coreOverview = if (Test-Path -LiteralPath $coreOverviewPath -PathType Leaf) { Get-Content -Raw -Encoding UTF8 -LiteralPath $coreOverviewPath } else { '' }
    $coreIssues = @()
    foreach ($property in @($core.homepage_properties)) {
        if ($coreHomepage -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
            $coreIssues += "homepage missing property: $property"
        }
    }
    foreach ($property in @($core.mainline_properties)) {
        if ($coreOverview -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
            $coreIssues += "mainline overview missing property: $property"
        }
    }
    $coreUnit = $null
    if ($coreOverview -match '(?m)^current_unit:\s*(?<u>[A-Z][A-Z0-9-]*-\d{2})\s*$') { $coreUnit = $Matches['u'] }
    if (-not $coreUnit) {
        $coreIssues += 'mainline current_unit not declared'
    }
    else {
        $mainlineDir = Join-Path $vaultPath '20-学习主线'
        $mainlineFiles = @()
        if (Test-Path -LiteralPath $mainlineDir -PathType Container) {
            $mainlineFiles += Get-ChildItem -LiteralPath $mainlineDir -File -Filter '*.md'
            $stageDir = Join-Path $mainlineDir '10-阶段'
            if (Test-Path -LiteralPath $stageDir -PathType Container) { $mainlineFiles += Get-ChildItem -LiteralPath $stageDir -File -Filter '*.md' }
        }
        $mainlineText = (@($mainlineFiles | Sort-Object Name | ForEach-Object { Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName }) -join "`n")
        $declaredUnits = @([regex]::Matches($mainlineText, '(?m)^- unit: `(?<u>[^`]+)`') | ForEach-Object { $_.Groups['u'].Value })
        if ($declaredUnits -notcontains $coreUnit) { $coreIssues += "current_unit is not declared: $coreUnit" }
    }
    $coreResult = [pscustomobject]@{
        vault            = $vaultPath
        mode             = 'core'
        schema_version   = $schema.schema_version
        schema_source    = $schemaSource
        current_unit     = $coreUnit
        missing_required = $coreMissing
        issues           = $coreIssues
        warnings         = @($warnings)
        valid            = ($coreMissing.Count -eq 0 -and $coreIssues.Count -eq 0)
    }
    $coreResult | ConvertTo-Json -Depth 10
    if (-not $coreResult.valid) { exit 1 }
    exit 0
}

$required = @($schema.paths.required)
$forbiddenLegacyPaths = @($schema.paths.forbidden_legacy)

$missing = @(
    $required | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $vaultPath $_))
    }
)
$legacyPathsPresent = @(
    $forbiddenLegacyPaths | Where-Object {
        Test-Path -LiteralPath (Join-Path $vaultPath $_)
    }
)
$rootPrefixGroups = @(
    Get-ChildItem -LiteralPath $vaultPath -Force |
        Where-Object { $_.Name -match '^(\d{2})-' } |
        Group-Object { [regex]::Match($_.Name, '^(\d{2})-').Groups[1].Value }
)
$duplicateRootPrefixes = @(
    $rootPrefixGroups |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object {
            [pscustomobject]@{
                prefix = $_.Name
                items = @($_.Group.Name)
            }
        }
)

$canonicalMarkdownFiles = @($schema.paths.markdown_files)
$canonicalMarkdownRoots = @($schema.paths.markdown_roots)
$canonicalNoteRoots = @($schema.paths.note_roots)


# Enumerate content while pruning environment/build trees before recursion.
function Get-VaultContentFiles {
    param([string]$Root)
    $stack = [Collections.Generic.Stack[string]]::new()
    $stack.Push($Root)
    while ($stack.Count -gt 0) {
        foreach ($item in Get-ChildItem -LiteralPath $stack.Pop() -Force) {
            if ($item.PSIsContainer) {
                if ($item.Name -in @('.venv', 'venv', 'node_modules', '__pycache__', '.git', '.obsidian', '.study-state', 'exports', '97-临时') -or
                    $item.Name -like '.tmp*' -or $item.Name -like '.codex*' -or
                    ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
                $stack.Push($item.FullName)
            } else { $item }
        }
    }
}

$contentFiles = @(Get-VaultContentFiles -Root $vaultPath)
$markdown = @($contentFiles | Where-Object {
    $relative = $_.FullName.Substring($vaultPath.Length + 1)
    $root = ($relative -split '[\\/]')[0]
    $_.Extension -ieq '.md' -and ($relative -in $canonicalMarkdownFiles -or $root -in $canonicalMarkdownRoots)
})
$nonMarkdownNoteFiles = @($contentFiles | Where-Object {
    $root = ($_.FullName.Substring($vaultPath.Length + 1) -split '[\\/]')[0]
    $root -in $canonicalNoteRoots -and $_.Extension -ine '.md'
} | ForEach-Object { $_.FullName })

$names = @{}
foreach ($file in $markdown) {
    if (-not $names.ContainsKey($file.BaseName)) { $names[$file.BaseName] = @() }
    $names[$file.BaseName] += $file.FullName
}
$duplicates = @($names.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | ForEach-Object {
    [pscustomobject]@{ basename = $_.Key; paths = $_.Value }
})

# Wiki links can name a note or an attachment, with paths relative to the note or Vault.
$fileNames = @{}
$contentPaths = @{}
foreach ($file in $contentFiles) {
    if (-not $fileNames.ContainsKey($file.Name)) { $fileNames[$file.Name] = @() }
    $fileNames[$file.Name] += $file.FullName
    $contentPaths[$file.FullName] = $true
}
function Test-WikiTarget {
    param([string]$Target, [string]$Source)
    $targetText = [Uri]::UnescapeDataString($Target.Trim())
    $variants = @($targetText)
    if (-not $targetText.EndsWith('.md', [StringComparison]::OrdinalIgnoreCase)) { $variants += $targetText + '.md' }
    foreach ($variant in $variants) {
        foreach ($base in @((Split-Path -Parent $Source), $vaultPath)) {
            try { $candidate = [IO.Path]::GetFullPath((Join-Path $base $variant)) } catch { continue }
            if ($contentPaths.ContainsKey($candidate)) { return $true }
        }
        # Obsidian short filenames resolve within the Vault, not only the note's folder.
        if ($variant -notmatch '[\\/]' -and $fileNames.ContainsKey($variant) -and $fileNames[$variant].Count -eq 1) { return $true }
        # A shortened folder-qualified link must resolve to one suffix match.
        $suffix = [IO.Path]::DirectorySeparatorChar + $variant.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $matches = @($contentFiles | Where-Object { $_.FullName.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase) })
        if ($matches.Count -eq 1) { return $true }
    }
    return $false
}

$brokenLinks = @()
foreach ($file in $markdown) {
    if ($file.FullName -like '*\90-模板\*') { continue }
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    foreach ($match in [regex]::Matches($content, '\[\[([^\]|#]+)')) {
        $target = $match.Groups[1].Value
        if (-not (Test-WikiTarget -Target $target -Source $file.FullName)) {
            $brokenLinks += [pscustomobject]@{ source = $file.FullName; target = $target }
        }
    }
}

$reviewRoot = Join-Path $vaultPath '30-学习日志\学习回顾'
$reviewRequiredHeadings = @(
    '## 今日学习过程',
    '## 今日形成的理解',
    '## 今日知识沉淀',
    '## 今日遇到的问题'
)
$invalidDailyReviews = @()
$reviewDates = @{}
foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $reviewRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $issues = @()
    if ($file.BaseName -notmatch '^(\d{4}-\d{2}-\d{2}) 学习回顾$') {
        $issues += 'filename must be YYYY-MM-DD 学习回顾.md'
    }
    else {
        $date = $Matches[1]
        if (-not $reviewDates.ContainsKey($date)) {
            $reviewDates[$date] = @()
        }
        $reviewDates[$date] += $file.FullName
        if ($content -notmatch '(?m)^## 实际使用的学习资料\s*$') {
            $warnings += "daily review lacks actual learning-source section: $($file.FullName)"
        }
    }
    foreach ($heading in $reviewRequiredHeadings) {
        if ($content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    if ($content -match '(?m)^## (仍待确认|下一次复习)\s*$') {
        $issues += 'legacy ingestion or review-schedule heading'
    }
    if ($issues.Count -gt 0) {
        $invalidDailyReviews += [pscustomobject]@{
            path = $file.FullName
            issues = $issues
        }
    }
}
$duplicateReviewDates = @(
    $reviewDates.GetEnumerator() |
        Where-Object { $_.Value.Count -gt 1 } |
        ForEach-Object {
            [pscustomobject]@{
                date = $_.Key
                paths = $_.Value
            }
        }
)

$dailyTemplatePath = Join-Path $vaultPath '90-模板\学习回顾模板.md'
$dailyTemplateContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $dailyTemplatePath
$dailyTemplateIssues = @()
foreach ($heading in @('## 今日学习过程', '## 实际使用的学习资料', '## 今日形成的理解', '## 今日知识沉淀', '## 今日遇到的问题')) {
    if ($dailyTemplateContent -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
        $dailyTemplateIssues += "missing heading: $heading"
    }
}
foreach ($field in @('主学习源代码', '实际访问 URL，或实体教材精确版次', '课程/文档章节与小节', '实际起点 → 停留位置', '可访问事实', '缺口补充源', 'Agent 兜底')) {
    if ($dailyTemplateContent -notmatch [regex]::Escape($field)) {
        $dailyTemplateIssues += "missing learning-source field: $field"
    }
}

$weeklyRoot = Join-Path $vaultPath '30-学习日志\每周'
$weeklyRequiredHeadings = @($schema.weekly.headings)
$weeklyRequiredProperties = @($schema.weekly.properties)
$invalidWeeklyNotes = @()
foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $weeklyRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $issues = @()
    if ($file.BaseName -notmatch '^\d{4}-W\d{2}$') {
        $issues += 'filename must be YYYY-Www.md'
    }
    foreach ($property in $weeklyRequiredProperties) {
        if ($content -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
            $issues += "missing property: $property"
        }
    }
    if ($content -match '(?m)^status:\s*(.+?)\s*$') {
        $weeklyStatus = $Matches[1].Trim()
        if ($weeklyStatus -notin @($schema.weekly.status_enum)) {
            $issues += "invalid status: $weeklyStatus"
        }
    }
    foreach ($heading in $weeklyRequiredHeadings) {
        if ($content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    # 日志只做字面记录：不绑定计划、配额、排期或预期产物，因此不校验任何计划字段。
    if ($content -match '(?m)^(focus|focus_status)\s*:' -or
        $content -match '(?m)^## 本周(唯一)?重点\s*$' -or
        $content -match '(?m)^## (问题与待验证|里程碑进度)\s*$') {
        $issues += 'legacy weekly progress state'
    }
    if ($issues.Count -gt 0) {
        $invalidWeeklyNotes += [pscustomobject]@{
            path = $file.FullName
            issues = $issues
        }
    }
}

$homepagePath = Join-Path $vaultPath '00-首页.md'
$homepageContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $homepagePath
$homepageRequiredHeadings = @($schema.files.'00-首页.md'.headings)
$homepageRequiredProperties = @($schema.files.'00-首页.md'.properties)
$homepageIssues = @()
foreach ($property in $homepageRequiredProperties) {
    if ($homepageContent -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
        $homepageIssues += "missing property: $property"
    }
}
foreach ($heading in $homepageRequiredHeadings) {
    if ($homepageContent -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
        $homepageIssues += "missing heading: $heading"
    }
}
if ($homepageContent -match '(?m)^current_focus\s*:' -or
    $homepageContent -match '(?m)^## 本周(唯一)?重点\s*$' -or
    $homepageContent -match '\[\[(问题看板|里程碑索引|项目索引|来源索引)') {
    $homepageIssues += 'legacy homepage state or index link'
}

$mainlineDir = Join-Path $vaultPath '20-学习主线'
$mainlinePath = Join-Path $mainlineDir '00-总览.md'
$mainlineFiles = @()
if (Test-Path -LiteralPath $mainlineDir -PathType Container) {
    $mainlineFiles += Get-ChildItem -LiteralPath $mainlineDir -File -Filter '*.md'
    $stageDir = Join-Path $mainlineDir '10-阶段'
    if (Test-Path -LiteralPath $stageDir -PathType Container) {
        $mainlineFiles += Get-ChildItem -LiteralPath $stageDir -File -Filter '*.md'
    }
}
$mainlineContent = (@($mainlineFiles | Sort-Object Name | ForEach-Object { Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName }) -join "`n")
$mainlineRequiredHeadings = @($schema.files.'20-学习主线'.headings)
$mainlineIssues = @()
foreach ($property in @($schema.files.'20-学习主线'.properties)) {
    if ($mainlineContent -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
        $mainlineIssues += "missing property: $property"
    }
}
foreach ($heading in $mainlineRequiredHeadings) {
    if ($mainlineContent -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
        $mainlineIssues += "missing heading: $heading"
    }
}

foreach ($property in @('current_stage', 'current_unit', 'current_position')) {
    $homepageMatch = [regex]::Match(
        $homepageContent,
        "(?m)^$([regex]::Escape($property))\s*:\s*(?<value>.+?)\s*$"
    )
    $mainlineMatch = [regex]::Match(
        $mainlineContent,
        "(?m)^$([regex]::Escape($property))\s*:\s*(?<value>.+?)\s*$"
    )
    if ($homepageMatch.Success -and $mainlineMatch.Success) {
        $homepageValue = $homepageMatch.Groups['value'].Value.Trim().Trim('"')
        $mainlineValue = $mainlineMatch.Groups['value'].Value.Trim().Trim('"')
        if ($homepageValue -ne $mainlineValue) {
            $homepageIssues += "homepage $property does not mirror mainline: $homepageValue != $mainlineValue"
        }
    }
}

function Get-FrontmatterListValues {
    param(
        [string]$Content,
        [string]$Property
    )

    $frontmatterMatch = [regex]::Match(
        $Content,
        '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---\s*\r?\n'
    )
    if (-not $frontmatterMatch.Success) {
        return @()
    }

    $inlineMatch = [regex]::Match($frontmatterMatch.Groups['body'].Value, "(?m)^$([regex]::Escape($Property))\s*:\s*\[(?<values>[^\]]*)\]\s*$")
    if ($inlineMatch.Success) {
        return @($inlineMatch.Groups['values'].Value -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ })
    }
    $values = @()
    $collecting = $false
    foreach ($line in @($frontmatterMatch.Groups['body'].Value -split '\r?\n')) {
        if (-not $collecting -and $line -match "^$([regex]::Escape($Property))\s*:\s*(?:\[\])?\s*$") {
            $collecting = $true
            continue
        }
        if (-not $collecting) {
            continue
        }
        if ($line -match '^\s{2}-\s*(?<value>.*?)\s*$') {
            $values += $Matches['value'].Trim().Trim('"')
            continue
        }
        if ($line -match '^\S') {
            break
        }
    }
    return $values
}

function Get-FrontmatterScalarValue {
    param(
        [string]$Content,
        [string]$Property
    )

    $frontmatterMatch = [regex]::Match($Content, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---\s*\r?\n')
    if (-not $frontmatterMatch.Success) { return $null }
    $match = [regex]::Match(
        $frontmatterMatch.Groups['body'].Value,
        "(?m)^$([regex]::Escape($Property))\s*:\s*(?<value>[^#\r\n]*?)(?:\s+#.*)?\s*$"
    )
    if (-not $match.Success) { return $null }
    return $match.Groups['value'].Value.Trim().Trim('"').Trim("'")
}

$homepageCurrentWeekMatch = [regex]::Match(
    $homepageContent,
    '(?m)^current_week\s*:\s*(?<value>\d{4}-W\d{2})\s*$'
)
if ($homepageCurrentWeekMatch.Success) {
    $currentWeekValue = $homepageCurrentWeekMatch.Groups['value'].Value
    $currentWeekPath = Join-Path $weeklyRoot "$currentWeekValue.md"
    if (-not (Test-Path -LiteralPath $currentWeekPath -PathType Leaf)) {
        $homepageIssues += "current_week note missing: $currentWeekValue"
    }
    # The current-week note is a dated factual ledger. Its stage context is
    # historical and must not mirror or control the live task route.
}

if (@([regex]::Matches($mainlineContent, '(?m)^## 阶段[一二三四五六七八九十]+：')).Count -eq 0) {
    $mainlineIssues += 'no ordered stage headings'
}
$unitIdPattern = $UnitIdPattern
$unitRowPattern = $UnitRowPattern
$mainlineUnitMatches = @([regex]::Matches($mainlineContent, $unitRowPattern))
$mainlineUnitIds = @($mainlineUnitMatches | ForEach-Object { $_.Groups['id'].Value })
if ($mainlineUnitIds.Count -eq 0) {
    $mainlineIssues += 'no curriculum unit rows'
}
if (@($mainlineUnitIds | Group-Object | Where-Object { $_.Count -gt 1 }).Count -gt 0) {
    $mainlineIssues += 'duplicate curriculum unit IDs'
}
if ($mainlineContent -match ("(?m)^current_unit:\s*(" + $unitIdPattern + ")\s*$")) {
    if ($mainlineUnitIds -notcontains $Matches[1]) {
        $mainlineIssues += "current_unit is not declared: $($Matches[1])"
    }
}

$pluginRoot = Split-Path -Parent $PSScriptRoot
$sourceParadigmPath = Join-Path $pluginRoot 'references\curriculum-sources.md'
$sourceRegistryPath = Resolve-SourceRegistryPath -VaultRoot $vaultPath -PluginRoot $pluginRoot
$sourceParadigmContent = if (Test-Path -LiteralPath $sourceParadigmPath -PathType Leaf) { Get-Content -Raw -Encoding UTF8 -LiteralPath $sourceParadigmPath } else { '' }
$registeredSourceCodes = @()
$sourceContractIssues = @()
if (-not (Test-Path -LiteralPath $sourceRegistryPath -PathType Leaf)) {
    $mainlineIssues += "source registry missing: $sourceRegistryPath"
}
else {
    $sourceRegistryContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourceRegistryPath
    $sourceRegistryMatches = @([regex]::Matches($sourceRegistryContent, $RegistryEntryPattern))
    $registeredSourceCodes = @($sourceRegistryMatches | ForEach-Object { $_.Groups['code'].Value })
    if ($registeredSourceCodes.Count -eq 0) {
        $mainlineIssues += 'source registry contains no source codes'
    }
    if (@($registeredSourceCodes | Group-Object | Where-Object { $_.Count -gt 1 }).Count -gt 0) {
        $sourceContractIssues += 'source registry contains duplicate source codes'
    }
    foreach ($source in $sourceRegistryMatches) {
        $code = $source.Groups['code'].Value
        $role = $source.Groups['role'].Value
        $locatorText = $source.Groups['rest'].Value
        if ($RegistryRoles -notcontains $role) {
            $sourceContractIssues += "registry role is invalid: $code -> $role"
        }
        if ($role -in @('teaching-open', 'technical-authority') -and $locatorText -notmatch '<https?://[^>]+>') {
            $sourceContractIssues += "external source lacks stable URL: $code"
        }
        if ($role -eq 'physical-book' -and $locatorText -notmatch '(版|edition).*(章|chapter)') {
            $sourceContractIssues += "physical-book registry entry lacks edition and chapter: $code"
        }
    }
    if ($sourceParadigmContent -notmatch '(?ms)^### Teaching completion path\s+.*?public online tutorial.*?official documentation.*?physical.*?Agent fallback') {
        $sourceContractIssues += 'teaching completion path is missing or out of order'
    }
    if ($sourceParadigmContent -notmatch '(?ms)^### Technical-fact authority\s+.*?official documentation') {
        $sourceContractIssues += 'official technical-fact authority is missing'
    }
    foreach ($format in @(
        '- unit: `<unit-id>` | primary_source: `<registered-code>` | type:',
        '- unit: `<unit-id>` | gap_source: `<registered-code>` | type:'
    )) {
        if ($sourceParadigmContent -notmatch [regex]::Escape($format)) {
            $sourceContractIssues += "missing machine-parseable source format: $format"
        }
    }
}

$unitSourceDeclarationPattern = $PrimaryDeclarationPattern
$unitSourceDeclarations = @([regex]::Matches($mainlineContent, $unitSourceDeclarationPattern))
$declaredUnitIds = @($unitSourceDeclarations | ForEach-Object { $_.Groups['unit'].Value })

if ($unitSourceDeclarations.Count -ne $mainlineUnitIds.Count) {
    $sourceContractIssues += "unit source declaration count $($unitSourceDeclarations.Count) does not equal unit count $($mainlineUnitIds.Count)"
}
foreach ($unitId in $mainlineUnitIds) {
    $declarations = @($unitSourceDeclarations | Where-Object { $_.Groups['unit'].Value -eq $unitId })
    if ($declarations.Count -ne 1) {
        $sourceContractIssues += "unit must have exactly one primary source declaration: $unitId -> $($declarations.Count)"
    }
}
foreach ($declaration in $unitSourceDeclarations) {
    $unitId = $declaration.Groups['unit'].Value
    $primaryCode = $declaration.Groups['source'].Value
    $sourceType = $declaration.Groups['type'].Value
    if ($SourceTypes -notcontains $sourceType) {
        $sourceContractIssues += "unit primary source type is invalid: $unitId -> $sourceType"
    }
    $locator = $declaration.Groups['locator'].Value.Trim()
    $extra = $declaration.Groups['extra'].Value
    if ($registeredSourceCodes -notcontains $primaryCode) {
        $sourceContractIssues += "unit primary source is unregistered: $unitId -> $primaryCode"
    }
    $registryRole = @($sourceRegistryMatches | Where-Object { $_.Groups['code'].Value -eq $primaryCode } | ForEach-Object { $_.Groups['role'].Value })
    $expectedRole = switch ($sourceType) {
        'online-tutorial' { 'teaching-open' }
        'official-docs' { 'technical-authority' }
        'physical-book' { 'physical-book' }
        'agent-fallback' { 'agent-fallback' }
        default { $null }
    }
    if ($sourceType -ne 'user-selected' -and ($registryRole.Count -ne 1 -or $registryRole[0] -ne $expectedRole)) {
        $sourceContractIssues += "unit source type does not match registry role: $unitId -> $primaryCode/$sourceType"
    }
    if (-not $locator -or $locator -match '^(待定|未知|未报告)$') {
        $sourceContractIssues += "unit primary source lacks reproducible locator: $unitId"
    }
    if ($sourceType -ne 'agent-fallback' -and $locator -notmatch '^registry:' -and $locator -notmatch '^(https?://|ISBN:)') {
        $sourceContractIssues += "unit primary source locator is not a registered anchor, URL, or ISBN: $unitId"
    }
    if ($sourceType -eq 'physical-book' -and $locator -notmatch '(版|edition).*(章|chapter)') {
        $sourceContractIssues += "physical-book locator lacks edition and chapter: $unitId"
    }
    if ($sourceType -eq 'agent-fallback') {
        if ($primaryCode -ne 'AGENT-FALLBACK') {
            $sourceContractIssues += "agent fallback must use AGENT-FALLBACK source code: $unitId"
        }
        foreach ($field in @('reason:', 'scope:', 'uncovered:')) {
            if ($extra -notmatch [regex]::Escape($field)) {
                $sourceContractIssues += "agent fallback lacks $field $unitId"
            }
        }
    }
}

$gapDeclarationPattern = $GapDeclarationPattern
$gapDeclarations = @([regex]::Matches($mainlineContent, $gapDeclarationPattern))
foreach ($group in @($gapDeclarations | Group-Object { $_.Groups['unit'].Value })) {
    if ($group.Count -gt 1) {
        $sourceContractIssues += "unit has more than one gap source: $($group.Name)"
    }
}
foreach ($declaration in $gapDeclarations) {
    $unitId = $declaration.Groups['unit'].Value
    $gapCode = $declaration.Groups['source'].Value
    $gapType = $declaration.Groups['type'].Value
    if ($GapSourceTypes -notcontains $gapType) {
        $sourceContractIssues += "gap source type is invalid: $unitId -> $gapType"
    }
    $gapLocator = $declaration.Groups['locator'].Value.Trim()
    $gapExtra = $declaration.Groups['extra'].Value
    if ($mainlineUnitIds -notcontains $unitId) {
        $sourceContractIssues += "gap source has unknown unit: $unitId"
    }
    if ($registeredSourceCodes -notcontains $gapCode) {
        $sourceContractIssues += "gap source is unregistered: $unitId -> $gapCode"
    }
    $gapRegistryRole = @($sourceRegistryMatches | Where-Object { $_.Groups['code'].Value -eq $gapCode } | ForEach-Object { $_.Groups['role'].Value })
    $expectedGapRole = switch ($gapType) {
        'online-tutorial' { 'teaching-open' }
        'official-docs' { 'technical-authority' }
        'physical-book' { 'physical-book' }
        'agent-fallback' { 'agent-fallback' }
    }
    if ($gapRegistryRole.Count -ne 1 -or $gapRegistryRole[0] -ne $expectedGapRole) {
        $sourceContractIssues += "gap source type does not match registry role: $unitId -> $gapCode/$gapType"
    }
    if (-not $gapLocator -or $gapLocator -match '^(待定|未知|未报告)$') {
        $sourceContractIssues += "gap source lacks reproducible locator: $unitId"
    }
    if ($gapType -eq 'physical-book' -and $gapLocator -notmatch '(版|edition).*(章|chapter)') {
        $sourceContractIssues += "physical-book gap locator lacks edition and chapter: $unitId"
    }
    if ($gapType -eq 'agent-fallback') {
        foreach ($field in @('reason:', 'scope:', 'uncovered:')) {
            if ($gapExtra -notmatch [regex]::Escape($field)) {
                $sourceContractIssues += "agent fallback gap lacks $field $unitId"
            }
        }
    }
}

foreach ($match in $mainlineUnitMatches) {
    $unitId = $match.Groups['id'].Value
    $contentValue = $match.Groups['content'].Value.Trim()
    $prerequisiteValue = $match.Groups['prerequisite'].Value.Trim()
    $modelValue = $match.Groups['model'].Value.Trim()
    $outputValue = $match.Groups['output'].Value.Trim()
    $sourceValue = $match.Groups['source'].Value.Trim()

    if (-not $contentValue) {
        $mainlineIssues += "unit lacks canonical content: $unitId"
    }
    if (-not $modelValue) {
        $mainlineIssues += "unit lacks underlying model: $unitId"
    }
    if (-not $outputValue) {
        $mainlineIssues += "unit lacks observable output: $unitId"
    }

    $sourceCodes = @(
        [regex]::Matches($sourceValue, '`(?<code>[A-Z][A-Z0-9-]+)`') |
            ForEach-Object { $_.Groups['code'].Value }
    )
    if ($sourceValue -notmatch '^主源:\s*`(?<tablePrimary>[A-Z][A-Z0-9-]+)`') {
        $sourceContractIssues += "unit table lacks machine-readable primary source: $unitId"
    }
    else {
        $declaredPrimary = @($unitSourceDeclarations | Where-Object { $_.Groups['unit'].Value -eq $unitId } | ForEach-Object { $_.Groups['source'].Value })
        if ($declaredPrimary.Count -eq 1 -and $declaredPrimary[0] -ne $Matches['tablePrimary']) {
            $sourceContractIssues += "unit table primary conflicts with declaration: $unitId -> $($Matches['tablePrimary'])/$($declaredPrimary[0])"
        }
    }
    if ($sourceCodes.Count -eq 0) {
        $mainlineIssues += "unit lacks explicit source code: $unitId"
    }
    foreach ($sourceCode in $sourceCodes) {
        if ($registeredSourceCodes -notcontains $sourceCode) {
            $mainlineIssues += "unit has unregistered source code: $unitId -> $sourceCode"
        }
    }
    if ($sourceValue -match '前述|所选库') {
        $mainlineIssues += "unit has ambiguous source text: $unitId"
    }

    foreach ($prerequisiteMatch in [regex]::Matches($prerequisiteValue, $unitIdPattern)) {
        $prerequisiteId = $prerequisiteMatch.Value
        if ($mainlineUnitIds -notcontains $prerequisiteId) {
            $mainlineIssues += "unit has unknown prerequisite: $unitId -> $prerequisiteId"
        }
    }
}

$reviewQueuePath = Join-Path $vaultPath '70-复习队列.md'
$reviewQueueContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $reviewQueuePath
$reviewQueueIssues = @()
if ($reviewQueueContent -notmatch '(?m)^type:\s*review-queue\s*$') {
    $reviewQueueIssues += 'type must be review-queue'
}
foreach ($heading in @($schema.files.'70-复习队列.md'.headings)) {
    if ($reviewQueueContent -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
        $reviewQueueIssues += "missing heading: $heading"
    }
}
$reviewTemplatePath = Join-Path $vaultPath '90-模板\复习题模板.md'
$reviewTemplateContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $reviewTemplatePath
$reviewTemplateIssues = @()
foreach ($heading in @('## 因果预测', '## 修错定位', '## 换情境迁移', '## 复习记录')) {
    if ($reviewTemplateContent -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
        $reviewTemplateIssues += "missing heading: $heading"
    }
}
foreach ($property in @('review_kind', 'primary_atomic', 'related_atomics', 'task_units')) {
    if ($reviewTemplateContent -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
        $reviewTemplateIssues += "missing property: $property"
    }
}
if ($reviewTemplateContent -notmatch '(?m)^## 题库类型与关联\s*$') {
    $reviewTemplateIssues += 'missing heading: ## 题库类型与关联'
}
if ($reviewTemplateContent -match '(?m)^## 建议复习日期\s*$') {
    $reviewTemplateIssues += 'review dates belong in the derived queue'
}

$weeklyTemplatePath = Join-Path $vaultPath '90-模板\每周学习复盘模板.md'
$weeklyTemplateContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $weeklyTemplatePath
$weeklyTemplateIssues = @()
foreach ($heading in $weeklyRequiredHeadings) {
    if ($weeklyTemplateContent -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
        $weeklyTemplateIssues += "missing heading: $heading"
    }
}
foreach ($property in $weeklyRequiredProperties) {
    if ($weeklyTemplateContent -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
        $weeklyTemplateIssues += "missing property: $property"
    }
}
if ($weeklyTemplateContent -match '(?m)^## (问题与待验证|里程碑进度)\s*$') {
    $weeklyTemplateIssues += 'legacy derived-progress heading'
}

$jobRequirementTemplatePath = Join-Path $vaultPath '90-模板\岗位需求分析模板.md'
$jobRequirementTemplateIssues = @()
if (-not (Test-Path -LiteralPath $jobRequirementTemplatePath -PathType Leaf)) {
    $jobRequirementTemplateIssues += 'missing job requirement analysis template'
}
else {
    $jobRequirementTemplateContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $jobRequirementTemplatePath
    foreach ($heading in @('## 来源与边界', '## 原始要求', '## 结构化需求', '## 主线映射', '## 差距与优先级', '## 变更建议', '## 写入状态')) {
        if ($jobRequirementTemplateContent -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $jobRequirementTemplateIssues += "missing heading: $heading"
        }
    }
}

$jobRequirementRoot = Join-Path $vaultPath '20-学习主线\岗位分析'
$invalidJobRequirementNotes = @()
if (Test-Path -LiteralPath $jobRequirementRoot -PathType Container) {
    foreach ($file in @(Get-ChildItem -LiteralPath $jobRequirementRoot -File -Filter '*.md')) {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        $issues = @()
        if ($content -notmatch '(?m)^type:\s*job-requirement-analysis\s*$') {
            $issues += 'type must be job-requirement-analysis'
        }
        foreach ($heading in @('## 来源与边界', '## 原始要求', '## 结构化需求', '## 主线映射', '## 差距与优先级', '## 变更建议', '## 写入状态')) {
            if ($content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
                $issues += "missing heading: $heading"
            }
        }
        if ($issues.Count -gt 0) {
            $invalidJobRequirementNotes += [pscustomobject]@{ path = $file.FullName; issues = $issues }
        }
    }
}

$atomicRoot = Join-Path $vaultPath '40-原子知识'
$atomicRequiredHeadings = @(
    '## 要解决的问题',
    '## 结论',
    '## 为什么',
    '## 最小例子',
    '## 边界与易错点',
    '## 相关知识'
)
$invalidAtomicNotes = @()
$atomicNoteRecords = @()
$atomicGranularityIssues = @()
foreach ($file in @(Get-ChildItem -Recurse -File -Filter '*.md' -LiteralPath $atomicRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $issues = @()
    foreach ($heading in $atomicRequiredHeadings) {
        if ($content -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += "missing heading: $heading"
        }
    }
    $questionHeadings = @([regex]::Matches($content, '(?m)^## 要解决的问题\s*$'))
    if ($questionHeadings.Count -ne 1) {
        $atomicGranularityIssues += [pscustomobject]@{ path = $file.FullName; issue = 'must contain exactly one question section' }
    }
    $questionSection = [regex]::Match($content, '(?ms)^## 要解决的问题\s*\r?\n(?<section>.*?)(?=^## |\z)')
    if (-not $questionSection.Success -or -not $questionSection.Groups['section'].Value.Trim()) {
        $atomicGranularityIssues += [pscustomobject]@{ path = $file.FullName; issue = 'question section must be non-empty' }
    }
    if ($content -match '(?m)^## (一句话理解|核心说明|示例与结果|易错点)\s*$') {
        $issues += 'legacy continuous-note heading'
    }
    $minimumExampleMatch = [regex]::Match(
        $content,
        '(?ms)^## 最小例子\s*\r?\n(?<section>.*?)(?=^## |\z)'
    )
    if ($minimumExampleMatch.Success) {
        $pythonBlocks = [regex]::Matches(
            $minimumExampleMatch.Groups['section'].Value,
            '(?ms)^```python\s*\r?\n(?<code>.*?)^```\s*$'
        )
        for ($blockIndex = 0; $blockIndex -lt $pythonBlocks.Count; $blockIndex++) {
            $code = $pythonBlocks[$blockIndex].Groups['code'].Value
            if (-not $code.Trim()) {
                $issues += "Python minimum example block $($blockIndex + 1) is empty"
            }
        }
    }
    else {
        $atomicGranularityIssues += [pscustomobject]@{ path = $file.FullName; issue = 'minimum example section must be non-empty' }
    }
    if ($minimumExampleMatch.Success -and -not $minimumExampleMatch.Groups['section'].Value.Trim()) {
        $atomicGranularityIssues += [pscustomobject]@{ path = $file.FullName; issue = 'minimum example section must be non-empty' }
    }
    $atomicNoteRecords += [pscustomobject]@{
        path = $file.FullName
        atomic_id = Get-FrontmatterScalarValue $content 'atomic_id'
        term_id = Get-FrontmatterScalarValue $content 'term_id'
    }
    if ($issues.Count -gt 0) {
        $invalidAtomicNotes += [pscustomobject]@{
            path = $file.FullName
            issues = $issues
        }
    }
}

$terminologyPath = Join-Path $vaultPath '10-术语规范.md'
$terminologyContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $terminologyPath
$terminologyLines = @(Get-Content -Encoding UTF8 -LiteralPath $terminologyPath)
$entries = @()
$inTable = $false
foreach ($line in $terminologyLines) {
    if ($line -eq '## 规范词表') {
        $inTable = $true
        continue
    }
    if ($inTable -and $line -match '^## ') {
        break
    }
    if (-not $inTable -or $line -notmatch '^\|') {
        continue
    }
    $parts = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($parts.Count -ne 8 -or $parts[0] -eq 'ID' -or $parts[0] -match '^-+$') {
        continue
    }
    $entries += [pscustomobject]@{
        id = $parts[0]
        canonical = $parts[1]
        structural_role = $parts[2]
        knowledge_category = $parts[3]
        parent = $parts[4]
        code_forms = $parts[5]
        deprecated_aliases = $parts[6]
        status = $parts[7]
    }
}

$terminologyIssues = @()
if ($entries.Count -eq 0) {
    $terminologyIssues += 'no terminology rows parsed'
}
$duplicateTermIds = @(
    $entries | Group-Object id | Where-Object Count -gt 1 | Select-Object -ExpandProperty Name
)
$duplicateCanonicalNames = @(
    $entries | Group-Object canonical | Where-Object Count -gt 1 | Select-Object -ExpandProperty Name
)
if ($duplicateTermIds.Count -gt 0) {
    $terminologyIssues += "duplicate IDs: $($duplicateTermIds -join ', ')"
}
if ($duplicateCanonicalNames.Count -gt 0) {
    $terminologyIssues += "duplicate canonical names: $($duplicateCanonicalNames -join ', ')"
}

$canonicalNames = @($entries | ForEach-Object { $_.canonical })
$canonicalSet = @{}
foreach ($name in $canonicalNames) {
    $canonicalSet[$name] = $true
}
$codeFormSet = @{}
foreach ($entry in $entries) {
    foreach ($form in @($entry.code_forms -split '、')) {
        $clean = $form.Trim().Trim('`')
        if ($clean) {
            $codeFormSet[$clean] = $true
        }
    }
}
$tagSet = @{}
foreach ($entry in @($entries | Where-Object structural_role -eq '标签')) {
    $tagSet[$entry.canonical] = $true
}

$orphanParentTerms = @(
    $entries |
        Where-Object { $_.parent -and -not $canonicalSet.ContainsKey($_.parent) } |
        ForEach-Object {
            [pscustomobject]@{
                id = $_.id
                parent = $_.parent
            }
        }
)
if ($orphanParentTerms.Count -gt 0) {
    $terminologyIssues += 'orphan parent terms'
}

$atomicIds = @($atomicNoteRecords | ForEach-Object { $_.atomic_id } | Where-Object { $_ })
$duplicateAtomicIds = @(
    $atomicIds | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
)
$invalidAtomicTermRefs = @(
    $atomicNoteRecords | Where-Object {
        $record = $_
        -not $record.atomic_id -or -not $record.term_id -or @($entries | Where-Object { $_.id -eq $record.term_id }).Count -ne 1
    } | ForEach-Object {
        [pscustomobject]@{ path = $_.path; atomic_id = $_.atomic_id; term_id = $_.term_id }
    }
)
foreach ($record in $atomicNoteRecords | Where-Object { -not $_.atomic_id }) {
    $atomicGranularityIssues += [pscustomobject]@{ path = $record.path; issue = 'missing atomic_id' }
}

$reviewBankRoot = Join-Path $vaultPath '60-复习'
$reviewBankRequiredHeadings = @('## 因果预测', '## 修错定位', '## 换情境迁移', '## 复习记录')
$allowedExtraReviewKinds = @('boundary-comparison', 'error-diagnosis', 'integration-transfer', 'task-performance', 'retention')
$invalidReviewBanks = @()
$mirrorClaims = @()
$orphanReviewAtomicRefs = @()
foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $reviewBankRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $issues = @()
    if ($content -notmatch '(?m)^## 复习记录\s*$') { $issues += 'missing heading: ## 复习记录' }
    $reviewKind = Get-FrontmatterScalarValue $content 'review_kind'
    $primaryAtomic = Get-FrontmatterScalarValue $content 'primary_atomic'
    $relatedAtomics = @(Get-FrontmatterListValues $content 'related_atomics')
    $taskUnits = @(Get-FrontmatterListValues $content 'task_units')
    if ($reviewKind -eq 'atomic-mirror') {
        if (-not $primaryAtomic) { $issues += 'atomic-mirror requires primary_atomic' }
        if ($relatedAtomics.Count -ne 0) { $issues += 'atomic-mirror requires related_atomics: []' }
        if ($primaryAtomic) { $mirrorClaims += [pscustomobject]@{ path = $file.FullName; atomic_id = $primaryAtomic } }
    }
    elseif ($reviewKind -notin $allowedExtraReviewKinds) {
        $issues += 'review_kind must be atomic-mirror or a permitted extra kind'
    }
    elseif ($relatedAtomics.Count -eq 0 -and $taskUnits.Count -eq 0) {
        $issues += 'extra review requires related_atomics or task_units'
    }
    $allAtomicRefs = @($relatedAtomics)
    if ($primaryAtomic) { $allAtomicRefs += $primaryAtomic }
    foreach ($atomicRef in $allAtomicRefs) {
        if ($atomicIds -notcontains $atomicRef) {
            $orphanReviewAtomicRefs += [pscustomobject]@{ path = $file.FullName; atomic_id = $atomicRef }
        }
    }
    if ($issues.Count -gt 0) { $invalidReviewBanks += [pscustomobject]@{ path = $file.FullName; issues = $issues } }
}
$atomicMirrorGaps = @(
    foreach ($atomicId in $atomicIds) {
        if (@($mirrorClaims | Where-Object { $_.atomic_id -eq $atomicId }).Count -eq 0) { $atomicId }
    }
)
$duplicateAtomicMirrors = @(
    $mirrorClaims | Group-Object atomic_id | Where-Object { $_.Count -gt 1 } | ForEach-Object { [pscustomobject]@{ atomic_id = $_.Name; paths = @($_.Group.path) } }
)

$namingSurfaceIssues = @()
function Test-CanonicalValue {
    param(
        [string]$Path,
        [string]$Surface,
        [string]$Value
    )
    if (-not $canonicalSet.ContainsKey($Value)) {
        $script:namingSurfaceIssues += [pscustomobject]@{
            path = $Path
            surface = $Surface
            value = $Value
        }
    }
}

if ($homepageContent -match '(?m)^current_stage:\s*(.+?)\s*$') {
    Test-CanonicalValue $homepagePath 'current_stage' $Matches[1].Trim('"')
}
if ($mainlineContent -match '(?m)^current_stage:\s*(.+?)\s*$') {
    Test-CanonicalValue $mainlinePath 'current_stage' $Matches[1].Trim('"')
}
foreach ($match in [regex]::Matches($mainlineContent, '(?m)^## 阶段[一二三四五六七八九十]+：(.+?)\s*$')) {
    Test-CanonicalValue $mainlinePath 'mainline_stage' $match.Groups[1].Value.Trim()
}
foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $weeklyRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    if ($content -match '(?m)^stage:\s*(.+?)\s*$') {
        Test-CanonicalValue $file.FullName 'weekly_stage' $Matches[1].Trim('"')
    }
}
foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $reviewRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    if ($content -match '(?m)^主题:\s*(.+?)\s*$') {
        Test-CanonicalValue $file.FullName 'daily_topic' $Matches[1].Trim('"')
    }
}
foreach ($file in @(Get-ChildItem -Recurse -File -Filter '*.md' -LiteralPath $atomicRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    if ($content -match '(?m)^主题:\s*(.+?)\s*$') {
        Test-CanonicalValue $file.FullName 'atomic_topic' $Matches[1].Trim('"')
    }
    $prefix = $file.BaseName.Split(' - ')[0]
    if (-not $canonicalSet.ContainsKey($prefix) -and -not $codeFormSet.ContainsKey($prefix)) {
        $namingSurfaceIssues += [pscustomobject]@{
            path = $file.FullName
            surface = 'atomic_prefix'
            value = $prefix
        }
    }
}

$mapRoot = Join-Path $vaultPath '50-主题地图'
foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $mapRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    if ($content -match '(?m)^topic:\s*(.+?)\s*$') {
        Test-CanonicalValue $file.FullName 'topic_map_topic' $Matches[1].Trim('"')
    }
    if (-not $canonicalSet.ContainsKey($file.BaseName)) {
        $namingSurfaceIssues += [pscustomobject]@{
            path = $file.FullName
            surface = 'topic_map_filename'
            value = $file.BaseName
        }
    }
}

$reviewBankRoot = Join-Path $vaultPath '60-复习'
foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $reviewBankRoot)) {
    $prefix = $file.BaseName.Split(' - ')[0]
    if (-not $canonicalSet.ContainsKey($prefix) -and -not $codeFormSet.ContainsKey($prefix)) {
        $namingSurfaceIssues += [pscustomobject]@{
            path = $file.FullName
            surface = 'review_prefix'
            value = $prefix
        }
    }
}

foreach ($file in $markdown) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    foreach ($match in [regex]::Matches($content, '(?m)^  - (python-[^\s]+)\s*$')) {
        $tag = $match.Groups[1].Value
        if (-not $tagSet.ContainsKey($tag)) {
            $namingSurfaceIssues += [pscustomobject]@{
                path = $file.FullName
                surface = 'tag'
                value = $tag
            }
        }
    }
}

$deprecatedAliasHits = @()
foreach ($entry in $entries) {
    foreach ($alias in @($entry.deprecated_aliases -split '、')) {
        $cleanAlias = $alias.Trim().Trim('`')
        if (-not $cleanAlias) {
            continue
        }
        foreach ($file in $markdown) {
            if ($file.FullName -eq $terminologyPath) {
                continue
            }
            $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
            $aliasPattern = "(?<![\p{L}\p{N}_])$([regex]::Escape($cleanAlias))(?![\p{L}\p{N}_])"
            if ($content -match $aliasPattern) {
                $deprecatedAliasHits += [pscustomobject]@{
                    alias = $cleanAlias
                    canonical = $entry.canonical
                    path = $file.FullName
                }
            }
        }
    }
}

$legacyReferences = @()
foreach ($file in $markdown) {
    if ($file.FullName -eq $terminologyPath) {
        continue
    }
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    if ($content -match '\[\[(问题看板|里程碑索引|项目索引|来源索引|Python - 面向对象与类型标注|类与方法 - 对象创建与调用复习|dataclass - post_init)' -or
        $content -match 'design-tech-learning|plan-tech-learning|run-tech-learning|learning-session-protocol|\.tmp-plugin-tech-learning-workflow|\.tmp-validation-deps') {
        $legacyReferences += $file.FullName
    }
}

$result = [pscustomobject]@{
    vault = $vaultPath
    mode = 'strict'
    schema_version = $schema.schema_version
    schema_source = $schemaSource
    markdown_files = $markdown.Count
    curriculum_units = $mainlineUnitIds.Count
    daily_reviews = $reviewDates.Count
    atomic_notes = @(Get-ChildItem -Recurse -File -Filter '*.md' -LiteralPath $atomicRoot).Count
    registered_terms = $entries.Count
    missing_required = $missing
    legacy_paths_present = $legacyPathsPresent
    non_markdown_note_files = $nonMarkdownNoteFiles
    duplicate_root_prefixes = $duplicateRootPrefixes
    duplicate_basenames = $duplicates
    broken_links = $brokenLinks
    invalid_daily_reviews = $invalidDailyReviews
    daily_template_issues = $dailyTemplateIssues
    duplicate_review_dates = $duplicateReviewDates
    invalid_weekly_notes = $invalidWeeklyNotes
    homepage_issues = $homepageIssues
    mainline_issues = $mainlineIssues
    source_contract_issues = $sourceContractIssues
    review_queue_issues = $reviewQueueIssues
    weekly_template_issues = $weeklyTemplateIssues
    job_requirement_template_issues = $jobRequirementTemplateIssues
    invalid_job_requirement_notes = $invalidJobRequirementNotes
    review_template_issues = $reviewTemplateIssues
    invalid_atomic_notes = $invalidAtomicNotes
    duplicate_atomic_ids = $duplicateAtomicIds
    invalid_atomic_term_refs = $invalidAtomicTermRefs
    atomic_granularity_issues = $atomicGranularityIssues
    invalid_review_banks = $invalidReviewBanks
    atomic_mirror_gaps = $atomicMirrorGaps
    duplicate_atomic_mirrors = $duplicateAtomicMirrors
    orphan_review_atomic_refs = $orphanReviewAtomicRefs
    terminology_issues = $terminologyIssues
    orphan_parent_terms = $orphanParentTerms
    unregistered_term_surfaces = $namingSurfaceIssues
    deprecated_alias_hits = $deprecatedAliasHits
    legacy_references = $legacyReferences
    warnings = @($warnings)
    downgraded = [pscustomobject]@{
        unregistered_term_surfaces = $namingSurfaceIssues.Count
        deprecated_alias_hits = $deprecatedAliasHits.Count
        legacy_references = $legacyReferences.Count
    }
    terminology_coverage = [pscustomobject]@{
        naming_surfaces_checked = (
            2 +
            @([regex]::Matches($mainlineContent, '(?m)^## 阶段[一二三四五六七八九十]+：')).Count +
            @(Get-ChildItem -File -Filter '*.md' -LiteralPath $weeklyRoot).Count +
            @(Get-ChildItem -File -Filter '*.md' -LiteralPath $reviewRoot).Count +
            (2 * @(Get-ChildItem -Recurse -File -Filter '*.md' -LiteralPath $atomicRoot).Count) +
            (2 * @(Get-ChildItem -File -Filter '*.md' -LiteralPath $mapRoot).Count) +
            @(Get-ChildItem -File -Filter '*.md' -LiteralPath $reviewBankRoot).Count
        )
        unregistered = $namingSurfaceIssues.Count
        known_alias_hits = $deprecatedAliasHits.Count
    }
    valid = (
        $missing.Count -eq 0 -and
        $legacyPathsPresent.Count -eq 0 -and
        $nonMarkdownNoteFiles.Count -eq 0 -and
        $duplicateRootPrefixes.Count -eq 0 -and
        $duplicates.Count -eq 0 -and
        $brokenLinks.Count -eq 0 -and
        $invalidDailyReviews.Count -eq 0 -and
        $dailyTemplateIssues.Count -eq 0 -and
        $duplicateReviewDates.Count -eq 0 -and
        $invalidWeeklyNotes.Count -eq 0 -and
        $homepageIssues.Count -eq 0 -and
        $mainlineIssues.Count -eq 0 -and
        $sourceContractIssues.Count -eq 0 -and
        $reviewQueueIssues.Count -eq 0 -and
        $weeklyTemplateIssues.Count -eq 0 -and
        $jobRequirementTemplateIssues.Count -eq 0 -and
        $invalidJobRequirementNotes.Count -eq 0 -and
        $reviewTemplateIssues.Count -eq 0 -and
        $invalidAtomicNotes.Count -eq 0 -and
        $duplicateAtomicIds.Count -eq 0 -and
        $invalidAtomicTermRefs.Count -eq 0 -and
        $atomicGranularityIssues.Count -eq 0 -and
        $invalidReviewBanks.Count -eq 0 -and
        $atomicMirrorGaps.Count -eq 0 -and
        $duplicateAtomicMirrors.Count -eq 0 -and
        $orphanReviewAtomicRefs.Count -eq 0 -and
        $terminologyIssues.Count -eq 0 -and
        $orphanParentTerms.Count -eq 0
    )
}

$result | ConvertTo-Json -Depth 20
if (-not $result.valid) {
    exit 1
}
