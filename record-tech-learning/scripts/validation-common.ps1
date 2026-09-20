# Infrastructure-only helpers shared by validation modules. This file must not
# encode Vault artifact, source, review, or curriculum business rules.

function ConvertTo-NormalizedPath {
    param([string]$PathText)
    if ([string]::IsNullOrWhiteSpace($PathText)) { return '' }
    return ($PathText.Trim() -replace '/', '\').TrimEnd('\')
}

function Get-VaultFrontmatterBody {
    param([Parameter(Mandatory = $true)][string]$Content)
    $match = [regex]::Match($Content, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---\s*\r?\n')
    if ($match.Success) { return $match.Groups['body'].Value }
    return $null
}

function Read-FrontmatterScalar {
    param([Parameter(Mandatory = $true)][string]$Content, [Parameter(Mandatory = $true)][string]$Key)
    $body = Get-VaultFrontmatterBody -Content $Content
    if ($null -eq $body) { return $null }
    $match = [regex]::Match($body, "(?m)^$([regex]::Escape($Key))[ \t]*:[ \t]*(?<value>[^#\r\n]*?)(?:[ \t]+#.*)?[ \t]*\r?$")
    if (-not $match.Success) { return $null }
    return $match.Groups['value'].Value.Trim().Trim('"').Trim("'")
}

function Read-FrontmatterList {
    param([Parameter(Mandatory = $true)][string]$Content, [Parameter(Mandatory = $true)][string]$Key)
    $body = Get-VaultFrontmatterBody -Content $Content
    if ($null -eq $body) { return @() }
    $inline = [regex]::Match($body, "(?m)^$([regex]::Escape($Key))[ \t]*:[ \t]*\[(?<values>[^\]]*)\][ \t]*\r?$")
    if ($inline.Success) { return @($inline.Groups['values'].Value -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ }) }
    $values = @()
    $collecting = $false
    foreach ($line in @($body -split '\r?\n')) {
        if (-not $collecting -and $line -match "^$([regex]::Escape($Key))[ \t]*:[ \t]*(?:\[\])?[ \t]*$") { $collecting = $true; continue }
        if (-not $collecting) { continue }
        if ($line -match '^\s{2}-\s*(?<value>.*?)\s*$') { $values += $Matches['value'].Trim().Trim('"'); continue }
        if ($line -match '^\S') { break }
    }
    return $values
}
