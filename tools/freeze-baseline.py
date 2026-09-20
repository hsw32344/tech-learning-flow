"""Freeze the current working-tree baseline (hashes + git state).

Usage:
    uv run python tools/freeze-baseline.py --output tests/baselines/baseline-0.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
EXCLUDED_DIRS = {".git"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def walk_files() -> list[Path]:
    files: list[Path] = []
    for path in REPO.rglob("*"):
        if any(part in EXCLUDED_DIRS for part in path.parts):
            continue
        if path.is_file():
            files.append(path)
    return sorted(files, key=lambda item: item.as_posix())


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True,
                            encoding="utf-8", errors="replace")
    return (result.stdout or "").strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="tests/baselines/baseline-0.json")
    parser.add_argument("--label", default="baseline-0")
    args = parser.parse_args()

    hashes = {}
    for path in walk_files():
        relative = path.relative_to(REPO).as_posix()
        hashes[relative] = {"sha256": sha256(path), "size": path.stat().st_size}

    status_lines = [line for line in git("status", "--porcelain").splitlines() if line.strip()]
    report = {
        "label": args.label,
        "created": date.today().isoformat(),
        "git_head": git("rev-parse", "HEAD"),
        "git_branch": git("branch", "--show-current"),
        "git_status": status_lines,
        "git_diff_stat": git("diff", "--stat"),
        "pre_existing_changes": [
            "analyze-job-requirements/scripts/validate-vault.ps1",
            "direct-tech-learning/scripts/validate-vault.ps1",
            "load-tech-learning-source/scripts/validate-snapshot.ps1",
            "record-tech-learning/scripts/validate-vault.ps1",
            "study-tech-learning/scripts/validate-snapshot.ps1",
            "study-tech-learning/scripts/validate-vault.ps1",
            "validation_v1.md",
        ],
        "file_count": len(hashes),
        "file_hashes": hashes,
    }
    output = REPO / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"baseline written: {output}")
    print(f"files: {len(hashes)}  head: {report['git_head'][:12]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
