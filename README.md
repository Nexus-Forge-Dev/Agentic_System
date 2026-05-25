# Forge Nexus — Agentic System

This repository contains the complete specification, rules, shims, and personas for the Forge Nexus multi-agent system.

## Structure

- `.agents/`: The canonical source of the agent system.
  - `personas/`: Roster of 28 agent personas.
  - `commands/`: 43 composite skills (slash commands).
  - `rules/`: Constituents, protocols, and division-specific rules.
- `design_docs/`: The 4 detailed design documents defining the system.
- `scripts/`: System tools like `sync-adapters.py`.
- `CLAUDE.md` / `AGENTS.md` / `.cursor/rules/`: Compatibility shims for various AI coding tools (Claude Code, Cursor, OpenCode, Codex).

## Synchronization
If you modify files inside `.agents/`, run:
```bash
python scripts/sync-adapters.py
```
This will regenerate all shims in the repository root.
