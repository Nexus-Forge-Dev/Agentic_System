<#
.SYNOPSIS
    Plan Scaffold -- creates queue directories from a validated plan JSON
.DESCRIPTION
    Reads a prompt-plan-v1 JSON file and creates the queue directory structure
    for every task in the plan. Each task gets its own directory under
    .agents/queue/<prompt_id>/<task_id>/ with an initial status.json.
    Also updates queue/index.json with the prompt-grouped v2 schema.
    Does NOT write brief.json -- that comes later from /brief-generate.
.PARAMETER PlanFile
    Path to the plan JSON file (.agents/plans/<prompt_id>.plan.json)
.PARAMETER QueueDir
    Path to the queue directory (default: ".agents/queue")
.PARAMETER Force
    Overwrite existing queue directories if they exist
.EXAMPLE
    .agents/scripts/plan-scaffold.ps1 -PlanFile .agents/plans/prompt_001.plan.json
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$PlanFile,

    [Parameter(Mandatory = $false)]
    [string]$QueueDir = ".agents/queue",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# ============================================================
# HELPERS
# ============================================================

function Get-Timestamp {
    return (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}

function Read-JsonFile {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return $null }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-JsonFile {
    param([string]$Path, [object]$Data)
    $parent = Split-Path $Path -Parent
    if (!(Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $Data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-IndexPath {
    return Join-Path -Path $QueueDir "index.json"
}

function Read-Index {
    $idxPath = Get-IndexPath
    if (Test-Path -LiteralPath $idxPath) {
        $index = Read-JsonFile $idxPath
        # Auto-migrate from v1 to v2
        if ($null -ne $index -and $index.schema -eq "queue-index-v1") {
            Write-Host "Migrating queue index from v1 to v2..."
            $v2 = @{
                schema = "queue-index-v2"
                version = 2
                created = if ($index.created) { $index.created } else { Get-Timestamp }
                updated = Get-Timestamp
                prompts = @()
                archive = @()
            }
            if ($null -ne $index.archive) {
                $v2.archive = @($index.archive | ForEach-Object { $_ })
            }
            if ($null -ne $index.queues -and $index.queues.Count -gt 0) {
                $legacyTasks = @()
                foreach ($q in $index.queues) {
                    $legacyTasks += @{
                        task_id = $q.task_id
                        path = $q.path
                        status = $q.status
                    }
                }
                $v2.prompts += @{
                    prompt_id = "prompt_legacy"
                    goal = "Migrated from queue-index-v1"
                    created_at = $index.created
                    status = "archived"
                    tasks = $legacyTasks
                }
            }
            Write-JsonFile $idxPath $v2
            Write-Host "Migration complete."
            return $v2
        }
        return $index
    }
    return @{ schema = "queue-index-v2"; version = 2; created = Get-Timestamp; updated = Get-Timestamp; prompts = @(); archive = @() }
}

function Write-Index {
    param([object]$Index)
    $Index.updated = Get-Timestamp
    Write-JsonFile (Get-IndexPath) $Index
}

# ============================================================
# READ PLAN
# ============================================================

if (!(Test-Path -LiteralPath $PlanFile)) {
    Write-Error "Plan file not found: $PlanFile"
    exit 1
}

$plan = Read-JsonFile $PlanFile
if ($null -eq $plan) {
    Write-Error "Failed to parse plan JSON: $PlanFile"
    exit 1
}

$promptId = $plan.prompt_id
$tasks = $plan.tasks
$goal = $plan.goal

Write-Output "Scaffolding plan: $promptId -- $goal"
Write-Output ("Tasks: " + $tasks.Count)

# ============================================================
# CREATE PROMPT DIRECTORY
# ============================================================

$promptDir = Join-Path -Path $QueueDir -ChildPath $promptId

if (Test-Path -LiteralPath $promptDir) {
    if ($Force) {
        Write-Output ("Warning: Prompt directory already exists, removing: " + $promptDir)
        Remove-Item -LiteralPath $promptDir -Recurse -Force
    } else {
        Write-Error ("Prompt directory already exists: " + $promptDir + ". Use -Force to overwrite.")
        exit 1
    }
}

New-Item -ItemType Directory -Path $promptDir -Force | Out-Null

# ============================================================
# SCAFFOLD EACH TASK
# ============================================================

$createdCount = 0
foreach ($t in $tasks) {
    $tid = $t.id
    $taskDir = Join-Path -Path $promptDir -ChildPath $tid

    # Create task directory
    New-Item -ItemType Directory -Path $taskDir -Force | Out-Null

    # Write initial status.json
    $status = @{
        schema = "queue-status-v1"
        task_id = $tid
        status = "pending"
        created_at = Get-Timestamp
        updated_at = Get-Timestamp
        started_at = $null
        completed_at = $null
        actor = $t.agent
        confidence = $null
        retry_count = 0
        blocker = $null
        error = $null
    }
    Write-JsonFile (Join-Path -Path $taskDir "status.json") $status

    $createdCount++
    Write-Output ("  Created: " + $promptId + "/" + $tid + " (" + $t.agent + ", risk=" + $t.risk + ")")
}

# ============================================================
# UPDATE INDEX
# ============================================================

$index = Read-Index

# Build task references
$taskRefs = @()
foreach ($t in $tasks) {
    $taskRefs += @{
        task_id = $t.id
        path = ($promptId + "/" + $t.id) -replace '\\', '/'
        status = "pending"
    }
}

# Add prompt entry
$index.prompts += @{
    prompt_id = $promptId
    goal = $goal
    created_at = Get-Timestamp
    status = "in_progress"
    tasks = $taskRefs
}

Write-Index $index

# ============================================================
# SUMMARY
# ============================================================

Write-Output ""
Write-Output ("Scaffold complete: " + $createdCount + " tasks created under " + $promptId)
Write-Output ("Queue directory: .agents/queue/" + $promptId + "/")
Write-Output ("Next step: run /brief-generate for each task to write brief.json")
exit 0
