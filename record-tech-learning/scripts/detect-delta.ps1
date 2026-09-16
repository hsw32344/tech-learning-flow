param(
    [Parameter(Mandatory = $true)]
    [string]$Workspace,

    [string]$StateRoot = (Join-Path $env:USERPROFILE '.agents\tech-learning-flow\state'),

    [switch]$Commit
)

$ErrorActionPreference = 'Stop'

$workspacePath = (Resolve-Path -LiteralPath $Workspace).Path
if (-not (Test-Path -LiteralPath $workspacePath -PathType Container)) {
    throw "Workspace is not a directory: $workspacePath"
}

$excludedDirectories = @(
    '.git', '.hg', '.svn', '.idea', '.obsidian', '.vscode-test', '.ipynb_checkpoints',
    '.venv', 'venv', 'env', 'node_modules', '__pycache__', '.mypy_cache',
    '.pytest_cache', '.ruff_cache', 'build', 'dist'
)

$eligibleExtensions = @(
    '.ipynb', '.py', '.md', '.rst', '.txt', '.toml', '.yaml', '.yml', '.json'
)

function Get-TextHash {
    param([string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Get-NotebookCells {
    param([string]$Path)

    try {
        $notebook = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return @()
    }

    $cells = @()
    for ($index = 0; $index -lt $notebook.cells.Count; $index++) {
        $cell = $notebook.cells[$index]
        $sourceText = [string]::Join('', @($cell.source))
        $outputText = ''
        if ($cell.cell_type -eq 'code') {
            $outputText = ($cell.outputs | ConvertTo-Json -Depth 20 -Compress)
        }
        $cells += [pscustomobject]@{
            index = $index
            type = [string]$cell.cell_type
            source_hash = Get-TextHash -Text $sourceText
            output_hash = Get-TextHash -Text $outputText
        }
    }
    return $cells
}

$workspaceKey = Get-TextHash -Text $workspacePath.ToLowerInvariant()
$stateFile = Join-Path $StateRoot "$workspaceKey.json"
$previous = $null
if (Test-Path -LiteralPath $stateFile) {
    $previous = Get-Content -Raw -Encoding UTF8 -LiteralPath $stateFile | ConvertFrom-Json
}

$previousByPath = @{}
if ($null -ne $previous) {
    foreach ($item in @($previous.files)) {
        $previousByPath[[string]$item.path] = $item
    }
}

$skippedDirectories = @()
function Get-EligibleSourceFiles {
    param([string]$Root)

    $found = @()
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($Root)

    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        try {
            $found += @(
                Get-ChildItem -File -LiteralPath $directory |
                    Where-Object {
                        $eligibleExtensions -contains $_.Extension.ToLowerInvariant()
                    }
            )
            $children = @(Get-ChildItem -Directory -LiteralPath $directory)
        }
        catch {
            $script:skippedDirectories += [pscustomobject]@{
                path = $directory
                reason = $_.Exception.Message
            }
            continue
        }

        foreach ($child in $children) {
            if (
                $excludedDirectories -contains $child.Name -or
                $child.Name -like '.venv*' -or
                $child.Name -like '.tmp-*' -or
                $child.Name -like '.repair-*'
            ) {
                continue
            }
            $pending.Push($child.FullName)
        }
    }

    return $found
}

$files = @(Get-EligibleSourceFiles -Root $workspacePath)

$current = @()
$changes = @()
foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($workspacePath.Length).TrimStart('\')
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
    $cells = @()
    if ($file.Extension -ieq '.ipynb') {
        $cells = @(Get-NotebookCells -Path $file.FullName)
    }

    $entry = [pscustomobject]@{
        path = $relativePath
        hash = $hash
        size = $file.Length
        modified_utc = $file.LastWriteTimeUtc.ToString('o')
        notebook_cells = $cells
    }
    $current += $entry

    $status = 'new'
    $changedCells = @()
    if ($previousByPath.ContainsKey($relativePath)) {
        $old = $previousByPath[$relativePath]
        if ([string]$old.hash -eq $hash) {
            $status = 'unchanged'
        }
        else {
            $status = 'modified'
            if ($file.Extension -ieq '.ipynb') {
                $oldCells = @{}
                foreach ($cell in @($old.notebook_cells)) {
                    $oldCells[[int]$cell.index] = $cell
                }
                foreach ($cell in $cells) {
                    if (
                        -not $oldCells.ContainsKey([int]$cell.index) -or
                        [string]$oldCells[[int]$cell.index].source_hash -ne [string]$cell.source_hash -or
                        [string]$oldCells[[int]$cell.index].output_hash -ne [string]$cell.output_hash
                    ) {
                        $changedCells += [int]$cell.index
                    }
                }
            }
        }
        $previousByPath.Remove($relativePath)
    }

    if ($status -ne 'unchanged') {
        $changes += [pscustomobject]@{
            path = $relativePath
            status = $status
            changed_notebook_cells = $changedCells
        }
    }
}

foreach ($deletedPath in $previousByPath.Keys) {
    $changes += [pscustomobject]@{
        path = $deletedPath
        status = 'deleted'
        changed_notebook_cells = @()
    }
}

$snapshot = [pscustomobject]@{
    schema_version = 1
    workspace = $workspacePath
    updated_utc = [DateTime]::UtcNow.ToString('o')
    files = @($current | Sort-Object path)
}

if ($Commit) {
    if (-not (Test-Path -LiteralPath $StateRoot)) {
        New-Item -ItemType Directory -Path $StateRoot -Force | Out-Null
    }
    $snapshot | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 -LiteralPath $stateFile
}

[pscustomobject]@{
    workspace = $workspacePath
    state_file = $stateFile
    baseline_exists = ($null -ne $previous)
    committed = [bool]$Commit
    candidate_file_count = $files.Count
    skipped_directories = $skippedDirectories
    changes = @($changes | Sort-Object path)
} | ConvertTo-Json -Depth 30

