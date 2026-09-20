# Domain rules for the source-backed route: homepage projection, mainline
# structure, task registry bindings, source registry, and stage ordering.
# Shared by the scoped action executor and the whole-vault audit so both decide
# identical route questions. No file I/O here: callers pass file content and
# map the returned {field, message} objects into their own diagnostic buckets.

. (Join-Path $PSScriptRoot 'vault-contract.ps1')

function Get-SourceRegistryRuleIssues {
    param([Parameter(Mandatory = $true)][object[]]$RegistryEntries)
    $issues = @()
    $codes = @($RegistryEntries | ForEach-Object { $_.Groups['code'].Value })
    if ($codes.Count -eq 0) {
        $issues += [pscustomobject]@{ field = 'mainline_issues'; message = 'source registry contains no source codes' }
    }
    if (@($codes | Group-Object | Where-Object { $_.Count -gt 1 }).Count -gt 0) {
        $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = 'source registry contains duplicate source codes' }
    }
    foreach ($entry in $RegistryEntries) {
        $code = $entry.Groups['code'].Value
        $role = $entry.Groups['role'].Value
        $locatorText = $entry.Groups['rest'].Value
        if ($RegistryRoles -notcontains $role) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "registry role is invalid: $code -> $role" }
        }
        if ($role -in @('teaching-open', 'technical-authority') -and $locatorText -notmatch '<https?://[^>]+>') {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "external source lacks stable URL: $code" }
        }
        if ($role -eq 'physical-book' -and $locatorText -notmatch '(版|edition).*(章|chapter)') {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "physical-book registry entry lacks edition and chapter: $code" }
        }
    }
    return $issues
}

function Get-SourceParadigmRuleIssues {
    param([Parameter(Mandatory = $true)][string]$SourceParadigmContent)
    $issues = @()
    if ($SourceParadigmContent -notmatch '(?ms)^### Teaching completion path\s+.*?public online tutorial.*?official documentation.*?physical.*?Agent fallback') {
        $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = 'teaching completion path is missing or out of order' }
    }
    if ($SourceParadigmContent -notmatch '(?ms)^### Technical-fact authority\s+.*?official documentation') {
        $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = 'official technical-fact authority is missing' }
    }
    foreach ($format in @(
            '- unit: `<unit-id>` | primary_source: `<registered-code>` | type:',
            '- unit: `<unit-id>` | gap_source: `<registered-code>` | type:'
        )) {
        if ($SourceParadigmContent -notmatch [regex]::Escape($format)) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "missing machine-parseable source format: $format" }
        }
    }
    return $issues
}

function Get-RouteStructureRuleIssues {
    param(
        [Parameter(Mandatory = $true)][string]$HomepageContent,
        [Parameter(Mandatory = $true)][string]$MainlineContent,
        $Schema,
        [Parameter(Mandatory = $true)][string]$WeeklyRoot
    )
    $issues = @()
    $homepageProperties = @('type', 'current_stage', 'current_unit', 'current_position')
    $homepageHeadings = @()
    $mainlineProperties = @('type', 'current_unit')
    $mainlineHeadings = @()
    if ($null -ne $Schema -and $Schema.PSObject.Properties['files']) {
        if ($Schema.files.PSObject.Properties['00-首页.md']) {
            if ($Schema.files.'00-首页.md'.PSObject.Properties['properties']) { $homepageProperties = @($Schema.files.'00-首页.md'.properties) }
            if ($Schema.files.'00-首页.md'.PSObject.Properties['headings']) { $homepageHeadings = @($Schema.files.'00-首页.md'.headings) }
        }
        if ($Schema.files.PSObject.Properties['20-学习主线']) {
            if ($Schema.files.'20-学习主线'.PSObject.Properties['properties']) { $mainlineProperties = @($Schema.files.'20-学习主线'.properties) }
            if ($Schema.files.'20-学习主线'.PSObject.Properties['headings']) { $mainlineHeadings = @($Schema.files.'20-学习主线'.headings) }
        }
    }
    foreach ($property in $homepageProperties) {
        if ($HomepageContent -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
            $issues += [pscustomobject]@{ field = 'homepage_issues'; message = "missing property: $property" }
        }
    }
    foreach ($heading in $homepageHeadings) {
        if ($HomepageContent -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += [pscustomobject]@{ field = 'homepage_issues'; message = "missing heading: $heading" }
        }
    }
    if ($HomepageContent -match '(?m)^current_focus\s*:' -or
        $HomepageContent -match '(?m)^## 本周(唯一)?重点\s*$' -or
        $HomepageContent -match '\[\[(问题看板|里程碑索引|项目索引|来源索引)') {
        $issues += [pscustomobject]@{ field = 'homepage_issues'; message = 'legacy homepage state or index link' }
    }
    foreach ($property in $mainlineProperties) {
        if ($MainlineContent -notmatch "(?m)^$([regex]::Escape($property))\s*:") {
            $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "missing property: $property" }
        }
    }
    foreach ($heading in $mainlineHeadings) {
        if ($MainlineContent -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "missing heading: $heading" }
        }
    }
    foreach ($property in @('current_stage', 'current_unit', 'current_position')) {
        $homepageMatch = [regex]::Match($HomepageContent, "(?m)^$([regex]::Escape($property))\s*:\s*(?<value>.+?)\s*$")
        $mainlineMatch = [regex]::Match($MainlineContent, "(?m)^$([regex]::Escape($property))\s*:\s*(?<value>.+?)\s*$")
        if ($homepageMatch.Success -and $mainlineMatch.Success) {
            $homepageValue = $homepageMatch.Groups['value'].Value.Trim().Trim('"')
            $mainlineValue = $mainlineMatch.Groups['value'].Value.Trim().Trim('"')
            if ($homepageValue -ne $mainlineValue) {
                $issues += [pscustomobject]@{ field = 'homepage_issues'; message = "homepage $property does not mirror mainline: $homepageValue != $mainlineValue" }
            }
        }
    }
    $currentWeekMatch = [regex]::Match($HomepageContent, '(?m)^current_week\s*:\s*(?<value>\d{4}-W\d{2})\s*$')
    if ($currentWeekMatch.Success) {
        $currentWeekValue = $currentWeekMatch.Groups['value'].Value
        if (-not (Test-Path -LiteralPath (Join-Path $WeeklyRoot "$currentWeekValue.md") -PathType Leaf)) {
            $issues += [pscustomobject]@{ field = 'homepage_issues'; message = "current_week note missing: $currentWeekValue" }
        }
    }
    return $issues
}

function Get-StageOrderingRuleIssues {
    param(
        [Parameter(Mandatory = $true)][string]$StageContent,
        [Parameter(Mandatory = $true)][string]$TaskRegistryContent
    )
    $issues = @()
    if (@([regex]::Matches($StageContent, '(?m)^## 阶段[一二三四五六七八九十]+：')).Count -eq 0) {
        $issues += [pscustomobject]@{ field = 'mainline_issues'; message = 'no ordered stage headings' }
    }
    $unitIds = @([regex]::Matches($TaskRegistryContent, $UnitRowPattern) | ForEach-Object { $_.Groups['id'].Value })
    $stageIds = @([regex]::Matches($StageContent, '(?m)^\|\s*\d+\s*\|\s*`(?<id>' + $UnitIdPattern + ')`\s*\|\s*$') | ForEach-Object { $_.Groups['id'].Value })
    if ($stageIds.Count -eq 0) {
        $issues += [pscustomobject]@{ field = 'mainline_issues'; message = 'no task package ordering rows' }
    }
    foreach ($stageId in $stageIds) {
        if ($unitIds -notcontains $stageId) {
            $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "stage references unregistered task package: $stageId" }
        }
    }
    foreach ($unitId in $unitIds) {
        if (@($stageIds | Where-Object { $_ -eq $unitId }).Count -ne 1) {
            $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "task package must appear exactly once in stage ordering: $unitId" }
        }
    }
    return $issues
}

function Get-UnitBindingRuleIssues {
    param(
        [Parameter(Mandatory = $true)][string]$TaskRegistryContent,
        [Parameter(Mandatory = $true)][string[]]$UnitIds,
        [Parameter(Mandatory = $true)][object[]]$RegistryEntries,
        [string]$CurrentUnit
    )
    $issues = @()
    if ($UnitIds.Count -eq 0) {
        $issues += [pscustomobject]@{ field = 'mainline_issues'; message = 'no curriculum unit rows' }
    }
    if (@($UnitIds | Group-Object | Where-Object { $_.Count -gt 1 }).Count -gt 0) {
        $issues += [pscustomobject]@{ field = 'mainline_issues'; message = 'duplicate curriculum unit IDs' }
    }
    if (-not [string]::IsNullOrWhiteSpace($CurrentUnit)) {
        if ($UnitIds -notcontains $CurrentUnit) {
            $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "current_unit is not declared: $CurrentUnit" }
        }
    }

    $registeredCodes = @($RegistryEntries | ForEach-Object { $_.Groups['code'].Value })
    $declarations = @([regex]::Matches($TaskRegistryContent, $PrimaryDeclarationPattern))
    $declaredUnitIds = @($declarations | ForEach-Object { $_.Groups['unit'].Value })
    if ($declarations.Count -ne $UnitIds.Count) {
        $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit source declaration count $($declarations.Count) does not equal unit count $($UnitIds.Count)" }
    }
    foreach ($unitId in $UnitIds) {
        $found = @($declarations | Where-Object { $_.Groups['unit'].Value -eq $unitId })
        if ($found.Count -ne 1) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit must have exactly one primary source declaration: $unitId -> $($found.Count)" }
        }
    }
    foreach ($declaration in $declarations) {
        $unitId = $declaration.Groups['unit'].Value
        $primaryCode = $declaration.Groups['source'].Value
        $sourceType = $declaration.Groups['type'].Value
        if ($SourceTypes -notcontains $sourceType) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit primary source type is invalid: $unitId -> $sourceType" }
        }
        $locator = $declaration.Groups['locator'].Value.Trim()
        $extra = $declaration.Groups['extra'].Value
        if ($registeredCodes -notcontains $primaryCode) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit primary source is unregistered: $unitId -> $primaryCode" }
        }
        $registryRole = @($RegistryEntries | Where-Object { $_.Groups['code'].Value -eq $primaryCode } | ForEach-Object { $_.Groups['role'].Value })
        $expectedRole = switch ($sourceType) {
            'online-tutorial' { 'teaching-open' }
            'official-docs' { 'technical-authority' }
            'physical-book' { 'physical-book' }
            'agent-fallback' { 'agent-fallback' }
            default { $null }
        }
        if ($registryRole.Count -ne 1) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit source must resolve to exactly one legal material registry entry: $unitId -> $primaryCode" }
        }
        elseif ($sourceType -ne 'user-selected' -and $registryRole[0] -ne $expectedRole) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit source type does not match registry role: $unitId -> $primaryCode/$sourceType" }
        }
        if (-not $locator -or $locator -match '^(待定|未知|未报告)$') {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit primary source lacks reproducible locator: $unitId" }
        }
        if ($sourceType -ne 'agent-fallback' -and $locator -notmatch '^registry:' -and $locator -notmatch '^(https?://|ISBN:)') {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit primary source locator is not a registered anchor, URL, or ISBN: $unitId" }
        }
        if ($sourceType -eq 'physical-book' -and $locator -notmatch '(版|edition).*(章|chapter)') {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "physical-book locator lacks edition and chapter: $unitId" }
        }
        if ($sourceType -eq 'agent-fallback') {
            if ($primaryCode -ne 'AGENT-FALLBACK') {
                $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "agent fallback must use AGENT-FALLBACK source code: $unitId" }
            }
            foreach ($field in @('reason:', 'scope:', 'uncovered:')) {
                if ($extra -notmatch [regex]::Escape($field)) {
                    $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "agent fallback lacks $field $unitId" }
                }
            }
        }
    }

    $gapDeclarations = @([regex]::Matches($TaskRegistryContent, $GapDeclarationPattern))
    foreach ($group in @($gapDeclarations | Group-Object { $_.Groups['unit'].Value } | Where-Object { $_.Count -gt 1 })) {
        $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit has more than one gap source: $($group.Name)" }
    }
    foreach ($declaration in $gapDeclarations) {
        $unitId = $declaration.Groups['unit'].Value
        $gapCode = $declaration.Groups['source'].Value
        $gapType = $declaration.Groups['type'].Value
        if ($GapSourceTypes -notcontains $gapType) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "gap source type is invalid: $unitId -> $gapType" }
        }
        $gapLocator = $declaration.Groups['locator'].Value.Trim()
        $gapExtra = $declaration.Groups['extra'].Value
        if ($UnitIds -notcontains $unitId) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "gap source has unknown unit: $unitId" }
        }
        if ($registeredCodes -notcontains $gapCode) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "gap source is unregistered: $unitId -> $gapCode" }
        }
        $gapRegistryRole = @($RegistryEntries | Where-Object { $_.Groups['code'].Value -eq $gapCode } | ForEach-Object { $_.Groups['role'].Value })
        $expectedGapRole = switch ($gapType) {
            'online-tutorial' { 'teaching-open' }
            'official-docs' { 'technical-authority' }
            'physical-book' { 'physical-book' }
            'agent-fallback' { 'agent-fallback' }
        }
        if ($gapRegistryRole.Count -ne 1 -or $gapRegistryRole[0] -ne $expectedGapRole) {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "gap source type does not match registry role: $unitId -> $gapCode/$gapType" }
        }
        if (-not $gapLocator -or $gapLocator -match '^(待定|未知|未报告)$') {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "gap source lacks reproducible locator: $unitId" }
        }
        if ($gapType -eq 'physical-book' -and $gapLocator -notmatch '(版|edition).*(章|chapter)') {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "physical-book gap locator lacks edition and chapter: $unitId" }
        }
        if ($gapType -eq 'agent-fallback') {
            foreach ($field in @('reason:', 'scope:', 'uncovered:')) {
                if ($gapExtra -notmatch [regex]::Escape($field)) {
                    $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "agent fallback gap lacks $field $unitId" }
                }
            }
        }
    }

    foreach ($match in [regex]::Matches($TaskRegistryContent, $UnitRowPattern)) {
        $unitId = $match.Groups['id'].Value
        $contentValue = $match.Groups['content'].Value.Trim()
        $prerequisiteValue = $match.Groups['prerequisite'].Value.Trim()
        $modelValue = $match.Groups['model'].Value.Trim()
        $outputValue = $match.Groups['output'].Value.Trim()
        $sourceValue = $match.Groups['source'].Value.Trim()
        if (-not $contentValue) {
            $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "unit lacks canonical content: $unitId" }
        }
        if (-not $modelValue) {
            $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "unit lacks underlying model: $unitId" }
        }
        if (-not $outputValue) {
            $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "unit lacks observable output: $unitId" }
        }
        $sourceCodes = @([regex]::Matches($sourceValue, '`(?<code>[A-Z][A-Z0-9-]+)`') | ForEach-Object { $_.Groups['code'].Value })
        if ($sourceValue -notmatch '^主源:\s*`(?<tablePrimary>[A-Z][A-Z0-9-]+)`') {
            $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit table lacks machine-readable primary source: $unitId" }
        }
        else {
            $declaredPrimary = @($declarations | Where-Object { $_.Groups['unit'].Value -eq $unitId } | ForEach-Object { $_.Groups['source'].Value })
            if ($declaredPrimary.Count -eq 1 -and $declaredPrimary[0] -ne $Matches['tablePrimary']) {
                $issues += [pscustomobject]@{ field = 'source_contract_issues'; message = "unit table primary conflicts with declaration: $unitId -> $($Matches['tablePrimary'])/$($declaredPrimary[0])" }
            }
        }
        if ($sourceCodes.Count -eq 0) {
            $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "unit lacks explicit source code: $unitId" }
        }
        foreach ($sourceCode in $sourceCodes) {
            if ($registeredCodes -notcontains $sourceCode) {
                $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "unit has unregistered source code: $unitId -> $sourceCode" }
            }
        }
        if ($sourceValue -match '前述|所选库') {
            $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "unit has ambiguous source text: $unitId" }
        }
        foreach ($prerequisiteMatch in [regex]::Matches($prerequisiteValue, $UnitIdPattern)) {
            $prerequisiteId = $prerequisiteMatch.Value
            if ($UnitIds -notcontains $prerequisiteId) {
                $issues += [pscustomobject]@{ field = 'mainline_issues'; message = "unit has unknown prerequisite: $unitId -> $prerequisiteId" }
            }
        }
    }
    return $issues
}
