# COMMAND: tdd-order
# OPTS: --trace-file <path> --task-path <path> --phase <RED|GREEN|REFACTOR|AUTO> [--force]
<#
.SYNOPSIS
  Validates that TDD (Test-Driven Development) order is respected in trace files.

.DESCRIPTION
  Reads an .exec.jsonl trace file, filters entries by TaskPath, and validates
  that file operations respect TDD phase constraints:
  
  - RED phase:     Only test files may be created/modified. No implementation files.
  - GREEN phase:   Tests must exist BEFORE implementation files (timestamp check).
  - REFACTOR phase: Only test files may be modified.
  - AUTO phase:    Infer the phase from the task description text.

  Supports both " (standard) and ' (single-quote) JSON variants found in
  real trace files, plus pipe-delimited format lines (skipped gracefully).

.PARAMETER TraceFile
  Required. Path to the .exec.jsonl trace file (main session or agent session).

.PARAMETER TaskPath
  Required. The task_path value to filter entries by (e.g., "002", "task_001").

.PARAMETER Phase
  Required. One of: "RED", "GREEN", "REFACTOR", "AUTO".
  - RED:      Only test files should exist in file_write entries.
  - GREEN:    Test file timestamps must precede implementation file timestamps.
  - REFACTOR: Only test files should appear in file_write entries.
  - AUTO:     Phase is inferred from the task description/detail text.

.PARAMETER Force
  Optional switch. When set, bypasses all checks, logs an override entry to
  audit.jsonl, and exits with code 0.

.PARAMETER Detailed
  Optional switch. Prints detailed file analysis to the console.

.EXAMPLE
  .agents\scripts\tdd_order.ps1 -TraceFile .agents\traces\sess_20260614_4a7b81ee.exec.jsonl -TaskPath 002 -Phase RED
  Validates that RED phase for task_002 only touched test files in the main session trace.

.EXAMPLE
  .agents\scripts\tdd_order.ps1 -TraceFile .agents\traces\agent_sessions\sess_20260614_4a7b81ee__sdet__002.exec.jsonl -TaskPath 002 -Phase RED -Detailed
  Validates RED phase with detailed output from the agent session trace.

.EXAMPLE
  .agents\scripts\tdd_order.ps1 -TraceFile .agents\traces\sess_20260614_4a7b81ee.exec.jsonl -TaskPath 003 -Phase GREEN
  Validates GREEN phase: checks test timestamps precede implementation timestamps.

.EXAMPLE
  .agents\scripts\tdd_order.ps1 -TraceFile .agents\traces\sess_20260614_4a7b81ee.exec.jsonl -TaskPath 004 -Phase REFACTOR -Force
  Bypasses validation, logs override, exits 0.

.NOTES
  Exit codes: 0 = TDD order respected, 1 = Violation found.
  Output is always a JSON object written to stdout.
#>

param(
  [Parameter(Mandatory = $true, HelpMessage = "Path to the .exec.jsonl trace file")]
  [string]$TraceFile,

  [Parameter(Mandatory = $true, HelpMessage = "The task_path to filter by (e.g., '002')")]
  [string]$TaskPath,

  [Parameter(Mandatory = $true, HelpMessage = "TDD phase to validate")]
  [ValidateSet("RED", "GREEN", "REFACTOR", "AUTO")]
  [string]$Phase,

  [Parameter(Mandatory = $false, HelpMessage = "Bypass check, log override, exit 0")]
  [switch]$Force,

  [Parameter(Mandatory = $false, HelpMessage = "Print detailed file analysis")]
  [switch]$Detailed
)

# ============================================================
# CONSTANTS
# ============================================================
$SCRIPT_NAME = "tdd_order"
$AGENTS_DIR = Split-Path -Parent $PSScriptRoot
$AUDIT_FILE = Join-Path -Path $AGENTS_DIR -ChildPath "audit.jsonl"

# ============================================================
# HELPER: Parse a JSON line that may use " or ' delimiters
# ============================================================
function Convert-JsonLine {
  param([string]$Line)

  if ([string]::IsNullOrWhiteSpace($Line)) { return $null }

  # First attempt: standard JSON parsing
  try {
    return $Line | ConvertFrom-Json -ErrorAction Stop
  } catch {
    # Ignore parse error, try alternative format
  }

  # Second attempt: single-quoted JSON (replace ' with ")
  # Match pattern: {'key':'value','key2':'value2'}
  try {
    # Replace outer single quotes on property names and string values
    $fixed = $Line -replace "'", '"'
    return $fixed | ConvertFrom-Json -ErrorAction Stop
  } catch {
    # Not valid JSON - skip
  }

  # Third attempt: Check if it's a pipe-delimited line (no JSON at all)
  if ($Line -match '^\d{4}-\d{2}-\d{2}T') {
    return $null  # Pipe-delimited format, skip
  }

  return $null
}

# ============================================================
# HELPER: Normalize timestamp to sortable string
# ============================================================
function Format-Timestamp {
  param([string]$Timestamp)

  if ([string]::IsNullOrWhiteSpace($Timestamp)) { return $null }

  try {
    $dt = [DateTime]::Parse($Timestamp)
    return $dt.ToString("yyyy-MM-ddTHH:mm:ss.fff")
  } catch {
    return $Timestamp  # Return as-is if parsing fails
  }
}

# ============================================================
# HELPER: Classify a file path as test, implementation, or other
# ============================================================
function Get-FileCategory {
  param([string]$FilePath)

  if ([string]::IsNullOrWhiteSpace($FilePath)) { return "other" }

  # Normalize path separators
  $normalized = $FilePath -replace '\\', '/'

  # TEST file detection (checked first)
  # Pattern 1: *.test.*, *.spec.* anywhere in filename
  $fileName = Split-Path -Leaf -Path $normalized
  if ($fileName -match '\.(test|spec)\.(ts|js|tsx|jsx|mjs|cjs)$') {
    return "test"
  }
  # Pattern 2: Test config files (vitest, jest, playwright configs)
  if ($fileName -match '^(vitest|jest|playwright)\.config\.(ts|js|mjs)$') {
    return "test"
  }
  # Pattern 3: Path contains /test/ or __tests__/
  if ($normalized -match '/test/' -or $normalized -match '__tests__') {
    return "test"
  }

  # IMPLEMENTATION file detection
  # *.ts without .test., *.js without .spec., *.tsx, *.jsx
  if ($fileName -match '\.(ts|tsx)$' -and $fileName -notmatch '\.(test|spec)\.') {
    return "impl"
  }
  if ($fileName -match '\.(js|jsx|mjs|cjs)$' -and $fileName -notmatch '\.(test|spec)\.') {
    return "impl"
  }

  return "other"
}

# ============================================================
# HELPER: Log override to audit.jsonl
# ============================================================
function Write-AuditOverride {
  param(
    [string]$TraceFilePath,
    [string]$TaskId,
    [string]$PhaseName
  )

  $override = @{
    ts      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    agent   = "sdet"
    action  = "tdd_override"
    detail  = "Force override for tdd_order.ps1 - TaskPath=$TaskId Phase=$PhaseName - checks bypassed"
    script  = $SCRIPT_NAME
    trace   = $TraceFilePath
    task_id = $TaskId
    phase   = $PhaseName
  }

  $jsonLine = ConvertTo-Json -Compress -InputObject $override
  Add-Content -LiteralPath $AUDIT_FILE -Value $jsonLine -Encoding UTF8

  if ($Detailed) { Write-Host "[AUDIT] Override logged to $AUDIT_FILE" -ForegroundColor Yellow }
}

# ============================================================
# HELPER: Extract file path from a trace entry
# ============================================================
function Get-EntryFilePath {
  param($Entry)

  # Try 'name' field first (primary in file_write/file_read entries)
  if ($Entry.name) {
    $name = [string]$Entry.name
    # Skip entries where name is a task name, not a file path
    if ($name -match '\.\w+$' -or $name -match '/') {
      return $name
    }
  }

  # Try 'detail' field for file paths
  # Match paths like: path/to/file.test.ts, path/to/file.ts, file.test.ts
  # Handles multiple dots (e.g., metrics.test.ts) by using \w+ for the final extension
  if ($Entry.detail) {
    $detail = [string]$Entry.detail
    if ($detail -match '([a-zA-Z0-9_\-/\\]+\.[a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+)') {
      return $matches[1]
    }
    # Fallback: simple extension
    if ($detail -match '([a-zA-Z0-9_\-/\\]+\.[a-zA-Z0-9]+)') {
      return $matches[1]
    }
  }

  return $null
}

# ============================================================
# HELPER: Infer phase from task description text
# ============================================================
function Get-InferredPhase {
  param([array]$Entries)

  foreach ($entry in $Entries) {
    if (-not $entry) { continue }

    $detail = ""
    if ($entry.detail) { $detail = [string]$entry.detail }
    if ($entry.name)   { $detail = "$detail $([string]$entry.name)" }

    if ($detail -match '(?i)\bRED\b')     { return "RED" }
    if ($detail -match '(?i)\bGREEN\b')   { return "GREEN" }
    if ($detail -match '(?i)\bREFACTOR\b') { return "REFACTOR" }
  }

  # If no phase keyword found, check task_start entries
  foreach ($entry in $Entries) {
    if (-not $entry) { continue }
    if ($entry.type -eq "task_start" -and $entry.detail) {
      $detail = [string]$entry.detail
      if ($detail -match '(?i)\bRED\b')     { return "RED" }
      if ($detail -match '(?i)\bGREEN\b')   { return "GREEN" }
      if ($detail -match '(?i)\bREFACTOR\b') { return "REFACTOR" }
    }
  }

  return $null
}

# ============================================================
# MAIN LOGIC
# ============================================================

# --- Handle -Force: bypass all checks ---
if ($Force) {
  Write-AuditOverride -TraceFilePath $TraceFile -TaskId $TaskPath -PhaseName $Phase

  $forceResult = @{
    script       = $SCRIPT_NAME
    trace_file   = $TraceFile
    task_path    = $TaskPath
    phase        = $Phase
    passed       = $true
    checks       = @{
      test_files_written          = @()
      impl_files_written          = @()
      tests_before_impl           = $true
      only_test_files_in_red      = $true
      only_test_files_in_refactor = $true
    }
    errors       = @()
    override_used = $true
  }

  Write-Output (ConvertTo-Json -Depth 10 -Compress -InputObject $forceResult)
  exit 0
}

# --- Validate trace file exists ---
if (-not (Test-Path -LiteralPath $TraceFile)) {
  $errResult = @{
    script       = $SCRIPT_NAME
    trace_file   = $TraceFile
    task_path    = $TaskPath
    phase        = $Phase
    passed       = $false
    checks       = @{
      test_files_written          = @()
      impl_files_written          = @()
      tests_before_impl           = $null
      only_test_files_in_red      = $null
      only_test_files_in_refactor = $null
    }
    errors       = @("Trace file not found: $TraceFile")
    override_used = $false
  }

  Write-Output (ConvertTo-Json -Depth 10 -Compress -InputObject $errResult)
  exit 1
}

# --- Read and parse trace file ---
if ($Detailed) { Write-Host "[INFO] Reading trace file: $TraceFile" -ForegroundColor Cyan }

$rawLines = Get-Content -Path $TraceFile -Encoding UTF8
$allEntries = @()
$lineNum = 0

foreach ($line in $rawLines) {
  $lineNum++
  $trimmed = $line.Trim()

  # Skip empty lines
  if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }

  # Skip pipe-delimited format lines (not JSON)
  if ($trimmed -match '^\d{4}-\d{2}-\d{2}T.*\|.*\|.*\|.*\|.*\|') {
    if ($Detailed) { Write-Host "[SKIP] Line $lineNum : pipe-delimited format" -ForegroundColor DarkGray }
    continue
  }

  $entry = Convert-JsonLine -Line $trimmed
  if ($entry) {
    $allEntries += $entry
  } else {
    if ($Detailed) { Write-Host "[SKIP] Line $lineNum : unparseable format" -ForegroundColor DarkGray }
  }
}

if ($Detailed) { Write-Host "[INFO] Parsed $($allEntries.Count) entries from trace file" -ForegroundColor Cyan }

# --- Filter by task_path ---
$taskEntries = @()
foreach ($entry in $allEntries) {
  if ($entry.task_path) {
    $tp = [string]$entry.task_path
    # Match exact or with "task_" prefix variants
    if ($tp -eq $TaskPath -or $tp -eq "task_$TaskPath" -or $tp -eq $TaskPath.TrimStart("task_")) {
      $taskEntries += $entry
    }
  }
}

if ($Detailed) { Write-Host "[INFO] Found $($taskEntries.Count) entries for TaskPath=$TaskPath" -ForegroundColor Cyan }

# --- Determine phase (AUTO mode) ---
$resolvedPhase = $Phase
if ($Phase -eq "AUTO") {
  $inferred = Get-InferredPhase -Entries $taskEntries
  if ($inferred) {
    $resolvedPhase = $inferred
    if ($Detailed) { Write-Host "[AUTO] Inferred phase: $resolvedPhase" -ForegroundColor Green }
  } else {
    $errResult = @{
      script       = $SCRIPT_NAME
      trace_file   = $TraceFile
      task_path    = $TaskPath
      phase        = $Phase
      passed       = $false
      checks       = @{
        test_files_written          = @()
        impl_files_written          = @()
        tests_before_impl           = $null
        only_test_files_in_red      = $null
        only_test_files_in_refactor = $null
      }
      errors       = @("AUTO mode: unable to infer phase from task description for TaskPath=$TaskPath")
      override_used = $false
    }
    Write-Output (ConvertTo-Json -Depth 10 -Compress -InputObject $errResult)
    exit 1
  }
}

# --- Extract file_write and file_read entries ---
$fileWrites = @()
$fileReads = @()
foreach ($entry in $taskEntries) {
  if (-not $entry) { continue }
  $entryType = ""
  if ($entry.type) { $entryType = [string]$entry.type }

  $filePath = Get-EntryFilePath -Entry $entry
  if (-not $filePath) { continue }

  $ts = ""
  if ($entry.ts) { $ts = [string]$entry.ts }

  $fileOp = @{
    path      = $filePath
    category  = Get-FileCategory -FilePath $filePath
    ts        = $ts
    tsNorm    = Format-Timestamp -Timestamp $ts
  }

  if ($entryType -eq "file_write") {
    $fileWrites += $fileOp
  } elseif ($entryType -eq "file_read") {
    $fileReads += $fileOp
  }
}

if ($Detailed) {
  Write-Host "[FILES] $($fileWrites.Count) file_write, $($fileReads.Count) file_read entries:" -ForegroundColor Cyan
  foreach ($fw in $fileWrites) {
    $color = switch ($fw.category) {
      "test"  { "Green" }
      "impl"  { "Red" }
      default { "Gray" }
    }
    Write-Host "  [WRITE][$($fw.category)] $($fw.path) @ $($fw.ts)" -ForegroundColor $color
  }
  foreach ($fr in $fileReads) {
    Write-Host "  [READ] [$($fr.category)] $($fr.path) @ $($fr.ts)" -ForegroundColor DarkCyan
  }
}

# --- Classify files ---
$testFiles = @($fileWrites | Where-Object { $_.category -eq "test" } | ForEach-Object { $_.path })
$implFiles = @($fileWrites | Where-Object { $_.category -eq "impl" } | ForEach-Object { $_.path })
$otherFiles = @($fileWrites | Where-Object { $_.category -eq "other" } | ForEach-Object { $_.path })

# --- Run phase-specific checks ---
$errors = @()
$testsBeforeImpl = $null
$onlyTestFilesInRed = $null
$onlyTestFilesInRefactor = $null

switch ($resolvedPhase) {
  "RED" {
    # RED phase: Only test files should be written. No implementation files.
    if ($implFiles.Count -gt 0) {
      $onlyTestFilesInRed = $false
      foreach ($if in $implFiles) {
        $errors += "RED phase violation: implementation file written - $if"
      }
    } else {
      $onlyTestFilesInRed = $true
    }

    # If no files at all, consider it a warning but not a hard failure
    if ($fileWrites.Count -eq 0) {
      if ($Detailed) { Write-Host "[WARN] RED phase: no file_write entries found for task" -ForegroundColor Yellow }
    }
  }

  "GREEN" {
    # GREEN phase: Tests must exist BEFORE implementation
    # Check BOTH file_write and file_read entries as evidence of test existence.
    # Tests written in RED phase appear as file_read in GREEN phase traces.
    if ($testFiles.Count -eq 0 -and $fileReads.Count -eq 0) {
      $errors += "GREEN phase violation: no test files found (tests should have been written in RED phase)"
      $testsBeforeImpl = $false
    } elseif ($implFiles.Count -eq 0) {
      # No implementation files written - nothing to validate against
      if ($Detailed) { Write-Host "[WARN] GREEN phase: no implementation files written (nothing to validate)" -ForegroundColor Yellow }
      $testsBeforeImpl = $true
    } else {
      # Collect all test existence timestamps (from writes OR reads)
      $testTimes = @()
      # Test files written in this trace
      $testTimes += @($fileWrites | Where-Object { $_.category -eq "test" -and $_.tsNorm } | ForEach-Object { $_.tsNorm })
      # Test files read in this trace (proves they existed before the read)
      $testTimes += @($fileReads | Where-Object { $_.category -eq "test" -and $_.tsNorm } | ForEach-Object { $_.tsNorm })

      $implTimes = @($fileWrites | Where-Object { $_.category -eq "impl" -and $_.tsNorm } | ForEach-Object { $_.tsNorm })

      if ($testTimes.Count -gt 0 -and $implTimes.Count -gt 0) {
        $earliestTest = $testTimes | Sort-Object | Select-Object -First 1
        $earliestImpl = $implTimes | Sort-Object | Select-Object -First 1

        if ($Detailed) {
          Write-Host "[TIMING] Earliest test evidence: $earliestTest" -ForegroundColor Cyan
          Write-Host "[TIMING] Earliest impl file write: $earliestImpl" -ForegroundColor Cyan
        }

        if ($earliestTest -lt $earliestImpl) {
          $testsBeforeImpl = $true
        } else {
          $testsBeforeImpl = $false
          $errors += "GREEN phase violation: implementation file written before test files existed (test=$earliestTest, impl=$earliestImpl)"
        }
      } else {
        if ($testTimes.Count -eq 0) {
          $errors += "GREEN phase violation: test files have no valid timestamps"
        }
        if ($implTimes.Count -eq 0) {
          $errors += "GREEN phase violation: impl files have no valid timestamps"
        }
        $testsBeforeImpl = $false
      }
    }
  }

  "REFACTOR" {
    # REFACTOR phase: Only test files should be modified
    # Only check entries whose detail explicitly contains "REFACTOR"
    # (entries from RED/GREEN phases share the same task_path and should be excluded)
    $refactorImplFiles = @()
    foreach ($entry in $taskEntries) {
      if (-not $entry) { continue }
      $entryType = ""
      if ($entry.type) { $entryType = [string]$entry.type }
      if ($entryType -ne "file_write") { continue }

      $detail = ""
      if ($entry.detail) { $detail = [string]$entry.detail }

      # Only check entries marked as REFACTOR
      if ($detail -notmatch '(?i)\bREFACTOR\b') { continue }

      $filePath = Get-EntryFilePath -Entry $entry
      if (-not $filePath) { continue }

      $cat = Get-FileCategory -FilePath $filePath
      if ($cat -eq "impl") {
        $refactorImplFiles += $filePath
      }
    }

    if ($refactorImplFiles.Count -gt 0) {
      $onlyTestFilesInRefactor = $false
      foreach ($if in $refactorImplFiles) {
        $errors += "REFACTOR phase violation: implementation file modified - $if"
      }
    } else {
      $onlyTestFilesInRefactor = $true
    }

    if ($refactorImplFiles.Count -eq 0 -and $fileWrites.Count -eq 0) {
      if ($Detailed) { Write-Host "[WARN] REFACTOR phase: no file_write entries found for task" -ForegroundColor Yellow }
    }
  }
}

# --- Determine pass/fail ---
$passed = ($errors.Count -eq 0)

# --- Build result object ---
$checks = @{
  test_files_written          = $testFiles
  impl_files_written          = $implFiles
  tests_before_impl           = $testsBeforeImpl
  only_test_files_in_red      = $onlyTestFilesInRed
  only_test_files_in_refactor = $onlyTestFilesInRefactor
}

$result = @{
  script        = $SCRIPT_NAME
  trace_file    = $TraceFile
  task_path     = $TaskPath
  phase         = $resolvedPhase
  passed        = $passed
  checks        = $checks
  errors        = $errors
  override_used = $false
}

# --- Output result ---
Write-Output (ConvertTo-Json -Depth 10 -Compress -InputObject $result)

# --- Exit with appropriate code ---
if ($passed) {
  if ($Detailed) { Write-Host "[RESULT] PASSED - TDD order respected for $resolvedPhase phase" -ForegroundColor Green }
  exit 0
} else {
  if ($Detailed) {
    Write-Host "[RESULT] FAILED - TDD violations found:" -ForegroundColor Red
    foreach ($err in $errors) {
      Write-Host "  - $err" -ForegroundColor Red
    }
  }
  exit 1
}
