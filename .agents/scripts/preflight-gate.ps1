<#
.SYNOPSIS
    Pre-flight Gate -- enforces the planning layer before every significant action.

.DESCRIPTION
    Runs before plan, delegate, execute, brief, and complete actions. Checks that
    the system is in a valid state for the requested action. If any check fails,
    the action is BLOCKED and must not proceed.

    Exit codes:
      0 = PASS    -- all checks pass, proceed with action
      1 = BLOCKED -- a blocking check failed, return BLOCKED result
      2 = WARN    -- non-blocking issue found, proceed with caution

.PARAMETER Action
    The action being gated: plan | delegate | execute | brief | complete | checkpoint

.PARAMETER TaskId
    The task ID (e.g., task_101). Required for delegate, execute, brief, complete.

.PARAMETER SessionId
    Current session ID (e.g., sess_20260628_fix-gaps). Auto-detected if not provided.

.PARAMETER PlansDir
    Path to plans directory (default: .agents/plans)

.PARAMETER QueueDir
    Path to queue directory (default: .agents/queue)

.PARAMETER ShowDetails
    Print detailed check results to console.

.EXAMPLE
    powershell .agents/scripts/preflight-gate.ps1 -Action plan -SessionId sess_001
    powershell .agents/scripts/preflight-gate.ps1 -Action delegate -TaskId task_101
    powershell .agents/scripts/preflight-gate.ps1 -Action execute -TaskId task_101 -ShowDetails
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("plan", "delegate", "execute", "brief", "complete", "checkpoint")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$TaskId = "",

    [Parameter(Mandatory = $false)]
    [string]$SessionId = "",

    [Parameter(Mandatory = $false)]
    [string]$PlansDir = ".agents/plans",

    [Parameter(Mandatory = $false)]
    [string]$QueueDir = ".agents/queue",

    [Parameter(Mandatory = $false)]
    [switch]$ShowDetails
)

# ============================================================
# HELPERS
# ============================================================

function Log {
    param([string]$Msg)
    if ($ShowDetails) { $script:result._logs += $Msg }
}

function Read-JsonFile {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { return $null }
}

function Get-Timestamp {
    return (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}

# ============================================================
# RESULT
# ============================================================

$result = @{
    gate = "preflight-gate-v1"
    ts = Get-Timestamp
    action = $Action
    task_id = $TaskId
    status = "PASS"
    exit_code = 0
    checks = @()
    blockers = @()
    warnings = @()
    _logs = @()  # verbose log messages (only populated when ShowDetails is on)
}

function Add-Check {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $result.checks += @{
        check = $Name
        passed = $Passed
        detail = $Detail
    }
    if (!$Passed) {
        $blockerMsg = $Name + ": " + $Detail
        $result.blockers += $blockerMsg
    }
}

function Add-Warning {
    param([string]$Detail)
    $result.warnings += $Detail
}

function Fail-Gate {
    $result.status = "BLOCKED"
    $result.exit_code = 1
}

function Warn-Gate {
    if ($result.exit_code -eq 0) {
        $result.status = "WARN"
        $result.exit_code = 2
    }
}

# ============================================================
# AUTO-DETECT SESSION
# ============================================================

if ([string]::IsNullOrEmpty($SessionId)) {
    $traceFiles = Get-ChildItem -Path ".agents/traces" -Filter "*.exec.jsonl" -ErrorAction SilentlyContinue `
        | Sort-Object LastWriteTime -Descending
    if ($null -ne $traceFiles -and $traceFiles.Count -gt 0) {
        $SessionId = $traceFiles[0].BaseName -replace '\.exec$', ''
        Log "Auto-detected session: $SessionId"
    } else {
        $SessionId = "unknown"
        Log "No session detected, using 'unknown'"
    }
}

# ============================================================
# DISCOVER PLANS
# ============================================================

$planFiles = @()
if (Test-Path -LiteralPath $PlansDir) {
    $planFiles = Get-ChildItem -Path $PlansDir -Filter "*.plan.json" -ErrorAction SilentlyContinue
}

$activePlan = $null
$activePromptId = $null

foreach ($pf in $planFiles) {
    $plan = Read-JsonFile $pf.FullName
    if ($null -ne $plan -and $plan.session_id -eq $SessionId) {
        $activePlan = $plan
        $activePromptId = $plan.prompt_id
        Log ("Found plan for session: " + $plan.prompt_id + " - " + $plan.goal)
        break
    }
}

if ($null -eq $activePlan -and $planFiles.Count -gt 0) {
    $latest = $planFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $plan = Read-JsonFile $latest.FullName
    if ($null -ne $plan) {
        $activePlan = $plan
        $activePromptId = $plan.prompt_id
        Log ("No session match. Using latest plan: " + $plan.prompt_id + " - " + $plan.goal)
    }
}

# ============================================================
# DISCOVER QUEUE INDEX
# ============================================================

$index = Read-JsonFile (Join-Path -Path $QueueDir "index.json")
if ($null -ne $index -and $index.schema -eq "queue-index-v1") {
    Log "Queue index is v1 -- auto-migration needed"
    $index = $null
}

# ============================================================
# RESOLVE TASK PATH
# ============================================================

function Resolve-TaskDir {
    param([string]$Tid)
    if ($null -eq $index -or [string]::IsNullOrEmpty($Tid)) { return $null }
    foreach ($prompt in $index.prompts) {
        foreach ($t in $prompt.tasks) {
            if ($t.task_id -eq $Tid) {
                $dir = Join-Path -Path $QueueDir -ChildPath (Join-Path -Path $prompt.prompt_id -ChildPath $Tid)
                if (Test-Path -LiteralPath $dir) { return $dir }
            }
        }
    }
    $candidates = Get-ChildItem -Path $QueueDir -Directory -Recurse -ErrorAction SilentlyContinue `
        | Where-Object { $_.Name -eq $Tid }
    foreach ($cd in $candidates) {
        if (Test-Path -LiteralPath (Join-Path -Path $cd.FullName "status.json")) {
            return $cd.FullName
        }
    }
    return $null
}

function Get-TaskDepIds {
    param([string]$Tid)
    if ($null -eq $activePlan) { return @() }
    foreach ($t in $activePlan.tasks) {
        if ($t.id -eq $Tid) { return $t.depends_on }
    }
    return @()
}

function Get-DepStatus {
    param([string]$DepId)
    if ($null -eq $index) { return "unknown" }
    foreach ($prompt in $index.prompts) {
        foreach ($t in $prompt.tasks) {
            if ($t.task_id -eq $DepId) { return $t.status }
        }
    }
    return "unknown"
}

# ============================================================
# ACTION: plan
# ============================================================

function Check-Plan {
    Log "Checking: plan action"
    if ($null -ne $activePlan) {
        Add-Check "existing_plan" $true ("Plan exists for session: " + $activePlan.prompt_id + " - " + $activePlan.goal)
    } else {
        Add-Check "existing_plan" $true "No existing plan for this session -- creating new plan is OK"
    }
    $plansDirOk = Test-Path -LiteralPath $PlansDir
    Add-Check "plans_dir_writable" $plansDirOk ("Plans directory " + $(if ($plansDirOk) { "exists" } else { "missing" }))
    if (!$plansDirOk) { Fail-Gate }
}

# ============================================================
# ACTION: delegate
# ============================================================

function Check-Delegate {
    Log ("Checking: delegate action for task " + $TaskId)
    if ([string]::IsNullOrEmpty($TaskId)) {
        Add-Check "task_id_provided" $false "TaskId is required for delegate action"
        Fail-Gate
        return
    }
    if ($null -eq $activePlan) {
        Add-Check "plan_exists" $false "No validated plan found. Run /plan first."
        Fail-Gate
    } else {
        Add-Check "plan_exists" $true ("Plan found: " + $activePlan.prompt_id)
    }
    $taskInPlan = $false
    if ($null -ne $activePlan) {
        foreach ($t in $activePlan.tasks) {
            if ($t.id -eq $TaskId) { $taskInPlan = $true; break }
        }
    }
    Add-Check "task_in_plan" $taskInPlan ("Task " + $TaskId + $(if ($taskInPlan) { " found in plan" } else { " NOT found in plan" }))
    if (!$taskInPlan) { Fail-Gate; return }
    $deps = Get-TaskDepIds $TaskId
    if ($deps.Count -gt 0) {
        $allDepsDone = $true
        foreach ($d in $deps) {
            $depStatus = Get-DepStatus $d
            if ($depStatus -ne "completed" -and $depStatus -ne "archived") {
                $allDepsDone = $false
                Add-Check ("dep_" + $d) $false ("Dependency " + $d + " is " + $depStatus + " (must be completed)")
                Fail-Gate
            }
        }
        if ($allDepsDone) {
            Add-Check "deps_complete" $true ("All " + $deps.Count + " dependencies completed")
        }
    } else {
        Add-Check "deps_complete" $true "No dependencies"
    }
    $taskDir = Resolve-TaskDir $TaskId
    if ($null -ne $taskDir) {
        $briefPath = Join-Path -Path $taskDir "brief.json"
        $briefExists = Test-Path -LiteralPath $briefPath
        Add-Check "brief_exists" $briefExists $(if ($briefExists) { "brief.json found" } else { "brief.json missing at " + $briefPath })
        if (!$briefExists) { Fail-Gate }
        if ($briefExists) {
            $brief = Read-JsonFile $briefPath
            Add-Check "brief_valid" ($null -ne $brief) $(if ($null -ne $brief) { "brief.json is valid JSON" } else { "brief.json is not valid JSON" })
            if ($null -eq $brief) { Fail-Gate }
        }
        $statusPath = Join-Path -Path $taskDir "status.json"
        $status = Read-JsonFile $statusPath
        if ($null -ne $status) {
            $currentStatus = $status.status
            $statusOk = ($currentStatus -eq "pending" -or $currentStatus -eq "in_progress")
            Add-Check "queue_status" $statusOk ("Current status: " + $currentStatus + $(if ($statusOk) { " - OK to delegate" } else { " - must be pending or in_progress" }))
            if (!$statusOk) { Fail-Gate }
        }
    } else {
        Add-Check "task_in_queue" $false ("Task " + $TaskId + " not found in queue. Run plan-scaffold.ps1 or New-QueueItem first.")
        Fail-Gate
    }
}

# ============================================================
# ACTION: execute
# ============================================================

function Check-Execute {
    Log ("Checking: execute action for task " + $TaskId)
    if ([string]::IsNullOrEmpty($TaskId)) {
        Add-Check "task_id_provided" $false "TaskId is required for execute action"
        Fail-Gate
        return
    }
    if ($null -eq $activePlan) {
        Add-Check "plan_exists" $false "No validated plan found. Run /plan first."
        Fail-Gate
    } else {
        Add-Check "plan_exists" $true ("Plan found: " + $activePlan.prompt_id)
    }
    $taskInPlan = $false
    if ($null -ne $activePlan) {
        foreach ($t in $activePlan.tasks) {
            if ($t.id -eq $TaskId) { $taskInPlan = $true; break }
        }
    }
    Add-Check "task_in_plan" $taskInPlan ("Task " + $TaskId + $(if ($taskInPlan) { " found in plan" } else { " NOT found in plan" }))
    if (!$taskInPlan) { Fail-Gate }
    $deps = Get-TaskDepIds $TaskId
    if ($deps.Count -gt 0) {
        $allDepsDone = $true
        foreach ($d in $deps) {
            $depStatus = Get-DepStatus $d
            if ($depStatus -ne "completed" -and $depStatus -ne "archived") {
                $allDepsDone = $false
                Add-Check ("dep_" + $d) $false ("Dependency " + $d + " is " + $depStatus + " (must be completed)")
                Fail-Gate
            }
        }
        if ($allDepsDone) {
            Add-Check "deps_complete" $true ("All " + $deps.Count + " dependencies completed")
        }
    } else {
        Add-Check "deps_complete" $true "No dependencies"
    }
    $taskDir = Resolve-TaskDir $TaskId
    if ($null -eq $taskDir) {
        Add-Check "task_in_queue" $false ("Task " + $TaskId + " not found in queue. Run plan-scaffold.ps1 first.")
        Fail-Gate
    } else {
        Add-Check "task_in_queue" $true "Task directory found"
        $statusPath = Join-Path -Path $taskDir "status.json"
        $status = Read-JsonFile $statusPath
        if ($null -ne $status) {
            $currentStatus = $status.status
            $statusOk = ($currentStatus -eq "pending")
            Add-Check "queue_status" $statusOk ("Current status: " + $currentStatus + $(if ($statusOk) { " - OK to execute" } else { " - must be pending" }))
            if (!$statusOk) { Fail-Gate }
        }
    }
}

# ============================================================
# ACTION: brief
# ============================================================

function Check-Brief {
    Log ("Checking: brief action for task " + $TaskId)
    if ([string]::IsNullOrEmpty($TaskId)) {
        Add-Check "task_id_provided" $false "TaskId is required for brief action"
        Fail-Gate
        return
    }
    if ($null -eq $activePlan) {
        Add-Check "plan_exists" $false "No validated plan found. Run /plan first."
        Fail-Gate
    } else {
        Add-Check "plan_exists" $true ("Plan found: " + $activePlan.prompt_id)
    }
    $taskInPlan = $false
    if ($null -ne $activePlan) {
        foreach ($t in $activePlan.tasks) {
            if ($t.id -eq $TaskId) {
                $taskInPlan = $true
                if ($t.brief_required) {
                    Add-Check "brief_required" $true "Plan marks this task as brief_required"
                }
                break
            }
        }
    }
    if (!$taskInPlan) {
        Add-Check "task_in_plan" $false ("Task " + $TaskId + " NOT found in plan - ad-hoc brief")
        Add-Warning "Task $TaskId is not in any plan. Ad-hoc briefs skip dependency validation."
        Warn-Gate
    } else {
        Add-Check "task_in_plan" $true ("Task " + $TaskId + " found in plan")
    }
    $taskDir = Resolve-TaskDir $TaskId
    if ($null -eq $taskDir) {
        Add-Warning ("Task " + $TaskId + " not in queue yet - will be created by New-QueueItem")
        Warn-Gate
    } else {
        $briefPath = Join-Path -Path $taskDir "brief.json"
        if (Test-Path -LiteralPath $briefPath) {
            Add-Warning ("brief.json already exists for " + $TaskId + " - will be overwritten")
            Warn-Gate
        }
    }
}

# ============================================================
# ACTION: complete
# ============================================================

function Check-Complete {
    Log ("Checking: complete action for task " + $TaskId)
    if ([string]::IsNullOrEmpty($TaskId)) {
        Add-Check "task_id_provided" $false "TaskId is required for complete action"
        Fail-Gate
        return
    }
    $taskDir = Resolve-TaskDir $TaskId
    if ($null -eq $taskDir) {
        Add-Check "task_in_queue" $false ("Task " + $TaskId + " not found in queue")
        Fail-Gate
        return
    }
    Add-Check "task_in_queue" $true "Task directory found"
    $statusPath = Join-Path -Path $taskDir "status.json"
    $status = Read-JsonFile $statusPath
    if ($null -ne $status) {
        $currentStatus = $status.status
        $statusOk = ($currentStatus -eq "in_progress")
        Add-Check "queue_status" $statusOk ("Current status: " + $currentStatus + $(if ($statusOk) { " - OK to complete" } else { " - must be in_progress" }))
        if (!$statusOk) { Fail-Gate }
    }
    $tracePath = Join-Path -Path $taskDir "trace.jsonl"
    if (Test-Path -LiteralPath $tracePath) {
        $traceContent = Get-Content -LiteralPath $tracePath -ErrorAction SilentlyContinue
        $hasQGScores = $false
        foreach ($line in $traceContent) {
            if ($line -match "quality_gate|QG=") {
                $hasQGScores = $true
                break
            }
        }
        if ($hasQGScores) {
            Add-Check "quality_gate_trace" $true "Quality gate score found in trace"
        } else {
            Add-Warning "No quality gate score found in trace. Run /review before completing."
            Warn-Gate
        }
    } else {
        Add-Warning ("No trace.jsonl found for " + $TaskId + ". Run /checkpoint before completing.")
        Warn-Gate
    }
    $briefPath = Join-Path -Path $taskDir "brief.json"
    if (Test-Path -LiteralPath $briefPath) {
        Add-Check "brief_exists" $true "brief.json found"
    } else {
        Add-Warning ("No brief.json found for " + $TaskId)
        Warn-Gate
    }
}

# ============================================================
# ACTION: checkpoint
# ============================================================

function Check-Checkpoint {
    Log "Checking: checkpoint action"
    $tracePath = ".agents/traces/" + $SessionId + ".exec.jsonl"
    if (Test-Path -LiteralPath $tracePath) {
        Add-Check "session_trace_exists" $true ("Session trace found: " + $tracePath)
    } else {
        Add-Check "session_trace_exists" $false ("Session trace not found at " + $tracePath)
        Fail-Gate
    }
    if (![string]::IsNullOrEmpty($TaskId)) {
        $taskDir = Resolve-TaskDir $TaskId
        if ($null -ne $taskDir) {
            Add-Check "task_in_queue" $true ("Task " + $TaskId + " found in queue")
            $statusPath = Join-Path -Path $taskDir "status.json"
            if (Test-Path -LiteralPath $statusPath) {
                Add-Check "status_exists" $true "status.json found"
            } else {
                Add-Check "status_exists" $false ("status.json missing for " + $TaskId)
                Warn-Gate
            }
        } else {
            Add-Warning ("Task " + $TaskId + " not found in queue")
            Warn-Gate
        }
    }
    $idxPath = Join-Path -Path $QueueDir "index.json"
    if (Test-Path -LiteralPath $idxPath) {
        Add-Check "queue_index_exists" $true "Queue index found"
    } else {
        Add-Check "queue_index_exists" $false ("Queue index not found at " + $idxPath)
        Warn-Gate
    }
}

# ============================================================
# DISPATCH
# ============================================================

switch ($Action) {
    "plan"       { Check-Plan }
    "delegate"   { Check-Delegate }
    "execute"    { Check-Execute }
    "brief"      { Check-Brief }
    "complete"   { Check-Complete }
    "checkpoint" { Check-Checkpoint }
}

# ============================================================
# OUTPUT
# ============================================================

$json = $result | ConvertTo-Json -Depth 5
Write-Output $json

$auditEntry = @{
    ts = $result.ts
    agent = "preflight-gate"
    action_type = "preflight_gate"
    session_id = $SessionId
    detail = $result.status
    action = $Action
    task_id = $TaskId
    blockers = $result.blockers
} | ConvertTo-Json -Depth 3 -Compress

$auditPath = ".agents/audit.jsonl"
try {
    Add-Content -LiteralPath $auditPath -Value $auditEntry -Encoding UTF8
} catch {
    # Audit write failure should not block the gate
}

exit $result.exit_code
