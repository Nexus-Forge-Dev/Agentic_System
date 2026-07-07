<#
.SYNOPSIS
  Tool result cache for Forge Nexus agents. Implements the cache layer
  defined in .agents/rules/tool-call-lifecycle.md §Cache Key Schema.

  Usage:
    cache.ps1 check <tool> <operation> <inputs_json>
      → Returns cached result JSON path, or exits with code 1 if miss/expired

    cache.ps1 write <tool> <operation> <inputs_json> <result_json> <ttl_seconds>
      → Writes result to .agents/cache/<tool>/<hash>.json

    cache.ps1 clear [tool]
      → Removes expired entries. If tool given, clears only that tool's cache.
#>

param (
  [Parameter(Position = 0, Mandatory = $true)]
  [ValidateSet("check", "write", "clear")]
  [string]$Action,

  [Parameter(Position = 1)]
  [string]$Tool,

  [Parameter(Position = 2)]
  [string]$Operation,

  [Parameter(Position = 3)]
  [string]$Inputs,

  [Parameter(Position = 4)]
  [string]$Result,

  [Parameter(Position = 5)]
  [int]$TtlSeconds = 300
)

$CacheRoot = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath "cache"

function Get-CacheHash {
  param([string]$Tool, [string]$Operation, [string]$InputsJson)
  $combined = "$Tool`:$Operation`:$InputsJson"
  $hashBytes = [System.Text.Encoding]::UTF8.GetBytes($combined)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $hash = $sha.ComputeHash($hashBytes)
  return [System.BitConverter]::ToString($hash[0..7]) -replace '-', '' -replace ' ', '' | ForEach-Object { $_.ToLower() }
}

function Get-CachePath {
  param([string]$Tool, [string]$Hash)
  $dir = Join-Path -Path $CacheRoot -ChildPath $Tool
  if (-not (Test-Path $dir)) { return $null }
  return Join-Path -Path $dir -ChildPath "$Hash.json"
}

function Read-CacheEntry {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return $null }
  try {
    $entry = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $expiresAt = [DateTime]::Parse($entry.expires_at)
    if ([DateTime]::UtcNow -gt $expiresAt) {
      Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
      return $null
    }
    return $entry
  } catch { return $null }
}

function Write-CacheEntry {
  param([string]$Tool, [string]$Hash, [string]$Operation, [string]$InputsJson, [string]$ResultJson, [int]$Ttl)
  $dir = Join-Path -Path $CacheRoot -ChildPath $Tool
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

  $now = [DateTime]::UtcNow
  $expiresAt = $now.AddSeconds($Ttl)

  $entry = @{
    key         = $Hash
    tool        = $Tool
    operation   = $Operation
    inputs      = $InputsJson
    result      = $ResultJson
    ts          = $now.ToString("yyyy-MM-ddTHH:mm:ssZ")
    ttl_seconds = $Ttl
    expires_at  = $expiresAt.ToString("yyyy-MM-ddTHH:mm:ssZ")
  }

  $path = Join-Path -Path $dir -ChildPath "$Hash.json"
  $entry | ConvertTo-Json -Depth 10 -Compress | Set-Content -Path $path -Encoding UTF8 -NoNewline
  return $path
}

function Clear-ExpiredEntries {
  param([string]$ToolFilter)
  if ($ToolFilter) {
    $dirs = @(Join-Path -Path $CacheRoot -ChildPath $ToolFilter)
  } else {
    $dirs = Get-ChildItem -Path $CacheRoot -Directory | ForEach-Object { $_.FullName }
  }

  $removed = 0
  foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) { continue }
    $entries = Get-ChildItem -Path $dir -Filter "*.json"
    foreach ($entry in $entries) {
      try {
        $content = Get-Content -Path $entry.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $expiresAt = [DateTime]::Parse($content.expires_at)
        if ([DateTime]::UtcNow -gt $expiresAt) {
          Remove-Item -Path $entry.FullName -Force -ErrorAction SilentlyContinue
          $removed++
        }
      } catch { continue }
    }
  }
  return $removed
}

# ---- Main dispatch ----
switch ($Action) {
  "check" {
    if (-not $Tool -or -not $Operation -or -not $Inputs) {
      Write-Error "Usage: cache.ps1 check <tool> <operation> <inputs_json>"
      exit 1
    }
    $hash = Get-CacheHash -Tool $Tool -Operation $Operation -InputsJson $Inputs
    $path = Get-CachePath -Tool $Tool -Hash $hash
    if (-not $path) { exit 1 }
    $entry = Read-CacheEntry -Path $path
    if (-not $entry) { exit 1 }
    Write-Output ($entry.result | ConvertTo-Json -Depth 10 -Compress)
    exit 0
  }

  "write" {
    if (-not $Tool -or -not $Operation -or -not $Inputs -or -not $Result) {
      Write-Error "Usage: cache.ps1 write <tool> <operation> <inputs_json> <result_json> <ttl_seconds>"
      exit 1
    }
    $hash = Get-CacheHash -Tool $Tool -Operation $Operation -InputsJson $Inputs
    $path = Write-CacheEntry -Tool $Tool -Hash $hash -Operation $Operation -InputsJson $Inputs -ResultJson $Result -Ttl $TtlSeconds
    Write-Output $path
    exit 0
  }

  "clear" {
    $removed = Clear-ExpiredEntries -ToolFilter $Tool
    Write-Output "Cleared $removed expired entries"
    exit 0
  }
}
