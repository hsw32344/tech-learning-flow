# Scoped change validation: validate the declared change set and its real
# dependencies inside one invocation, reusing the shared domain rules from
# vault-rules.ps1 and route-rules.ps1. A missing or inconsistent change
# declaration is reported as an explicit failure; the executor never guesses a
# delete from a missing path and never falls back to a whole-vault scan.

. (Join-Path $PSScriptRoot 'vault-contract.ps1')
. (Join-Path $PSScriptRoot 'vault-rules.ps1')
. (Join-Path $PSScriptRoot 'route-rules.ps1')
. (Join-Path $PSScriptRoot 'validation-registry.ps1')

$script:ScopeContentCache = @{}

function Get-ScopeContent {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not $script:ScopeContentCache.ContainsKey($Path)) {
        $script:ScopeContentCache[$Path] = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
    }
    return $script:ScopeContentCache[$Path]
}

function New-ScopeDiagnostic {
    param(
        [Parameter(Mandatory = $true)][string]$Field,
        [Parameter(Mandatory = $true)]$Item
    )
    return ConvertTo-VaultDiagnostic -Item $Item -Field $Field
}

function ConvertTo-ScopeFullPath {
    param([string]$VaultRoot, [string]$PathText)
    if ([string]::IsNullOrWhiteSpace($PathText)) { return $null }
    $normalized = ConvertTo-NormalizedPath $PathText
    if (-not [IO.Path]::IsPathRooted($normalized)) { $normalized = Join-Path $VaultRoot $normalized }
    try { return ConvertTo-NormalizedPath ([IO.Path]::GetFullPath($normalized)) } catch { return $null }
}

function Test-ScopeUnderRoot {
    param([string]$FullPath, [string]$RootPath)
    if ([string]::IsNullOrWhiteSpace($FullPath) -or [string]::IsNullOrWhiteSpace($RootPath)) { return $false }
    $root = ConvertTo-NormalizedPath $RootPath
    return ($FullPath.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
        $FullPath.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase))
}

function Read-ScopeSchema {
    param([string]$VaultRoot, [string]$BundledSchemaPath)
    $markerPath = Join-Path $VaultRoot '.tech-vault.json'
    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        try {
            $marker = [IO.File]::ReadAllText($markerPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            if ($marker.PSObject.Properties['schema'] -and $null -ne $marker.schema) { return $marker.schema }
        }
        catch { }
    }
    if (Test-Path -LiteralPath $BundledSchemaPath -PathType Leaf) {
        try { return ([IO.File]::ReadAllText($BundledSchemaPath, [Text.Encoding]::UTF8) | ConvertFrom-Json) } catch { return $null }
    }
    return $null
}

function Get-ScopeFrontmatterText {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (@(Get-Content -LiteralPath $Path -TotalCount 40 -Encoding UTF8) -join "`n")
}

function Get-ScopeAtomicIdentity {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Read-FrontmatterScalar -Content (Get-ScopeFrontmatterText -Path $Path) -Key 'atomic_id')
}

function Get-ScopeTerminologyEntries {
    param([Parameter(Mandatory = $true)][string]$VaultRoot)
    $path = Join-Path $VaultRoot '10-术语规范.md'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    $entries = @()
    $inTable = $false
    foreach ($line in @(Get-Content -Encoding UTF8 -LiteralPath $path)) {
        if ($line -eq '## 规范词表') { $inTable = $true; continue }
        if ($inTable -and $line -match '^## ') { break }
        if (-not $inTable -or $line -notmatch '^\|') { continue }
        $parts = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($parts.Count -ne 8 -or $parts[0] -eq 'ID' -or $parts[0] -match '^-+$') { continue }
        $entries += [pscustomobject]@{ id = $parts[0]; canonical = $parts[1] }
    }
    return $entries
}

# One metadata pass, scoped to the selected kinds: filenames and frontmatter
# only, and unrelated areas are never read. Bodies of unrelated files are never
# read here.
function Get-ScopeIndex {
    param(
        [Parameter(Mandatory = $true)][string]$VaultRoot,
        $Schema,
        [string[]]$Kinds = @(),
        [switch]$NeedsReviewRecords
    )
    $markdownFileNames = @()
    $markdownRoots = @()
    if ($null -ne $Schema -and $Schema.PSObject.Properties['paths'] -and $null -ne $Schema.paths) {
        $sp = $Schema.paths
        if ($sp.PSObject.Properties['markdown_files']) { $markdownFileNames = @($sp.markdown_files) }
        if ($sp.PSObject.Properties['markdown_roots']) { $markdownRoots = @($sp.markdown_roots) }
    }
    $contentFiles = @(Get-VaultContentFiles -Root $VaultRoot)
    $markdownFiles = @($contentFiles | Where-Object {
            $relative = $_.FullName.Substring($VaultRoot.Length + 1)
            $root = ($relative -split '[\\/]')[0]
            $_.Extension -ieq '.md' -and ($relative -in $markdownFileNames -or $root -in $markdownRoots)
        })
    $fileNames = @{}
    $contentPaths = @{}
    foreach ($file in $contentFiles) {
        if (-not $fileNames.ContainsKey($file.Name)) { $fileNames[$file.Name] = @() }
        $fileNames[$file.Name] += $file.FullName
        $contentPaths[$file.FullName] = $true
    }

    $atomicRecords = @()
    if ($Kinds -contains 'atomic' -or $Kinds -contains 'reviewbank') {
        $atomicRoot = Join-Path $VaultRoot '40-原子知识'
        if (Test-Path -LiteralPath $atomicRoot -PathType Container) {
            foreach ($file in @(Get-ChildItem -Recurse -File -Filter '*.md' -LiteralPath $atomicRoot)) {
                $front = Get-ScopeFrontmatterText -Path $file.FullName
                $atomicRecords += [pscustomobject]@{
                    path      = $file.FullName
                    atomic_id = Read-FrontmatterScalar -Content $front -Key 'atomic_id'
                    term_id   = Read-FrontmatterScalar -Content $front -Key 'term_id'
                }
            }
        }
    }
    $reviewRecords = @()
    if ($Kinds -contains 'reviewbank' -or $NeedsReviewRecords) {
        $reviewRoot = Join-Path $VaultRoot '60-复习'
        if (Test-Path -LiteralPath $reviewRoot -PathType Container) {
            foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $reviewRoot)) {
                $front = Get-ScopeFrontmatterText -Path $file.FullName
                $reviewRecords += [pscustomobject]@{
                    path            = $file.FullName
                    review_kind     = Read-FrontmatterScalar -Content $front -Key 'review_kind'
                    primary_atomic  = Read-FrontmatterScalar -Content $front -Key 'primary_atomic'
                    related_atomics = @(Read-FrontmatterList -Content $front -Key 'related_atomics')
                }
            }
        }
    }
    $dailyRecords = @()
    if ($Kinds -contains 'daily') {
        $dailyRoot = Join-Path $VaultRoot '30-学习日志\学习回顾'
        if (Test-Path -LiteralPath $dailyRoot -PathType Container) {
            foreach ($file in @(Get-ChildItem -File -Filter '*.md' -LiteralPath $dailyRoot)) {
                $date = $null
                if ($file.BaseName -match '^(\d{4}-\d{2}-\d{2}) 学习回顾$') { $date = $Matches[1] }
                $dailyRecords += [pscustomobject]@{ path = $file.FullName; date = $date }
            }
        }
    }
    $terminologyEntries = @()
    if ($Kinds -contains 'atomic' -or $Kinds -contains 'topicmap') {
        $terminologyEntries = @(Get-ScopeTerminologyEntries -VaultRoot $VaultRoot)
    }
    return [pscustomobject]@{
        content_files       = $contentFiles
        markdown_files      = $markdownFiles
        file_names          = $fileNames
        content_paths       = $contentPaths
        atomic_records      = $atomicRecords
        review_records      = $reviewRecords
        daily_records       = $dailyRecords
        terminology_entries = $terminologyEntries
    }
}

function Get-ScopeCommonDiagnostics {
    param($Index, $Schema, [Parameter(Mandatory = $true)][string]$VaultRoot)
    $diags = @()
    if ($null -eq $Schema -or -not $Schema.PSObject.Properties['paths'] -or
        -not $Schema.paths.PSObject.Properties['required'] -or @($Schema.paths.required).Count -eq 0) {
        $diags += New-ScopeDiagnostic -Field 'schema_defects' -Item 'vault schema lacks paths.required'
    }
    # Unrelated historical structure defects belong to validate-vault.ps1.
    # An action checks only its declared targets and dependencies below.
    return $diags
}

function Get-ScopeRouteDiagnostics {
    param(
        [Parameter(Mandatory = $true)][string]$VaultRoot,
        $Schema
    )
    $diags = @()
    $homepagePath = Join-Path $VaultRoot '00-首页.md'
    $mainlinePath = Join-Path $VaultRoot '20-学习主线\00-总览.md'
    $taskRegistryPath = Join-Path $VaultRoot '20-学习主线\20-任务包注册表.md'
    $sourceRegistryPath = Resolve-SourceRegistryPath -VaultRoot $VaultRoot
    $stageRoot = Join-Path $VaultRoot '20-学习主线\10-阶段'
    foreach ($path in @($homepagePath, $mainlinePath, $taskRegistryPath, $sourceRegistryPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $diags += New-ScopeDiagnostic -Field 'missing_required' -Item $path
        }
    }
    if (-not (Test-Path -LiteralPath $stageRoot -PathType Container)) {
        $diags += New-ScopeDiagnostic -Field 'missing_required' -Item $stageRoot
    }
    if ($diags.Count -gt 0) { return $diags }

    $homepage = Get-ScopeContent -Path $homepagePath
    $mainline = Get-ScopeContent -Path $mainlinePath
    $taskRegistry = Get-ScopeContent -Path $taskRegistryPath
    $sourceRegistry = Get-ScopeContent -Path $sourceRegistryPath
    $stageText = (@(Get-ChildItem -LiteralPath $stageRoot -File -Filter '*.md' | Sort-Object Name |
                ForEach-Object { Get-ScopeContent -Path $_.FullName }) -join "`n")

    $weeklyRoot = Join-Path $VaultRoot '30-学习日志\每周'
    $structureIssues = @(Get-RouteStructureRuleIssues -HomepageContent $homepage -MainlineContent $mainline `
            -Schema $Schema -WeeklyRoot $weeklyRoot)
    $stageIssues = @(Get-StageOrderingRuleIssues -StageContent $stageText -TaskRegistryContent $taskRegistry)
    $registryEntries = @([regex]::Matches($sourceRegistry, $RegistryEntryPattern))
    $unitIds = @([regex]::Matches($taskRegistry, $UnitRowPattern) | ForEach-Object { $_.Groups['id'].Value })
    $currentUnitMatch = [regex]::Match($mainline, "(?m)^current_unit:\s*(?<unit>$UnitIdPattern)\s*$")
    $currentUnit = if ($currentUnitMatch.Success) { $currentUnitMatch.Groups['unit'].Value } else { $null }
    $bindingIssues = @(Get-UnitBindingRuleIssues -TaskRegistryContent $taskRegistry -UnitIds $unitIds `
            -RegistryEntries $registryEntries -CurrentUnit $currentUnit)
    $registryIssues = @(Get-SourceRegistryRuleIssues -RegistryEntries $registryEntries)
    $paradigmPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'references\curriculum-sources.md'
    $paradigmContent = if (Test-Path -LiteralPath $paradigmPath -PathType Leaf) {
        Get-Content -Raw -Encoding UTF8 -LiteralPath $paradigmPath
    }
    else { '' }
    $paradigmIssues = @(Get-SourceParadigmRuleIssues -SourceParadigmContent $paradigmContent)

    foreach ($issue in @($structureIssues + $registryIssues + $bindingIssues + $stageIssues + $paradigmIssues)) {
        $diags += New-ScopeDiagnostic -Field $issue.field -Item $issue.message
    }
    return $diags
}

function Get-ScopeHomepageDiagnostics {
    param(
        [Parameter(Mandatory = $true)][string]$VaultRoot,
        $Schema
    )
    $diags = @()
    $path = Join-Path $VaultRoot '00-首页.md'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return @(New-ScopeDiagnostic -Field 'missing_required' -Item $path)
    }
    $content = Get-ScopeContent -Path $path
    $properties = @('type', 'current_week', 'latest_review')
    if ($null -ne $Schema -and $Schema.PSObject.Properties['files'] -and
        $Schema.files.PSObject.Properties['00-首页.md'] -and
        $Schema.files.'00-首页.md'.PSObject.Properties['properties']) {
        $properties = @($Schema.files.'00-首页.md'.properties)
    }
    foreach ($property in $properties) {
        if ($content -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
            $diags += New-ScopeDiagnostic -Field 'homepage_issues' -Item "missing property: $property"
        }
    }
    $currentWeek = [regex]::Match($content, '(?m)^current_week\s*:\s*(?<value>\d{4}-W\d{2})\s*$')
    if ($currentWeek.Success) {
        $weeklyPath = Join-Path $VaultRoot ('30-学习日志\每周\' + $currentWeek.Groups['value'].Value + '.md')
        if (-not (Test-Path -LiteralPath $weeklyPath -PathType Leaf)) {
            $diags += New-ScopeDiagnostic -Field 'homepage_issues' -Item "current_week note missing: $($currentWeek.Groups['value'].Value)"
        }
    }
    return $diags
}

function Get-ScopeTopicMapDiagnostics {
    param($Index, [string[]]$RelatedTargets)
    $diags = @()
    $canonical = @{}
    foreach ($entry in $Index.terminology_entries) {
        if ($entry.canonical) { $canonical[$entry.canonical] = $true }
    }
    foreach ($path in @($RelatedTargets | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })) {
        if (-not $path.EndsWith('.md', [StringComparison]::OrdinalIgnoreCase)) { continue }
        $content = Get-ScopeContent -Path $path
        $baseName = [IO.Path]::GetFileNameWithoutExtension($path)
        if (-not $canonical.ContainsKey($baseName)) {
            $diags += New-ScopeDiagnostic -Field 'unregistered_term_surfaces' -Item ([pscustomobject]@{
                    path = $path; surface = 'topic_map_filename'; value = $baseName
                })
        }
        $topicMatch = [regex]::Match($content, '(?m)^topic:\s*(?<value>.+?)\s*$')
        if ($topicMatch.Success) {
            $topic = $topicMatch.Groups['value'].Value.Trim().Trim('"')
            if (-not $canonical.ContainsKey($topic)) {
                $diags += New-ScopeDiagnostic -Field 'unregistered_term_surfaces' -Item ([pscustomobject]@{
                        path = $path; surface = 'topic_map_topic'; value = $topic
                    })
            }
        }
    }
    return $diags
}

function Get-ScopeTerminologyDiagnostics {
    param([Parameter(Mandatory = $true)][string]$VaultRoot)
    $diags = @()
    $path = Join-Path $VaultRoot '10-术语规范.md'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return @(New-ScopeDiagnostic -Field 'missing_required' -Item $path)
    }
    $entries = @()
    $inTable = $false
    foreach ($line in @(Get-Content -Encoding UTF8 -LiteralPath $path)) {
        if ($line -eq '## 规范词表') { $inTable = $true; continue }
        if ($inTable -and $line -match '^## ') { break }
        if (-not $inTable -or $line -notmatch '^\|') { continue }
        $parts = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($parts.Count -ne 8 -or $parts[0] -eq 'ID' -or $parts[0] -match '^-+$') { continue }
        $entries += [pscustomobject]@{ id = $parts[0]; canonical = $parts[1]; parent = $parts[4] }
    }
    if ($entries.Count -eq 0) { $diags += New-ScopeDiagnostic -Field 'terminology_issues' -Item 'no terminology rows parsed' }
    if (@($entries | Group-Object id | Where-Object { $_.Count -gt 1 }).Count -gt 0) { $diags += New-ScopeDiagnostic -Field 'terminology_issues' -Item 'duplicate IDs' }
    if (@($entries | Group-Object canonical | Where-Object { $_.Count -gt 1 }).Count -gt 0) { $diags += New-ScopeDiagnostic -Field 'terminology_issues' -Item 'duplicate canonical names' }
    $names = @($entries | ForEach-Object { $_.canonical })
    foreach ($entry in @($entries | Where-Object { $_.parent -and $names -notcontains $_.parent })) {
        $diags += New-ScopeDiagnostic -Field 'orphan_parent_terms' -Item ([pscustomobject]@{ id = $entry.id; parent = $entry.parent })
    }
    return $diags
}

function Get-ScopeOutgoingLinkDiagnostics {
    param($Index, [string[]]$ChangedFiles, [Parameter(Mandatory = $true)][string]$VaultRoot)
    $diags = @()
    foreach ($path in $ChangedFiles) {
        if (-not $path.EndsWith('.md', [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($path -like '*\90-模板\*') { continue }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $content = Get-ScopeContent -Path $path
        foreach ($match in [regex]::Matches($content, '\[\[([^\]|#]+)')) {
            $target = $match.Groups[1].Value
            if (-not (Test-WikiTarget -Target $target -Source $path -VaultRoot $VaultRoot `
                        -FileNames $Index.file_names -ContentPaths $Index.content_paths -ContentFiles $Index.content_files)) {
                $diags += New-ScopeDiagnostic -Field 'broken_links' -Item ([pscustomobject]@{ source = $path; target = $target })
            }
        }
    }
    return $diags
}

function Get-ScopeDeletedLinkDiagnostics {
    param($Index, [object[]]$DeletedTargets, [Parameter(Mandatory = $true)][string]$VaultRoot)
    # A rename or delete must not miss inbound links: read all markdown bodies
    # once, only in this case.
    $diags = @()
    $deletedNames = @{}
    foreach ($target in $DeletedTargets) {
        $deletedNames[[IO.Path]::GetFileNameWithoutExtension($target)] = $true
        $deletedNames[[IO.Path]::GetFileName($target)] = $true
    }
    foreach ($file in $Index.markdown_files) {
        if ($file.FullName -like '*\90-模板\*') { continue }
        $content = Get-ScopeContent -Path $file.FullName
        foreach ($match in [regex]::Matches($content, '\[\[([^\]|#]+)')) {
            $linkText = $match.Groups[1].Value.Trim()
            $name = [IO.Path]::GetFileNameWithoutExtension($linkText)
            if (-not $deletedNames.ContainsKey($name)) { continue }
            if (-not (Test-WikiTarget -Target $linkText -Source $file.FullName -VaultRoot $VaultRoot `
                        -FileNames $Index.file_names -ContentPaths $Index.content_paths -ContentFiles $Index.content_files)) {
                $diags += New-ScopeDiagnostic -Field 'broken_links' -Item ([pscustomobject]@{ source = $file.FullName; target = $linkText })
            }
        }
    }
    return $diags
}

function Get-ScopeKindDiagnostics {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [string[]]$RelatedTargets,
        $Index,
        $Schema,
        [Parameter(Mandatory = $true)][string]$VaultRoot,
        [switch]$EnforceReviewScope
    )
    $diags = @()
    $existing = @($RelatedTargets | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    switch ($Kind) {
        'route' {
            $diags += @(Get-ScopeRouteDiagnostics -VaultRoot $VaultRoot -Schema $Schema)
        }
        'terminology' {
            $diags += @(Get-ScopeTerminologyDiagnostics -VaultRoot $VaultRoot)
        }
        'homepage' {
            $diags += @(Get-ScopeHomepageDiagnostics -VaultRoot $VaultRoot -Schema $Schema)
        }
        'topicmap' {
            $diags += @(Get-ScopeTopicMapDiagnostics -Index $Index -RelatedTargets $RelatedTargets)
        }
        'daily' {
            foreach ($path in $existing) {
                $content = Get-ScopeContent -Path $path
                $issues = @(Get-DailyReviewIssues -Content $content -BaseName ([IO.Path]::GetFileNameWithoutExtension($path)))
                if ($issues.Count -gt 0) {
                    $diags += New-ScopeDiagnostic -Field 'invalid_daily_reviews' -Item ([pscustomobject]@{ path = $path; issues = $issues })
                }
            }
            $changedDates = @{}
            foreach ($path in $existing) {
                $record = @($Index.daily_records | Where-Object { $_.path -eq $path }) | Select-Object -First 1
                if ($record -and $record.date) { $changedDates[$record.date] = $true }
            }
            foreach ($date in $changedDates.Keys) {
                $paths = @($Index.daily_records | Where-Object { $_.date -eq $date } | ForEach-Object { $_.path })
                if ($paths.Count -gt 1) {
                    $diags += New-ScopeDiagnostic -Field 'duplicate_review_dates' -Item ([pscustomobject]@{ date = $date; paths = $paths })
                }
            }
            $template = Join-Path $VaultRoot '90-模板\学习回顾模板.md'
            if (Test-Path -LiteralPath $template -PathType Leaf) {
                foreach ($issue in @(Get-DailyTemplateIssues -Content (Get-ScopeContent -Path $template))) {
                    $diags += New-ScopeDiagnostic -Field 'daily_template_issues' -Item $issue
                }
            }
        }
        'weekly' {
            $properties = @()
            $headings = @()
            $statusEnum = @()
            if ($null -ne $Schema -and $Schema.PSObject.Properties['weekly']) {
                if ($Schema.weekly.PSObject.Properties['properties']) { $properties = @($Schema.weekly.properties) }
                if ($Schema.weekly.PSObject.Properties['headings']) { $headings = @($Schema.weekly.headings) }
                if ($Schema.weekly.PSObject.Properties['status_enum']) { $statusEnum = @($Schema.weekly.status_enum) }
            }
            foreach ($path in $existing) {
                $content = Get-ScopeContent -Path $path
                $issues = @(Get-WeeklyNoteIssues -Content $content -BaseName ([IO.Path]::GetFileNameWithoutExtension($path)) `
                        -Properties $properties -Headings $headings -StatusEnum $statusEnum)
                if ($issues.Count -gt 0) {
                    $diags += New-ScopeDiagnostic -Field 'invalid_weekly_notes' -Item ([pscustomobject]@{ path = $path; issues = $issues })
                }
            }
            $template = Join-Path $VaultRoot '90-模板\每周学习复盘模板.md'
            if (Test-Path -LiteralPath $template -PathType Leaf) {
                foreach ($issue in @(Get-WeeklyTemplateIssues -Content (Get-ScopeContent -Path $template) -Properties $properties -Headings $headings)) {
                    $diags += New-ScopeDiagnostic -Field 'weekly_template_issues' -Item $issue
                }
            }
        }
        'atomic' {
            $allIds = @($Index.atomic_records | ForEach-Object { $_.atomic_id } | Where-Object { $_ })
            foreach ($path in $existing) {
                $content = Get-ScopeContent -Path $path
                $issues = @(Get-AtomicNoteIssues -Content $content)
                if ($issues.Count -gt 0) {
                    $diags += New-ScopeDiagnostic -Field 'invalid_atomic_notes' -Item ([pscustomobject]@{ path = $path; issues = $issues })
                }
                foreach ($finding in @(Get-AtomicGranularityFindings -Content $content)) {
                    $diags += New-ScopeDiagnostic -Field 'atomic_granularity_issues' -Item ([pscustomobject]@{ path = $path; issue = $finding })
                }
                $record = @($Index.atomic_records | Where-Object { $_.path -eq $path }) | Select-Object -First 1
                if ($record -and -not $record.atomic_id) {
                    $diags += New-ScopeDiagnostic -Field 'atomic_granularity_issues' -Item ([pscustomobject]@{ path = $path; issue = 'missing atomic_id' })
                }
                if ($record -and $record.atomic_id) {
                    $duplicateCount = @($Index.atomic_records | Where-Object { $_.atomic_id -eq $record.atomic_id }).Count
                    if ($duplicateCount -gt 1) {
                        $diags += New-ScopeDiagnostic -Field 'duplicate_atomic_ids' -Item $record.atomic_id
                    }
                }
                $termCount = if ($record -and $record.term_id) {
                    @($Index.terminology_entries | Where-Object { $_.id -eq $record.term_id }).Count
                }
                else { 0 }
                if ($record -and (-not $record.atomic_id -or -not $record.term_id -or $termCount -ne 1)) {
                    $diags += New-ScopeDiagnostic -Field 'invalid_atomic_term_refs' -Item ([pscustomobject]@{
                            path      = $path
                            atomic_id = $record.atomic_id
                            term_id   = $record.term_id
                        })
                }
            }
        }
        'reviewbank' {
            $allAtomicIds = @($Index.atomic_records | ForEach-Object { $_.atomic_id } | Where-Object { $_ })
            $scopeAtoms = @()
            $changedClaims = @()
            foreach ($path in $existing) {
                $content = Get-ScopeContent -Path $path
                $analysis = Get-ReviewBankAnalysis -Content $content
                if ($analysis.issues.Count -gt 0) {
                    $diags += New-ScopeDiagnostic -Field 'invalid_review_banks' -Item ([pscustomobject]@{ path = $path; issues = @($analysis.issues) })
                }
                $refs = @($analysis.related_atomics)
                if ($analysis.primary_atomic) { $refs += $analysis.primary_atomic }
                foreach ($ref in $refs) {
                    if ($allAtomicIds -notcontains $ref) {
                        $diags += New-ScopeDiagnostic -Field 'orphan_review_atomic_refs' -Item ([pscustomobject]@{ path = $path; atomic_id = $ref })
                    }
                }
                if ($analysis.review_kind -eq 'atomic-mirror' -and $analysis.primary_atomic) {
                    $changedClaims += [pscustomobject]@{ path = $path; atomic_id = $analysis.primary_atomic }
                }
                if ($analysis.primary_atomic) { $scopeAtoms += $analysis.primary_atomic }
                $scopeAtoms += @($analysis.related_atomics)
            }
            $claims = @($Index.review_records |
                    Where-Object { $_.review_kind -eq 'atomic-mirror' -and $_.primary_atomic } |
                    ForEach-Object { [pscustomobject]@{ path = $_.path; atomic_id = $_.primary_atomic } } |
                    Where-Object { $existing -notcontains $_.path })
            $claims += $changedClaims
            foreach ($group in @($claims | Group-Object atomic_id | Where-Object { $_.Count -gt 1 })) {
                $paths = @($group.Group.path)
                if (@($paths | Where-Object { $existing -contains $_ }).Count -gt 0) {
                    $diags += New-ScopeDiagnostic -Field 'duplicate_atomic_mirrors' -Item ([pscustomobject]@{ atomic_id = $group.Name; paths = $paths })
                }
            }
            foreach ($atom in @($scopeAtoms | Select-Object -Unique)) {
                if (@($claims | Where-Object { $_.atomic_id -eq $atom }).Count -eq 0) {
                    $diagnostic = New-ScopeDiagnostic -Field 'atomic_mirror_gaps' -Item $atom
                    if ($EnforceReviewScope) {
                        $diagnostic.severity = 'error'
                        $diagnostic.message = 'atomic in the recorded review scope has no atomic-mirror bank: ' + $atom
                    }
                    $diags += $diagnostic
                }
            }
            foreach ($atom in @($Index.atomic_records | ForEach-Object { $_.atomic_id } | Where-Object { $_ } | Select-Object -Unique)) {
                if ($scopeAtoms -contains $atom -or @($claims | Where-Object { $_.atomic_id -eq $atom }).Count -gt 0) { continue }
                $diags += New-ScopeDiagnostic -Field 'atomic_mirror_gaps' -Item $atom
            }
        }
        'queue' {
            $queue = Join-Path $VaultRoot '70-复习队列.md'
            if (Test-Path -LiteralPath $queue -PathType Leaf) {
                $headings = @()
                if ($null -ne $Schema -and $Schema.PSObject.Properties['files'] -and $Schema.files.PSObject.Properties['70-复习队列.md']) {
                    $headings = @($Schema.files.'70-复习队列.md'.headings)
                }
                foreach ($issue in @(Get-ReviewQueueIssues -Content (Get-ScopeContent -Path $queue) -Headings $headings)) {
                    $diags += New-ScopeDiagnostic -Field 'review_queue_issues' -Item $issue
                }
            }
            $template = Join-Path $VaultRoot '90-模板\复习题模板.md'
            if (Test-Path -LiteralPath $template -PathType Leaf) {
                foreach ($issue in @(Get-ReviewTemplateIssues -Content (Get-ScopeContent -Path $template))) {
                    $diags += New-ScopeDiagnostic -Field 'review_template_issues' -Item $issue
                }
            }
        }
        'jobnote' {
            foreach ($path in $existing) {
                $issues = @(Get-JobNoteIssues -Content (Get-ScopeContent -Path $path))
                if ($issues.Count -gt 0) {
                    $diags += New-ScopeDiagnostic -Field 'invalid_job_requirement_notes' -Item ([pscustomobject]@{ path = $path; issues = $issues })
                }
            }
            $template = Join-Path $VaultRoot '90-模板\岗位需求分析模板.md'
            if (-not (Test-Path -LiteralPath $template -PathType Leaf)) {
                $diags += New-ScopeDiagnostic -Field 'job_requirement_template_issues' -Item 'missing job requirement analysis template'
            }
            else {
                foreach ($issue in @(Get-JobTemplateIssues -Content (Get-ScopeContent -Path $template))) {
                    $diags += New-ScopeDiagnostic -Field 'job_requirement_template_issues' -Item $issue
                }
            }
        }
    }
    return $diags
}

function New-ScopeChangeResult {
    param(
        [string]$Vault,
        $Checks,
        [object[]]$Diagnostics
    )
    $errors = @($Diagnostics | Where-Object { $_.severity -eq 'error' })
    $warnings = @($Diagnostics | Where-Object { $_.severity -eq 'warning' })
    $runtime = @($Diagnostics | Where-Object { $_.field -eq 'runtime' })
    return [pscustomobject]@{
        kind          = 'change'
        vault         = $Vault
        valid         = ($errors.Count -eq 0)
        runtime_error = ($runtime.Count -gt 0)
        checks        = $Checks
        issues        = @($errors | ForEach-Object { Format-VaultDiagnostic -Diagnostic $_ })
        warnings      = @($warnings | ForEach-Object { Format-VaultDiagnostic -Diagnostic $_ })
        diagnostics   = @($Diagnostics)
    }
}

function New-ScopeUnavailableResult {
    param(
        [Parameter(Mandatory = $true)][string]$Vault,
        [string[]]$Kinds,
        [string[]]$PathTexts,
        [Parameter(Mandatory = $true)][string]$Reason
    )
    $diagnostic = [pscustomobject]@{
        field = 'runtime'; code = 'SCOPE_UNAVAILABLE'; severity = 'error'; category = 'runtime'
        paths = @(); message = "validation scope unavailable: $Reason"
    }
    return New-ScopeChangeResult -Vault $Vault -Checks ([pscustomobject]@{}) -Diagnostics @($diagnostic)
}

function Invoke-ScopedChangeValidation {
    param(
        [Parameter(Mandatory = $true)][string]$Vault,
        [Parameter(Mandatory = $true)][string[]]$Kinds,
        [object[]]$Changes = @(),
        [switch]$EnforceReviewScope
    )
    $kindRoots = Get-ValidationKindRoots -RegistryPath (Get-ValidationRegistryPath -ScriptRoot $PSScriptRoot)
    if ($kindRoots.Count -eq 0) {
        return New-ScopeUnavailableResult -Vault $Vault -Kinds $Kinds -PathTexts @() `
            -Reason 'validation registry declares no kind_roots'
    }
    $scopable = @($kindRoots.Keys)
    $unscopable = @($Kinds | Where-Object { $_ -notin $scopable })
    if ($unscopable.Count -gt 0) {
        return New-ScopeUnavailableResult -Vault $Vault -Kinds $Kinds -PathTexts @() `
            -Reason "scoped mode does not cover kind(s): $($unscopable -join ', ')"
    }
    if ($Changes.Count -eq 0) {
        return New-ScopeUnavailableResult -Vault $Vault -Kinds $Kinds -PathTexts @() `
            -Reason 'no change entries were declared'
    }

    $targets = @()
    $deletedTargets = @()
    $containers = @()
    $identityChecks = @()
    $preDiagnostics = @()
    foreach ($change in $Changes) {
        $full = ConvertTo-ScopeFullPath -VaultRoot $Vault -PathText $change.path
        if (-not $full) {
            return New-ScopeUnavailableResult -Vault $Vault -Kinds $Kinds -PathTexts @($change.path) `
                -Reason "unresolvable change path: $($change.path)"
        }
        $operation = if ($change.PSObject.Properties['operation'] -and $change.operation) { $change.operation } else { 'update' }
        $oldIdentity = if ($change.PSObject.Properties['old_identity']) { $change.old_identity } else { $null }
        if ($operation -notin @('update', 'create', 'delete', 'rename')) {
            return New-ScopeUnavailableResult -Vault $Vault -Kinds $Kinds -PathTexts @($change.path) `
                -Reason "unknown change operation '$operation'"
        }
        if (Test-Path -LiteralPath $full -PathType Container) {
            if ($operation -ne 'update' -and $operation -ne 'create') {
                $preDiagnostics += New-ScopeDiagnostic -Field 'inconsistent_change' -Item "operation '$operation' cannot target a directory: $full"
                continue
            }
            $containers += $full
            $targets += @(Get-ChildItem -LiteralPath $full -Recurse -File | ForEach-Object {
                    [pscustomobject]@{ full = $_.FullName; operation = 'update'; old_identity = $null }
                })
            continue
        }
        $exists = Test-Path -LiteralPath $full -PathType Leaf
        $atomicRoot = Join-Path $Vault '40-原子知识'
        switch ($operation) {
            'update' {
                if ($exists) {
                    $targets += [pscustomobject]@{ full = $full; operation = 'update'; old_identity = $oldIdentity }
                    if ($oldIdentity -and (Get-ScopeAtomicIdentity -Path $full) -ne $oldIdentity) {
                        $identityChecks += [pscustomobject]@{ identity = $oldIdentity; path = $full }
                    }
                }
                else { $preDiagnostics += New-ScopeDiagnostic -Field 'missing_change_target' -Item "declared update target does not exist: $full" }
            }
            'create' {
                if ($exists) { $targets += [pscustomobject]@{ full = $full; operation = 'create'; old_identity = $oldIdentity } }
                else { $preDiagnostics += New-ScopeDiagnostic -Field 'missing_change_target' -Item "declared creation target not found; validate after writing it: $full" }
            }
            'delete' {
                if ($exists) {
                    $preDiagnostics += New-ScopeDiagnostic -Field 'inconsistent_change' -Item "operation 'delete' declared but the target still exists: $full"
                }
                else {
                    $deletedTargets += $full
                    if (Test-ScopeUnderRoot -FullPath $full -RootPath $atomicRoot) {
                        if ($oldIdentity) {
                            $identityChecks += [pscustomobject]@{ identity = $oldIdentity; path = $full }
                        }
                        else {
                            $preDiagnostics += New-ScopeDiagnostic -Field 'missing_change_identity' -Item "atomic delete requires -OldIdentity so references can be checked: $full"
                        }
                    }
                }
            }
            'rename' {
                $oldFull = $null
                if ($change.PSObject.Properties['old_path'] -and $change.old_path) {
                    $oldFull = ConvertTo-ScopeFullPath -VaultRoot $Vault -PathText $change.old_path
                }
                if (-not $oldFull) {
                    return New-ScopeUnavailableResult -Vault $Vault -Kinds $Kinds -PathTexts @($change.path) `
                        -Reason "operation 'rename' requires a resolvable old_path"
                }
                if (-not $exists) {
                    $preDiagnostics += New-ScopeDiagnostic -Field 'missing_change_target' -Item "renamed target does not exist: $full"
                }
                elseif (Test-Path -LiteralPath $oldFull -PathType Leaf) {
                    $preDiagnostics += New-ScopeDiagnostic -Field 'inconsistent_change' -Item "renamed source still exists: $oldFull"
                }
                else {
                    $targets += [pscustomobject]@{ full = $full; operation = 'rename'; old_identity = $oldIdentity }
                    $deletedTargets += $oldFull
                    if ($oldIdentity -and (Get-ScopeAtomicIdentity -Path $full) -ne $oldIdentity) {
                        $identityChecks += [pscustomobject]@{ identity = $oldIdentity; path = $oldFull }
                    }
                }
            }
        }
    }
    if ($preDiagnostics.Count -gt 0) {
        return New-ScopeChangeResult -Vault $Vault -Checks ([pscustomobject]@{}) -Diagnostics $preDiagnostics
    }

    $bundledSchemaPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\vault-schema.json'
    $schema = Read-ScopeSchema -VaultRoot $Vault -BundledSchemaPath $bundledSchemaPath
    if ($null -eq $schema) {
        return New-ScopeUnavailableResult -Vault $Vault -Kinds $Kinds -PathTexts @() -Reason 'vault schema unavailable'
    }

    $declaredScope = @()
    foreach ($change in $Changes) {
        $full = ConvertTo-ScopeFullPath -VaultRoot $Vault -PathText $change.path
        if ($full) { $declaredScope += $full }
    }
    $kindTargets = @{}
    foreach ($kind in $Kinds) {
        $roots = @($kindRoots[$kind])
        if ($roots.Count -eq 0) { $kindTargets[$kind] = @($declaredScope); continue }
        $related = @()
        foreach ($root in $roots) {
            $rootPath = Join-Path $Vault $root
            $related += @($targets | Where-Object { Test-ScopeUnderRoot -FullPath $_.full -RootPath $rootPath } | ForEach-Object { $_.full })
            $related += @($containers | Where-Object { Test-ScopeUnderRoot -FullPath $_ -RootPath $rootPath })
            $related += @($deletedTargets | Where-Object { Test-ScopeUnderRoot -FullPath $_ -RootPath $rootPath })
        }
        $related = @($related | Select-Object -Unique)
        if ($related.Count -eq 0) {
            return New-ScopeUnavailableResult -Vault $Vault -Kinds $Kinds -PathTexts @($declaredScope) `
                -Reason "no declared change belongs to kind '$kind'"
        }
        $kindTargets[$kind] = $related
    }

    # Every declared change target must be covered by at least one selected
    # kind, so a batch can never report success while silently skipping a file.
    $coveredTargets = @()
    foreach ($kind in $Kinds) { $coveredTargets += @($kindTargets[$kind]) }
    $coveredTargets = @($coveredTargets | Select-Object -Unique)
    foreach ($declared in $declaredScope) {
        if ($coveredTargets -notcontains $declared) {
            return New-ScopeUnavailableResult -Vault $Vault -Kinds $Kinds -PathTexts @($declared) `
                -Reason "change target is not covered by the selected kinds: $declared"
        }
    }

    $index = Get-ScopeIndex -VaultRoot $Vault -Schema $schema -Kinds $Kinds -NeedsReviewRecords:($identityChecks.Count -gt 0)
    $allDiagnostics = @(Get-ScopeCommonDiagnostics -Index $index -Schema $schema -VaultRoot $Vault)
    foreach ($kind in $Kinds) {
        $allDiagnostics += @(Get-ScopeKindDiagnostics -Kind $kind -RelatedTargets $kindTargets[$kind] -Index $index -Schema $schema -VaultRoot $Vault -EnforceReviewScope:$EnforceReviewScope)
    }
    foreach ($identityCheck in $identityChecks) {
        foreach ($record in $index.review_records) {
            $references = @($record.related_atomics)
            if ($record.primary_atomic) { $references += $record.primary_atomic }
            if ($references -contains $identityCheck.identity) {
                $allDiagnostics += New-ScopeDiagnostic -Field 'orphan_review_atomic_refs' -Item ([pscustomobject]@{
                        path      = $record.path
                        atomic_id = $identityCheck.identity
                    })
            }
        }
    }
    $changedExisting = @($targets | ForEach-Object { $_.full })
    $allDiagnostics += @(Get-ScopeOutgoingLinkDiagnostics -Index $index -ChangedFiles $changedExisting -VaultRoot $Vault)
    if ($deletedTargets.Count -gt 0) {
        $allDiagnostics += @(Get-ScopeDeletedLinkDiagnostics -Index $index -DeletedTargets $deletedTargets -VaultRoot $Vault)
    }
    $seen = @{}
    $deduped = @()
    foreach ($diagnostic in $allDiagnostics) {
        $key = $diagnostic.field + '|' + $diagnostic.message + '|' + ($diagnostic.paths -join ',')
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $deduped += $diagnostic
    }
    $allDiagnostics = $deduped

    $checks = [ordered]@{}
    $checks['common'] = New-VaultCheckGroup -Diagnostics @($allDiagnostics | Where-Object { $_.field -in $script:VaultCommonFields })
    $checks['links'] = New-VaultCheckGroup -Diagnostics @($allDiagnostics | Where-Object { $_.field -eq 'broken_links' })
    foreach ($kind in $Kinds) {
        $meta = $script:VaultKindFields[$kind]
        $fields = @($meta.errorFields) + @($meta.warningFields)
        $checks[$kind] = New-VaultCheckGroup -Diagnostics @($allDiagnostics | Where-Object { $_.field -in $fields })
    }
    return New-ScopeChangeResult -Vault $Vault -Checks ([pscustomobject]$checks) -Diagnostics $allDiagnostics
}