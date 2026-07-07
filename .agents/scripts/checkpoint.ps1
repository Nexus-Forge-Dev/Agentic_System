# COMMAND: checkpoint
# OPTS: --session <id> --task <path> --phase <RED|GREEN|REFACTOR|AUTO> [--threshold <n>] [--force]
<#
.SYNOPSIS
  Unified orchestrator that runs all three validators and produces a pass/fail report.

.DESCRIPTION
  Runs trace_completeness.ps1, tdd_order.ps1, and qg_enforcer.ps1 for a specific
  session/task/phase combination and prints a comprehensive report. This is the
  single entry point called after every task completion.

  Flow:
    1. Resolve trace file path
    2. Print header
    3. Run trace_completeness.ps1          -- FAIL FAST if exit != 0
    4. Run tdd_order.ps1                   -- FAIL FAST if exit != 0
    5. Run qg_enforcer.ps1 (GREEN/REFACTOR only) -- FAIL FAST if exit != 0
    6. Print PASS/FAIL summary, exit 0 or 1

.PARAMETER SessionId
  Required. The session ID (used to find trace files).

.PARAMETER TaskPath
  Required. The task_path to validate (e.g., "003").

.PARAMETER Phase
  Required. TDD phase: "RED", "GREEN", "REFACTOR", or "AUTO".

.PARAMETER TraceDir
  Optional. Directory containing trace files (default: .agents/traces).

.PARAMETER Threshold
  Optional. QG threshold (default: 8.0).

.PARAMETER Force
  Optional. Bypass all checks, log override to audit.jsonl, exit 0.

.PARAMETER VerboseOutput
  Optional. Print detailed output from each validator JSON result.

.EXAMPLE
  .agents\scripts\checkpoint.ps1 -SessionId "20260614_4a7b81ee" -TaskPath "003" -Phase "GREEN"

.EXAMPLE
  .agents\scripts\checkpoint.ps1 -SessionId "20260614_4a7b81ee" -TaskPath "002" -Phase "RED" -VerboseOutput

.EXAMPLE
  .agents\scripts\checkpoint.ps1 -SessionId "..." -TaskPath "004" -Phase "REFACTOR" -Threshold 9.0

.EXAMPLE
  .agents\scripts\checkpoint.ps1 -SessionId "..." -TaskPath "005" -Phase "GREEN" -Force

.NOTES
  Exit codes:
    0: All checks passed (or -Force used)
    1: One or more checks failed
  PowerShell 5.1 compatible.
#>

param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Session ID for trace file lookup")]
    [string]$SessionId,

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Task path to validate (e.g., '003')")]
    [string]$TaskPath,

    [Parameter(Mandatory = $true, Position = 2, HelpMessage = "TDD phase: RED, GREEN, REFACTOR, or AUTO")]
    [ValidateSet("RED", "GREEN", "REFACTOR", "AUTO")]
    [string]$Phase,

    [Parameter(Mandatory = $false, HelpMessage = "Directory containing trace files")]
    [string]$TraceDir = ".agents/traces",

    [Parameter(Mandatory = $false, HelpMessage = "Minimum QG threshold")]
    [float]$Threshold = 8.0,

    [Parameter(Mandatory = $false, HelpMessage = "Bypass all checks, log override, exit 0")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Print detailed JSON output from each validator")]
    [switch]$VerboseOutput
)

# ============================================================
# CONSTANTS
# ============================================================
$SCRIPT_NAME = "checkpoint"

# Resolve script directory (works with -File and dot-sourcing)
$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptPath)) {
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "checkpoint.ps1"
}
$scriptDir = Split-Path -Parent $scriptPath
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = Split-Path -Parent (Get-Location).Path
}
$agentsDir = Split-Path -Parent $scriptDir
$auditFile = Join-Path -Path $agentsDir -ChildPath "audit.jsonl"
$sepLine = "--------------------------------------------------------------"

# ============================================================
# HELPER: Write colored report line
# ============================================================
function Write-ReportLine {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

# ============================================================
# HELPER: Log override entry to audit.jsonl
# ============================================================
function Write-OverrideToAudit {
    $entry = @{
        ts        = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        agent     = "backend-architect"
        action    = "checkpoint_override"
        detail    = "Checkpoint bypassed for SessionId=$SessionId TaskPath=$TaskPath Phase=$Phase"
        reason    = "-Force flag used"
        session   = $SessionId
        task_path = $TaskPath
        phase     = $Phase
    } | ConvertTo-Json -Compress

    try {
        Add-Content -LiteralPath $auditFile -Value $entry -Encoding UTF8
        if ($VerboseOutput) {
            Write-Host "  [FORCE] Override logged to $auditFile" -ForegroundColor Magenta
        }
    } catch {
        Write-Warning "Failed to log override to audit.jsonl: $_"
    }
}

# ============================================================
# HELPER: Run a validator script and capture output + exit code
# ============================================================
function Invoke-Validator {
    param(
        [string]$ScriptPath,
        [string]$Arguments
    )

    # Check if the validator script exists
    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        return @{
            Output   = $null
            ExitCode = 255
            Json     = $null
            ErrorMsg = "Script not found: $ScriptPath"
        }
    }

    # Invoke via powershell.exe subprocess for clean isolation
    # Use ProcessStartInfo to capture stdout and stderr separately
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -File `"$ScriptPath`" $Arguments"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        $exitCode = $proc.ExitCode
        $proc.Dispose()
    } catch {
        return @{
            Output   = $null
            ExitCode = 1
            Json     = $null
            ErrorMsg = "Failed to start subprocess: $_"
        }
    }

    # Attempt to parse JSON from stdout
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
        try {
            $json = $stdout | ConvertFrom-Json -ErrorAction Stop
        } catch {
            # Non-JSON output -- keep json as null, use raw output
        }
    }

    return @{
        Output       = $stdout
        ExitCode     = $exitCode
        Json         = $json
        Stderr       = $stderr
        ErrorMsg     = $null
    }
}

# ============================================================
# HELPER: Print divider with summary and exit
# ============================================================
function Write-FailAndExit {
    param([string]$Message)
    Write-ReportLine $sepLine "Cyan"
    Write-ReportLine "FAIL - $Message" "Red"
    exit 1
}

# ============================================================
# MAIN
# ============================================================

# ---- Resolve trace file path ----
# Strip sess_ prefix if present so callers can pass either sess_XXXX or XXXX
$sid = $SessionId -replace '^sess_', ''
$traceFile = Join-Path -Path $TraceDir -ChildPath "sess_${sid}.exec.jsonl"
$hasTraceFile = Test-Path -LiteralPath $traceFile -PathType Leaf

# ---- Handle -Force (bypass all checks) ----
if ($Force) {
    Write-OverrideToAudit
    Write-ReportLine "Checkpoint Report - $SessionId / $TaskPath ($Phase)" "Cyan"
    Write-ReportLine $sepLine "Cyan"
    Write-ReportLine "[SKIP] FORCE OVERRIDE - All checks bypassed" "Magenta"
    Write-ReportLine $sepLine "Cyan"
    Write-ReportLine "PASS - Force override" "Green"
    exit 0
}

# ---- Print header ----
Write-ReportLine "Checkpoint Report - $SessionId / $TaskPath ($Phase)" "Cyan"
Write-ReportLine $sepLine "Cyan"

# ---- Check trace file exists ----
if (-not $hasTraceFile) {
    Write-ReportLine "[FAIL] checkpoint - Trace file not found: $traceFile" "Red"
    Write-FailAndExit "Trace file not found"
}

# ============================================================
# STEP 1: trace_completeness.ps1
# ============================================================
$tcScript = Join-Path -Path $scriptDir -ChildPath "trace_completeness.ps1"
$tcArgs = "-TraceFile `"$traceFile`" -TaskPath $TaskPath"

if ($VerboseOutput) {
    Write-Host "[CMD] powershell.exe -NoProfile -File `"$tcScript`" $tcArgs" -ForegroundColor DarkGray
}

$tcResult = Invoke-Validator -ScriptPath $tcScript -Arguments $tcArgs

if ($tcResult.ErrorMsg) {
    Write-ReportLine "[FAIL] trace_completeness  - Error: $($tcResult.ErrorMsg)" "Red"
    Write-FailAndExit "trace_completeness script unavailable"
}

if ($tcResult.ExitCode -eq 0) {
    $details = @()
    $checks = $tcResult.Json.checks
    if ($checks) {
        if ($checks.file_exists)         { $details += "file_exists" }
        if ($checks.valid_jsonl)         { $details += "valid_jsonl" }
        if ($checks.task_start_found)    { $details += "task_start" }
        if ($checks.task_complete_found) { $details += "task_complete" }
        if ($checks.chronological)       { $details += "chronological" }
    }
    Write-ReportLine "[PASS] trace_completeness  - All entries present, chronological" "Green"
    if ($VerboseOutput -and $details.Count -gt 0) {
        Write-Host "        exit=$($tcResult.ExitCode) checks: $($details -join ', ')" -ForegroundColor DarkGray
        if ($tcResult.Json.errors -and $tcResult.Json.errors.Count -gt 0) {
            Write-Host "        warnings: $($tcResult.Json.errors -join '; ')" -ForegroundColor Yellow
        }
    }
} else {
    $errText = "exit code $($tcResult.ExitCode)"
    if ($tcResult.Json -and $tcResult.Json.errors -and $tcResult.Json.errors.Count -gt 0) {
        $errText = $tcResult.Json.errors -join '; '
    }
    Write-ReportLine "[FAIL] trace_completeness  - $errText" "Red"
    if ($VerboseOutput -and $tcResult.Output) {
        Write-Host "        stdout: $($tcResult.Output.Trim())" -ForegroundColor DarkGray
    }
    Write-FailAndExit "trace_completeness failed"
}

# ============================================================
# STEP 2: tdd_order.ps1
#   Uses subagent trace if available (has file_read/file_write entries)
#   Falls back to main session trace
# ============================================================
$tddScript = Join-Path -Path $scriptDir -ChildPath "tdd_order.ps1"

# Resolve the best trace file for TDD order validation
# Subagent traces now live alongside main traces in traces/ root
# Identified by naming convention: sess_<sid>__<agent>__<task>.exec.jsonl
$subagentDir = $TraceDir
$subagentPattern = "sess_${sid}__*__${TaskPath}.exec.jsonl"
$subagentFile = $null

if (Test-Path -LiteralPath $subagentDir -PathType Container) {
    $matchingFiles = @(Get-ChildItem -LiteralPath $subagentDir -Filter $subagentPattern -File)
    if ($matchingFiles.Count -gt 0) {
        $subagentFile = $matchingFiles[0].FullName
    }
}

$tddTraceFile = if ($subagentFile) { $subagentFile } else { $traceFile }
$tddArgs = "-TraceFile `"$tddTraceFile`" -TaskPath $TaskPath -Phase $Phase"

if ($VerboseOutput) {
    Write-Host "[CMD] powershell.exe -NoProfile -File `"$tddScript`" $tddArgs" -ForegroundColor DarkGray
    if ($subagentFile) {
        Write-Host "       Using subagent trace for TDD order validation" -ForegroundColor DarkGray
    }
}

$tddResult = Invoke-Validator -ScriptPath $tddScript -Arguments $tddArgs

if ($tddResult.ErrorMsg) {
    Write-ReportLine "[FAIL] tdd_order           - Error: $($tddResult.ErrorMsg)" "Red"
    Write-FailAndExit "tdd_order script unavailable"
}

if ($tddResult.ExitCode -eq 0) {
    # Build a descriptive summary based on phase
    $summary = "TDD order respected"
    $phaseUsed = $tddResult.Json.phase
    if ($phaseUsed -eq "RED") {
        $summary = "Only test files modified in RED phase"
    } elseif ($phaseUsed -eq "GREEN") {
        $summary = "Test file existed before implementation"
    } elseif ($phaseUsed -eq "REFACTOR") {
        $summary = "Only test files modified in REFACTOR phase"
    } elseif ($phaseUsed -eq "AUTO") {
        $summary = "TDD order respected (inferred: $phaseUsed)"
    } else {
        $summary = "TDD order respected for $phaseUsed phase"
    }
    Write-ReportLine "[PASS] tdd_order           - $summary" "Green"
    if ($VerboseOutput) {
        $testFiles = @($tddResult.Json.checks.test_files_written)
        $implFiles = @($tddResult.Json.checks.impl_files_written)
        Write-Host "        exit=$($tddResult.ExitCode) phase=$phaseUsed test_files=$($testFiles.Count) impl_files=$($implFiles.Count)" -ForegroundColor DarkGray
        if ($testFiles.Count -gt 0) {
            Write-Host "        tests: $($testFiles -join ', ')" -ForegroundColor DarkGray
        }
        if ($implFiles.Count -gt 0) {
            Write-Host "        impl:  $($implFiles -join ', ')" -ForegroundColor DarkGray
        }
    }
} else {
    $errText = "exit code $($tddResult.ExitCode)"
    if ($tddResult.Json -and $tddResult.Json.errors -and $tddResult.Json.errors.Count -gt 0) {
        $errText = $tddResult.Json.errors -join '; '
    }
    Write-ReportLine "[FAIL] tdd_order           - $errText" "Red"
    if ($VerboseOutput -and $tddResult.Output) {
        Write-Host "        stdout: $($tddResult.Output.Trim())" -ForegroundColor DarkGray
    }
    Write-FailAndExit "tdd_order failed"
}

# ============================================================
# STEP 3: qg_enforcer.ps1 (skip for RED phase -- RED has no QG)
# ============================================================
$qgPassed = $true

if ($Phase -eq "RED") {
    Write-ReportLine "[SKIP] qg_enforcer        - Skipped (RED phase has no quality gate)" "Yellow"
} else {
    $qgScript = Join-Path -Path $scriptDir -ChildPath "qg_enforcer.ps1"
    $qgArgs = "-TraceFile `"$traceFile`" -TaskPath $TaskPath -Threshold $Threshold"

    if ($VerboseOutput) {
        Write-Host "[CMD] powershell.exe -NoProfile -File `"$qgScript`" $qgArgs" -ForegroundColor DarkGray
    }

    $qgResult = Invoke-Validator -ScriptPath $qgScript -Arguments $qgArgs

    if ($qgResult.ErrorMsg) {
        Write-ReportLine "[FAIL] qg_enforcer         - Error: $($qgResult.ErrorMsg)" "Red"
        Write-FailAndExit "qg_enforcer script unavailable"
    }

    # qg enforcer has multiple exit codes:
    #   0 = pass
    #   1 = below threshold
    #   2 = no QG found
    #   3 = security below 7
    if ($qgResult.ExitCode -eq 0) {
        $score = if ($qgResult.Json.checks.score -ne $null) { $qgResult.Json.checks.score } else { "?" }
        $qgSummary = "QG=${score}/10 >= $Threshold, all axes scored"
        Write-ReportLine "[PASS] qg_enforcer         - $qgSummary" "Green"
        if ($VerboseOutput) {
            Write-Host "        exit=$($qgResult.ExitCode) score=$score threshold=$Threshold security_ok=$($qgResult.Json.checks.security_ok)" -ForegroundColor DarkGray
            if ($qgResult.Json.errors -and $qgResult.Json.errors.Count -gt 0) {
                Write-Host "        notes: $($qgResult.Json.errors -join '; ')" -ForegroundColor Yellow
            }
        }
    } else {
        $qgPassed = $false
        if ($qgResult.ExitCode -eq 1) {
            $exitMsg = "QG below threshold"
        } elseif ($qgResult.ExitCode -eq 2) {
            $exitMsg = "No QG score found"
        } elseif ($qgResult.ExitCode -eq 3) {
            $exitMsg = "Security axis below 7"
        } else {
            $exitMsg = "exit code $($qgResult.ExitCode)"
        }
        $errText = $exitMsg
        if ($qgResult.Json -and $qgResult.Json.errors -and $qgResult.Json.errors.Count -gt 0) {
            $errText = $qgResult.Json.errors -join '; '
        }
        Write-ReportLine "[FAIL] qg_enforcer         - $errText" "Red"
        if ($VerboseOutput -and $qgResult.Output) {
            Write-Host "        stdout: $($qgResult.Output.Trim())" -ForegroundColor DarkGray
        }
        Write-FailAndExit "qg_enforcer failed"
    }
}

# ============================================================
# SUMMARY
# ============================================================
Write-ReportLine $sepLine "Cyan"
Write-ReportLine "PASS - All gates passed" "Green"
exit 0
