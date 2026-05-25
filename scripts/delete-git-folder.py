import os
import stat
import shutil
from pathlib import Path

target_dir = Path("c:/Project_New/Agentic_System/.agents/skills/ui-ux-pro-max/.git")

def remove_readonly(func, path, excinfo):
    os.chmod(path, stat.S_IWRITE)
    func(path)

def main():
    if target_dir.exists():
        print(f"Removing: {target_dir}")
        shutil.rmtree(target_dir, onerror=remove_readonly)
        print("Successfully removed .git folder!")
    else:
        print(f"Directory not found: {target_dir}")

if __name__ == "__main__":
    main()
