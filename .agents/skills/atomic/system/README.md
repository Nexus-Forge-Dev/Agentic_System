# Atomic Skills: System-Level Primitives
# .agents/skills/atomic/system/README.md
# These are SYSTEM-LEVEL primitives — not user-invokable, used by the agent runtime
# Source: agents_and_skills_design.md §9.1 Tier 1 Atomic Skills

---

## System Primitives Inventory

These skills are the internal runtime operations of the agent system.
They are not slash commands. They are invoked by agents internally during execution.

| Skill | File | Purpose |
|-------|------|---------|
| `mcp_call` | mcp_call.md | Wrapper for all MCP tool invocations |
| `tool_cache_check` | tool_cache_check.md | Check cache before any tool invocation |
| `audit_log_write` | audit_log_write.md | Write a structured entry to audit.jsonl |
| `memory_read` | memory_read.md | Read and filter learned.jsonl |
| `memory_write` | memory_write.md | Write a new pattern to learned.jsonl |
| `context_compress` | context_compress.md | Apply compression protocol |
| `session_checkpoint` | session_checkpoint.md | Save current session state to disk |
| `delegate` | delegate.md | Pass work to another agent via Orchestrator |
| `timer` | timer.md | Non-blocking checkpoint timer |
| `notify` | notify.md | Send external notification (always Tier 2) |
