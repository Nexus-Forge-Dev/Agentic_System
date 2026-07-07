<#
.SYNOPSIS
  Append an execution trace entry to the current session's .exec.jsonl file.
.DESCRIPTION
  Part of the Forge Nexus unified trace system.
  Each invocation appends one JSON line to .agents/traces/<session-id>.exec.jsonl.
.PARAMETER SessionId
  The current session ID (e.g. sess_dashboard_20260612).
.PARAMETER Type
  Trace entry type: task_start|task_complete|skill_load|command_ref|file_read|file_write|audit_write|tool_invoke|agent_delegate|decision
.PARAMETER Name
  Name of the thing being traced.
.PARAMETER Detail
  Human-readable context string.
.PARAMETER Phase
  "execute" (default) or "plan".
.EXAMPLE
  .agents\scripts\append-trace.ps1 -SessionId sess_demo -Type task_start -Name task_001 -Detail "Building auth service"
#>

param(
  [Parameter(Mandatory=$true)] [string]$SessionId,
  [Parameter(Mandatory=$true)] [string]$Type,
  [Parameter(Mandatory=$true)] [string]$Name,
  [Parameter(Mandatory=$false)] [string]$Detail = "",
  [Parameter(Mandatory=$false)] [string]$Phase = "execute",
  [Parameter(Mandatory=$false)] [string]$Result = ""
)

$TRACE_DIR = Join-Path (Split-Path -Parent $PSScriptRoot) "traces"
$TRACE_FILE = Join-Path $TRACE_DIR "${SessionId}.exec.jsonl"

$entry = @{
  ts = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
  phase = $Phase
  type = $Type
  name = $Name
}

if ($Detail) { $entry.detail = $Detail }
if ($Result) { $entry.result = $Result }

$jsonLine = ConvertTo-Json -Compress -InputObject $entry

# Ensure directory exists
if (-not (Test-Path $TRACE_DIR)) { New-Item -ItemType Directory -Path $TRACE_DIR -Force | Out-Null }

# Append to file (create if not exists)
Add-Content -LiteralPath $TRACE_FILE -Value $jsonLine -Encoding UTF8

Write-Output "trace: $Type $Name -> $TRACE_FILE"
