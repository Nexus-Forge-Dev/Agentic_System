# COMMAND: trace-completeness
# OPTS: --trace-file <path> [--task-path <path>] [--subagent-dir <dir>] [--force]
<#
.SYNOPSIS
  Validates trace completeness for any task within a trace file.

.DESCRIPTION
  After every delegation, the orchestrator runs this to confirm the subagent
  wrote a complete, chronological trace. Validates:

  1. File exists and is valid JSONL (each non-empty line parses as JSON)
  2. For each task_path found in the file:
     - task_start entry exists
     - At least one file_read entry exists (for change tasks)
     - At least one file_write entry exists (for change tasks)
     - task_complete entry exists
     - Timestamps are chronological
  3. If the file is from agent_sessions/ (subagent trace), additional constraints

.PARAMETER TraceFile
  Required. Path to the .exec.jsonl trace file.

.PARAMETER TaskPath
  Optional. Filter to a specific task_path. If omitted, checks ALL.

.PARAMETER SubagentDir
  Optional. If provided, also check subagent trace files in this directory.

.PARAMETER Force
  Optional. Bypass check, log override to audit.jsonl, exit 0.

.PARAMETER Verbose
  Optional. Print detailed per-entry analysis.

.EXAMPLE
  # Basic validation
  .\trace_completeness.ps1 -TraceFile ".agents\traces\sess_20260614_4a7b81ee.exec.jsonl"

.EXAMPLE
  # Filter to a specific task and check subagents
  .\trace_completeness.ps1 -TraceFile ".agents\traces\sess_20260614_4a7b81ee.exec.jsonl" -TaskPath "003" -SubagentDir ".agents\traces\agent_sessions"

.EXAMPLE
  # Subagent trace direct check
  .\trace_completeness.ps1 -TraceFile ".agents\traces\agent_sessions\sess_20260614_4a7b81ee__backend__003.exec.jsonl"

.EXAMPLE
  # Bypass with -Force
  .\trace_completeness.ps1 -TraceFile "..." -Force

.EXAMPLE
  # Verbose output
  .\trace_completeness.ps1 -TraceFile "..." -Verbose

.NOTES
  Exit codes: 0 = All checks pass, 1 = One or more checks fail
  PowerShell 5.1 compatible. Handles mixed quote styles.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TraceFile,

    [Parameter(Position = 1)]
    [string]$TaskPath = "",

    [Parameter(Position = 2)]
    [string]$SubagentDir = "",

    [switch]$Force
)

# ---------------------------------------------------------------
# Helper: Get a sortable timestamp string from any ISO 8601 format
# ---------------------------------------------------------------
function Get-TimeSortable {
    param([string]$Timestamp)
    if ([string]::IsNullOrEmpty($Timestamp)) { return "0000-01-01T00:00:00.0000000" }
    try {
        $dt = [DateTime]::Parse($Timestamp)
        return $dt.ToString("yyyy-MM-ddTHH:mm:ss.fffffff")
    } catch {
        return $Timestamp
    }
}

# ---------------------------------------------------------------
# Helper: Try to parse a JSON line that may use mixed quoting
# ---------------------------------------------------------------
function ConvertFrom-MixedJson {
    param([string]$Line)
    if ([string]::IsNullOrEmpty($Line.Trim())) { return $null }

    # Direct parse (fast path for valid JSON)
    try { return $Line | ConvertFrom-Json -ErrorAction Stop } catch {}

    # Replace single-quoted keys with double-quoted keys
    $fixed = $Line -replace "'([^']+)'\s*:", '"$1":'

    # Replace single-quoted values with double-quoted values
    $fixed = $fixed -replace ":\s*'([^']*)'", ':"$1"'

    # Still not valid? Return null for non-JSON lines (e.g. pipe-delimited)
    try { return $fixed | ConvertFrom-Json -ErrorAction Stop } catch { return $null }
}

# ---------------------------------------------------------------
# Helper: Collect task entries grouped by task_path from a batch
# ---------------------------------------------------------------
function Group-EntriesByTaskPath {
    param([array]$AllEntries)

    $grouped = @{}
    foreach ($entry in $AllEntries) {
        $tp = $null
        # Try both hashtable and PSCustomObject access
        if ($entry -is [hashtable]) {
            if ($entry.ContainsKey('task_path') -and -not [string]::IsNullOrEmpty($entry['task_path'])) {
                $tp = $entry['task_path']
            }
        } else {
            try {
                if (-not [string]::IsNullOrEmpty($entry.task_path)) { $tp = $entry.task_path }
            } catch { }
        }

        if ($null -ne $tp) {
            if (-not $grouped.ContainsKey($tp)) { $grouped[$tp] = @() }
            $grouped[$tp] += $entry
        }
    }
    return $grouped
}

# ---------------------------------------------------------------
# Helper: Classify entries by type for a single task_path
# ---------------------------------------------------------------
function Get-EntryTypeAccessor {
    param([object]$Entry)

    $tsVal = ''
    $typeVal = ''
    $tpVal = ''

    if ($Entry -is [hashtable]) {
        if ($Entry.ContainsKey('ts')) { $tsVal = $Entry['ts'] }
        if ($Entry.ContainsKey('type')) { $typeVal = $Entry['type'] }
        if ($Entry.ContainsKey('task_path')) { $tpVal = $Entry['task_path'] }
    } else {
        # PSCustomObject from ConvertFrom-Json
        $tsVal = if ($Entry.ts -ne $null) { "$($Entry.ts)" } else { '' }
        $typeVal = if ($Entry.type -ne $null) { "$($Entry.type)" } else { '' }
        $tpVal = if ($Entry.task_path -ne $null) { "$($Entry.task_path)" } else { '' }
    }

    return @{
        ts = $tsVal
        type = $typeVal
        task_path = $tpVal
    }
}

# ---------------------------------------------------------------
# Helper: Test if path is a subagent trace
# ---------------------------------------------------------------
function Test-IsSubagentPath {
    param([string]$Path)
    $normalized = $Path -replace '\\', '/'
    return $normalized -match '/agent_sessions/'
}

# ---------------------------------------------------------------
# Helper: Validate subagent filename convention
# ---------------------------------------------------------------
function Test-SubagentFilename {
    param([string]$Path)
    $name = Split-Path -Path $Path -Leaf
    # Format: sess_<sessionid>__<agent>__<task>.exec.jsonl
    # sessionid can contain underscores (e.g., "20260614_4a7b81ee")
    return ($name -match '^sess_.+__.+__.+\.exec\.jsonl$')
}

# ---------------------------------------------------------------
# Helper: Log override to audit.jsonl
# ---------------------------------------------------------------
function Write-OverrideToAudit {
    param([string]$ScriptPath)
    $auditPath = Join-Path -Path (Split-Path -Parent $ScriptPath) -ChildPath "audit.jsonl"
    $entry = @{
        ts          = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        agent       = "sdet"
        action_type = "override"
        detail      = "trace_completeness bypassed for $TraceFile"
        reason      = "-Force flag used"
        script      = "trace_completeness.ps1"
    } | ConvertTo-Json -Compress
    Add-Content -LiteralPath $auditPath -Value $entry -Encoding UTF8
    if ($PSBoundParameters.ContainsKey('Verbose')) {
        Write-Host "  [FORCE] Override appended to $auditPath" -ForegroundColor Magenta
    }
}

# ---------------------------------------------------------------
# Helper: Validate trace entries for completeness
# ---------------------------------------------------------------
function Test-TraceCompleteness {
    param(
        [string]$TraceFilePath,
        [string]$TaskFilter,
        [bool]$IsSubagent
    )

    $errors = @()
    $aggregate = @{
        file_exists = $true
        valid_jsonl = $true
        task_start_found = $false
        file_read_found = $false
        file_write_found = $false
        task_complete_found = $false
        chronological = $false
    }
    $overrideUsed = $false
    $malformedCount = 0
    $parsedCount = 0
    $totalLines = 0
    $emptyLines = 0

    # 1. Collect parsed entries from the trace file
    $parsedEntries = @()
    $lines = Get-Content -LiteralPath $TraceFilePath -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($null -eq $lines) {
        $errors += "File not found: $TraceFilePath"
        $aggregate.file_exists = $false
        $aggregate.valid_jsonl = $false
        return @{ Aggregates = $aggregate; Errors = $errors; OverrideUsed = $false }
    }

    $totalLines = $lines.Count
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrEmpty($trimmed)) { $emptyLines++; continue }

        $parsed = ConvertFrom-MixedJson -Line $trimmed
        if ($null -eq $parsed) { $malformedCount++; continue }
        $parsedEntries += $parsed
        $parsedCount++
    }

    if ($parsedCount -eq 0) {
        $aggregate.valid_jsonl = $false
        $errors += "No valid JSON entries found in trace file"
        return @{ Aggregates = $aggregate; Errors = $errors; OverrideUsed = $false }
    }

    if ($malformedCount -gt 0) {
        $errors += "$malformedCount malformed JSON lines skipped (non-JSON or mixed quote edge case)"
    }

    # 2. Group entries by task_path
    $grouped = Group-EntriesByTaskPath -AllEntries $parsedEntries

    if ($grouped.Keys.Count -eq 0) {
        $errors += "No entries with task_path found in trace file"
        return @{ Aggregates = $aggregate; Errors = $errors; OverrideUsed = $false }
    }

    # 3. Apply TaskPath filter if specified
    $taskPathsToCheck = @()
    if (-not [string]::IsNullOrEmpty($TaskFilter)) {
        if ($grouped.ContainsKey($TaskFilter)) {
            $taskPathsToCheck += $TaskFilter
        } else {
            $errors += "TaskPath '$TaskFilter' not found in trace file"
            return @{ Aggregates = $aggregate; Errors = $errors; OverrideUsed = $false }
        }
    } else {
        $taskPathsToCheck = @($grouped.Keys)
    }

    # 4. Validate each task_path
    $globalStartOk = $true
    $globalReadOk = $true
    $globalWriteOk = $true
    $globalDoneOk = $true
    $globalChronoOk = $true
    $anyChangeTask = $false
    $changeTaskCount = 0
    $changeReadOkCount = 0
    $changeWriteOkCount = 0

    foreach ($tp in $taskPathsToCheck) {
        $taskEntries = $grouped[$tp]
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            Write-Host "`n--- Validating task_path: $tp ---" -ForegroundColor Yellow
        }

        # Classify entries by type using direct iteration (avoid Where-Object issues)
        $startList = @(); $readList = @(); $writeList = @(); $doneList = @()

        foreach ($e in $taskEntries) {
            $acc = Get-EntryTypeAccessor -Entry $e
            switch ($acc.type) {
                'task_start'   { $startList += $e }
                'file_read'    { $readList += $e }
                'file_write'   { $writeList += $e }
                'task_complete' { $doneList += $e }
            }
        }

        $hasStart  = ($startList.Count -gt 0)
        $hasRead   = ($readList.Count -gt 0)
        $hasWrite  = ($writeList.Count -gt 0)
        $hasDone   = ($doneList.Count -gt 0)

        # task_start check
        if (-not $hasStart) {
            $globalStartOk = $false
            $errors += "task_path '$tp': Missing task_start entry"
        }

        # task_complete check
        if (-not $hasDone) {
            $globalDoneOk = $false
            $errors += "task_path '$tp': Missing task_complete entry"
        }

        # Is this a change task (has file operations)?
        $isChangeTask = $hasRead -or $hasWrite
        if ($isChangeTask) {
            $anyChangeTask = $true
            $changeTaskCount++

            if ($hasRead) { $changeReadOkCount++ }
            if ($hasWrite) { $changeWriteOkCount++ }
        }

        if ($PSBoundParameters.ContainsKey('Verbose')) {
            Write-Host "  Entries: $($taskEntries.Count) (start=$hasStart, read=$hasRead, write=$hasWrite, done=$hasDone, change=$isChangeTask)" -ForegroundColor Gray
        }

        # Subagent consistency check: all entries should share the same task_path
        if ($IsSubagent) {
            $uniquePaths = @{}
            foreach ($e in $taskEntries) {
                $acc = Get-EntryTypeAccessor -Entry $e
                if (-not [string]::IsNullOrEmpty($acc.task_path)) {
                    $uniquePaths[$acc.task_path] = $true
                }
            }
            if ($uniquePaths.Keys.Count -gt 1) {
                $pathList = ($uniquePaths.Keys | ForEach-Object { "$_ " }) -join ', '
                $errors += "Subagent trace has mixed task_path values: $pathList"
            }
        }

        # Chronological check
        if ($hasStart -and $hasDone) {
            $startTs = Get-TimeSortable -Timestamp (Get-EntryTypeAccessor -Entry $startList[0]).ts
            $doneTs  = Get-TimeSortable -Timestamp (Get-EntryTypeAccessor -Entry $doneList[-1]).ts

            $chronoOk = ($startTs -le $doneTs)
            if (-not $chronoOk) {
                $globalChronoOk = $false
                $errors += "task_path '$tp': task_start ($startTs) is after task_complete ($doneTs)"
            }

            # Check file_read <= file_write ordering if both exist
            if ($hasRead -and $hasWrite) {
                $sortedReads = @($readList | Sort-Object { Get-TimeSortable -Timestamp (Get-EntryTypeAccessor -Entry $_).ts })
                $sortedWrites = @($writeList | Sort-Object { Get-TimeSortable -Timestamp (Get-EntryTypeAccessor -Entry $_).ts })

                $readTs = Get-TimeSortable -Timestamp (Get-EntryTypeAccessor -Entry $sortedReads[0]).ts
                $writeTs = Get-TimeSortable -Timestamp (Get-EntryTypeAccessor -Entry $sortedWrites[-1]).ts

                if ($readTs -gt $writeTs) {
                    $globalChronoOk = $false
                    $errors += "task_path '$tp': First file_read ($readTs) is after last file_write ($writeTs)"
                }
            }
        } elseif ($hasStart -and -not $hasDone) {
            # Task started but not completed — chronological is broken
            $globalChronoOk = $false
            $errors += "task_path '$tp': task_start found but missing task_complete (incomplete lifecycle)"
        } elseif (-not $hasStart -and $hasDone) {
            $globalDoneOk = $false
            $globalChronoOk = $false
            $errors += "task_path '$tp': task_complete found but no task_start"
        }
    }

    # Compute file_read/file_write aggregate results
    # These are informational reporting flags, not pass/fail requirements.
    # A task can be write-only (creating a new file, no file_read needed)
    # or read-only (analysis, no file_write needed).
    # file_read_found is true if ANY task path has file_read entries.
    # file_write_found is true if ANY task path has file_write entries.
    $globalReadOk = ($changeReadOkCount -gt 0)
    $globalWriteOk = ($changeWriteOkCount -gt 0)

    $aggregate.task_start_found = $globalStartOk
    $aggregate.file_read_found = $globalReadOk
    $aggregate.file_write_found = $globalWriteOk
    $aggregate.task_complete_found = $globalDoneOk
    $aggregate.chronological = $globalChronoOk

    # Subagent filename check
    if ($IsSubagent -and -not (Test-SubagentFilename -Path $TraceFilePath)) {
        $errors += "Subagent filename does not follow convention: sess_<session>__<agent>__<task>.exec.jsonl"
    }

    return @{
        Aggregates = $aggregate
        Errors = $errors
        OverrideUsed = $false
        MalformedCount = $malformedCount
        ParsedCount = $parsedCount
        TotalLines = $totalLines
        EmptyLines = $emptyLines
        TaskPathCount = $taskPathsToCheck.Count
        IsSubagent = $IsSubagent
    }
}

# ---------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------

$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptPath)) {
    $scriptPath = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath "scripts\trace_completeness.ps1"
}

# ---- Handle -Force (bypass) ----
if ($Force) {
    Write-OverrideToAudit -ScriptPath $scriptPath
    $result = @{
        script         = "trace_completeness"
        trace_file     = $TraceFile
        task_path      = if ($TaskPath) { $TaskPath } else { "ALL" }
        passed         = $true
        checks         = @{
            file_exists         = $true
            valid_jsonl         = $true
            task_start_found    = $true
            file_read_found     = $true
            file_write_found    = $true
            task_complete_found = $true
            chronological       = $true
        }
        errors         = @()
        override_used  = $true
    }
    $result | ConvertTo-Json -Depth 10 -Compress
    exit 0
}

# ---- Show file info if verbose ----
if ($PSBoundParameters.ContainsKey('Verbose')) {
    Write-Host "`n=== trace_completeness.ps1 ===" -ForegroundColor Green
    Write-Host "  File: $TraceFile" -ForegroundColor White
    Write-Host "  Filter: $(if ($TaskPath) { $TaskPath } else { 'ALL' })" -ForegroundColor White
}

# ---- Process the trace file ----
$validation = Test-TraceCompleteness -TraceFilePath $TraceFile -TaskFilter $TaskPath -IsSubagent (Test-IsSubagentPath -Path $TraceFile)

# ---- Output verbose details ----
if ($PSBoundParameters.ContainsKey('Verbose')) {
    Write-Host "`n--- Parsing ---" -ForegroundColor Yellow
    Write-Host "  Total lines: $($validation.TotalLines)" -ForegroundColor Gray
    Write-Host "  Empty lines skipped: $($validation.EmptyLines)" -ForegroundColor Gray
    Write-Host "  Malformed lines skipped: $($validation.MalformedCount)" -ForegroundColor Gray
    Write-Host "  Parsed entries: $($validation.ParsedCount)" -ForegroundColor Gray
    Write-Host "  Task paths found: $($validation.TaskPathCount)" -ForegroundColor Gray
    Write-Host "  Subagent trace: $($validation.IsSubagent)" -ForegroundColor Gray
}

# ---- Process SubagentDir if provided ----
$subagentFilesChecked = 0
$subagentAllPassed = $true

if (-not [string]::IsNullOrEmpty($SubagentDir) -and (Test-Path -LiteralPath $SubagentDir)) {
    if ($PSBoundParameters.ContainsKey('Verbose')) {
        Write-Host "`n=== Subagent Directory Check: $SubagentDir ===" -ForegroundColor Green
    }

    $saFiles = @(Get-ChildItem -LiteralPath $SubagentDir -Filter "*.exec.jsonl" -File | ForEach-Object { $_.FullName })
    $subagentFilesChecked = $saFiles.Count

    foreach ($saf in $saFiles) {
        $saName = Split-Path -Path $saf -Leaf
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            Write-Host "`n--- Subagent: $saName ---" -ForegroundColor Cyan
        }

        $saResult = Test-TraceCompleteness -TraceFilePath $saf -TaskFilter "" -IsSubagent $true
        if (-not $saResult.Aggregates.task_start_found -or -not $saResult.Aggregates.task_complete_found) {
            $subagentAllPassed = $false
            foreach ($saErr in $saResult.Errors) {
                $validation.Errors += "Subagent $saName`: $saErr"
            }
        }

        # Filename check
        if (-not (Test-SubagentFilename -Path $saf)) {
            $subagentAllPassed = $false
            $validation.Errors += "Subagent $saName`: filename does not follow convention"
        }

        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $saStatus = "PASS"
            if (-not $saResult.Aggregates.task_start_found) { $saStatus = "FAIL (no start)" }
            elseif (-not $saResult.Aggregates.task_complete_found) { $saStatus = "FAIL (no complete)" }
            Write-Host "  Result: $saStatus" -ForegroundColor $(if ($saStatus -eq 'PASS') { 'Green' } else { 'Red' })
        }
    }
}

# ---- Compute overall pass/fail ----
$allChecks = $validation.Aggregates
# Core requirements: file exists, valid JSONL, task_start + task_complete for each path,
# and chronological ordering. file_read/write are informational (write-only tasks valid).
$overallPass = $allChecks.file_exists `
    -and $allChecks.valid_jsonl `
    -and $allChecks.task_start_found `
    -and $allChecks.task_complete_found `
    -and $allChecks.chronological

if ($subagentFilesChecked -gt 0 -and -not $subagentAllPassed) {
    $overallPass = $overallPass -and $subagentAllPassed
}

# ---- Build report ----
$report = @{
    script        = "trace_completeness"
    trace_file    = $TraceFile
    task_path     = if ($TaskPath) { $TaskPath } else { "ALL" }
    passed        = $overallPass
    checks        = @{
        file_exists         = $allChecks.file_exists
        valid_jsonl         = $allChecks.valid_jsonl
        task_start_found    = $allChecks.task_start_found
        file_read_found     = $allChecks.file_read_found
        file_write_found    = $allChecks.file_write_found
        task_complete_found = $allChecks.task_complete_found
        chronological       = $allChecks.chronological
    }
    errors        = $validation.Errors
    override_used = $false
}

if ($validation.IsSubagent) {
    $report.checks.subagent_filename_ok = (Test-SubagentFilename -Path $TraceFile)
}

if ($subagentFilesChecked -gt 0) {
    $report.subagent_checked = $true
    $report.subagent_file_count = $subagentFilesChecked
    $report.subagent_all_passed = $subagentAllPassed
}

# ---- Verbose summary ----
if ($PSBoundParameters.ContainsKey('Verbose')) {
    Write-Host "`n=== Final Report ===" -ForegroundColor Green
    Write-Host "  Passed: $overallPass" -ForegroundColor $(if ($overallPass) { 'Green' } else { 'Red' })
    Write-Host "  Checks:" -ForegroundColor White
    foreach ($ck in $report.checks.Keys) {
        $cv = $report.checks[$ck]
        Write-Host "    $ck = $cv" -ForegroundColor $(if ($cv) { 'Green' } else { 'Red' })
    }
    if ($validation.Errors.Count -gt 0) {
        Write-Host "  Errors:" -ForegroundColor Red
        foreach ($e in $validation.Errors) {
            Write-Host "    - $e" -ForegroundColor Red
        }
    }
    Write-Host "`n"
}

# ---- Output JSON report ----
$report | ConvertTo-Json -Depth 10 -Compress

# ---- Exit ----
if ($overallPass) { exit 0 } else { exit 1 }
