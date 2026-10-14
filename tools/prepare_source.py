"""Create a portable source archive without local builds or credentials.

Run from any directory: python tools/prepare_source.py
Uses only the Python standard library. Does not run Git or contact a server.
"""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
DIRECTORIES = {
    "addons", "assets", "data", "docs", "feature_profiles", "scenes",
    "script_templates", "scripts", "settings", "tests", "texture",
    "text_editor_themes", "tools", "web", ".github",
}
EXCLUDED_DIRS = {
    ".git", ".godot", ".tools", ".agents", ".codex", ".claude", ".cursor",
    "node_modules", "__pycache__", "skills", "build", "test-output",
}
EXCLUDED_NAMES = {
    "AGENTS.md", "CLAUDE.md", "SKILL.md", ".mcp.json", ".cursorrules",
    "export_credentials.cfg", "copilot-instructions.md",
}


def include(path: Path) -> bool:
    relative = path.relative_to(ROOT)
    if not path.is_file() or path.is_symlink():
        return False
    if set(relative.parts[:-1]) & EXCLUDED_DIRS:
        return False
    if path.name in EXCLUDED_NAMES or path.name.startswith(".env"):
        return False
    if path.suffix in {".log", ".tmp", ".bak", ".pyc"}:
        return False
    if path.suffix.startswith(".blend") and path.suffix[6:].isdigit():
        return False
    return len(relative.parts) == 1 or relative.parts[0] in DIRECTORIES


def main() -> None:
    candidates = list(ROOT.iterdir())
    for name in DIRECTORIES:
        directory = ROOT / name
        if directory.is_dir(): candidates.extend(directory.rglob("*"))
    files = sorted(p for p in candidates if include(p))
    large = [p for p in files if p.stat().st_size >= 100 * 1024 * 1024]
    if large:
        raise SystemExit("GitHub file limit exceeded: " + ", ".join(str(p.relative_to(ROOT)) for p in large))
    output = ROOT / "build" / "FreeKick-Source.zip"
    output.parent.mkdir(exist_ok=True)
    with ZipFile(output, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            archive.write(path, path.relative_to(ROOT).as_posix())
    with ZipFile(output) as archive:
        assert archive.testzip() is None, "Archive integrity check failed"
        assert "project.godot" in archive.namelist(), "Missing root project file"
        assert all(include(ROOT / name) for name in archive.namelist()), "Excluded file entered archive"
    print(f"Source archive: {output} ({len(files)} files, {output.stat().st_size / 1024**2:.2f} MiB)")


if __name__ == "__main__":
    main()
