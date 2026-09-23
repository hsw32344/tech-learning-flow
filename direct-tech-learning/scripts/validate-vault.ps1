param(
    [Alias('VaultRoot')][string]$Vault,
    [switch]$Strict,
    [switch]$Diagnostics
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'vault-contract.ps1')
. (Join-Path $PSScriptRoot 'vault-rules.ps1')
. (Join-Path $PSScriptRoot 'route-rules.ps1')

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
# Relative-path arithmetic below assumes the root and the enumerated child
# FullName values use the same form. A short 8.3 input (for example a $env:TEMP
# path) otherwise mismatches the filesystem's long names and can silently hide
# every markdown file, so align the root with the first resolved child.
$vaultProbe = @(Get-ChildItem -LiteralPath $vaultPath -Force | Select-Object -First 1)
if ($vaultProbe.Count -gt 0) {
    $probeName = $vaultProbe[0].Name
    $probeFull = $vaultProbe[0].FullName
    $probePrefix = $probeFull.Substring(0, [Math]::Max(0, $probeFull.Length - $probeName.Length))
    if ($probePrefix.EndsWith('\') -and $probePrefix.TrimEnd('\')) {
        $vaultPath = $probePrefix.TrimEnd('\')
    }
}

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
    $coreHomepageProperties = @('type', 'current_stage', 'current_unit', 'current_position')
    $coreMainlineProperties = @('type', 'current_unit')
    if ($schema.PSObject.Properties['core'] -and $null -ne $schema.core) {
        if ($schema.core.PSObject.Properties['homepage_properties'] -and @($schema.core.homepage_properties).Count -gt 0) {
            $coreHomepageProperties = @($schema.core.homepage_properties)
        }
        if ($schema.core.PSObject.Properties['mainline_properties'] -and @($schema.core.mainline_properties).Count -gt 0) {
            $coreMainlineProperties = @($schema.core.mainline_properties)
        }
    }
    $coreRequired = @()
    if ($schema.PSObject.Properties['paths'] -and $schema.paths.PSObject.Properties['required']) {
        $coreRequired = @($schema.paths.required)
    }
    $coreMissing = @($coreRequired | Where-Object { -not (Test-Path -LiteralPath (Join-Path $vaultPath $_)) })
    $coreHomepagePath = Join-Path $vaultPath '00-首页.md'
    $coreOverviewPath = Join-Path $vaultPath '20-学习主线\00-总览.md'
    $coreHomepage = if (Test-Path -LiteralPath $coreHomepagePath -PathType Leaf) { Get-Content -Raw -Encoding UTF8 -LiteralPath $coreHomepagePath } else { '' }
    $coreOverview = if (Test-Path -LiteralPath $coreOverviewPath -PathType Leaf) { Get-Content -Raw -Encoding UTF8 -LiteralPath $coreOverviewPath } else { '' }
    $coreIssues = @()
    if ($coreRequired.Count -eq 0) {
        $coreIssues += 'vault schema lacks paths.required; the core readiness check cannot run'
    }
    foreach ($property in $coreHomepageProperties) {
        if ($coreHomepage -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
            $coreIssues += "homepage missing property: $property"
        }
    }
    foreach ($property in $coreMainlineProperties) {
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
        $taskRegistryPath = Join-Path $mainlineDir '20-任务包注册表.md'
        $mainlineText = if (Test-Path -LiteralPath $taskRegistryPath -PathType Leaf) {
            Get-Content -Raw -Encoding UTF8 -LiteralPath $taskRegistryPath
        }
        else { '' }
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

$schemaPaths = if ($schema.PSObject.Properties['paths'] -and $null -ne $schema.paths) { $schema.paths } else { $null }
$required = @()
$forbiddenLegacyPaths = @()
if ($null -ne $schemaPaths) {
    if ($schemaPaths.PSObject.Properties['required']) { $required = @($schemaPaths.required) }
    if ($schemaPaths.PSObject.Properties['forbidden_legacy']) { $forbiddenLegacyPaths = @($schemaPaths.forbidden_legacy) }
}
$schemaDefects = @()
if ($required.Count -eq 0) { $schemaDefects += 'vault schema lacks paths.required' }

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

$canonicalMarkdownFiles = @()
$canonicalMarkdownRoots = @()
$canonicalNoteRoots = @()
if ($null -ne $schemaPaths) {
    if ($schemaPaths.PSObject.Properties['markdown_files']) { $canonicalMarkdownFiles = @($schemaPaths.markdown_files) }
    if ($schemaPaths.PSObject.Properties['markdown_roots']) { $canonicalMarkdownRoots = @($schemaPaths.markdown_roots) }
    if ($schemaPaths.PSObject.Properties['note_roots']) { $canonicalNoteRoots = @($schemaPaths.note_roots) }
}


# Get-VaultContentFiles is shared through vault-contract.ps1.

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
# Test-WikiTarget is shared through vault-contract.ps1.

$brokenLinks = @()
foreach ($file in $markdown) {
    if ($file.FullName -like '*\90-模板\*') { continue }
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    foreach ($match in [regex]::Matches($content, '\[\[([^\]|#]+)')) {
        $target = $match.Groups[1].Value
        if (-not (Test-WikiTarget -Target $target -Source $file.FullName -VaultRoot $vaultPath -FileNames $fileNames -ContentPaths $contentPaths -ContentFiles $contentFiles)) {
            $brokenLinks += [pscustomobject]@{ source = $file.FullName; target = $target }
        }
    }
}

$reviewRoot = Join-Path $vaultPath '30-学习日志\学习回顾'
$invalidDailyReviews = @()
$reviewDates = @{}
foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $reviewRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $issues = @(Get-DailyReviewIssues -Content $content -BaseName $file.BaseName)
    if ($file.BaseName -match '^(\d{4}-\d{2}-\d{2}) 学习回顾$') {
        $date = $Matches[1]
        if (-not $reviewDates.ContainsKey($date)) {
            $reviewDates[$date] = @()
        }
        $reviewDates[$date] += $file.FullName
        if (-not (Test-DailyReviewSourceSection -Content $content)) {
            $warnings += "daily review lacks actual learning-source section: $($file.FullName)"
        }
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
$dailyTemplateIssues = @(Get-DailyTemplateIssues -Content $dailyTemplateContent)

$weeklyRoot = Join-Path $vaultPath '30-学习日志\每周'
$weeklyRequiredHeadings = @($schema.weekly.headings)
$weeklyRequiredProperties = @($schema.weekly.properties)
$invalidWeeklyNotes = @()
foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $weeklyRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $issues = @(Get-WeeklyNoteIssues -Content $content -BaseName $file.BaseName `
            -Properties $weeklyRequiredProperties -Headings $weeklyRequiredHeadings `
            -StatusEnum @($schema.weekly.status_enum))
    if ($issues.Count -gt 0) {
        $invalidWeeklyNotes += [pscustomobject]@{
            path = $file.FullName
            issues = $issues
        }
    }
}

$homepagePath = Join-Path $vaultPath '00-首页.md'
$homepageContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $homepagePath
$mainlineDir = Join-Path $vaultPath '20-学习主线'
$mainlinePath = Join-Path $mainlineDir '00-总览.md'
$taskRegistryPath = Join-Path $mainlineDir '20-任务包注册表.md'
$stageDir = Join-Path $mainlineDir '10-阶段'
$mainlineContent = if (Test-Path -LiteralPath $mainlinePath -PathType Leaf) { Get-Content -Raw -Encoding UTF8 -LiteralPath $mainlinePath } else { '' }
$taskRegistryContent = if (Test-Path -LiteralPath $taskRegistryPath -PathType Leaf) { Get-Content -Raw -Encoding UTF8 -LiteralPath $taskRegistryPath } else { '' }
$stageFiles = if (Test-Path -LiteralPath $stageDir -PathType Container) { @(Get-ChildItem -LiteralPath $stageDir -File -Filter '*.md' | Sort-Object Name) } else { @() }
$stageContent = (@($stageFiles | ForEach-Object { Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName }) -join "`n")
$routeStructureIssues = @(Get-RouteStructureRuleIssues -HomepageContent $homepageContent -MainlineContent $mainlineContent `
        -Schema $schema -WeeklyRoot $weeklyRoot)
$homepageIssues = @($routeStructureIssues | Where-Object { $_.field -eq 'homepage_issues' } | ForEach-Object { $_.message })
$mainlineIssues = @($routeStructureIssues | Where-Object { $_.field -eq 'mainline_issues' } | ForEach-Object { $_.message })

# Frontmatter readers and per-artifact rules are shared through vault-rules.ps1.

$mainlineUnitIds = @([regex]::Matches($taskRegistryContent, $UnitRowPattern) | ForEach-Object { $_.Groups['id'].Value })
$mainlineIssues += @(Get-StageOrderingRuleIssues -StageContent $stageContent -TaskRegistryContent $taskRegistryContent |
        Where-Object { $_.field -eq 'mainline_issues' } | ForEach-Object { $_.message })

$pluginRoot = Split-Path -Parent $PSScriptRoot
$sourceParadigmPath = Join-Path $pluginRoot 'references\curriculum-sources.md'
$sourceRegistryPath = Resolve-SourceRegistryPath -VaultRoot $vaultPath -PluginRoot $pluginRoot
$sourceParadigmContent = if (Test-Path -LiteralPath $sourceParadigmPath -PathType Leaf) { Get-Content -Raw -Encoding UTF8 -LiteralPath $sourceParadigmPath } else { '' }
$registeredSourceCodes = @()
$sourceContractIssues = @()
if (-not (Test-Path -LiteralPath $sourceRegistryPath -PathType Leaf)) {
    $mainlineIssues += "material source registry missing: $sourceRegistryPath"
}
else {
    $sourceRegistryContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourceRegistryPath
    $sourceRegistryMatches = @([regex]::Matches($sourceRegistryContent, $RegistryEntryPattern))
    $registeredSourceCodes = @($sourceRegistryMatches | ForEach-Object { $_.Groups['code'].Value })
    foreach ($issue in @(Get-SourceRegistryRuleIssues -RegistryEntries $sourceRegistryMatches)) {
        if ($issue.field -eq 'mainline_issues') { $mainlineIssues += $issue.message }
        else { $sourceContractIssues += $issue.message }
    }
    foreach ($issue in @(Get-SourceParadigmRuleIssues -SourceParadigmContent $sourceParadigmContent)) {
        $sourceContractIssues += $issue.message
    }
}

$currentUnitMatch = [regex]::Match($mainlineContent, "(?m)^current_unit:\s*(?<unit>$UnitIdPattern)\s*$")
$currentUnit = if ($currentUnitMatch.Success) { $currentUnitMatch.Groups['unit'].Value } else { $null }
$unitBindingIssues = @(Get-UnitBindingRuleIssues -TaskRegistryContent $taskRegistryContent -UnitIds $mainlineUnitIds -RegistryEntries $sourceRegistryMatches -CurrentUnit $currentUnit)
foreach ($issue in $unitBindingIssues) {
    if ($issue.field -eq 'mainline_issues') { $mainlineIssues += $issue.message }
    else { $sourceContractIssues += $issue.message }
}

$reviewQueuePath = Join-Path $vaultPath '70-复习队列.md'
$reviewQueueContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $reviewQueuePath
$reviewQueueIssues = @(Get-ReviewQueueIssues -Content $reviewQueueContent -Headings @($schema.files.'70-复习队列.md'.headings))
$reviewTemplatePath = Join-Path $vaultPath '90-模板\复习题模板.md'
$reviewTemplateContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $reviewTemplatePath
$reviewTemplateIssues = @(Get-ReviewTemplateIssues -Content $reviewTemplateContent)

$weeklyTemplatePath = Join-Path $vaultPath '90-模板\每周学习复盘模板.md'
$weeklyTemplateContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $weeklyTemplatePath
$weeklyTemplateIssues = @(Get-WeeklyTemplateIssues -Content $weeklyTemplateContent -Properties $weeklyRequiredProperties -Headings $weeklyRequiredHeadings)

$jobRequirementTemplatePath = Join-Path $vaultPath '90-模板\岗位需求分析模板.md'
$jobRequirementTemplateIssues = @()
if (-not (Test-Path -LiteralPath $jobRequirementTemplatePath -PathType Leaf)) {
    $jobRequirementTemplateIssues += 'missing job requirement analysis template'
}
else {
    $jobRequirementTemplateIssues += @(Get-JobTemplateIssues -Content (Get-Content -Raw -Encoding UTF8 -LiteralPath $jobRequirementTemplatePath))
}

$jobRequirementRoot = Join-Path $vaultPath '20-学习主线\岗位分析'
$invalidJobRequirementNotes = @()
if (Test-Path -LiteralPath $jobRequirementRoot -PathType Container) {
    foreach ($file in @(Get-ChildItem -LiteralPath $jobRequirementRoot -File -Filter '*.md')) {
        $issues = @(Get-JobNoteIssues -Content (Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName))
        if ($issues.Count -gt 0) {
            $invalidJobRequirementNotes += [pscustomobject]@{ path = $file.FullName; issues = $issues }
        }
    }
}

$atomicRoot = Join-Path $vaultPath '40-原子知识'
$invalidAtomicNotes = @()
$atomicNoteRecords = @()
$atomicGranularityIssues = @()
foreach ($file in @(Get-ChildItem -Recurse -File -Filter '*.md' -LiteralPath $atomicRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $issues = @(Get-AtomicNoteIssues -Content $content)
    foreach ($finding in @(Get-AtomicGranularityFindings -Content $content)) {
        $atomicGranularityIssues += [pscustomobject]@{ path = $file.FullName; issue = $finding }
    }
    $atomicNoteRecords += [pscustomobject]@{
        path = $file.FullName
        atomic_id = Read-FrontmatterScalar -Content $content -Key 'atomic_id'
        term_id = Read-FrontmatterScalar -Content $content -Key 'term_id'
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
$invalidReviewBanks = @()
$mirrorClaims = @()
$orphanReviewAtomicRefs = @()
foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $reviewBankRoot)) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $analysis = Get-ReviewBankAnalysis -Content $content
    $issues = @($analysis.issues)
    $primaryAtomic = $analysis.primary_atomic
    $relatedAtomics = @($analysis.related_atomics)
    if ($analysis.review_kind -eq 'atomic-mirror' -and $primaryAtomic) {
        $mirrorClaims += [pscustomobject]@{ path = $file.FullName; atomic_id = $primaryAtomic }
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
$atomicMirrorGaps = @()
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
    schema_defects = $schemaDefects
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
        atomic_mirror_gaps = $atomicMirrorGaps.Count
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
        $schemaDefects.Count -eq 0 -and
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
        $duplicateAtomicMirrors.Count -eq 0 -and
        $orphanReviewAtomicRefs.Count -eq 0 -and
        $terminologyIssues.Count -eq 0 -and
        $orphanParentTerms.Count -eq 0
    )
}

# Structured diagnostics keep every error's code, category, paths, and reason
# stable, so thin validators never have to re-derive meaning from bucket shapes.
# They are built only on request: the full audit stays lean by default.
if ($Diagnostics) {
    $diagnosticFields = @(
        'schema_defects', 'missing_required', 'legacy_paths_present', 'non_markdown_note_files', 'duplicate_root_prefixes',
        'duplicate_basenames', 'broken_links', 'invalid_daily_reviews', 'daily_template_issues',
        'duplicate_review_dates', 'invalid_weekly_notes', 'weekly_template_issues', 'homepage_issues',
        'mainline_issues', 'source_contract_issues', 'review_queue_issues', 'review_template_issues',
        'job_requirement_template_issues', 'invalid_job_requirement_notes', 'invalid_atomic_notes',
        'duplicate_atomic_ids', 'invalid_atomic_term_refs', 'atomic_granularity_issues',
        'invalid_review_banks', 'duplicate_atomic_mirrors', 'orphan_review_atomic_refs',
        'atomic_mirror_gaps', 'terminology_issues', 'orphan_parent_terms', 'unregistered_term_surfaces',
        'deprecated_alias_hits', 'legacy_references'
    )
    $normalizedDiagnostics = @()
    foreach ($field in $diagnosticFields) {
        $normalizedDiagnostics += Get-VaultFieldDiagnostics -Result $result -Field $field
    }
    Add-Member -InputObject $result -NotePropertyName 'diagnostics' -NotePropertyValue $normalizedDiagnostics
}

$result | ConvertTo-Json -Depth 20
if (-not $result.valid) {
    exit 1
}
