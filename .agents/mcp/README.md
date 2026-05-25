# MCP Tool Registry — README
# .agents/mcp/README.md

## Purpose

This directory defines the **operational contract** for all MCP tool usage:
- Which agents can call which tools
- Which operations require human approval (Tier 2) vs. auto-approved (Tier 1)
- Rate limits and retry policies per tool
- Cache TTLs for idempotent read operations

## Files

| File | Purpose |
|------|---------|
| `settings.json` | Full tool registry — tiers, limits, cache config |

## How Agents Use This

Every pre-flight sequence (Step 6: VALIDATE permissions) checks `settings.json`:

1. Agent identifies planned tool calls
2. Looks up each tool + operation in `settings.json`
3. Checks `tier_defaults[operation]`:
   - Tier 1 → auto-proceed
   - Tier 2 → request human approval before executing
   - Tier 3 → BLOCKED, log and stop
4. Checks `allowed_agents` → if agent not listed, BLOCKED
5. Checks cache before executing any read operation

## Connection vs. Registry

**This file ≠ MCP server connection config.**

Actual MCP server connection (URL, credentials) lives in your AI tool's settings:
- **Antigravity**: `C:\Users\<user>\.gemini\config\mcp_servers.json`
- **Claude Code**: `.claude/mcp.json` or global Claude settings
- **Cursor**: Cursor settings → MCP tab

This file tells agents HOW to use those connections safely.

## Adding a New Tool

1. Add entry to `settings.json` under `tools.<tool-name>`
2. Define tier_defaults for every operation (err on side of Tier 2)
3. Define rate_limit (ask the tool's docs for actual limits)
4. Define cache_ttl_seconds for all read operations
5. List allowed_agents (principle of least privilege — start narrow)
6. Run `/sync-adapters` to regenerate adapter files
