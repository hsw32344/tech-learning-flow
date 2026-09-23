"""Measure validator runtime cost on isolated fixtures.

Usage:
    uv run python tools/benchmark-validation.py --fixture small --repeat 5
    uv run python tools/benchmark-validation.py --vault <path> --repeat 3 --json out.json

Fixture sizes: small=50 notes, medium=500, large=2000. Every run uses an
explicit -Vault path and a redirected USERPROFILE; the real Vault binding is
never touched.
"""
from __future__ import annotations

import argparse
import json
import shutil
import statistics
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))

from tests.fixtures.vault_factory import (  # noqa: E402
    DIRECT, SKILL_DIRS, make_vault, populate, run_ps, parse_json,
)

SCALE = {"small": 50, "medium": 500, "large": 2000}


def measure(label: str, script: Path, vault: Path, userprofile: Path, *extra: object,
            repeat: int = 5) -> dict:
    warmup = run_ps(script, "-Vault", vault, *extra, userprofile=userprofile)
    times = []
    for _ in range(repeat):
        started = time.perf_counter()
        result = run_ps(script, "-Vault", vault, *extra, userprofile=userprofile)
        times.append((time.perf_counter() - started) * 1000.0)
    try:
        payload = parse_json(result)
        valid = payload.get("valid")
    except AssertionError:
        valid = "unparseable"
    return {
        "label": label,
        "command": f"{script.name} {' '.join(str(e) for e in extra)}".strip(),
        "exit_code": result.returncode,
        "warmup_exit_code": warmup.returncode,
        "valid": valid,
        "stdout_bytes": len(result.stdout or ""),
        "median_ms": round(statistics.median(times), 1),
        "min_ms": round(min(times), 1),
        "max_ms": round(max(times), 1),
        "runs": repeat,
        "process_starts": repeat + 1,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", choices=sorted(SCALE), default="small")
    parser.add_argument("--vault", help="Use an existing Vault instead of building a fixture")
    parser.add_argument("--repeat", type=int, default=5)
    parser.add_argument("--json", help="Write the report to this path")
    args = parser.parse_args()

    temporary = tempfile.mkdtemp(prefix="tech-learning-bench-")
    userprofile = Path(temporary) / "profile"
    userprofile.mkdir(parents=True, exist_ok=True)
    try:
        if args.vault:
            vault = Path(args.vault).resolve()
        else:
            vault = make_vault(Path(temporary) / "vault")
            populate(vault, SCALE[args.fixture])
        strict = DIRECT / "scripts" / "validate-vault.ps1"
        thin_learning = SKILL_DIRS["record"] / "scripts" / "validate-learning.ps1"
        thin_atomic = SKILL_DIRS["record"] / "scripts" / "validate-atomic.ps1"
        change = SKILL_DIRS["record"] / "scripts" / "validate-change.ps1"
        sample_atomic = vault / "40-原子知识" / "基准" / "基准对象 0000 - 问题 0000.md"
        runs = [
            measure("core", strict, vault, userprofile, repeat=args.repeat),
            measure("strict", strict, vault, userprofile, "-Strict", repeat=args.repeat),
        ]
        if sample_atomic.exists():
            runs += [
                measure("thin-learning", thin_learning, vault, userprofile, repeat=args.repeat),
                measure("thin-atomic", thin_atomic, vault, userprofile, repeat=args.repeat),
                measure("change-batch", change, vault, userprofile,
                        "-Kinds", "atomic", "-Paths", sample_atomic, repeat=args.repeat),
                measure("action-atomic", SKILL_DIRS["record"] / "scripts" / "validate-action.ps1",
                        vault, userprofile, "-Action", "atomic-record", "-Path", sample_atomic,
                        repeat=args.repeat),
            ]
        report = {
            "fixture": args.fixture if not args.vault else "external",
            "note_count": SCALE.get(args.fixture) if not args.vault else None,
            "vault": str(vault),
            "runs": runs,
        }
        text = json.dumps(report, ensure_ascii=False, indent=2)
        if args.json:
            Path(args.json).write_text(text, encoding="utf-8")
            print(f"report written: {args.json}")
        for entry in runs:
            print(f"{entry['label']:10} median={entry['median_ms']:>8} ms  "
                  f"range=[{entry['min_ms']}, {entry['max_ms']}]  exit={entry['exit_code']}  "
                  f"stdout={entry['stdout_bytes']}B  valid={entry['valid']}")
        return 0
    finally:
        shutil.rmtree(temporary, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
