import shutil
from pathlib import Path

# Paths
WORKSPACE = Path(__file__).resolve().parent.parent
EXPORT_DIR = WORKSPACE / "Agentic_System"
ART_DIR = Path("C:/Users/sudev/.gemini/antigravity-ide/brain/59276e0d-6ed5-43d2-a7b3-f5af9b303c74")

# Design docs to copy
DESIGN_DOCS = [
    "agentic_system_design.md",
    "agents_and_skills_design.md",
    "communication_guardrails_errors.md",
    "research_council_design.md"
]

def copy_file(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    print(f"Copied: {src.name} -> {dst}")

def copy_dir(src, dst, ignore_patterns=None):
    if not src.exists():
        return
    dst.mkdir(parents=True, exist_ok=True)
    for path in src.rglob("*"):
        if path.is_file():
            # Check ignore patterns
            rel_path = path.relative_to(src)
            skip = False
            if ignore_patterns:
                for pat in ignore_patterns:
                    if pat in str(rel_path):
                        skip = True
                        break
            if not skip:
                target = dst / rel_path
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)

def main():
    print("Preparing export files...")

    # 1. Copy design docs
    for doc in DESIGN_DOCS:
        src = ART_DIR / doc
        if src.exists():
            copy_file(src, EXPORT_DIR / "design_docs" / doc)
        else:
            print(f"Warning: Design doc {doc} not found in {ART_DIR}")

    # 2. Copy .agents folder (excluding cache and local sessions logs to keep it clean)
    print("Copying .agents/ folder...")
    copy_dir(
        WORKSPACE / ".agents",
        EXPORT_DIR / ".agents",
        ignore_patterns=["cache", "sessions", "cost.jsonl", "audit.jsonl"]
    )

    # 3. Copy .cursor rules
    print("Copying .cursor/ rules...")
    copy_dir(WORKSPACE / ".cursor", EXPORT_DIR / ".cursor")

    # 4. Copy scripts folder
    print("Copying scripts/...")
    copy_file(WORKSPACE / "scripts" / "sync-adapters.py", EXPORT_DIR / "scripts" / "sync-adapters.py")

    # 5. Copy root shims
    print("Copying root shims...")
    copy_file(WORKSPACE / "CLAUDE.md", EXPORT_DIR / "CLAUDE.md")
    copy_file(WORKSPACE / "AGENTS.md", EXPORT_DIR / "AGENTS.md")

    # 6. Write a README for the new repo
    readme_content = """# Forge Nexus — Agentic System

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
"""
    with open(EXPORT_DIR / "README.md", "w", encoding="utf-8") as f:
        f.write(readme_content)
    print("Generated README.md in Agentic_System repository")
    
    print("Export preparation complete!")

if __name__ == "__main__":
    main()
