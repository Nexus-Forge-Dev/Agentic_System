<#
.SYNOPSIS
    Queue Manager -- filesystem-based delegation queue protocol
.DESCRIPTION
    Manages the lifecycle of delegation queue entries. Creates briefs, updates
    status, reads/writes outputs, and maintains the queue index.
    Runtime-agnostic: works with any agent harness (OpenCode, Cursor, etc.).
.PARAMETER Action
    The queue operation to perform: New-QueueItem, Set-QueueStatus,
    Get-QueueItem, Write-QueueOutput, Get-QueueOutput, Remove-QueueItem,
    Get-QueueIndex, Archive-QueueItem, Get-PendingItems
.PARAMETER TaskId
    The task identifier (e.g., "task_003")
.PARAMETER QueueDir
    Path to the queue directory (default: ".agents/queue")
.PARAMETER BriefPath
    Path to a brief JSON file to load (for New-QueueItem)
.PARAMETER Status
    New status value (for Set-QueueStatus)
.PARAMETER OutputPath
    Path to output JSON to write (for Write-QueueOutput)
.PARAMETER PromptId
    Prompt/plan ID for grouping (default: "prompt_adhoc")
.PARAMETER Force
    Skip safety checks (for admin overrides)
.EXAMPLE
    .agents/scripts/queue-manager.ps1 -Action New-QueueItem -BriefPath .agents/briefs/task_003.json -PromptId prompt_001
.EXAMPLE
    .agents/scripts/queue-manager.ps1 -Action Set-QueueStatus -TaskId task_003 -Status in_progress
.EXAMPLE
    .agents/scripts/queue-manager.ps1 -Action Get-QueueItem -TaskId task_003
.EXAMPLE
    .agents/scripts/queue-manager.ps1 -Action Get-PendingItems
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('New-QueueItem','Set-QueueStatus','Get-QueueItem','Write-QueueOutput','Get-QueueOutput','Remove-QueueItem','Get-QueueIndex','Archive-QueueItem','Get-PendingItems')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$TaskId,

    [Parameter(Mandatory = $false)]
    [string]$QueueDir = ".agents/queue",

    [Parameter(Mandatory = $false)]
    [string]$BriefPath,

    [Parameter(Mandatory = $false)]
    [string]$Status,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$PromptId = "prompt_adhoc",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

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
            # Copy archive entries as-is
            if ($null -ne $index.archive) {
                $v2.archive = @($index.archive | ForEach-Object { $_ })
            }
            # Move active queues to _legacy prompt
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
            Write-Host "Migration complete. Index now at v2 schema."
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

function Find-TaskInIndex {
    param([string]$Tid)
    $index = Read-Index
    foreach ($prompt in $index.prompts) {
        foreach ($t in $prompt.tasks) {
            if ($t.task_id -eq $Tid) {
                return @{
                    prompt_id = $prompt.prompt_id
                    task = $t
                }
            }
        }
    }
    # Check archive
    foreach ($entry in $index.archive) {
        if ($entry.task_id -eq $Tid) {
            return @{
                prompt_id = "archive"
                task = $entry
            }
        }
    }
    return $null
}

function Resolve-TaskPath {
    param([string]$Tid)
    $found = Find-TaskInIndex -Tid $Tid
    if ($null -eq $found) { return $null }
    $taskPath = Join-Path -Path $QueueDir -ChildPath $found.task.path
    return $taskPath
}

function Get-QueuePath {
    param([string]$Tid)
    # First try resolving through index
    $resolved = Resolve-TaskPath -Tid $Tid
    if ($null -ne $resolved) {
        return $resolved
    }
    # Fallback: use PromptId (needed before the task is in the index)
    return Join-Path -Path $QueueDir -ChildPath (Join-Path -Path $PromptId -ChildPath $Tid)
}

function Get-BriefPath {
    param([string]$Tid)
    return Join-Path -Path (Get-QueuePath $Tid) "brief.json"
}

function Get-StatusPath {
    param([string]$Tid)
    return Join-Path -Path (Get-QueuePath $Tid) "status.json"
}

function Get-OutputPath {
    param([string]$Tid)
    return Join-Path -Path (Get-QueuePath $Tid) "output.json"
}

function Get-TracePath {
    param([string]$Tid)
    return Join-Path -Path (Get-QueuePath $Tid) "trace.jsonl"
}

# ============================================================
# ACTIONS
# ============================================================

function New-QueueItem {
    param([string]$BriefFilePath)

    if ([string]::IsNullOrEmpty($BriefFilePath) -or !(Test-Path -LiteralPath $BriefFilePath)) {
        Write-Error "BriefPath is required and must point to a valid JSON file"
        exit 1
    }

    $brief = Read-JsonFile $BriefFilePath
    if ($null -eq $brief) {
        Write-Error "Failed to read brief from $BriefFilePath"
        exit 1
    }

    $tid = $brief.task_id
    if ([string]::IsNullOrEmpty($tid)) {
        Write-Error "brief.json must contain a task_id field"
        exit 1
    }

    # Use brief's prompt_id if available, else fallback to parameter
    $usePromptId = $PromptId
    if ($null -ne $brief.prompt_id -and ![string]::IsNullOrEmpty($brief.prompt_id)) {
        $usePromptId = $brief.prompt_id
    }

    $queuePath = Join-Path -Path $QueueDir -ChildPath (Join-Path -Path $usePromptId -ChildPath $tid)
    if (Test-Path -LiteralPath $queuePath) {
        if (!$Force) {
            Write-Error "Queue entry already exists for $tid at $queuePath. Use -Force to overwrite."
            exit 1
        }
        Remove-Item -LiteralPath $queuePath -Recurse -Force
    }

    # Create queue directory
    New-Item -ItemType Directory -Path $queuePath -Force | Out-Null

    # Write brief.json
    Write-JsonFile (Join-Path -Path $queuePath "brief.json") $brief

    # Write status.json
    $status = @{
        schema = "queue-status-v1"
        task_id = $tid
        status = "pending"
        created_at = Get-Timestamp
        updated_at = Get-Timestamp
        started_at = $null
        completed_at = $null
        actor = $brief.delegate
        confidence = $null
        retry_count = 0
        blocker = $null
        error = $null
    }
    Write-JsonFile (Join-Path -Path $queuePath "status.json") $status

    # Update index (v2 format)
    $index = Read-Index
    $relativePath = ($usePromptId + "/" + $tid) -replace '\\', '/'
    $taskRef = @{
        task_id = $tid
        path = $relativePath + "/"
        status = "pending"
    }

    # Find or create prompt entry
    $promptFound = $false
    for ($i = 0; $i -lt $index.prompts.Count; $i++) {
        if ($index.prompts[$i].prompt_id -eq $usePromptId) {
            $index.prompts[$i].tasks += $taskRef
            $promptFound = $true
            break
        }
    }
    if (!$promptFound) {
        $newPrompt = @{
            prompt_id = $usePromptId
            goal = if ($brief.context -and $brief.context.goal) { $brief.context.goal } else { $brief.title }
            created_at = Get-Timestamp
            status = "in_progress"
            tasks = @($taskRef)
        }
        $index.prompts += $newPrompt
    }
    Write-Index $index

    Write-Output ("QUEUE CREATED: " + $tid + " at " + ($queuePath -replace '\\', '/') + "/")
    Write-Output ("Delegate: " + $brief.delegate + " | Risk: " + $brief.risk + " | Prompt: " + $usePromptId)
    return $true
}

function Set-QueueStatus {
    param([string]$Tid, [string]$NewStatus)

    $validStatuses = @("pending", "in_progress", "completed", "failed", "blocked", "cancelled", "timed_out")
    if ($validStatuses -notcontains $NewStatus) {
        Write-Error ("Invalid status '" + $NewStatus + "'. Valid: " + ($validStatuses -join ', '))
        exit 1
    }

    $statusPath = Get-StatusPath $Tid
    if (!(Test-Path -LiteralPath $statusPath)) {
        Write-Error "No queue entry found for $Tid"
        exit 1
    }

    $status = Read-JsonFile $statusPath

    # Validate state transitions
    $validTransitions = @{
        "pending" = @("in_progress", "blocked", "cancelled")
        "in_progress" = @("completed", "failed", "blocked")
        "blocked" = @("in_progress", "cancelled")
        "completed" = @()
        "failed" = @()
        "cancelled" = @()
        "timed_out" = @()
    }

    $currentStatus = $status.status
    if (!$Force -and $validTransitions[$currentStatus] -notcontains $NewStatus) {
        Write-Error ("Invalid transition: " + $currentStatus + " -> " + $NewStatus + ". Allowed: " + ($validTransitions[$currentStatus] -join ', '))
        exit 1
    }

    $status.status = $NewStatus
    $status.updated_at = Get-Timestamp

    if ($NewStatus -eq "in_progress" -and $null -eq $status.started_at) {
        $status.started_at = Get-Timestamp
    }
    if (@("completed", "failed", "blocked", "cancelled", "timed_out") -contains $NewStatus) {
        $status.completed_at = Get-Timestamp
    }

    Write-JsonFile $statusPath $status

    # Update index
    $index = Read-Index
    for ($pi = 0; $pi -lt $index.prompts.Count; $pi++) {
        for ($ti = 0; $ti -lt $index.prompts[$pi].tasks.Count; $ti++) {
            if ($index.prompts[$pi].tasks[$ti].task_id -eq $Tid) {
                $index.prompts[$pi].tasks[$ti].status = $NewStatus
                # Update prompt-level status
                $promptStatuses = @($index.prompts[$pi].tasks | ForEach-Object { $_.status })
                if ($promptStatuses -contains "in_progress" -or $promptStatuses -contains "pending") {
                    $index.prompts[$pi].status = "in_progress"
                } elseif ($promptStatuses -contains "blocked" -or $promptStatuses -contains "failed") {
                    $index.prompts[$pi].status = "blocked"
                } else {
                    $allTerminal = $true
                    foreach ($ps in $promptStatuses) {
                        if ($ps -ne "completed" -and $ps -ne "cancelled") { $allTerminal = $false }
                    }
                    if ($allTerminal) { $index.prompts[$pi].status = "completed" }
                }
                break
            }
        }
    }
    Write-Index $index

    Write-Output ("STATUS UPDATED: " + $Tid + " -> " + $NewStatus)
    return $true
}

function Get-QueueItem {
    param([string]$Tid)

    $queuePath = Get-QueuePath $Tid
    if (!(Test-Path -LiteralPath $queuePath)) {
        Write-Error "No queue entry found for $Tid"
        exit 1
    }

    $result = @{
        task_id = $Tid
        path = ($queuePath -replace '\\', '/') + "/"
    }

    $briefPath = Join-Path -Path $queuePath "brief.json"
    if (Test-Path -LiteralPath $briefPath) {
        $result.brief = Read-JsonFile $briefPath
    }

    $statusPath = Join-Path -Path $queuePath "status.json"
    if (Test-Path -LiteralPath $statusPath) {
        $result.status = Read-JsonFile $statusPath
    }

    $outputPath = Join-Path -Path $queuePath "output.json"
    if (Test-Path -LiteralPath $outputPath) {
        $result.output = Read-JsonFile $outputPath
    }

    $tracePath = Join-Path -Path $queuePath "trace.jsonl"
    if (Test-Path -LiteralPath $tracePath) {
        $result.trace_count = (Get-Content -LiteralPath $tracePath | Where-Object { $_.Trim() -ne "" }).Count
    }

    return $result | ConvertTo-Json -Depth 10
}

function Write-QueueOutput {
    param([string]$Tid, [string]$OutPath)

    if ([string]::IsNullOrEmpty($OutPath) -or !(Test-Path -LiteralPath $OutPath)) {
        Write-Error "OutputPath is required and must point to a valid JSON file"
        exit 1
    }

    $output = Read-JsonFile $OutPath
    if ($null -eq $output) {
        Write-Error "Failed to read output from $OutPath"
        exit 1
    }

    $queuePath = Get-QueuePath $Tid
    if (!(Test-Path -LiteralPath $queuePath)) {
        Write-Error "No queue entry found for $Tid"
        exit 1
    }

    # Write output.json
    Write-JsonFile (Join-Path -Path $queuePath "output.json") $output

    Write-Output ("OUTPUT WRITTEN: " + $Tid)
    return $true
}

function Get-QueueOutput {
    param([string]$Tid)

    $queuePath = Get-QueuePath $Tid
    $outputPath = Join-Path -Path $queuePath "output.json"
    if (!(Test-Path -LiteralPath $outputPath)) {
        Write-Error "No output found for $Tid"
        exit 1
    }

    return Get-Content -LiteralPath $outputPath -Raw
}

function Remove-QueueItem {
    param([string]$Tid)

    $queuePath = Get-QueuePath $Tid
    if (!(Test-Path -LiteralPath $queuePath)) {
        Write-Error "No queue entry found for $Tid"
        exit 1
    }

    if (!$Force) {
        Write-Warning ("This will permanently delete the queue entry for " + $Tid + ". Use -Force to confirm.")
        exit 1
    }

    Remove-Item -LiteralPath $queuePath -Recurse -Force

    # Update index
    $index = Read-Index
    for ($pi = 0; $pi -lt $index.prompts.Count; $pi++) {
        $index.prompts[$pi].tasks = @($index.prompts[$pi].tasks | Where-Object { $_.task_id -ne $Tid })
    }
    # Remove empty prompts
    $index.prompts = @($index.prompts | Where-Object { $_.tasks.Count -gt 0 })
    Write-Index $index

    Write-Output ("QUEUE REMOVED: " + $Tid)
    return $true
}

function Archive-QueueItem {
    param([string]$Tid)

    $queuePath = Get-QueuePath $Tid
    if (!(Test-Path -LiteralPath $queuePath)) {
        Write-Error "No queue entry found for $Tid"
        exit 1
    }

    $statusPath = Join-Path -Path $queuePath "status.json"
    if (Test-Path -LiteralPath $statusPath) {
        $status = Read-JsonFile $statusPath
        $terminalStates = @("completed", "failed", "blocked", "cancelled", "timed_out")
        if (!$Force -and ($terminalStates -notcontains $status.status)) {
            Write-Error ("Cannot archive task in non-terminal status: " + $status.status + ". Use -Force to override.")
            exit 1
        }
    }

    $archivePath = Join-Path -Path $QueueDir "archive"
    $destPath = Join-Path -Path $archivePath $Tid

    New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
    if (Test-Path -LiteralPath $destPath) {
        Remove-Item -LiteralPath $destPath -Recurse -Force
    }

    Move-Item -LiteralPath $queuePath -Destination $destPath

    # Update index
    $index = Read-Index
    $entry = $null
    for ($pi = 0; $pi -lt $index.prompts.Count; $pi++) {
        $remaining = @()
        foreach ($t in $index.prompts[$pi].tasks) {
            if ($t.task_id -eq $Tid) {
                $entry = @{
                    task_id = $t.task_id
                    title = $t.task_id
                    status = "completed"
                    path = ($destPath -replace '\\', '/') + "/"
                }
            } else {
                $remaining += $t
            }
        }
        $index.prompts[$pi].tasks = $remaining
    }
    # Remove empty prompts
    $index.prompts = @($index.prompts | Where-Object { $_.tasks.Count -gt 0 })
    if ($entry) {
        $entry | Add-Member -NotePropertyName "archived_at" -NotePropertyValue (Get-Timestamp)
        $index.archive += $entry
    }
    Write-Index $index

    Write-Output ("QUEUE ARCHIVED: " + $Tid + " -> archive/" + $Tid)
    return $true
}

function Get-QueueIndex {
    return Read-Index | ConvertTo-Json -Depth 10
}

function Get-PendingItems {
    $index = Read-Index
    $pending = @()
    foreach ($prompt in $index.prompts) {
        foreach ($t in $prompt.tasks) {
            if ($t.status -eq "pending") {
                $pending += @{
                    task_id = $t.task_id
                    prompt_id = $prompt.prompt_id
                    path = $t.path
                    status = $t.status
                }
            }
        }
    }
    if ($pending.Count -eq 0) {
        Write-Output "No pending queue items."
        return
    }
    return $pending | ConvertTo-Json -Depth 10
}

# ============================================================
# MAIN DISPATCH
# ============================================================

switch ($Action) {
    "New-QueueItem" {
        New-QueueItem -BriefFilePath $BriefPath
    }
    "Set-QueueStatus" {
        if ([string]::IsNullOrEmpty($TaskId) -or [string]::IsNullOrEmpty($Status)) {
            Write-Error "Set-QueueStatus requires -TaskId and -Status parameters"
            exit 1
        }
        Set-QueueStatus -Tid $TaskId -NewStatus $Status
    }
    "Get-QueueItem" {
        if ([string]::IsNullOrEmpty($TaskId)) {
            Write-Error "Get-QueueItem requires -TaskId parameter"
            exit 1
        }
        Get-QueueItem -Tid $TaskId
    }
    "Write-QueueOutput" {
        if ([string]::IsNullOrEmpty($TaskId) -or [string]::IsNullOrEmpty($OutputPath)) {
            Write-Error "Write-QueueOutput requires -TaskId and -OutputPath parameters"
            exit 1
        }
        Write-QueueOutput -Tid $TaskId -OutPath $OutputPath
    }
    "Get-QueueOutput" {
        if ([string]::IsNullOrEmpty($TaskId)) {
            Write-Error "Get-QueueOutput requires -TaskId parameter"
            exit 1
        }
        Get-QueueOutput -Tid $TaskId
    }
    "Remove-QueueItem" {
        if ([string]::IsNullOrEmpty($TaskId)) {
            Write-Error "Remove-QueueItem requires -TaskId parameter"
            exit 1
        }
        Remove-QueueItem -Tid $TaskId
    }
    "Archive-QueueItem" {
        if ([string]::IsNullOrEmpty($TaskId)) {
            Write-Error "Archive-QueueItem requires -TaskId parameter"
            exit 1
        }
        Archive-QueueItem -Tid $TaskId
    }
    "Get-QueueIndex" {
        Get-QueueIndex
    }
    "Get-PendingItems" {
        Get-PendingItems
    }
}
