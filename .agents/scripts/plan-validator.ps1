<#
.SYNOPSIS
    Plan Validator -- validates prompt-plan-v1 JSON files against structural rules
.DESCRIPTION
    Reads a plan JSON file and validates all 13 rules defined in plan.schema.md:
    unique IDs, valid dependencies, no cycles, valid agents/divisions/risk,
    brief_required for HIGH+, positive estimated_files, prompt_id format, task count limits.
.PARAMETER PlanFile
    Path to the plan JSON file (.agents/plans/<prompt_id>.plan.json)
.PARAMETER ManifestPath
    Path to MANIFEST.md for division/agent registry (default: .agents/MANIFEST.md)
.EXAMPLE
    .agents/scripts/plan-validator.ps1 -PlanFile .agents/plans/prompt_001.plan.json
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$PlanFile,

    [Parameter(Mandatory = $false)]
    [string]$ManifestPath = ".agents/MANIFEST.md"
)

# ============================================================
# HELPERS
# ============================================================

$exitCode = 0
$errors = @()

function Add-Error {
    param([string]$Message)
    $script:errors += $Message
    Write-Output "[FAIL] $Message"
    $script:exitCode = 1
}

# ============================================================
# READ PLAN FILE
# ============================================================

if (!(Test-Path -LiteralPath $PlanFile)) {
    Add-Error "Plan file not found: $PlanFile"
    exit 1
}

$plan = Get-Content -LiteralPath $PlanFile -Raw -Encoding UTF8 | ConvertFrom-Json
if ($null -eq $plan) {
    Add-Error "Failed to parse plan JSON: $PlanFile"
    exit 1
}

# ============================================================
# AGENT -> DIVISION MAPPING (from MANIFEST.md)
# ============================================================

$divisionMap = @{
    "engineering" = @(
        "orchestrator", "engineering-lead", "frontend-developer",
        "backend-architect", "database-engineer"
    )
    "platform" = @(
        "platform-lead", "devops-engineer", "cloud-architect",
        "security-engineer", "incident-commander"
    )
    "quality" = @(
        "quality-lead", "sdet", "performance-tester",
        "visual-qa-specialist", "qa-automation-engineer"
    )
    "design" = @(
        "design-lead", "ui-designer", "ux-researcher",
        "design-systems-engineer", "animator"
    )
    "intelligence" = @(
        "intelligence-lead", "session-analyst", "optimization-architect"
    )
    "research-council" = @(
        "moderator", "advocate", "skeptic", "devils-advocate", "domain-expert"
    )
}

$validDivisions = @($divisionMap.Keys)
$validAgents = @()
foreach ($div in $divisionMap.Keys) {
    $validAgents += $divisionMap[$div]
}

# ============================================================
# VALIDATION RULES
# ============================================================

Write-Output "Validating plan: $PlanFile"
Write-Output ("Plan: " + $plan.prompt_id + " - " + $plan.goal)
Write-Output ("Tasks: " + $plan.tasks.Count)
Write-Output ""

$planPromptId = $plan.prompt_id
$planTasks = $plan.tasks

# --- Rule 10: prompt_id format ---
if ($planPromptId -notmatch '^[a-zA-Z0-9_]+$') {
    Add-Error ("RULE 10: Invalid prompt_id format: '" + $planPromptId + "'. Must match: ^[a-zA-Z0-9_]+$")
}

# --- Rule 11: At least 1 task ---
if ($null -eq $planTasks -or $planTasks.Count -eq 0) {
    Add-Error "RULE 11: Plan has no tasks"
    exit 1
}

# --- Rule 12: Maximum 15 tasks ---
if ($planTasks.Count -gt 15) {
    Add-Error ("RULE 12: Plan exceeds maximum 15 tasks (has " + $planTasks.Count + ")")
}

# --- Build task ID set for lookup ---
$taskIds = @{}
foreach ($t in $planTasks) {
    if ($null -eq $t.id) { continue }
    $taskIds[$t.id] = $true
}

# --- Validate each task ---
foreach ($t in $planTasks) {
    $tid = $t.id

    # --- Rule 13: task ID format ---
    if ($tid -notmatch '^task_\d+$') {
        Add-Error ("RULE 13: Invalid task ID format: '" + $tid + "'. Must match: ^task_\d+$")
    }

    # --- Rule 7: valid risk ---
    $validRisks = @("LOW", "MED", "HIGH", "CRITICAL")
    if ($validRisks -notcontains $t.risk) {
        Add-Error ("RULE 7: Task '" + $tid + "' has invalid risk: '" + $t.risk + "'. Valid: " + ($validRisks -join ', '))
    }

    # --- Rule 4: valid agent ---
    if ($validAgents -notcontains $t.agent) {
        Add-Error ("RULE 4: Task '" + $tid + "' has invalid agent role: '" + $t.agent + "'. Must be one of: " + ($validAgents -join ', '))
    }

    # --- Rule 5: valid division ---
    if ($validDivisions -notcontains $t.division) {
        Add-Error ("RULE 5: Task '" + $tid + "' has invalid division: '" + $t.division + "'. Valid: " + ($validDivisions -join ', '))
    }

    # --- Rule 6: agent belongs to division ---
    if ($divisionMap.ContainsKey($t.division)) {
        $divAgents = $divisionMap[$t.division]
        if ($t.agent -ne "orchestrator" -and $divAgents -notcontains $t.agent) {
            Add-Error ("RULE 6: Task '" + $tid + "': agent '" + $t.agent + "' is not in division '" + $t.division + "'. Valid agents: " + ($divAgents -join ', '))
        }
    }

    # --- Rule 8: brief_required for HIGH/CRITICAL ---
    if (($t.risk -eq "HIGH" -or $t.risk -eq "CRITICAL") -and $t.brief_required -ne $true) {
        Add-Error ("RULE 8: Task '" + $tid + "' has risk '" + $t.risk + "' but brief_required is false")
    }

    # --- Rule 9: estimated_files must be positive ---
    if ($null -eq $t.estimated_files -or $t.estimated_files -lt 1) {
        Add-Error ("RULE 9: Task '" + $tid + "' has invalid estimated_files: '" + [string]$t.estimated_files + "'. Must be >= 1")
    }
}

# --- Rule 1: Duplicate task IDs ---
$seenIds = @{}
foreach ($t in $planTasks) {
    if ($seenIds.ContainsKey($t.id)) {
        Add-Error ("RULE 1: Duplicate task ID: '" + $t.id + "'")
    }
    $seenIds[$t.id] = $true
}

# --- Rule 2: Dependency references ---
foreach ($t in $planTasks) {
    if ($null -eq $t.depends_on) { continue }
    foreach ($dep in $t.depends_on) {
        if (!$taskIds.ContainsKey($dep)) {
            Add-Error ("RULE 2: Task '" + $t.id + "' depends on '" + $dep + "' which does not exist in plan")
        }
    }
}

# --- Rule 3: Cycle detection (Kahn's algorithm / topological sort) ---
$depGraph = @{}
foreach ($t in $planTasks) {
    $deps = @()
    if ($null -ne $t.depends_on) {
        foreach ($dep in $t.depends_on) {
            $deps += $dep
        }
    }
    $depGraph[$t.id] = $deps
}

# Calculate in-degree for each node (initialize all nodes first)
$inDegree = @{}
foreach ($node in $depGraph.Keys) {
    $inDegree[$node] = 0
}
foreach ($node in $depGraph.Keys) {
    foreach ($dep in $depGraph[$node]) {
        if ($inDegree.ContainsKey($dep)) {
            $inDegree[$dep]++
        }
    }
}

# Queue nodes with no incoming edges
$queue = New-Object System.Collections.Queue
foreach ($node in $inDegree.Keys) {
    if ($inDegree[$node] -eq 0) {
        $queue.Enqueue($node)
    }
}

$visited = 0
while ($queue.Count -gt 0) {
    $node = $queue.Dequeue()
    $visited++
    foreach ($dep in $depGraph[$node]) {
        $inDegree[$dep]--
        if ($inDegree[$dep] -eq 0) {
            $queue.Enqueue($dep)
        }
    }
}

# If not all nodes visited, there's a cycle
if ($visited -ne $depGraph.Keys.Count) {
    $cycleNodes = @()
    foreach ($node in $depGraph.Keys) {
        if ($inDegree[$node] -gt 0) {
            $cycleNodes += $node
        }
    }
    Add-Error ("RULE 3: Cycle detected involving tasks: " + ($cycleNodes -join ', '))
}

# ============================================================
# SUMMARY
# ============================================================

Write-Output ""
if ($exitCode -eq 0) {
    Write-Output ("[PASS] Plan validation PASSED for " + $planPromptId + " -- " + $planTasks.Count + " tasks, 0 errors")
    exit 0
} else {
    Write-Output ("[FAIL] Plan validation FAILED for " + $planPromptId + " -- " + $errors.Count + " error(s):")
    foreach ($e in $errors) {
        Write-Output ("  - " + $e)
    }
    exit 1
}
