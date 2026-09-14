#!/usr/bin/env python3
"""
.agents/scripts/maintainability.py — Component Closure Maintainability Ratchet
Enforces Sensio-equivalent shrink-only technical debt baselines.

Usage:
  python3 .agents/scripts/maintainability.py <codebase> [--bootstrap]
"""

import sys
import os
import json
import re
from pathlib import Path

DEFAULT_LIMITS = {
    "sourceLines": 350,
    "functionLines": 120,
    "directCodeFilesPerDirectory": 12
}

EXCLUDED_DIRS = {
    ".git", "node_modules", "dist", "build", ".dart_tool", "coverage",
    ".idea", ".vscode", "ios", "android", "macos", "windows", "linux",
    "web", "test", "integration_test"
}

SOURCE_EXTENSIONS = {
    "node-backend": {".ts", ".js", ".mjs"},
    "flutter": {".dart"},
    "generic": {".ts", ".js", ".dart", ".py", ".sh"}
}

def load_registry(repo_root):
    conf_path = repo_root / ".agents" / "codebases.conf"
    if not conf_path.is_file():
        raise FileNotFoundError(f"Codebase registry not found at {conf_path}")

    codebases = {}
    with open(conf_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("|")
            if len(parts) >= 4:
                codebases[parts[0]] = {
                    "root": parts[1],
                    "kind": parts[2],
                    "source_roots": [s.strip() for s in parts[3].split(",") if s.strip()]
                }
    return codebases

def is_source_file(path, kind):
    name = path.name
    # Exclude generated code and specs
    if name.endswith(".g.dart") or name.endswith(".freezed.dart"):
        return False
    if name.endswith(".spec.ts") or name.endswith(".test.ts"):
        return False
    if name.endswith(".d.ts"):
        return False

    allowed_exts = SOURCE_EXTENSIONS.get(kind, SOURCE_EXTENSIONS["generic"])
    return path.suffix in allowed_exts

def count_lines(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        return sum(1 for _ in f)

def extract_functions(path, kind):
    """
    Language-aware function length measurement tracking open/close braces.
    """
    functions = []
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except Exception:
        return functions

    # Simple robust brace-depth function analyzer
    in_function = False
    brace_depth = 0
    func_start = 0

    # Common function declaration patterns
    if kind == "flutter":
        func_regex = re.compile(r'^\s*(Widget|void|Future|Stream|int|double|String|bool|[A-Z][a-zA-Z0-9<>_?]+)\s+([a-zA-Z0-9_]+)\s*\([^;]*$')
    else:
        func_regex = re.compile(r'^\s*(async\s+)?(function\s+[a-zA-Z0-9_]+|[a-zA-Z0-9_]+\s*\([^)]*\)\s*[:{]|[a-zA-Z0-9_]+\s*=\s*(async\s*)?\([^)]*\)\s*=>\s*\{)')

    for idx, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not in_function:
            # Check for function start
            if "{" in line and func_regex.search(line):
                in_function = True
                func_start = idx
                brace_depth = line.count("{") - line.count("}")
                if brace_depth <= 0:
                    # Single line function
                    in_function = False
        else:
            brace_depth += line.count("{") - line.count("}")
            if brace_depth <= 0:
                length = idx - func_start + 1
                if length > DEFAULT_LIMITS["functionLines"]:
                    functions.append(length)
                in_function = False
                brace_depth = 0

    return sorted(functions, reverse=True)

def count_bypasses(path, kind):
    count = 0
    patterns = [
        "// @ts-ignore", "/* @ts-ignore */",
        "// @ts-nocheck",
        "// eslint-disable", "/* eslint-disable",
        "// ignore:", "// ignore_for_file:"
    ]
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                for p in patterns:
                    if p in line:
                        count += 1
                        break
    except Exception:
        pass
    return count

def scan_codebase(repo_root, cb_name, cb_info):
    cb_dir = repo_root / cb_info["root"]
    kind = cb_info["kind"]
    source_roots = cb_info["source_roots"] or ["."]

    observed_files = {}
    observed_functions = {}
    observed_directories = {}
    observed_bypasses = {}

    for src_rel in source_roots:
        src_path = cb_dir / src_rel
        if not src_path.exists():
            continue

        for root, dirs, files in os.walk(src_path):
            # Prune excluded directories
            dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]

            rel_dir = Path(root).relative_to(repo_root).as_posix()
            code_files_in_dir = 0

            for file_name in files:
                file_path = Path(root) / file_name
                if not is_source_file(file_path, kind):
                    continue

                code_files_in_dir += 1
                rel_file = file_path.relative_to(repo_root).as_posix()

                # File lines
                lines = count_lines(file_path)
                if lines > DEFAULT_LIMITS["sourceLines"]:
                    observed_files[rel_file] = lines

                # Function lines
                funcs = extract_functions(file_path, kind)
                if funcs:
                    observed_functions[rel_file] = funcs

                # Bypasses
                bypasses = count_bypasses(file_path, kind)
                if bypasses > 0:
                    observed_bypasses[rel_file] = bypasses

            if code_files_in_dir > DEFAULT_LIMITS["directCodeFilesPerDirectory"]:
                observed_directories[rel_dir] = code_files_in_dir

    return {
        "codebase": cb_name,
        "limits": DEFAULT_LIMITS,
        "files": observed_files,
        "functions": observed_functions,
        "directories": observed_directories,
        "bypasses": observed_bypasses
    }

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 maintainability.py <codebase> [--bootstrap]")
        sys.exit(1)

    codebase = sys.argv[1]
    bootstrap = "--bootstrap" in sys.argv

    repo_root = Path(__file__).resolve().parent.parent.parent
    registry = load_registry(repo_root)

    if codebase not in registry:
        print(f"Error: Codebase '{codebase}' not found in registry (.agents/codebases.conf)")
        sys.exit(1)

    baseline_dir = repo_root / ".agents" / "maintainability"
    baseline_dir.mkdir(parents=True, exist_ok=True)
    baseline_file = baseline_dir / f"{codebase}.json"

    observed = scan_codebase(repo_root, codebase, registry[codebase])

    if bootstrap:
        with open(baseline_file, "w", encoding="utf-8") as f:
            json.dump(observed, f, indent=2)
        print(f"==> [maintainability] Bootstrapped exact baseline for '{codebase}': {baseline_file}")
        print(f"    Oversized files: {len(observed['files'])}")
        print(f"    Oversized functions in files: {len(observed['functions'])}")
        print(f"    Dense directories: {len(observed['directories'])}")
        print(f"    Files with bypasses: {len(observed['bypasses'])}")
        sys.exit(0)

    # Ratchet check mode
    if not baseline_file.is_file():
        print(f"Error: Baseline file not found for '{codebase}'. Run with --bootstrap first.")
        sys.exit(1)

    with open(baseline_file, "r", encoding="utf-8") as f:
        baseline = json.load(f)

    errors = []

    # 1. File line checks (shrink-only)
    b_files = baseline.get("files", {})
    for path, lines in observed["files"].items():
        if path not in b_files:
            errors.append(f"NEW DEBT: File '{path}' has {lines} lines (> {DEFAULT_LIMITS['sourceLines']}) and is not in baseline.")
        elif lines > b_files[path]:
            errors.append(f"REGRESSION: File '{path}' grew from {b_files[path]} to {lines} lines.")

    for path, b_lines in b_files.items():
        if path not in observed["files"]:
            errors.append(f"IMPROVEMENT: File '{path}' is now <= {DEFAULT_LIMITS['sourceLines']} lines. Remove from baseline!")
        elif observed["files"][path] < b_lines:
            errors.append(f"IMPROVEMENT: File '{path}' shrank from {b_lines} to {observed['files'][path]}. Lower the baseline!")

    # 2. Directory density checks
    b_dirs = baseline.get("directories", {})
    for path, count in observed["directories"].items():
        if path not in b_dirs:
            errors.append(f"NEW DEBT: Directory '{path}' has {count} code files (> {DEFAULT_LIMITS['directCodeFilesPerDirectory']}) and is not in baseline.")
        elif count > b_dirs[path]:
            errors.append(f"REGRESSION: Directory '{path}' grew from {b_dirs[path]} to {count} code files.")

    for path, b_count in b_dirs.items():
        if path not in observed["directories"]:
            errors.append(f"IMPROVEMENT: Directory '{path}' now has <= {DEFAULT_LIMITS['directCodeFilesPerDirectory']} code files. Remove from baseline!")
        elif observed["directories"][path] < b_count:
            errors.append(f"IMPROVEMENT: Directory '{path}' count reduced from {b_count} to {observed['directories'][path]}. Lower the baseline!")

    # 3. Bypass checks
    b_bypasses = baseline.get("bypasses", {})
    for path, count in observed["bypasses"].items():
        if path not in b_bypasses:
            errors.append(f"NEW DEBT: File '{path}' has {count} lint/type bypasses and is not in baseline.")
        elif count > b_bypasses[path]:
            errors.append(f"REGRESSION: File '{path}' bypass count grew from {b_bypasses[path]} to {count}.")

    for path, b_count in b_bypasses.items():
        if path not in observed["bypasses"]:
            errors.append(f"IMPROVEMENT: File '{path}' no longer has bypasses. Remove from baseline!")
        elif observed["bypasses"][path] < b_count:
            errors.append(f"IMPROVEMENT: File '{path}' bypass count dropped from {b_count} to {observed['bypasses'][path]}. Lower the baseline!")

    if errors:
        print(f"FAILED: Maintainability ratchet violations for '{codebase}':")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)

    print(f"PASSED: Maintainability ratchet satisfied for '{codebase}'.")

if __name__ == "__main__":
    main()
