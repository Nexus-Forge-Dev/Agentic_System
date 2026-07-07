# COMMAND: qg-enforce
# OPTS: --trace-file <path> --task-path <path> [--threshold <n>] [--force]
<#
.SYNOPSIS
  Quality Gate Enforcer - validates QG score exists and meets minimum threshold
  before a task is marked complete.

.DESCRIPTION
  Reads a Forge Nexus .exec.jsonl trace file, finds the task_output entry for a
  given task_path, parses the quality gate score (QG=), and validates it meets
  the configurable threshold. Also optionally validates security axis score.

  Handles both double-quoted ("...") and single-quoted ('...') JSON in trace files.

.PARAMETER TraceFile
  Required. Path to the .exec.jsonl trace file.

.PARAMETER TaskPath
  Required. The task_path to check (e.g., "003").

.PARAMETER Threshold
  Optional. Minimum QG score (default: 8.0).

.PARAMETER Force
  Optional switch. Bypass all checks, log override to audit.jsonl, exit 0.

.PARAMETER Detailed
  Optional switch. Print detailed scoring analysis to stderr.

.EXAMPLE
  .agents\scripts\qg_enforcer.ps1 -TraceFile .agents\traces\sess_20260614_4a7b81ee.exec.jsonl -TaskPath 003

.EXAMPLE
  .agents\scripts\qg_enforcer.ps1 -TraceFile trace.jsonl -TaskPath 001 -Threshold 9.0 -Detailed

.EXAMPLE
  .agents\scripts\qg_enforcer.ps1 -TraceFile trace.jsonl -TaskPath 003 -Force

.NOTES
  Exit codes:
    0: Quality gate passed
    1: Below threshold (with detail on what scored below)
    2: No quality gate found for this task_path
    3: Security axis below 7
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$TraceFile,

  [Parameter(Mandatory = $true)]
  [string]$TaskPath,

  [Parameter(Mandatory = $false)]
  [float]$Threshold = 8.0,

  [Parameter(Mandatory = $false)]
  [switch]$Force,

  [Parameter(Mandatory = $false)]
  [switch]$Detailed
)

# ---------------------------------------------------------------
# Helper: normalize single-quoted JSON to double-quoted JSON
# The trace file uses both " and ' for JSON keys/values.
# Convert 'key':'value' -> "key":"value" for ConvertFrom-Json.
# ---------------------------------------------------------------
function ConvertFrom-TraceJson {
  param([string]$Line)

  if (-not $Line) { return $null }

  $trimmed = $Line.Trim()

  # If it starts with { and contains single-quoted patterns, normalize
  if ($trimmed -match '^\s*\{' -and $trimmed -match "'") {
    # Replace single quotes around keys (word characters before colon)
    $normalized = $trimmed -replace "'([a-zA-Z_][a-zA-Z0-9_]*)'\s*:", '"$1":'
    # Replace single quotes around string values (colon/comma/start-of-value followed by single-quoted string)
    # Match patterns like :'value' or ,'value' or ['value'
    $normalized = $normalized -replace ":\s*'([^']*?)'(\s*[,}])", ':"$1"$2'
    $normalized = $normalized -replace "\[\s*'", '["'
    $normalized = $normalized -replace "'\s*\]", '"]'
    $normalized = $normalized -replace "'\s*,", '",'
    # Edge case: value at very end of object
    $normalized = $normalized -replace "'\s*\}", '"}'
    # Edge case: value at start (after {)
    $normalized = $normalized -replace "\{\s*'", '{"'

    try {
      return $normalized | ConvertFrom-Json
    } catch {
      # If normalization still fails, try raw parse
      try {
        return $trimmed | ConvertFrom-Json
      } catch {
        return $null
      }
    }
  }

  # Already valid JSON (double-quoted)
  try {
    return $trimmed | ConvertFrom-Json
  } catch {
    return $null
  }
}

# ---------------------------------------------------------------
# Helper: extract QG score from a string
# Matches patterns like:
#   QG=9.50/10
#   QG: 9.25/10
#   QG 9.50/10
#   qg=9.50
# ---------------------------------------------------------------
function Get-QGScore {
  param([string]$Text)

  if (-not $Text) { return $null }

  # Pattern 1: QG=NN.NN/10 or QG:NN.NN/10 or QG NN.NN/10 (case-insensitive)
  if ($Text -match '(?i)QG\s*[=:]\s*(\d+\.?\d*)\s*/\s*10') {
    return [float]($Matches[1])
  }

  # Pattern 2: QG NN.NN (without /10) (case-insensitive)
  if ($Text -match '(?i)QG\s*[=:]\s*(\d+\.?\d*)') {
    return [float]($Matches[1])
  }

  # Pattern 3: QG in result with just a number after space
  if ($Text -match '(?i)\bqg\s+(\d+\.?\d*)\b') {
    return [float]($Matches[1])
  }

  # Pattern 4: standalone score between result and other text
  # e.g., "SUCCESS, QG 9.50/10"
  if ($Text -match '(?i)\bquality.?gate[=:\s]+(\d+\.?\d*)') {
    return [float]($Matches[1])
  }

  return $null
}

# ---------------------------------------------------------------
# Helper: check which quality axes are mentioned
# 6 axes: correctness, security, performance, style, coverage, docs
# ---------------------------------------------------------------
function Get-MentionedAxes {
  param([string]$Text)

  $axes = @{
    correctness = $false
    security    = $false
    performance = $false
    style       = $false
    coverage    = $false
    docs        = $false
  }

  if (-not $Text) { return $axes }

  if ($Text -match '(?i)\bcorrectness\b')  { $axes.correctness = $true }
  if ($Text -match '(?i)\bsecurity\b')     { $axes.security = $true }
  if ($Text -match '(?i)\bperformance\b')  { $axes.performance = $true }
  if ($Text -match '(?i)\bstyle\b')        { $axes.style = $true }
  if ($Text -match '(?i)\bcoverage\b')     { $axes.coverage = $true }
  if ($Text -match '(?i)\bdocs\b')         { $axes.docs = $true }

  return $axes
}

# ---------------------------------------------------------------
# Helper: extract security axis score
# Pattern: security[=:]N, security=N/10, etc.
# ---------------------------------------------------------------
function Get-SecurityAxisScore {
  param([string]$Text)

  if (-not $Text) { return $null }

  if ($Text -match '(?i)\bsecurity\s*[=:]\s*(\d+\.?\d*)\s*(?:/\s*10)?') {
    return [float]($Matches[1])
  }

  return $null
}

# ---------------------------------------------------------------
# Helper: log override to audit.jsonl when -Force is used
# ---------------------------------------------------------------
function Log-Override {
  param(
    [string]$TraceFilePath,
    [string]$Task,
    [float]$OverrideThreshold
  )

  $agentsDir = Split-Path -Parent $PSScriptRoot
  $auditFile = Join-Path -Path $agentsDir -ChildPath "audit.jsonl"

  $entry = @{
    ts         = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    agent      = "qg_enforcer"
    action     = "qg_override"
    trace_file = $TraceFilePath
    task_path  = $Task
    threshold  = $OverrideThreshold
    reason     = "Force override - bypassed quality gate check"
    status     = "OVERRIDDEN"
  }

  $json = $entry | ConvertTo-Json -Compress

  try {
    Add-Content -LiteralPath $auditFile -Value $json -Encoding UTF8
    if ($Detailed) { Write-Warning "Override logged to $auditFile" }
  } catch {
    Write-Warning "Failed to log override to audit.jsonl: $_"
  }
}

# ---------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------

function Invoke-QGEnforcer {
  param(
    [string]$TraceFile,
    [string]$TaskPath,
    [float]$Threshold,
    [switch]$Force,
    [switch]$Detailed
  )

  # Build output object
  $result = @{
    script     = "qg_enforcer"
    trace_file = $TraceFile
    task_path  = $TaskPath
    threshold  = $Threshold
    passed     = $false
    checks     = @{
      qg_score_found  = $false
      score           = $null
      meets_threshold = $false
      security_ok     = $true
    }
    errors       = @()
    override_used = $false
  }

  # ---- FORCE MODE ----
  if ($Force) {
    $result.passed = $true
    $result.override_used = $true
    $result.checks.qg_score_found = $true
    $result.checks.meets_threshold = $true
    Log-Override -TraceFilePath $TraceFile -Task $TaskPath -OverrideThreshold $Threshold

    # Output JSON and exit 0
    return $result
  }

  # ---- Validate trace file exists ----
  if (-not (Test-Path -LiteralPath $TraceFile)) {
    $result.errors += "Trace file not found: $TraceFile"
    return $result
  }

  # ---- Read all lines from trace file ----
  $lines = @()
  try {
    $lines = Get-Content -LiteralPath $TraceFile -Encoding UTF8
  } catch {
    $result.errors += "Failed to read trace file: $_"
    return $result
  }

  if ($lines.Count -eq 0) {
    $result.errors += "Trace file is empty: $TraceFile"
    return $result
  }

  # ---- Find task_output entries for the given task_path ----
  $taskOutputs = @()
  $allTaskPaths = @{}
  $combinedText = ""

  foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if (-not $trimmed) { continue }

    $parsed = ConvertFrom-TraceJson -Line $trimmed
    if (-not $parsed) { continue }

    # Track all task_paths found for error reporting
    if ($parsed.task_path) {
      $tp = "$($parsed.task_path)"
      $allTaskPaths[$tp] = $true
    }

    # We're interested in task_output and task_complete entries
    if ($parsed.task_path -eq $TaskPath) {
      # Accumulate all text for combined analysis
      if ($parsed.result) { $combinedText += " $($parsed.result)" }
      if ($parsed.detail) { $combinedText += " $($parsed.detail)" }

      if ($parsed.type -eq "task_output" -or $parsed.type -eq "task_complete") {
        $taskOutputs += $parsed
      }
    }
  }

  # ---- Search for QG score ----
  $score = $null
  $foundInField = $null

  # Search each matching task entry for QG
  foreach ($entry in $taskOutputs) {
    $s = Get-QGScore -Text $entry.result
    if ($s -ne $null) { $score = $s; $foundInField = "result"; break }

    $s = Get-QGScore -Text $entry.detail
    if ($s -ne $null) { $score = $s; $foundInField = "detail"; break }
  }

  # If not found in task_output entries, search combined text
  if ($score -eq $null) {
    $score = Get-QGScore -Text $combinedText
    if ($score -ne $null) { $foundInField = "combined" }
  }

  # Also search all lines for this task_path
  if ($score -eq $null) {
    foreach ($line in $lines) {
      $trimmed = $line.Trim()
      if (-not $trimmed) { continue }

      $parsed = ConvertFrom-TraceJson -Line $trimmed
      if ($parsed -and $parsed.task_path -eq $TaskPath) {
        # Check all string fields
        $parsed.PSObject.Properties | ForEach-Object {
          if ($_.Value -is [string]) {
            $s = Get-QGScore -Text $_.Value
            if ($s -ne $null) { $score = $s; $foundInField = "$($_.Name)"; break }
          }
        }
        if ($score -ne $null) { break }
      }
    }
  }

  # ---- Populate checks ----
  if ($score -ne $null) {
    $result.checks.qg_score_found = $true
    $result.checks.score = $score

    if ($Detailed) {
      Write-Warning "QG score found: $score (in field: $foundInField)"
    }

    if ($score -ge $Threshold) {
      $result.checks.meets_threshold = $true
    } else {
      $result.errors += "QG score $score is below threshold $Threshold"
    }
  } else {
    $result.checks.qg_score_found = $false
    $result.checks.score = $null
    $result.checks.meets_threshold = $false

    # Build list of available task_paths
    $availablePaths = @($allTaskPaths.Keys | Sort-Object)
    if ($availablePaths.Count -gt 0) {
      $result.errors += "No quality gate score found for task_path '$TaskPath'. Available task_paths: $($availablePaths -join ', ')"
    } else {
      $result.errors += "No quality gate score found for task_path '$TaskPath'. No task_path entries found in trace file."
    }
  }

  # ---- Axis check (soft check - warn but don't fail) ----
  $mentionedAxes = Get-MentionedAxes -Text $combinedText
  $mentionedCount = @($mentionedAxes.Keys | Where-Object { $mentionedAxes[$_] -eq $true }).Count

  if ($Detailed) {
    Write-Warning "Quality axes mentioned: $mentionedCount/6"
    foreach ($axName in $mentionedAxes.Keys) {
      if ($mentionedAxes[$axName]) { Write-Warning "  [+] $axName" }
    }
  }

  if ($mentionedCount -lt 3) {
    $result.errors += "Axes check: only $mentionedCount/6 quality axes mentioned (expected at least 3). Consider scoring all 6 axes: correctness, security, performance, style, coverage, docs"
  }

  # ---- Security axis check (hard if mentioned) ----
  if ($mentionedAxes.security) {
    $securityScore = Get-SecurityAxisScore -Text $combinedText
    if ($securityScore -ne $null) {
      if ($Detailed) { Write-Warning "Security axis score: $securityScore" }
      if ($securityScore -lt 7.0) {
        $result.checks.security_ok = $false
        $result.errors += "Security axis score $securityScore is below minimum 7.0"
      }
    } else {
      # Security mentioned but no explicit score - warn
      if ($Detailed) { Write-Warning "Security axis mentioned but no explicit score found" }
    }
  }

  # ---- Determine pass/fail and exit code ----
  $logicalPass = $true
  if (-not $result.checks.qg_score_found) { $logicalPass = $false }
  if (-not $result.checks.meets_threshold) { $logicalPass = $false }
  if (-not $result.checks.security_ok) { $logicalPass = $false }

  $result.passed = $logicalPass

  return $result
}

# ---------------------------------------------------------------
# Execute
# ---------------------------------------------------------------
$output = Invoke-QGEnforcer -TraceFile $TraceFile -TaskPath $TaskPath -Threshold $Threshold -Force:$Force -Detailed:$Detailed

# Convert output to JSON and write to stdout
$jsonOutput = $output | ConvertTo-Json -Depth 10

# Determine exit code based on checks
$exitCode = 0

if ($Force) {
  $exitCode = 0
} elseif (-not $output.checks.qg_score_found) {
  $exitCode = 2
} elseif (-not $output.checks.security_ok) {
  $exitCode = 3
} elseif (-not $output.checks.meets_threshold) {
  $exitCode = 1
} else {
  $exitCode = 0
}

# Always output JSON result
Write-Output $jsonOutput

# Exit with appropriate code
exit $exitCode
