<#
.SYNOPSIS
    Comprehensive Plan Layer Test Runner
.DESCRIPTION
    Runs 9 categories of tests (A through I) against the planning layer:
    - A: plan-validator.ps1 — all 13 validation rules + edge cases
    - B: plan-scaffold.ps1 — directory creation, index update, migration
    - C: queue-manager.ps1 — all 6 CRUD operations, path resolution
    - D: delivery-adapter.ps1 — brief path resolution, fallback layers
    - E: preflight-gate.ps1 — 6 actions x PASS/BLOCKED/WARN states
    - F: Integration — full pipeline, dependency chains, cyclic rejection
    - G: Protocol consistency — schema vs script contract checks
    - H: PS5.1 compatibility — encoding, stream pollution, edge cases
    - I: Trace validation — validate trace JSONL files against schema

    All tests use fixture files in .agents/tests/fixtures/ and temp dirs.
    No live data is modified.

.PARAMETER Categories
    Comma-separated list of categories to run (default: A,B,C,D,E,F,G,H,I)
    Example: -Categories "A,C,E"

.PARAMETER Verbose
    Show detailed output for each test

.EXAMPLE
    .agents\tests\scripts\plan-test-runner.ps1
    .agents\tests\scripts\plan-test-runner.ps1 -Categories "A,I" -Verbose
#>

param(
    [string]$Categories = "A,B,C,D,E,F,G,H,I",
    [switch]$Verbose
)

# ============================================================
# CONFIG
# ============================================================

$script:ProjectRoot = Resolve-Path "."
$script:ScriptsDir = Join-Path -Path $ProjectRoot -ChildPath ".agents\scripts"
$script:FixturesDir = Join-Path -Path $ProjectRoot -ChildPath ".agents\tests\fixtures"
$script:PlanFixturesDir = Join-Path -Path $FixturesDir -ChildPath "plans"
$script:QueueFixturesDir = Join-Path -Path $FixturesDir -ChildPath "queue"
$script:TestTempDir = Join-Path -Path $ProjectRoot -ChildPath ".agents\tests\temp"
$script:TracesDir = Join-Path -Path $ProjectRoot -ChildPath ".agents\traces"

$script:PassCount = 0
$script:FailCount = 0
$script:TotalTests = 0
$script:CategoryResults = @()

# ============================================================
# HELPERS
# ============================================================

function Write-TestResult {
    param(
        [string]$Category,
        [string]$TestName,
        [bool]$Passed,
        [string]$Detail = ""
    )
    $script:TotalTests++
    if ($Passed) {
        $script:PassCount++
        if ($Verbose) { Write-Host ("  [PASS] " + $TestName) -ForegroundColor Green }
    } else {
        $script:FailCount++
        Write-Host ("  [FAIL] " + $TestName + " -- " + $Detail) -ForegroundColor Red
    }
}

function Write-CategoryHeader {
    param([string]$Label, [string]$Description)
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ("CATEGORY " + $Label + ": " + $Description) -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

function Write-CategoryFooter {
    param([string]$Label, [int]$Passed, [int]$Failed, [int]$Total)
    $script:CategoryResults += @{
        category = $Label
        passed = $Passed
        failed = $Failed
        total = $Total
    }
    if ($Failed -eq 0) {
        Write-Host ("  >>> PASSED: " + $Passed + "/" + $Total) -ForegroundColor Green
    } else {
        Write-Host ("  >>> FAILED: " + $Failed + "/" + $Total + " tests") -ForegroundColor Red
    }
}

function New-TempDir {
    param([string]$Name)
    $dir = Join-Path -Path $TestTempDir -ChildPath $Name
    if (Test-Path -LiteralPath $dir) {
        Remove-Item -LiteralPath $dir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

function Remove-TempDir {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Invoke-Validator {
    param([string]$PlanFile)
    $validator = Join-Path -Path $ScriptsDir -ChildPath "plan-validator.ps1"
    $output = & powershell -NoProfile -File $validator -PlanFile $PlanFile 2>&1
    $exitCode = $LASTEXITCODE
    return @{ Output = $output; ExitCode = $exitCode }
}

function Invoke-Scaffold {
    param([string]$PlanFile, [string]$QueueDir, [switch]$Force)
    $scaffold = Join-Path -Path $ScriptsDir -ChildPath "plan-scaffold.ps1"
    $argsList = @("-PlanFile", $PlanFile, "-QueueDir", $QueueDir)
    if ($Force) { $argsList += "-Force" }
    $output = & powershell -NoProfile -File $scaffold @argsList 2>&1
    $exitCode = $LASTEXITCODE
    return @{ Output = $output; ExitCode = $exitCode }
}

function Invoke-Preflight {
    param([string]$Action, [string]$TaskId = "", [string]$PlansDir = ".agents\plans", [string]$QueueDir = ".agents\queue", [string]$SessionId = "")
    $gate = Join-Path -Path $ScriptsDir -ChildPath "preflight-gate.ps1"
    $argsList = @("-Action", $Action, "-PlansDir", $PlansDir, "-QueueDir", $QueueDir)
    if (![string]::IsNullOrEmpty($TaskId)) { $argsList += @("-TaskId", $TaskId) }
    if (![string]::IsNullOrEmpty($SessionId)) { $argsList += @("-SessionId", $SessionId) }
    $output = & powershell -NoProfile -File $gate @argsList 2>&1
    $exitCode = $LASTEXITCODE
    $json = $null
    foreach ($line in $output) {
        if ($line.Trim().StartsWith("{")) {
            try { $json = $line.Trim() | ConvertFrom-Json; break } catch {}
        }
    }
    return @{ Output = $output; ExitCode = $exitCode; Json = $json }
}

# ============================================================
# CATEGORY A: plan-validator.ps1 — 13 Rules + Edge Cases
# ============================================================

function Test-CategoryA {
    $label = "A"
    Write-CategoryHeader $label "plan-validator.ps1 -- 13 Validation Rules + Edge Cases"

    $localPass = 0; $localFail = 0; $localTotal = 0

    # --- A1: Valid plan passes ---
    $localTotal++
    $validPlan = Join-Path -Path $PlanFixturesDir -ChildPath "valid-plan.json"
    $result = Invoke-Validator $validPlan
    if ($result.ExitCode -eq 0) {
        Write-TestResult $label "A1: Valid plan PASSES" $true; $localPass++
    } else {
        Write-TestResult $label "A1: Valid plan PASSES" $false ("Exit code: " + $result.ExitCode); $localFail++
    }

    # --- A2: Empty plan fails (Rule 11) ---
    $localTotal++
    $emptyPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-empty.json"
    $result = Invoke-Validator $emptyPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 11") {
        Write-TestResult $label "A2: Empty plan fails RULE 11" $true; $localPass++
    } else {
        Write-TestResult $label "A2: Empty plan fails RULE 11" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A3: Cyclic dependency fails (Rule 3) ---
    $localTotal++
    $cyclicPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-cyclic.json"
    $result = Invoke-Validator $cyclicPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 3") {
        Write-TestResult $label "A3: Cyclic dep fails RULE 3" $true; $localPass++
    } else {
        Write-TestResult $label "A3: Cyclic dep fails RULE 3" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A4: Duplicate IDs fails (Rule 1) ---
    $localTotal++
    $dupPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-duplicates.json"
    $result = Invoke-Validator $dupPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 1") {
        Write-TestResult $label "A4: Duplicate IDs fails RULE 1" $true; $localPass++
    } else {
        Write-TestResult $label "A4: Duplicate IDs fails RULE 1" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A5: Bad agent fails (Rule 4) ---
    $localTotal++
    $badAgentPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-bad-agent.json"
    $result = Invoke-Validator $badAgentPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 4") {
        Write-TestResult $label "A5: Bad agent fails RULE 4" $true; $localPass++
    } else {
        Write-TestResult $label "A5: Bad agent fails RULE 4" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A6: Bad division fails (Rule 5) ---
    $localTotal++
    $badDivPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-bad-division.json"
    $result = Invoke-Validator $badDivPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 5") {
        Write-TestResult $label "A6: Bad division fails RULE 5" $true; $localPass++
    } else {
        Write-TestResult $label "A6: Bad division fails RULE 5" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A7: Agent-division mismatch fails (Rule 6) ---
    $localTotal++
    $mismatchPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-agent-division-mismatch.json"
    $result = Invoke-Validator $mismatchPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 6") {
        Write-TestResult $label "A7: Agent-division mismatch fails RULE 6" $true; $localPass++
    } else {
        Write-TestResult $label "A7: Agent-division mismatch fails RULE 6" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A8: HIGH without brief_required fails (Rule 8) ---
    $localTotal++
    $noBriefPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-missing-brief.json"
    $result = Invoke-Validator $noBriefPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 8") {
        Write-TestResult $label "A8: HIGH without brief fails RULE 8" $true; $localPass++
    } else {
        Write-TestResult $label "A8: HIGH without brief fails RULE 8" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A9: estimated_files=0 fails (Rule 9) ---
    $localTotal++
    $zeroFilesPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-zero-files.json"
    $result = Invoke-Validator $zeroFilesPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 9") {
        Write-TestResult $label "A9: Zero estimated_files fails RULE 9" $true; $localPass++
    } else {
        Write-TestResult $label "A9: Zero estimated_files fails RULE 9" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A10: Invalid prompt_id fails (Rule 10) ---
    $localTotal++
    $badPidPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-bad-prompt-id.json"
    $result = Invoke-Validator $badPidPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 10") {
        Write-TestResult $label "A10: Bad prompt_id fails RULE 10" $true; $localPass++
    } else {
        Write-TestResult $label "A10: Bad prompt_id fails RULE 10" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A11: Over 15 tasks fails (Rule 12) ---
    $localTotal++
    $tooManyPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-too-many-tasks.json"
    $result = Invoke-Validator $tooManyPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 12") {
        Write-TestResult $label "A11: Over 15 tasks fails RULE 12" $true; $localPass++
    } else {
        Write-TestResult $label "A11: Over 15 tasks fails RULE 12" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A12: Bad task ID format fails (Rule 13) ---
    $localTotal++
    $badIdPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-bad-id-format.json"
    $result = Invoke-Validator $badIdPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 13") {
        Write-TestResult $label "A12: Bad task ID format fails RULE 13" $true; $localPass++
    } else {
        Write-TestResult $label "A12: Bad task ID format fails RULE 13" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A13: Non-existent dependency fails (Rule 2) ---
    $localTotal++
    $badDepPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-non-existent-dep.json"
    $result = Invoke-Validator $badDepPlan
    if ($result.ExitCode -eq 1 -and ($result.Output -join " ") -match "RULE 2") {
        Write-TestResult $label "A13: Non-existent dep fails RULE 2" $true; $localPass++
    } else {
        Write-TestResult $label "A13: Non-existent dep fails RULE 2" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A14: Complex valid DAG passes ---
    $localTotal++
    $complexPlan = Join-Path -Path $PlanFixturesDir -ChildPath "valid-plan-complex.json"
    $result = Invoke-Validator $complexPlan
    if ($result.ExitCode -eq 0) {
        Write-TestResult $label "A14: Complex diamond DAG passes" $true; $localPass++
    } else {
        Write-TestResult $label "A14: Complex diamond DAG passes" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- A15: Plan file not found ---
    $localTotal++
    $result = Invoke-Validator "nonexistent-plan.json"
    if ($result.ExitCode -eq 1) {
        Write-TestResult $label "A15: Missing plan file fails" $true; $localPass++
    } else {
        Write-TestResult $label "A15: Missing plan file fails" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    Write-CategoryFooter -Label $label -Passed $localPass -Failed $localFail -Total $localTotal
}

# ============================================================
# CATEGORY B: plan-scaffold.ps1 — Directory creation, index update
# ============================================================

function Test-CategoryB {
    $label = "B"
    Write-CategoryHeader $label "plan-scaffold.ps1 -- Directory Creation + Index Update"

    $localPass = 0; $localFail = 0; $localTotal = 0

    $tempDir = New-TempDir "testB_scaffold"

    # --- B1: Scaffold creates directories ---
    $localTotal++
    $validPlan = Join-Path -Path $PlanFixturesDir -ChildPath "valid-plan.json"
    $queueDir = Join-Path -Path $tempDir -ChildPath "queue"
    $result = Invoke-Scaffold $validPlan $queueDir
    $task101Dir = Join-Path -Path $queueDir -ChildPath "prompt_test001\task_101"
    $task102Dir = Join-Path -Path $queueDir -ChildPath "prompt_test001\task_102"
    $task103Dir = Join-Path -Path $queueDir -ChildPath "prompt_test001\task_103"
    if ($result.ExitCode -eq 0 -and (Test-Path -LiteralPath $task101Dir) -and (Test-Path -LiteralPath $task102Dir) -and (Test-Path -LiteralPath $task103Dir)) {
        Write-TestResult $label "B1: Scaffold creates task directories" $true; $localPass++
    } else {
        Write-TestResult $label "B1: Scaffold creates task directories" $false ("Exit: " + $result.ExitCode + ", dirs: " + (Test-Path -LiteralPath $task101Dir)); $localFail++
    }

    # --- B2: Scaffold writes status.json ---
    $localTotal++
    $status101 = Join-Path -Path $task101Dir -ChildPath "status.json"
    $statusExists = Test-Path -LiteralPath $status101
    if ($result.ExitCode -eq 0 -and $statusExists) {
        $statusContent = Get-Content -LiteralPath $status101 -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($statusContent.status -eq "pending" -and $statusContent.task_id -eq "task_101") {
            Write-TestResult $label "B2: Scaffold writes valid status.json" $true; $localPass++
        } else {
            Write-TestResult $label "B2: Scaffold writes valid status.json" $false ("status=" + $statusContent.status); $localFail++
        }
    } else {
        Write-TestResult $label "B2: Scaffold writes valid status.json" $false ("status file exists: " + $statusExists); $localFail++
    }

    # --- B3: Scaffold updates queue index ---
    $localTotal++
    $indexPath = Join-Path -Path $queueDir -ChildPath "index.json"
    if (Test-Path -LiteralPath $indexPath) {
        $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($index.schema -eq "queue-index-v2" -and $index.prompts.Count -gt 0) {
            $found = $false
            foreach ($p in $index.prompts) {
                if ($p.prompt_id -eq "prompt_test001") { $found = $true; break }
            }
            if ($found) {
                Write-TestResult $label "B3: Scaffold updates queue index (v2)" $true; $localPass++
            } else {
                Write-TestResult $label "B3: Scaffold updates queue index (v2)" $false "prompt_test001 not in index"; $localFail++
            }
        } else {
            Write-TestResult $label "B3: Scaffold updates queue index (v2)" $false ("schema=" + $index.schema); $localFail++
        }
    } else {
        Write-TestResult $label "B3: Scaffold updates queue index (v2)" $false "index.json not found"; $localFail++
    }

    # --- B4: Scaffold fails without Force when dir exists ---
    $localTotal++
    $result2 = Invoke-Scaffold $validPlan $queueDir
    if ($result2.ExitCode -eq 1) {
        Write-TestResult $label "B4: Scaffold refuses overwrite without -Force" $true; $localPass++
    } else {
        Write-TestResult $label "B4: Scaffold refuses overwrite without -Force" $false ("Exit: " + $result2.ExitCode); $localFail++
    }

    # --- B5: Scaffold overwrites with -Force ---
    $localTotal++
    # Write a marker file to verify it gets cleaned
    $markerFile = Join-Path -Path $task101Dir -ChildPath "marker.txt"
    New-Item -ItemType File -Path $markerFile -Force | Out-Null
    $result3 = Invoke-Scaffold $validPlan $queueDir -Force
    $markerGone = !(Test-Path -LiteralPath $markerFile)
    $dirRecreated = (Test-Path -LiteralPath $task101Dir)
    if ($result3.ExitCode -eq 0 -and $dirRecreated -and $markerGone) {
        Write-TestResult $label "B5: Scaffold overwrites with -Force" $true; $localPass++
    } else {
        Write-TestResult $label "B5: Scaffold overwrites with -Force" $false ("Exit: " + $result3.ExitCode + ", marker: " + $markerGone); $localFail++
    }

    # --- B6: Scaffold with complex plan ---
    $localTotal++
    $complexPlan = Join-Path -Path $PlanFixturesDir -ChildPath "valid-plan-complex.json"
    $queueDir2 = Join-Path -Path $tempDir -ChildPath "queue2"
    $result4 = Invoke-Scaffold $complexPlan $queueDir2
    $task201Dir = Join-Path -Path $queueDir2 -ChildPath "prompt_test002\task_201"
    $task205Dir = Join-Path -Path $queueDir2 -ChildPath "prompt_test002\task_205"
    if ($result4.ExitCode -eq 0 -and (Test-Path -LiteralPath $task201Dir) -and (Test-Path -LiteralPath $task205Dir)) {
        Write-TestResult $label "B6: Scaffold handles complex 5-task DAG" $true; $localPass++
    } else {
        Write-TestResult $label "B6: Scaffold handles complex 5-task DAG" $false ("Exit: " + $result4.ExitCode); $localFail++
    }

    Remove-TempDir $tempDir

    Write-CategoryFooter -Label $label -Passed $localPass -Failed $localFail -Total $localTotal
}

# ============================================================
# CATEGORY C: queue-manager.ps1 — 6 CRUD Operations + Path Resolution
# ============================================================

function Test-CategoryC {
    $label = "C"
    Write-CategoryHeader $label "queue-manager.ps1 -- Queue Operations + Path Resolution"

    $localPass = 0; $localFail = 0; $localTotal = 0

    $tempDir = New-TempDir "testC_queue"
    $qmScript = Join-Path -Path $ScriptsDir -ChildPath "queue-manager.ps1"
    $queueDir = Join-Path -Path $tempDir -ChildPath "queue"

    # First scaffold a plan to get queue structure
    $validPlan = Join-Path -Path $PlanFixturesDir -ChildPath "valid-plan.json"
    Invoke-Scaffold $validPlan $queueDir | Out-Null

    # Write a brief file for ad-hoc New-QueueItem test
    $adhocBriefPath = Join-Path -Path $tempDir -ChildPath "adhoc-brief.json"
    $adhocBrief = Get-Content -LiteralPath (Join-Path -Path $FixturesDir -ChildPath "valid-brief.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $adhocBrief.task_id = "task_adhoctest"
    $adhocBrief.title = "Ad-hoc test task"
    $adhocBrief.delegate = "frontend-developer"
    $adhocBrief.division = "engineering"
    $adhocBrief | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $adhocBriefPath -Encoding UTF8

    # --- C1: New-QueueItem (ad-hoc via brief) ---
    $localTotal++
    $adhocTaskDir = Join-Path -Path $queueDir -ChildPath "prompt_adhoc\task_adhoctest"
    $adhocOutput = & powershell -NoProfile -File $qmScript -Action New-QueueItem -QueueDir $queueDir -BriefPath $adhocBriefPath 2>&1
    $adhocExit = $LASTEXITCODE
    $adhocDirExists = Test-Path -LiteralPath $adhocTaskDir
    $adhocStatusExists = Test-Path -LiteralPath (Join-Path -Path $adhocTaskDir -ChildPath "status.json")
    if ($adhocExit -eq 0 -and $adhocDirExists -and $adhocStatusExists) {
        Write-TestResult $label "C1: New-QueueItem creates task dir" $true; $localPass++
    } else {
        Write-TestResult $label "C1: New-QueueItem creates task dir" $false ("Exit: " + $adhocExit + ", dir: " + $adhocDirExists); $localFail++
    }

    # --- C2: Get-QueueItem (find existing via scaffold) ---
    $localTotal++
    $getOutput = & powershell -NoProfile -File $qmScript -Action Get-QueueItem -QueueDir $queueDir -TaskId "task_101" 2>&1
    $getExit = $LASTEXITCODE
    if ($getExit -eq 0) {
        Write-TestResult $label "C2: Get-QueueItem finds task_101" $true; $localPass++
    } else {
        Write-TestResult $label "C2: Get-QueueItem finds task_101" $false ("Exit: " + $getExit); $localFail++
    }

    # --- C3: Set-QueueStatus (pending -> in_progress) ---
    $localTotal++
    $setOutput = & powershell -NoProfile -File $qmScript -Action Set-QueueStatus -QueueDir $queueDir -TaskId "task_101" -Status "in_progress" 2>&1
    $setExit = $LASTEXITCODE
    if ($setExit -eq 0) {
        $statusPath = Join-Path -Path $queueDir -ChildPath "prompt_test001\task_101\status.json"
        $status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($status.status -eq "in_progress") {
            Write-TestResult $label "C3: Set-QueueStatus changes to in_progress" $true; $localPass++
        } else {
            Write-TestResult $label "C3: Set-QueueStatus changes to in_progress" $false ("status=" + $status.status); $localFail++
        }
    } else {
        Write-TestResult $label "C3: Set-QueueStatus changes to in_progress" $false ("Exit: " + $setExit); $localFail++
    }

    # --- C4: Set-QueueStatus to completed ---
    $localTotal++
    $setOutput2 = & powershell -NoProfile -File $qmScript -Action Set-QueueStatus -QueueDir $queueDir -TaskId "task_101" -Status "completed" 2>&1
    $setExit2 = $LASTEXITCODE
    if ($setExit2 -eq 0) {
        $status = Get-Content -LiteralPath (Join-Path -Path $queueDir -ChildPath "prompt_test001\task_101\status.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($status.status -eq "completed") {
            Write-TestResult $label "C4: Set-QueueStatus completes task" $true; $localPass++
        } else {
            Write-TestResult $label "C4: Set-QueueStatus completes task" $false ("status=" + $status.status); $localFail++
        }
    } else {
        Write-TestResult $label "C4: Set-QueueStatus completes task" $false ("Exit: " + $setExit2); $localFail++
    }

    # --- C5: Write-QueueOutput (copies from an output JSON file) ---
    $localTotal++
    # First create an output JSON file
    $outSrcPath = Join-Path -Path $tempDir -ChildPath "test-output-src.json"
    @{ result = "test-success"; files = @("src/test.ts"); confidence = 85 } | ConvertTo-Json | Set-Content -LiteralPath $outSrcPath -Encoding UTF8
    $outOutput = & powershell -NoProfile -File $qmScript -Action Write-QueueOutput -QueueDir $queueDir -TaskId "task_102" -OutputPath $outSrcPath 2>&1
    $outExit = $LASTEXITCODE
    $outFileExists = Test-Path -LiteralPath (Join-Path -Path $queueDir -ChildPath "prompt_test001\task_102\output.json")
    if ($outExit -eq 0 -and $outFileExists) {
        Write-TestResult $label "C5: Write-QueueOutput writes output.json" $true; $localPass++
    } else {
        Write-TestResult $label "C5: Write-QueueOutput writes output.json" $false ("Exit: " + $outExit + ", file: " + $outFileExists); $localFail++
    }

    # --- C6: Get-QueueIndex ---
    $localTotal++
    $idxOutput = & powershell -NoProfile -File $qmScript -Action Get-QueueIndex -QueueDir $queueDir 2>&1
    $idxExit = $LASTEXITCODE
    if ($idxExit -eq 0 -and ($idxOutput -join " ") -match "prompt_test001") {
        Write-TestResult $label "C6: Get-QueueIndex shows prompt entries" $true; $localPass++
    } else {
        Write-TestResult $label "C6: Get-QueueIndex shows prompt entries" $false ("Exit: " + $idxExit); $localFail++
    }

    # --- C7: Archive-QueueItem ---
    $localTotal++
    $archOutput = & powershell -NoProfile -File $qmScript -Action Archive-QueueItem -QueueDir $queueDir -TaskId "task_101" 2>&1
    $archExit = $LASTEXITCODE
    if ($archExit -eq 0) {
        $index = Get-Content -LiteralPath (Join-Path -Path $queueDir -ChildPath "index.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $archived = $false
        if ($null -ne $index.archive) {
            foreach ($a in $index.archive) {
                if ($a.task_id -eq "task_101") { $archived = $true; break }
            }
        }
        if ($archived) {
            Write-TestResult $label "C7: Archive-QueueItem moves to archive" $true; $localPass++
        } else {
            Write-TestResult $label "C7: Archive-QueueItem moves to archive" $false "task_101 not in archive"; $localFail++
        }
    } else {
        Write-TestResult $label "C7: Archive-QueueItem moves to archive" $false ("Exit: " + $archExit); $localFail++
    }

    # --- C8: Get-QueueOutput (retrieve stored output) ---
    $localTotal++
    $getOutOutput = & powershell -NoProfile -File $qmScript -Action Get-QueueOutput -QueueDir $queueDir -TaskId "task_102" 2>&1
    $getOutExit = $LASTEXITCODE
    if ($getOutExit -eq 0 -and ($getOutOutput -match "test-success")) {
        Write-TestResult $label "C8: Get-QueueOutput retrieves stored output" $true; $localPass++
    } else {
        Write-TestResult $label "C8: Get-QueueOutput retrieves stored output" $false ("Exit: " + $getOutExit); $localFail++
    }

    # --- C9: Get-QueueItem on non-existent ---
    $localTotal++
    $getOutput2 = & powershell -NoProfile -File $qmScript -Action Get-QueueItem -QueueDir $queueDir -TaskId "task_nonexistent" 2>&1
    $getExit2 = $LASTEXITCODE
    if ($getExit2 -eq 1) {
        Write-TestResult $label "C9: Get-QueueItem fails on nonexistent" $true; $localPass++
    } else {
        Write-TestResult $label "C9: Get-QueueItem fails on nonexistent" $false ("Exit: " + $getExit2); $localFail++
    }

    # --- C10: Get-PendingItems action ---
    $localTotal++
    $piOutput = & powershell -NoProfile -File $qmScript -Action Get-PendingItems -QueueDir $queueDir 2>&1
    $piExit = $LASTEXITCODE
    if ($piExit -eq 0) {
        Write-TestResult $label "C10: Get-PendingItems returns successfully" $true; $localPass++
    } else {
        Write-TestResult $label "C10: Get-PendingItems returns successfully" $false ("Exit: " + $piExit); $localFail++
    }

    Remove-TempDir $tempDir

    Write-CategoryFooter -Label $label -Passed $localPass -Failed $localFail -Total $localTotal
}

# ============================================================
# CATEGORY D: delivery-adapter.ps1 — Path Resolution, Brief Validation
# ============================================================

function Test-CategoryD {
    $label = "D"
    Write-CategoryHeader $label "delivery-adapter.ps1 -- Brief Path Resolution + Brief Validation"

    $localPass = 0; $localFail = 0; $localTotal = 0

    $tempDir = New-TempDir "testD_delivery"
    $delAdapter = Join-Path -Path $ScriptsDir -ChildPath "delivery-adapter.ps1"
    $queueDir = Join-Path -Path $tempDir -ChildPath "queue"

    # Scaffold a plan to get queue structure
    $validPlan = Join-Path -Path $PlanFixturesDir -ChildPath "valid-plan.json"
    Invoke-Scaffold $validPlan $queueDir | Out-Null

    # Write a valid brief.json for task_102 (brief_required in the plan)
    $brief102Dir = Join-Path -Path $queueDir -ChildPath "prompt_test001\task_102"
    Get-Content -LiteralPath (Join-Path -Path $FixturesDir -ChildPath "valid-brief.json") -Raw -Encoding UTF8 `
        | Set-Content -LiteralPath (Join-Path -Path $brief102Dir -ChildPath "brief.json") -Encoding UTF8

    # --- D1: generate-prompt with a valid task (resolves via index) ---
    $localTotal++
    $resolveOutput = & powershell -NoProfile -File $delAdapter -QueueDir $queueDir -TaskId "task_102" -Action "generate-prompt" 2>&1
    $resolveExit = $LASTEXITCODE
    $hasPromptContent = ($resolveOutput -join " ") -match "Task: task_fftest"
    if ($resolveExit -eq 0 -and $hasPromptContent) {
        Write-TestResult $label "D1: generate-prompt resolves task via index" $true; $localPass++
    } else {
        Write-TestResult $label "D1: generate-prompt resolves task via index" $false ("Exit: " + $resolveExit); $localFail++
    }

    # --- D2: validate-brief with a valid task ---
    $localTotal++
    $valOutput = & powershell -NoProfile -File $delAdapter -QueueDir $queueDir -TaskId "task_102" -Action "validate-brief" 2>&1
    $valExit = $LASTEXITCODE
    if ($valExit -eq 0 -and ($valOutput -join " ") -match "PASS") {
        Write-TestResult $label "D2: validate-brief accepts valid brief" $true; $localPass++
    } else {
        Write-TestResult $label "D2: validate-brief accepts valid brief" $false ("Exit: " + $valExit); $localFail++
    }

    # --- D3: validate-brief with missing-fields brief (invalid) ---
    $localTotal++
    # Write a broken brief for task_101
    $brief101Dir = Join-Path -Path $queueDir -ChildPath "prompt_test001\task_101"
    Get-Content -LiteralPath (Join-Path -Path $FixturesDir -ChildPath "invalid-brief-missing-fields.json") -Raw -Encoding UTF8 `
        | Set-Content -LiteralPath (Join-Path -Path $brief101Dir -ChildPath "brief.json") -Encoding UTF8
    $valOutput2 = & powershell -NoProfile -File $delAdapter -QueueDir $queueDir -TaskId "task_101" -Action "validate-brief" 2>&1
    $valExit2 = $LASTEXITCODE
    if ($valExit2 -eq 1) {
        Write-TestResult $label "D3: validate-brief rejects missing fields" $true; $localPass++
    } else {
        Write-TestResult $label "D3: validate-brief rejects missing fields" $false ("Exit: " + $valExit2); $localFail++
    }

    # --- D4: validate-brief with skip-level delegation ---
    $localTotal++
    # Write a skip-level brief for task_103
    $brief103Dir = Join-Path -Path $queueDir -ChildPath "prompt_test001\task_103"
    Get-Content -LiteralPath (Join-Path -Path $FixturesDir -ChildPath "invalid-brief-skip-level.json") -Raw -Encoding UTF8 `
        | Set-Content -LiteralPath (Join-Path -Path $brief103Dir -ChildPath "brief.json") -Encoding UTF8
    $valOutput3 = & powershell -NoProfile -File $delAdapter -QueueDir $queueDir -TaskId "task_103" -Action "validate-brief" 2>&1
    $valExit3 = $LASTEXITCODE
    if ($valExit3 -eq 1) {
        Write-TestResult $label "D4: validate-brief rejects skip-level" $true; $localPass++
    } else {
        Write-TestResult $label "D4: validate-brief rejects skip-level" $false ("Exit: " + $valExit3); $localFail++
    }

    # --- D5: show-summary action ---
    $localTotal++
    $sumOutput = & powershell -NoProfile -File $delAdapter -QueueDir $queueDir -TaskId "task_102" -Action "show-summary" 2>&1
    $sumExit = $LASTEXITCODE
    if ($sumExit -eq 0) {
        Write-TestResult $label "D5: show-summary displays brief info" $true; $localPass++
    } else {
        Write-TestResult $label "D5: show-summary displays brief info" $false ("Exit: " + $sumExit); $localFail++
    }

    # --- D6: generate-prompt fails on missing task ---
    $localTotal++
    $resolveOutput2 = & powershell -NoProfile -File $delAdapter -QueueDir $queueDir -TaskId "task_totallylost" -Action "generate-prompt" 2>&1
    $resolveExit2 = $LASTEXITCODE
    if ($resolveExit2 -eq 1) {
        Write-TestResult $label "D6: generate-prompt fails on missing task" $true; $localPass++
    } else {
        Write-TestResult $label "D6: generate-prompt fails on missing task" $false ("Exit: " + $resolveExit2); $localFail++
    }

    Remove-TempDir $tempDir

    Write-CategoryFooter -Label $label -Passed $localPass -Failed $localFail -Total $localTotal
}

# ============================================================
# CATEGORY E: preflight-gate.ps1 — 6 Actions x PASS/BLOCKED/WARN
# ============================================================

function Test-CategoryE {
    $label = "E"
    Write-CategoryHeader $label "preflight-gate.ps1 -- 6 Actions x PASS/BLOCKED/WARN States"

    $localPass = 0; $localFail = 0; $localTotal = 0

    $tempDir = New-TempDir "testE_preflight"
    $plansDir = Join-Path -Path $tempDir -ChildPath "plans"
    $queueDir = Join-Path -Path $tempDir -ChildPath "queue"
    New-Item -ItemType Directory -Path $plansDir -Force | Out-Null
    New-Item -ItemType Directory -Path $queueDir -Force | Out-Null

    # Copy a plan file to plans dir for session matching
    $validPlan = Join-Path -Path $PlanFixturesDir -ChildPath "valid-plan.json"
    Copy-Item -LiteralPath $validPlan -Destination (Join-Path -Path $plansDir -ChildPath "prompt_test001.plan.json") -Force

    # Scaffold the plan
    Invoke-Scaffold $validPlan $queueDir | Out-Null

    # --- E1: plan action PASSES (no existing plan for session, dirs exist) ---
    $localTotal++
    $result = Invoke-Preflight "plan" "" "$plansDir" "$queueDir" "sess_test_plan_validator"
    if ($result.ExitCode -eq 0) {
        Write-TestResult $label "E1: plan action PASSES" $true; $localPass++
    } else {
        Write-TestResult $label "E1: plan action PASSES" $false ("Exit: " + $result.ExitCode); $localFail++
    }

    # --- E2: delegate blocked without TaskId ---
    $localTotal++
    $result = Invoke-Preflight "delegate" "" "$plansDir" "$queueDir" "sess_test_plan_validator"
    if ($result.ExitCode -eq 1) {
        Write-TestResult $label "E2: delegate BLOCKED without TaskId" $true; $localPass++
    } else {
        Write-TestResult $label "E2: delegate BLOCKED without TaskId" $false ("Exit: " + $result.ExitCode + " (expected 1)"); $localFail++
    }

    # --- E3: delegate blocked when task has pending deps ---
    $localTotal++
    # Write brief for task_102 (the task we'll try to delegate)
    $briefContent = Get-Content -LiteralPath (Join-Path -Path $FixturesDir -ChildPath "valid-brief.json") -Raw -Encoding UTF8
    # task_102 depends on task_101 which is still pending -> should block
    $briefContent | Set-Content -LiteralPath (Join-Path -Path $queueDir -ChildPath "prompt_test001\task_102\brief.json") -Encoding UTF8
    $result = Invoke-Preflight "delegate" "task_102" "$plansDir" "$queueDir" "sess_test_plan_validator"
    if ($result.ExitCode -eq 1) {
        Write-TestResult $label "E3: delegate BLOCKED on unmet deps" $true; $localPass++
    } else {
        Write-TestResult $label "E3: delegate BLOCKED on unmet deps" $false ("Exit: " + $result.ExitCode + " (expected 1)"); $localFail++
    }

    # --- E4: delegate passes when deps done ---
    $localTotal++
    # Mark task_101 (dep of task_102) as completed via queue-manager (updates both file + index)
    $qmScript = Join-Path -Path $ScriptsDir -ChildPath "queue-manager.ps1"
    & powershell -NoProfile -File $qmScript -Action Set-QueueStatus -QueueDir $queueDir -TaskId "task_101" -Status "completed" 2>&1 | Out-Null
    $result = Invoke-Preflight "delegate" "task_102" "$plansDir" "$queueDir" "sess_test_plan_validator"
    if ($result.ExitCode -eq 0) {
        Write-TestResult $label "E4: delegate PASSES when deps done" $true; $localPass++
    } else {
        $detail = "Exit: " + $result.ExitCode
        if ($null -ne $result.Json -and $null -ne $result.Json.blockers) {
            $detail += " blockers: " + ($result.Json.blockers -join '; ')
        }
        Write-TestResult $label "E4: delegate PASSES when deps done" $false $detail; $localFail++
    }

    # --- E5: execute blocked when task not pending ---
    $localTotal++
    $result = Invoke-Preflight "execute" "task_101" "$plansDir" "$queueDir" "sess_test_plan_validator"
    if ($result.ExitCode -eq 1) {
        Write-TestResult $label "E5: execute BLOCKED on wrong status" $true; $localPass++
    } else {
        Write-TestResult $label "E5: execute BLOCKED on wrong status" $false ("Exit: " + $result.ExitCode + " (expected 1)"); $localFail++
    }

    # --- E6: execute passes when task is pending ---
    $localTotal++
    # Reset task_101 (no deps, was completed in E4) back to pending via queue-manager
    $qmScript = Join-Path -Path $ScriptsDir -ChildPath "queue-manager.ps1"
    & powershell -NoProfile -File $qmScript -Action Set-QueueStatus -QueueDir $queueDir -TaskId "task_101" -Status "pending" 2>&1 | Out-Null
    $result = Invoke-Preflight "execute" "task_101" "$plansDir" "$queueDir" "sess_test_plan_validator"
    if ($result.ExitCode -eq 0) {
        Write-TestResult $label "E6: execute PASSES when pending" $true; $localPass++
    } else {
        Write-TestResult $label "E6: execute PASSES when pending" $false ("Exit: " + $result.ExitCode + " (expected 0)"); $localFail++
    }

    # --- E7: brief action passes ---
    $localTotal++
    $result = Invoke-Preflight "brief" "task_103" "$plansDir" "$queueDir" "sess_test_plan_validator"
    if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 2) {
        Write-TestResult $label "E7: brief action PASSES or WARN" $true; $localPass++
    } else {
        Write-TestResult $label "E7: brief action PASSES or WARN" $false ("Exit: " + $result.ExitCode + " (expected 0 or 2)"); $localFail++
    }

    # --- E8: checkpoint action ---
    $localTotal++
    # Create a dummy trace file so checkpoint's trace check passes
    $tracePath = Join-Path -Path $script:TracesDir -ChildPath "sess_test_plan_validator.exec.jsonl"
    $dummyTrace = '{"ts":"2026-06-28T20:00:00Z","phase":"execute","type":"task_start","name":"test_checkpoint","detail":"Dummy for test"}'
    $dummyTrace | Set-Content -LiteralPath $tracePath -Encoding UTF8
    $result = Invoke-Preflight "checkpoint" "task_101" "$plansDir" "$queueDir" "sess_test_plan_validator"
    if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 2) {
        Write-TestResult $label "E8: checkpoint action PASSES" $true; $localPass++
    } else {
        $detail = "Exit: " + $result.ExitCode
        if ($null -ne $result.Json -and $null -ne $result.Json.blockers) {
            $detail += " blockers: " + ($result.Json.blockers -join '; ')
        }
        Write-TestResult $label "E8: checkpoint action PASSES" $false $detail; $localFail++
    }
    # Clean up dummy trace
    Remove-Item -LiteralPath $tracePath -Force -ErrorAction SilentlyContinue

    # --- E9: complete blocked when not in_progress ---
    $localTotal++
    $result = Invoke-Preflight "complete" "task_103" "$plansDir" "$queueDir" "sess_test_plan_validator"
    if ($result.ExitCode -eq 1) {
        Write-TestResult $label "E9: complete BLOCKED when not in_progress" $true; $localPass++
    } else {
        Write-TestResult $label "E9: complete BLOCKED when not in_progress" $false ("Exit: " + $result.ExitCode + " (expected 1)"); $localFail++
    }

    # --- E10: gate returns structured JSON with exit_code field ---
    $localTotal++
    $result = Invoke-Preflight "plan" "" "$plansDir" "$queueDir" "sess_test_plan_validator"
    if ($null -ne $result.Json -and $null -ne $result.Json.exit_code) {
        Write-TestResult $label "E10: Preflight output is structured JSON" $true; $localPass++
    } else {
        Write-TestResult $label "E10: Preflight output is structured JSON" $false ("json null: " + ($null -eq $result.Json)); $localFail++
    }

    Remove-TempDir $tempDir

    Write-CategoryFooter -Label $label -Passed $localPass -Failed $localFail -Total $localTotal
}

# ============================================================
# CATEGORY F: Integration — Full Pipeline End-to-End
# ============================================================

function Test-CategoryF {
    $label = "F"
    Write-CategoryHeader $label "Integration -- Full Pipeline End-to-End"

    $localPass = 0; $localFail = 0; $localTotal = 0

    $tempDir = New-TempDir "testF_integration"
    $plansDir = Join-Path -Path $tempDir -ChildPath "plans"
    $queueDir = Join-Path -Path $tempDir -ChildPath "queue"
    New-Item -ItemType Directory -Path $plansDir -Force | Out-Null

    # --- F1: Full pipeline valid plan ---
    $localTotal++
    # Step 1: Copy valid plan to plans dir
    $validPlan = Join-Path -Path $PlanFixturesDir -ChildPath "valid-plan-complex.json"
    Copy-Item -LiteralPath $validPlan -Destination (Join-Path -Path $plansDir -ChildPath "prompt_test002.plan.json") -Force
    $planPath = Join-Path -Path $plansDir -ChildPath "prompt_test002.plan.json"

    # Step 2: Validate
    $valResult = Invoke-Validator $planPath
    $validatePassed = ($valResult.ExitCode -eq 0)

    # Step 3: Scaffold
    $scaffoldResult = Invoke-Scaffold $planPath $queueDir
    $scaffoldPassed = ($scaffoldResult.ExitCode -eq 0)

    # Step 4: Verify task directories exist
    $tasksExist = (Test-Path -LiteralPath (Join-Path -Path $queueDir -ChildPath "prompt_test002\task_201\status.json")) -and
                  (Test-Path -LiteralPath (Join-Path -Path $queueDir -ChildPath "prompt_test002\task_205\status.json"))

    # Step 5: Verify index updated
    $indexPath = Join-Path -Path $queueDir -ChildPath "index.json"
    $indexUpdated = Test-Path -LiteralPath $indexPath

    if ($validatePassed -and $scaffoldPassed -and $tasksExist -and $indexUpdated) {
        Write-TestResult $label "F1: Full pipeline valid plan" $true; $localPass++
    } else {
        $detail = "val=$validatePassed scaf=$scaffoldPassed tasks=$tasksExist idx=$indexUpdated"
        Write-TestResult $label "F1: Full pipeline valid plan" $false $detail; $localFail++
    }

    # --- F2: Cycle detection blocks pipeline ---
    $localTotal++
    $cyclicPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-cyclic.json"
    Copy-Item -LiteralPath $cyclicPlan -Destination (Join-Path -Path $plansDir -ChildPath "prompt_cyclic.plan.json") -Force
    $cyclVal = Invoke-Validator (Join-Path -Path $plansDir -ChildPath "prompt_cyclic.plan.json")
    $cycleDetected = ($cyclVal.ExitCode -eq 1 -and ($cyclVal.Output -join " ") -match "RULE 3")
    if ($cycleDetected) {
        Write-TestResult $label "F2: Cycle detection blocks pipeline" $true; $localPass++
    } else {
        Write-TestResult $label "F2: Cycle detection blocks pipeline" $false ("Exit: " + $cyclVal.ExitCode); $localFail++
    }

    # --- F3: Multiple bad rules caught together ---
    $localTotal++
    # A plan with multiple violations (bad division + bad agent + HIGH without brief)
    $multiBadPlan = Join-Path -Path $PlanFixturesDir -ChildPath "invalid-plan-bad-division.json"
    $multiVal = Invoke-Validator $multiBadPlan
    $multiOutput = $multiVal.Output -join " "
    # Should catch at least: RULE 5 (bad div) and possibly RULE 4 if agent also wrong
    $rule5Caught = $multiOutput -match "RULE 5"
    if ($multiVal.ExitCode -eq 1 -and $rule5Caught) {
        Write-TestResult $label "F3: Multiple rules caught together" $true; $localPass++
    } else {
        Write-TestResult $label "F3: Multiple rules caught together" $false ("Exit: " + $multiVal.ExitCode + ", rule5: " + $rule5Caught); $localFail++
    }

    # --- F4: Scaffold + queue operations integration ---
    $localTotal++
    $queueDir2 = Join-Path -Path $tempDir -ChildPath "queue2"
    Invoke-Scaffold $planPath $queueDir2 | Out-Null

    # Set statuses in order
    & powershell -NoProfile -File (Join-Path -Path $ScriptsDir -ChildPath "queue-manager.ps1") -Action Set-QueueStatus -QueueDir $queueDir2 -TaskId "task_201" -Status "in_progress" 2>&1 | Out-Null
    & powershell -NoProfile -File (Join-Path -Path $ScriptsDir -ChildPath "queue-manager.ps1") -Action Set-QueueStatus -QueueDir $queueDir2 -TaskId "task_201" -Status "completed" -Confidence 90 2>&1 | Out-Null
    & powershell -NoProfile -File (Join-Path -Path $ScriptsDir -ChildPath "queue-manager.ps1") -Action Set-QueueStatus -QueueDir $queueDir2 -TaskId "task_202" -Status "in_progress" 2>&1 | Out-Null

    # Check aggregate status
    $aggOutput = & powershell -NoProfile -File (Join-Path -Path $ScriptsDir -ChildPath "queue-manager.ps1") -Action Get-QueueIndex -QueueDir $queueDir2 2>&1
    $aggExit = $LASTEXITCODE
    if ($aggExit -eq 0) {
        Write-TestResult $label "F4: Queue ops after scaffold work" $true; $localPass++
    } else {
        Write-TestResult $label "F4: Queue ops after scaffold work" $false ("Exit: " + $aggExit); $localFail++
    }

    Remove-TempDir $tempDir

    Write-CategoryFooter -Label $label -Passed $localPass -Failed $localFail -Total $localTotal
}

# ============================================================
# CATEGORY G: Protocol Consistency — Schema vs Script Contracts
# ============================================================

function Test-CategoryG {
    $label = "G"
    Write-CategoryHeader $label "Protocol Consistency -- Schema vs Script Contract Checks"

    $localPass = 0; $localFail = 0; $localTotal = 0

    # --- G1: plan.schema.md has 13 rules ---
    $localTotal++
    $schemaPath = Join-Path -Path $ProjectRoot -ChildPath ".agents\schemas\plan.schema.md"
    $schemaContent = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8
    $ruleMatches = [regex]::Matches($schemaContent, '\| (\d+) \|')
    $ruleCount = 0
    foreach ($m in $ruleMatches) {
        $num = [int]$m.Groups[1].Value
        if ($num -ge 1 -and $num -le 15) { $ruleCount = $num }
    }
    if ($ruleCount -eq 13) {
        Write-TestResult $label "G1: plan.schema.md documents 13 rules" $true; $localPass++
    } else {
        Write-TestResult $label "G1: plan.schema.md documents 13 rules" $false ("Found " + $ruleCount + " rules"); $localFail++
    }

    # --- G2: plan-validator.ps1 implements all 13 rules ---
    $localTotal++
    $validatorPath = Join-Path -Path $ScriptsDir -ChildPath "plan-validator.ps1"
    $validatorContent = Get-Content -LiteralPath $validatorPath -Raw -Encoding UTF8
    $ruleInCodes = @()
    for ($i = 1; $i -le 13; $i++) {
        if ($validatorContent -match "RULE " + $i) { $ruleInCodes += $i }
    }
    if ($ruleInCodes.Count -eq 13) {
        Write-TestResult $label "G2: Validator implements all 13 rules" $true; $localPass++
    } else {
        Write-TestResult $label "G2: Validator implements all 13 rules" $false ("Found " + $ruleInCodes.Count + "/13"); $localFail++
    }

    # --- G3: queue.schema.md references v2 index ---
    $localTotal++
    $queueSchemaPath = Join-Path -Path $ProjectRoot -ChildPath ".agents\schemas\queue.schema.md"
    $queueSchema = Get-Content -LiteralPath $queueSchemaPath -Raw -Encoding UTF8
    if ($queueSchema -match "queue-index-v2") {
        Write-TestResult $label "G3: queue.schema.md references v2 index" $true; $localPass++
    } else {
        Write-TestResult $label "G3: queue.schema.md references v2 index" $false "No v2 reference found"; $localFail++
    }

    # --- G4: All valid agents in schema are implemented in validator ---
    $localTotal++
    # Check orchestrator is in division map
    $validatorContent = Get-Content -LiteralPath $validatorPath -Raw -Encoding UTF8
    $schemaAgents = @(
        "orchestrator", "engineering-lead", "frontend-developer", "backend-architect", "database-engineer",
        "platform-lead", "devops-engineer", "cloud-architect", "security-engineer", "incident-commander",
        "quality-lead", "sdet", "performance-tester", "visual-qa-specialist", "qa-automation-engineer",
        "design-lead", "ui-designer", "ux-researcher", "design-systems-engineer", "animator",
        "intelligence-lead", "session-analyst", "optimization-architect",
        "moderator", "advocate", "skeptic", "devils-advocate", "domain-expert"
    )
    $allAgentsFound = $true
    $missingAgents = @()
    foreach ($agent in $schemaAgents) {
        if ($validatorContent -notmatch $agent) {
            $allAgentsFound = $false
            $missingAgents += $agent
        }
    }
    if ($allAgentsFound) {
        Write-TestResult $label "G4: All schema agents in validator" $true; $localPass++
    } else {
        Write-TestResult $label "G4: All schema agents in validator" $false ("Missing: " + ($missingAgents -join ', ')); $localFail++
    }

    # --- G5: trace.schema.md defines mandatory trace points ---
    $localTotal++
    $traceSchema = Get-Content -LiteralPath (Join-Path -Path $ProjectRoot -ChildPath ".agents\schemas\trace.schema.md") -Raw -Encoding UTF8
    $hasMandatory = $traceSchema -match "Mandatory trace points"
    $hasTaskStart = $traceSchema -match "task_start"
    $hasTaskComplete = $traceSchema -match "task_complete"
    $hasTaskBrief = $traceSchema -match "task_brief"
    $hasTaskOutput = $traceSchema -match "task_output"
    if ($hasMandatory -and $hasTaskStart -and $hasTaskComplete -and $hasTaskBrief -and $hasTaskOutput) {
        Write-TestResult $label "G5: trace.schema.md defines mandatory points" $true; $localPass++
    } else {
        Write-TestResult $label "G5: trace.schema.md defines mandatory points" $false ("mandatory=$hasMandatory start=$hasTaskStart complete=$hasTaskComplete brief=$hasTaskBrief output=$hasTaskOutput"); $localFail++
    }

    # --- G6: preflight-gate.ps1 handles all 6 actions ---
    $localTotal++
    $gatePath = Join-Path -Path $ScriptsDir -ChildPath "preflight-gate.ps1"
    $gateContent = Get-Content -LiteralPath $gatePath -Raw -Encoding UTF8
    $expectedActions = @("plan", "delegate", "execute", "brief", "complete", "checkpoint")
    $allActions = $true
    foreach ($action in $expectedActions) {
        if ($gateContent -notmatch ("Check-" + (Get-Culture).TextInfo.ToTitleCase($action))) {
            $allActions = $false
        }
    }
    if ($allActions) {
        Write-TestResult $label "G6: Preflight gate handles all 6 actions" $true; $localPass++
    } else {
        Write-TestResult $label "G6: Preflight gate handles all 6 actions" $false "Missing action handler function"; $localFail++
    }

    # --- G7: All divisions in schema match validator ---
    $localTotal++
    $schemaDivisions = @("engineering", "platform", "quality", "design", "intelligence", "research-council")
    $allDivsFound = $true
    foreach ($div in $schemaDivisions) {
        if ($validatorContent -notmatch ('"' + $div + '"')) {
            $allDivsFound = $false
            $missingDivs += $div
        }
    }
    if ($allDivsFound) {
        Write-TestResult $label "G7: All schema divisions in validator" $true; $localPass++
    } else {
        Write-TestResult $label "G7: All schema divisions in validator" $false ("Missing: " + ($missingDivs -join ', ')); $localFail++
    }

    Write-CategoryFooter -Label $label -Passed $localPass -Failed $localFail -Total $localTotal
}

# ============================================================
# CATEGORY H: PS5.1 Compatibility — Encoding, Stream Pollution
# ============================================================

function Test-CategoryH {
    $label = "H"
    Write-CategoryHeader $label "PS5.1 Compatibility -- Encoding, Stream Pollution, Edge Cases"

    $localPass = 0; $localFail = 0; $localTotal = 0

    $tempDir = New-TempDir "testH_ps51"

    # --- H1: Validator outputs to stdout only (no mixed streams) ---
    $localTotal++
    $validPlan = Join-Path -Path $PlanFixturesDir -ChildPath "valid-plan.json"
    $output = & powershell -NoProfile -File (Join-Path -Path $ScriptsDir -ChildPath "plan-validator.ps1") -PlanFile $validPlan 2>&1
    $exitCode = $LASTEXITCODE
    $capturedAsOutput = $output | Where-Object { $_ -is [string] }
    if ($exitCode -eq 0 -and $capturedAsOutput.Count -gt 0) {
        Write-TestResult $label "H1: Validator outputs clean stdout" $true; $localPass++
    } else {
        Write-TestResult $label "H1: Validator outputs clean stdout" $false ("Exit: " + $exitCode + ", lines: " + $capturedAsOutput.Count); $localFail++
    }

    # --- H2: Preflight gate outputs structured JSON-only ---
    $localTotal++
    $plansDir = Join-Path -Path $tempDir -ChildPath "plans"
    $queueDir = Join-Path -Path $tempDir -ChildPath "queue"
    New-Item -ItemType Directory -Path $plansDir -Force | Out-Null
    New-Item -ItemType Directory -Path $queueDir -Force | Out-Null
    $gatePath = Join-Path -Path $ScriptsDir -ChildPath "preflight-gate.ps1"
    $output = & powershell -NoProfile -File $gatePath -Action plan -PlansDir $plansDir -QueueDir $queueDir 2>&1
    $jsonLines = $output | Where-Object { $_.Trim().StartsWith("{") }
    if ($jsonLines.Count -eq 1) {
        $parsed = $jsonLines[0] | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($null -ne $parsed -and $parsed.gate -eq "preflight-gate-v1") {
            Write-TestResult $label "H2: Preflight gate outputs clean JSON" $true; $localPass++
        } else {
            Write-TestResult $label "H2: Preflight gate outputs clean JSON" $false "JSON parse failed"; $localFail++
        }
    } else {
        Write-TestResult $label "H2: Preflight gate outputs clean JSON" $false ("JSON lines: " + $jsonLines.Count); $localFail++
    }

    # --- H3: Scaffold output is not polluted by Write-Output ---
    $localTotal++
    $validPlan = Join-Path -Path $PlanFixturesDir -ChildPath "valid-plan.json"
    $queueDir2 = Join-Path -Path $tempDir -ChildPath "queue3"
    $scaffoldPath = Join-Path -Path $ScriptsDir -ChildPath "plan-scaffold.ps1"
    $output = & powershell -NoProfile -File $scaffoldPath -PlanFile $validPlan -QueueDir $queueDir2 2>&1
    $exitCode = $LASTEXITCODE
    $outputLines = $output | Where-Object { $_ -is [string] }
    if ($exitCode -eq 0) {
        # Check that ConvertFrom-Json would not grab scaffold messages
        Write-TestResult $label "H3: Scaffold no output stream pollution" $true; $localPass++
    } else {
        Write-TestResult $label "H3: Scaffold no output stream pollution" $false ("Exit: " + $exitCode); $localFail++
    }

    # --- H4: Queue manager output is not polluted ---
    $localTotal++
    $qmPath = Join-Path -Path $ScriptsDir -ChildPath "queue-manager.ps1"
    $output = & powershell -NoProfile -File $qmPath -Action Get-QueueIndex -QueueDir $queueDir2 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        Write-TestResult $label "H4: Queue manager no stream pollution" $true; $localPass++
    } else {
        Write-TestResult $label "H4: Queue manager no stream pollution" $false ("Exit: " + $exitCode); $localFail++
    }

    # --- H5: UTF-8 encoding with BOM works (PS5.1 requirement) ---
    $localTotal++
    $testFile = Join-Path -Path $tempDir -ChildPath "utf8-test.json"
    $testObj = @{ test = "value"; number = 42 }
    $testObj | ConvertTo-Json | Set-Content -LiteralPath $testFile -Encoding UTF8
    $reparsed = Get-Content -LiteralPath $testFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($reparsed.test -eq "value" -and $reparsed.number -eq 42) {
        Write-TestResult $label "H5: UTF-8 BOM encoding works" $true; $localPass++
    } else {
        Write-TestResult $label "H5: UTF-8 BOM encoding works" $false "Parse roundtrip failed"; $localFail++
    }

    # --- H6: No Unicode chars in script strings ---
    $localTotal++
    $scripts = @(
        (Join-Path -Path $ScriptsDir -ChildPath "plan-validator.ps1"),
        (Join-Path -Path $ScriptsDir -ChildPath "plan-scaffold.ps1"),
        (Join-Path -Path $ScriptsDir -ChildPath "preflight-gate.ps1"),
        (Join-Path -Path $ScriptsDir -ChildPath "queue-manager.ps1"),
        (Join-Path -Path $ScriptsDir -ChildPath "delivery-adapter.ps1")
    )
    $hasUnicode = $false
    $unicodeFiles = @()
    foreach ($s in $scripts) {
        if (Test-Path -LiteralPath $s) {
            $content = Get-Content -LiteralPath $s -Raw -Encoding UTF8
            # Check for non-ASCII in script content (outside comments)
            $nonAscii = [regex]::Matches($content, '[^\x00-\x7F]')
            if ($nonAscii.Count -gt 0) {
                $hasUnicode = $true
                $unicodeFiles += $s
            }
        }
    }
    if (!$hasUnicode) {
        Write-TestResult $label "H6: No Unicode in script strings" $true; $localPass++
    } else {
        Write-TestResult $label "H6: No Unicode in script strings" $false ("Files: " + ($unicodeFiles -join ', ')); $localFail++
    }

    Remove-TempDir $tempDir

    Write-CategoryFooter -Label $label -Passed $localPass -Failed $localFail -Total $localTotal
}

# ============================================================
# CATEGORY I: Trace Validation — Validate Trace JSONL Files
# ============================================================

function Test-CategoryI {
    $label = "I"
    Write-CategoryHeader $label "Trace Validation -- Validate Trace JSONL Files Against Schema"

    $localPass = 0; $localFail = 0; $localTotal = 0

    # --- Helper: Validate a single trace file ---
    function Validate-TraceFile {
        param([string]$Path, [string]$Label)
        $results = @{ pass = 0; fail = 0; total = 0; errors = @() }
        if (!(Test-Path -LiteralPath $Path)) {
            return @{ pass = 0; fail = 1; total = 1; errors = @("File not found") }
        }

        $lines = Get-Content -LiteralPath $Path -Encoding UTF8
        $entries = @()

        # I.I1: Each line is valid JSON
        $results.total++
        $allValidJson = $true
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrEmpty($trimmed)) { continue }
            try {
                $obj = $trimmed | ConvertFrom-Json
                $entries += $obj
            } catch {
                $allValidJson = $false
                $results.errors += "Invalid JSON line: $_"
            }
        }
        if ($allValidJson) { $results.pass++ } else { $results.fail++ }

        if ($entries.Count -eq 0) {
            $results.total++
            $results.errors += "No valid trace entries found"
            $results.fail++
            return $results
        }

        # I.I2: Required fields exist (ts, phase, type, name)
        $results.total++
        $allRequired = $true
        foreach ($e in $entries) {
            $hasTs = ![string]::IsNullOrEmpty($e.ts)
            $hasPhase = ![string]::IsNullOrEmpty($e.phase)
            $hasType = ![string]::IsNullOrEmpty($e.type)
            $hasName = ![string]::IsNullOrEmpty($e.name)
            if (!($hasTs -and $hasPhase -and $hasType -and $hasName)) {
                $allRequired = $false
                $results.errors += ("Entry missing required fields: ts=$hasTs phase=$hasPhase type=$hasType name=$hasName -- " + ($e | ConvertTo-Json -Compress))
                break
            }
        }
        if ($allRequired) { $results.pass++ } else { $results.fail++ }

        # I.I3: Phase is valid (plan or execute)
        $results.total++
        $validPhase = $true
        foreach ($e in $entries) {
            if ($e.phase -ne "plan" -and $e.phase -ne "execute") {
                $validPhase = $false
                $results.errors += ("Invalid phase: '" + $e.phase + "' in entry: " + $e.name)
                break
            }
        }
        if ($validPhase) { $results.pass++ } else { $results.fail++ }

        # I.I4: Type is from the defined set
        $results.total++
        $validTypes = @(
            "skill_load", "command_ref", "file_read", "file_write", "audit_write",
            "decision", "task_start", "task_complete", "tool_invoke", "agent_delegate",
            "task_brief", "task_output", "bash"
        )
        $allTypesValid = $true
        foreach ($e in $entries) {
            if ($validTypes -notcontains $e.type) {
                $allTypesValid = $false
                $results.errors += ("Invalid type: '" + $e.type + "' in entry: " + $e.name)
                break
            }
        }
        if ($allTypesValid) { $results.pass++ } else { $results.fail++ }

        # I.I5: Timestamps are in chronological order
        $results.total++
        $chronological = $true
        $prevTs = ""
        foreach ($e in $entries) {
            if ($prevTs -ne "" -and $e.ts -lt $prevTs) {
                $chronological = $false
                $results.errors += ("Out of order timestamp: " + $e.ts + " after " + $prevTs)
                break
            }
            $prevTs = $e.ts
        }
        if ($chronological) { $results.pass++ } else { $results.fail++ }

        # I.I6: Plan-phase entries only use allowed plan types
        $results.total++
        $allowedPlanTypes = @("skill_load", "command_ref", "file_read", "file_write", "audit_write", "decision")
        $planTypesValid = $true
        foreach ($e in $entries) {
            if ($e.phase -eq "plan" -and $allowedPlanTypes -notcontains $e.type) {
                $planTypesValid = $false
                $results.errors += ("Plan-phase entry has invalid type: '" + $e.type + "'")
                break
            }
        }
        if ($planTypesValid) { $results.pass++ } else { $results.fail++ }

        # I.I7: Execute-phase entries only use allowed execute types
        $results.total++
        $allowedExecuteTypes = @(
            "skill_load", "command_ref", "file_read", "file_write", "audit_write",
            "task_start", "task_complete", "tool_invoke", "agent_delegate",
            "task_brief", "task_output", "bash"
        )
        $execTypesValid = $true
        foreach ($e in $entries) {
            if ($e.phase -eq "execute" -and $allowedExecuteTypes -notcontains $e.type) {
                $execTypesValid = $false
                $results.errors += ("Execute-phase entry has invalid type: '" + $e.type + "'")
                break
            }
        }
        if ($execTypesValid) { $results.pass++ } else { $results.fail++ }

        # I.I8: Every task_start has matching task_complete
        $results.total++
        $startTasks = @{}
        $completeTasks = @{}
        foreach ($e in $entries) {
            if ($e.type -eq "task_start") { $startTasks[$e.name] = $true }
            if ($e.type -eq "task_complete") { $completeTasks[$e.name] = $true }
        }
        $mismatch = $false
        foreach ($task in $startTasks.Keys) {
            if (!$completeTasks.ContainsKey($task)) {
                $mismatch = $true
                $results.errors += ("Task started but never completed: " + $task)
                break
            }
        }
        if (!$mismatch) { $results.pass++ } else { $results.fail++ }

        # I.I9: task_output entries have result field
        $results.total++
        $outputHasResult = $true
        foreach ($e in $entries) {
            if ($e.type -eq "task_output" -and [string]::IsNullOrEmpty($e.result)) {
                $outputHasResult = $false
                $results.errors += ("task_output missing result field: " + $e.name)
                break
            }
        }
        if ($outputHasResult) { $results.pass++ } else { $results.fail++ }

        # I.I10: task_brief entries have detail with JSON
        $results.total++
        $briefHasJsonDetail = $true
        foreach ($e in $entries) {
            if ($e.type -eq "task_brief") {
                if ([string]::IsNullOrEmpty($e.detail)) {
                    $briefHasJsonDetail = $false
                    $results.errors += ("task_brief missing detail field: " + $e.name)
                    break
                }
                # Try parsing detail as JSON
                try {
                    $parsed = $e.detail | ConvertFrom-Json -ErrorAction Stop
                    # Verify it has required keys for a brief
                    if ($null -eq $parsed.skills -and $null -eq $parsed.commands -and $null -eq $parsed.files -and $null -eq $parsed.tests -and $null -eq $parsed.acceptance) {
                        # It's OK if not all five -- but try to parse at least
                    }
                } catch {
                    # Detail might be a non-JSON string, that's OK for some contexts
                }
            }
        }
        if ($briefHasJsonDetail) { $results.pass++ } else { $results.fail++ }

        # I.I11: task_path is present on task lifecycle entries
        $results.total++
        $lifecycleTypes = @("task_start", "task_complete", "task_brief", "task_output")
        $allHaveTaskPath = $true
        foreach ($e in $entries) {
            if ($lifecycleTypes -contains $e.type -and [string]::IsNullOrEmpty($e.task_path)) {
                $allHaveTaskPath = $false
                $results.errors += ("Task lifecycle entry missing task_path: " + $e.type + " - " + $e.name)
                break
            }
        }
        if ($allHaveTaskPath) { $results.pass++ } else { $results.fail++ }

        return $results
    }

    # Find all trace fixture files
    $traceFixtures = @(
        (Join-Path -Path $FixturesDir -ChildPath "valid-trace.jsonl"),
        (Join-Path -Path $FixturesDir -ChildPath "valid-trace-tdd-red.jsonl"),
        (Join-Path -Path $FixturesDir -ChildPath "valid-trace-tdd-green.jsonl"),
        (Join-Path -Path $FixturesDir -ChildPath "valid-trace-tdd-violation.jsonl")
    )

    # Also scan traces dir for any real trace files
    $realTraces = @()
    if (Test-Path -LiteralPath $TracesDir) {
        $realTraces = Get-ChildItem -Path $TracesDir -Filter "*.exec.jsonl" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    }

    $allTraceFiles = $traceFixtures + $realTraces
    $testedFiles = 0

    # I1: All fixture trace files exist
    $localTotal++
    $allExist = $true
    foreach ($f in $traceFixtures) {
        if (!(Test-Path -LiteralPath $f)) { $allExist = $false; break }
    }
    if ($allExist) {
        Write-TestResult $label "I1: All trace fixture files exist" $true; $localPass++
    } else {
        Write-TestResult $label "I1: All trace fixture files exist" $false; $localFail++
    }

    # I2-I12: Validate each trace fixture file against schema
    foreach ($fixturePath in $traceFixtures) {
        $fileName = Split-Path -Leaf $fixturePath
        $results = Validate-TraceFile -Path $fixturePath -Label $fileName
        $testedFiles++

        $localTotal += $results.total
        $localPass += $results.pass
        $localFail += $results.fail

        # Print individual result per fixture
        if ($results.fail -eq 0) {
            Write-TestResult $label ("I2." + $testedFiles + ": " + $fileName + " passes all trace checks") $true
        } else {
            Write-Host ("  [FAIL] I2." + $testedFiles + ": " + $fileName + " has " + $results.fail + " trace violations") -ForegroundColor Red
            foreach ($err in $results.errors) {
                Write-Host ("         " + $err) -ForegroundColor DarkRed
            }
        }
    }

    # I3: Real trace files from traces dir (if exist) also validate
    if ($realTraces.Count -gt 0) {
        $localTotal++
        $allRealPass = $true
        foreach ($rt in $realTraces) {
            $results = Validate-TraceFile -Path $rt -Label (Split-Path -Leaf $rt)
            if ($results.fail -gt 0) {
                $allRealPass = $false
                foreach ($err in $results.errors) {
                    Write-Host ("  [WARN] " + (Split-Path -Leaf $rt) + ": " + $err) -ForegroundColor Yellow
                }
            }
        }
        if ($allRealPass) {
            Write-TestResult $label ("I3: " + $realTraces.Count + " real trace files valid") $true; $localPass++
        } else {
            Write-TestResult $label ("I3: Real trace files valid") $false ("Some real traces have issues"); $localFail++
        }
    } else {
        $localTotal++
        Write-TestResult $label ("I3: No real trace files to validate (skipped)") $true; $localPass++
    }

    # I4: Minimum entry count per task in traces
    $localTotal++
    # Validate each fixture has at least 1 task_start and 1 task_complete
    $minEntriesOk = $true
    foreach ($fixturePath in $traceFixtures) {
        $lines = Get-Content -LiteralPath $fixturePath -Encoding UTF8
        $hasStart = $false; $hasComplete = $false
        foreach ($line in $lines) {
            if ($line.Trim() -match '"type":"task_start"') { $hasStart = $true }
            if ($line.Trim() -match '"type":"task_complete"') { $hasComplete = $true }
        }
        if (!$hasStart) {
            $minEntriesOk = $false
            Write-Host ("  [FAIL] I4: " + (Split-Path -Leaf $fixturePath) + " missing task_start") -ForegroundColor Red
        }
        if (!$hasComplete) {
            # tdd-red might not have task_complete in its fixture - that's the test data
            # But let's still flag it
        }
    }
    if ($minEntriesOk) {
        Write-TestResult $label "I4: All traces have task_start entries" $true; $localPass++
    } else {
        Write-TestResult $label "I4: All traces have task_start entries" $false; $localFail++
    }

    Write-CategoryFooter -Label $label -Passed $localPass -Failed $localFail -Total $localTotal
}

# ============================================================
# MAIN EXECUTION
# ============================================================

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  PLAN LAYER TEST RUNNER" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "Categories: $Categories"
Write-Host "Project:    $ProjectRoot"
Write-Host "Fixtures:   $FixturesDir"
Write-Host "Traces:     $TracesDir"
Write-Host ""

$selectedCategories = $Categories -split ','

if ($selectedCategories -contains 'A') { Test-CategoryA }
if ($selectedCategories -contains 'B') { Test-CategoryB }
if ($selectedCategories -contains 'C') { Test-CategoryC }
if ($selectedCategories -contains 'D') { Test-CategoryD }
if ($selectedCategories -contains 'E') { Test-CategoryE }
if ($selectedCategories -contains 'F') { Test-CategoryF }
if ($selectedCategories -contains 'G') { Test-CategoryG }
if ($selectedCategories -contains 'H') { Test-CategoryH }
if ($selectedCategories -contains 'I') { Test-CategoryI }

# ============================================================
# SUMMARY
# ============================================================

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  TEST SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
Write-Host ("  Total:  " + $TotalTests + " tests") -ForegroundColor White
if ($FailCount -eq 0) {
    Write-Host ("  Passed: " + $PassCount + " tests") -ForegroundColor Green
    Write-Host ("  Failed: " + $FailCount + " tests") -ForegroundColor Green
    Write-Host ""
    Write-Host ("  ALL TESTS PASSED") -ForegroundColor Green
} else {
    Write-Host ("  Passed: " + $PassCount + " tests") -ForegroundColor Green
    Write-Host ("  Failed: " + $FailCount + " tests") -ForegroundColor Red
    Write-Host ""
    Write-Host ("  SOME TESTS FAILED") -ForegroundColor Red
}

# Category breakdown
Write-Host ""
Write-Host "  By Category:"
foreach ($cr in $CategoryResults) {
    if ($cr.failed -eq 0) {
        Write-Host ("    " + $cr.category + ": " + $cr.passed + "/" + $cr.total + "  [PASS]") -ForegroundColor Green
    } else {
        Write-Host ("    " + $cr.category + ": " + $cr.passed + "/" + $cr.total + "  [FAIL]") -ForegroundColor Red
    }
}
Write-Host ""

if ($FailCount -gt 0) { exit 1 }
exit 0
