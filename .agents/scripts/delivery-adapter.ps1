<#
.SYNOPSIS
    Delivery Adapter -- bridges filesystem queue protocol to OpenCode Task tool
.DESCRIPTION
    Reads a brief.json from the queue and generates a self-contained Task tool
    prompt that can be used to delegate the task via OpenCode's Task tool.
    Runtime-agnostic design: the same brief.json can be consumed by any runtime.
    Uses Resolve-TaskPath to find queue entries through the prompt-grouped index.
.PARAMETER TaskId
    The task identifier (e.g., "task_003")
.PARAMETER QueueDir
    Path to the queue directory (default: ".agents/queue")
.PARAMETER Action
    generate-prompt | validate-brief | show-summary
.PARAMETER OutputFile
    If specified, writes the generated prompt to this file
.EXAMPLE
    .agents/scripts/delivery-adapter.ps1 -TaskId task_003 -Action generate-prompt
.EXAMPLE
    .agents/scripts/delivery-adapter.ps1 -TaskId task_003 -Action validate-brief
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TaskId,

    [Parameter(Mandatory = $false)]
    [string]$QueueDir = ".agents/queue",

    [Parameter(Mandatory = $false)]
    [ValidateSet('generate-prompt','validate-brief','show-summary')]
    [string]$Action = 'generate-prompt',

    [Parameter(Mandatory = $false)]
    [string]$OutputFile
)

function Read-JsonFile {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return $null }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

# ============================================================
# Path resolution through queue index
# ============================================================

function Read-Index {
    $idxPath = Join-Path -Path $QueueDir "index.json"
    if (Test-Path -LiteralPath $idxPath) {
        return Read-JsonFile $idxPath
    }
    return $null
}

function Resolve-TaskPath {
    param([string]$Tid)
    $index = Read-Index
    if ($null -eq $index) { return $null }
    foreach ($prompt in $index.prompts) {
        foreach ($t in $prompt.tasks) {
            if ($t.task_id -eq $Tid) {
                return Join-Path -Path $QueueDir -ChildPath $t.path
            }
        }
    }
    return $null
}

# ============================================================
# Resolve path and read brief
# ============================================================

# First try resolving through index
$taskDir = Resolve-TaskPath -Tid $TaskId

# Fallback: direct lookup in each prompt directory
if ($null -eq $taskDir) {
    # Try scanning prompt directories
    $index = Read-Index
    if ($null -ne $index) {
        foreach ($prompt in $index.prompts) {
            $candidate = Join-Path -Path $QueueDir -ChildPath (Join-Path -Path $prompt.prompt_id -ChildPath $TaskId)
            if (Test-Path -LiteralPath (Join-Path -Path $candidate "brief.json")) {
                $taskDir = $candidate
                break
            }
        }
    }
}

# Last resort: scan all subdirectories
if ($null -eq $taskDir) {
    $briefs = Get-ChildItem -Path $QueueDir -Recurse -Filter "brief.json" -Depth 3 -ErrorAction SilentlyContinue
    foreach ($bf in $briefs) {
        $briefContent = Read-JsonFile $bf.FullName
        if ($null -ne $briefContent -and $briefContent.task_id -eq $TaskId) {
            $taskDir = $bf.DirectoryName
            break
        }
    }
}

if ($null -eq $taskDir -or !(Test-Path -LiteralPath $taskDir)) {
    Write-Error "No queue entry found for $TaskId. Use New-QueueItem first."
    exit 1
}

$briefPath = Join-Path -Path $taskDir "brief.json"
$contextPath = Join-Path -Path $taskDir "context.json"

if (!(Test-Path -LiteralPath $briefPath)) {
    Write-Error "No brief.json found for $TaskId at $briefPath"
    exit 1
}

$brief = Read-JsonFile $briefPath
if ($null -eq $brief) {
    Write-Error "Invalid brief.json for $TaskId"
    exit 1
}

$context = Read-JsonFile $contextPath

# ============================================================
# Validate brief
# ============================================================

function Validate-Brief {
    $errors = @()

    if ([string]::IsNullOrEmpty($brief.task_id)) { $errors += "Missing: task_id" }
    if ([string]::IsNullOrEmpty($brief.task_path)) { $errors += "Missing: task_path" }
    if ([string]::IsNullOrEmpty($brief.title)) { $errors += "Missing: title" }
    if ([string]::IsNullOrEmpty($brief.delegator)) { $errors += "Missing: delegator" }
    if ([string]::IsNullOrEmpty($brief.delegate)) { $errors += "Missing: delegate" }
    if ([string]::IsNullOrEmpty($brief.division)) { $errors += "Missing: division" }
    if ([string]::IsNullOrEmpty($brief.risk)) { $errors += "Missing: risk" }
    if ($null -eq $brief.context -or [string]::IsNullOrEmpty($brief.context.goal)) { $errors += "Missing: context.goal" }
    if ($null -eq $brief.skills -or $brief.skills.Count -eq 0) { $errors += "Missing: skills (at least 1 required)" }
    if ($null -eq $brief.files_write -or $brief.files_write.Count -eq 0) { $errors += "Missing: files_write (at least 1 required)" }
    if ($null -eq $brief.test_cases -or $brief.test_cases.Count -eq 0) { $errors += "Missing: test_cases (at least 1 required)" }
    if ($null -eq $brief.acceptance_criteria -or $brief.acceptance_criteria.Count -eq 0) { $errors += "Missing: acceptance_criteria" }

    # Validate agent chain
    $allowedChains = @{
        "orchestrator" = @("engineering-lead", "platform-lead", "quality-lead", "design-lead", "intelligence-lead")
        "engineering-lead" = @("frontend-developer", "backend-architect", "database-engineer")
        "platform-lead" = @("devops-engineer", "cloud-architect", "security-engineer", "incident-commander")
        "quality-lead" = @("sdet", "performance-tester", "visual-qa-specialist", "qa-automation-engineer")
        "design-lead" = @("ui-designer", "ux-researcher", "design-systems-engineer", "animator")
    }

    $from = $brief.delegator
    $to = $brief.delegate
    if ($allowedChains.ContainsKey($from) -and $allowedChains[$from] -notcontains $to) {
        $errors += "Invalid delegation: " + $from + " cannot delegate to " + $to + ". Allowed: " + ($allowedChains[$from] -join ', ')
    }

    return $errors
}

# ============================================================
# Generate Task tool prompt
# ============================================================

function Generate-Prompt {
    $skillsBlock = ""
    foreach ($s in $brief.skills) {
        $skillsBlock += "- " + $s.name + " -- " + $s.reason + "`n"
    }

    $commandsBlock = ""
    if ($null -ne $brief.commands) {
        foreach ($c in $brief.commands) {
            $commandsBlock += "- " + $c.name + " -- " + $c.reason + "`n"
        }
    }

    $filesReadBlock = ""
    foreach ($f in $brief.files_read) {
        $filesReadBlock += "- " + $f + "`n"
    }

    $filesWriteBlock = ""
    foreach ($f in $brief.files_write) {
        $filesWriteBlock += "- " + $f + "`n"
    }

    $testCasesBlock = ""
    foreach ($t in $brief.test_cases) {
        $testCasesBlock += "- [ ] " + $t + "`n"
    }

    $acceptanceBlock = ""
    foreach ($a in $brief.acceptance_criteria) {
        $acceptanceBlock += "- [ ] " + $a + "`n"
    }

    $contextBlock = $brief.context.goal
    if ($null -ne $brief.context.constraints -and $brief.context.constraints.Count -gt 0) {
        $contextBlock += "`n`nConstraints:"
        foreach ($c in $brief.context.constraints) {
            $contextBlock += "`n- " + $c
        }
    }

    $dependsBlock = ""
    if ($null -ne $brief.depends_on -and $brief.depends_on.Count -gt 0) {
        $dependsBlock = "Depends on: " + ($brief.depends_on -join ', ')
    }

    $tddBlock = if ($brief.tdd_required -ne $false) {
        "`n### Test-Driven Development (MANDATORY)`n1. RED: Write tests FIRST that fail`n2. GREEN: Implement to make tests pass`n3. REFACTOR: Add comprehensive edge-case tests`n4. VERIFY: All tests pass before returning`n"
    } else { "" }

    $traceFile = ($taskDir -replace '\\', '/') + "/trace.jsonl"

    $priorOutputsBlock = ""
    if ($null -ne $context -and $null -ne $context.handoff -and $null -ne $context.handoff.prior_outputs) {
        $priorOutputsBlock = "`n### Prior Outputs"
        foreach ($key in $context.handoff.prior_outputs.PSObject.Properties) {
            $priorOutputsBlock += "`n- " + $key.Name + ": " + $key.Value
        }
    }

    $memoriesBlock = ""
    if ($null -ne $context -and $null -ne $context.handoff -and $null -ne $context.handoff.relevant_memories) {
        $memoriesBlock = "`n### Relevant Prior Patterns"
        foreach ($mem in $context.handoff.relevant_memories) {
            $memoriesBlock += "`n- " + $mem
        }
    }

    $prompt = @"
## Task: $($brief.task_id) -- $($brief.title)
Task Path: $($brief.task_path)
Risk: $($brief.risk)
$dependsBlock

### Context
$contextBlock
$priorOutputsBlock
$memoriesBlock

### Required Skills
Load these skills before starting:
$skillsBlock
### Required Commands
Read these commands before starting:
$commandsBlock
### Files to Read First
$filesReadBlock
### Files to Create/Modify
$filesWriteBlock
### Test Cases
$testCasesBlock
### Acceptance Criteria
$acceptanceBlock
$tddBlock
### Queue Trace File (MANDATORY)
You MUST write your execution trace to: $traceFile
Append one JSONL entry per significant action (skill_load, file_read, file_write, task_complete, etc.)
Each entry: {"ts":"<ISO>","phase":"execute","type":"<type>","name":"<name>","task_path":"$($brief.task_path)","detail":"<detail>"}

### Result Message Format
Return a JSON object with:
{
  "task_id": "$($brief.task_id)",
  "status": "completed|failed|blocked",
  "summary": "1-3 sentence summary",
  "files_written": [...],
  "test_results": {"total": N, "passed": N, "failed": N},
  "quality_gate_score": 0-10,
  "acceptance_criteria_passed": true|false,
  "confidence": 0-100,
  "trace_file": "$traceFile"
}
"@

    return $prompt
}

# ============================================================
# Show summary
# ============================================================

function Show-Summary {
    $cmdCount = 0
    if ($null -ne $brief.commands) { $cmdCount = $brief.commands.Count }
    $oqCount = 0
    if ($null -ne $brief.open_questions) { $oqCount = $brief.open_questions.Count }
    $tddText = "Yes"
    if ($brief.tdd_required -eq $false) { $tddText = "No" }

    Write-Output "+-- QUEUE BRIEF SUMMARY ----------------------------------------------+"
    Write-Output ("| Task: " + $brief.task_id + " -- " + $brief.title)
    Write-Output ("| Path: " + $brief.task_path)
    Write-Output ("| From: " + $brief.delegator + " -> To: " + $brief.delegate + " (" + $brief.division + ")")
    Write-Output ("| Risk: " + $brief.risk)
    Write-Output ("| Skills: " + $brief.skills.Count + " | Commands: " + $cmdCount)
    Write-Output ("| Files Read: " + $brief.files_read.Count + " | Files Write: " + $brief.files_write.Count)
    Write-Output ("| Test Cases: " + $brief.test_cases.Count + " | Acceptance: " + $brief.acceptance_criteria.Count)
    Write-Output ("| TDD Required: " + $tddText)
    Write-Output ("| QG Minimum: " + $brief.quality_gate_minimum)
    Write-Output ("| Open Questions: " + $oqCount)
    Write-Output "+----------------------------------------------------------------------+"
}

# ============================================================
# MAIN DISPATCH
# ============================================================

switch ($Action) {
    "generate-prompt" {
        $errors = Validate-Brief
        if ($errors.Count -gt 0) {
            Write-Error "Brief validation failed:"
            $errors | ForEach-Object { Write-Error ("  - " + $_) }
            exit 1
        }
        $prompt = Generate-Prompt
        if (![string]::IsNullOrEmpty($OutputFile)) {
            $parent = Split-Path $OutputFile -Parent
            if (!(Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            $prompt | Set-Content -LiteralPath $OutputFile -Encoding UTF8
            Write-Output ("Prompt written to: " + $OutputFile)
        } else {
            Write-Output $prompt
        }
    }
    "validate-brief" {
        $errors = Validate-Brief
        if ($errors.Count -eq 0) {
            Write-Output ("[PASS] Brief validation PASSED for " + $TaskId)
            exit 0
        } else {
            Write-Output ("[FAIL] Brief validation FAILED for " + $TaskId + ":")
            $errors | ForEach-Object { Write-Output ("  - " + $_) }
            exit 1
        }
    }
    "show-summary" {
        Show-Summary
    }
}
