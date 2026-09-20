"""Sync shared assets from shared/ to their declared skill copies.

Usage:
    uv run python tools/sync-skill-assets.py --check            # verify copies
    uv run python tools/sync-skill-assets.py --check --json r.json
    uv run python tools/sync-skill-assets.py --write            # regenerate copies

--check is read-only and exits 1 on any drift, missing file, or extra file.
--write copies byte-for-byte (encoding and line endings preserved), removes
files that are no longer declared inside managed directories, and is
idempotent: running it twice produces no further changes. Skill packages stay
self-contained; running this tool is a maintenance action for the repository,
never a requirement for using a skill.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MANIFEST = REPO / "tools" / "skill-assets-manifest.json"
VALIDATION_REGISTRY = REPO / "shared" / "assets" / "validation-registry.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def file_map(path: Path) -> dict[str, str]:
    if path.is_file():
        return {"": sha256(path)}
    mapping: dict[str, str] = {}
    for child in sorted(path.rglob("*")):
        if child.is_file():
            mapping[child.relative_to(path).as_posix()] = sha256(child)
    return mapping


def check_group(group: dict) -> list[dict]:
    name = group["group"]
    source = REPO / group["source"]
    problems: list[dict] = []
    if not source.exists():
        return [{"group": name, "kind": "missing-source", "path": group["source"]}]
    source_map = file_map(source)
    for copy in group["copies"]:
        copy_path = REPO / copy
        if not copy_path.exists():
            problems.append({"group": name, "kind": "missing-copy", "path": copy})
            continue
        copy_map = file_map(copy_path)
        for relative, digest in source_map.items():
            other = copy_map.get(relative)
            label = f"{copy}/{relative}".rstrip("/")
            if other is None:
                problems.append({"group": name, "kind": "missing-file", "path": label})
            elif other != digest:
                problems.append({"group": name, "kind": "drift", "path": label})
        for relative in sorted(set(copy_map) - set(source_map)):
            problems.append({"group": name, "kind": "unexpected-file", "path": f"{copy}/{relative}".rstrip("/")})
    return problems


def write_group(group: dict) -> list[dict]:
    name = group["group"]
    source = REPO / group["source"]
    changes: list[dict] = []
    if not source.exists():
        return [{"group": name, "kind": "missing-source", "path": group["source"]}]
    source_map = file_map(source)
    for copy in group["copies"]:
        copy_path = REPO / copy
        copy_path.parent.mkdir(parents=True, exist_ok=True)
        if source.is_file():
            if not copy_path.exists() or sha256(copy_path) != source_map[""]:
                shutil.copyfile(source, copy_path)
                changes.append({"group": name, "kind": "written", "path": copy})
            continue
        for relative in sorted(source_map):
            target = copy_path / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists() or sha256(target) != source_map[relative]:
                shutil.copyfile(source / relative, target)
                changes.append({"group": name, "kind": "written", "path": f"{copy}/{relative}"})
        copy_map = file_map(copy_path)
        for relative in sorted(set(copy_map) - set(source_map)):
            (copy_path / relative).unlink()
            changes.append({"group": name, "kind": "removed", "path": f"{copy}/{relative}"})
    return changes


def skill_of(copy: str) -> str:
    return copy.split("/", 1)[0]


def check_group_skills(manifest: dict) -> list[dict]:
    """The declared skill set must match the copies exactly (no missing, no extra)."""
    problems: list[dict] = []
    for group in manifest["assets"]:
        declared = group.get("skills")
        if declared is None:
            continue
        actual = {skill_of(copy) for copy in group["copies"]}
        for skill in sorted(set(declared) - actual):
            problems.append({"group": group["group"], "kind": "missing-skill-copy",
                             "path": f"{skill} lacks {group['group']}"})
        for skill in sorted(actual - set(declared)):
            problems.append({"group": group["group"], "kind": "over-distributed",
                             "path": f"{skill} should not receive {group['group']}"})
    return problems


def check_group_requires(manifest: dict) -> list[dict]:
    """Every declared runtime dependency must reach every skill that owns the group."""
    groups = {group["group"]: group for group in manifest["assets"]}
    problems: list[dict] = []
    for group in manifest["assets"]:
        optional = set(group.get("optional_requires", []))
        for required_name in group.get("requires", []) + sorted(optional):
            required = groups.get(required_name)
            if required is None:
                problems.append({"group": group["group"], "kind": "unknown-requirement",
                                 "path": f"{group['group']} requires {required_name}"})
                continue
            if required_name in optional:
                continue
            required_skills = {skill_of(copy) for copy in required["copies"]}
            for copy in group["copies"]:
                skill = skill_of(copy)
                if skill not in required_skills:
                    problems.append({"group": group["group"], "kind": "missing-requirement-copy",
                                     "path": f"{skill}: {group['group']} requires {required_name}"})
    return problems


def check_reference_extracts(manifest: dict) -> list[dict]:
    """A slice must be assembled from verbatim sections of its authoritative contract."""
    problems: list[dict] = []
    for group in manifest["assets"]:
        extract_of = group.get("extract_of")
        if not extract_of:
            continue
        source = REPO / extract_of
        slice_path = REPO / group["source"]
        if not source.is_file() or not slice_path.is_file():
            problems.append({"group": group["group"], "kind": "missing-extract-source",
                             "path": f"{group['source']} <- {extract_of}"})
            continue
        full_text = source.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        slice_text = slice_path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        full_sections = {section.rstrip("\n")
                         for section in re.findall(r"(?ms)^## .+?(?=^## |\Z)", full_text)}
        slice_sections = re.findall(r"(?ms)^## .+?(?=^## |\Z)", slice_text)
        headings = [section.splitlines()[0].strip() for section in slice_sections]
        if not slice_sections:
            problems.append({"group": group["group"], "kind": "empty-slice",
                             "path": group["source"]})
        duplicates = {heading for heading in headings if headings.count(heading) > 1}
        for heading in sorted(duplicates):
            problems.append({"group": group["group"], "kind": "duplicate-section",
                             "path": f"{group['source']}: {heading}"})
        for section in slice_sections:
            if section.rstrip("\n") not in full_sections:
                heading = section.splitlines()[0].strip()
                problems.append({"group": group["group"], "kind": "non-verbatim-section",
                                 "path": f"{group['source']}: {heading}"})
        for heading in group.get("required_sections", []):
            if headings.count(heading) != 1:
                problems.append({"group": group["group"], "kind": "missing-required-section",
                                 "path": f"{group['source']}: {heading}"})
    return problems


def check_script_dependencies(manifest: dict) -> list[dict]:
    """Every dot-source/import between managed scripts must be a declared requirement."""
    managed = {}
    for group in manifest["assets"]:
        source = group["source"]
        name = Path(source).name
        if Path(source).is_file() and name not in managed:
            managed[name] = group
    problems: list[dict] = []
    for group in manifest["assets"]:
        source = REPO / group["source"]
        if not source.is_file():
            continue
        text = source.read_text(encoding="utf-8-sig", errors="replace")
        referenced: set[str] = set()
        if source.suffix == ".ps1":
            for match in re.finditer(r"Join-Path \$(?:PSScriptRoot|scriptDir|scriptRoot) '([^']+)'", text):
                referenced.add(Path(match.group(1)).name)
        elif source.suffix == ".py":
            for match in re.finditer(r"^\s*(?:from|import)\s+([A-Za-z_][A-Za-z0-9_]*)", text, re.M):
                referenced.add(match.group(1) + ".py")
        declared = set(group.get("requires", [])) | set(group.get("optional_requires", []))
        for name in sorted(referenced):
            if name in managed and name != Path(group["source"]).name and name not in declared:
                problems.append({"group": group["group"], "kind": "undeclared-requirement",
                                 "path": f"{group['group']} references {name}"})
    return problems


def check_undeclared_copies(manifest: dict) -> list[dict]:
    """A managed file must not exist in a skill directory that is not declared."""
    problems: list[dict] = []
    skill_dirs = sorted(path for path in REPO.iterdir()
                        if path.is_dir() and (path / "SKILL.md").is_file())
    for group in manifest["assets"]:
        source = REPO / group["source"]
        if not source.is_file():
            continue
        name = source.name
        declared = set(group["copies"])
        for skill_dir in skill_dirs:
            for sub in ("scripts", "references", "assets"):
                candidate = skill_dir / sub / name
                if not candidate.is_file():
                    continue
                relative = candidate.relative_to(REPO).as_posix()
                if relative not in declared:
                    problems.append({"group": group["group"], "kind": "undeclared-copy",
                                     "path": relative})
    return problems


def check_validation_registry(manifest: dict) -> list[dict]:
    """Ensure action declarations and distributed runtime dependencies agree."""
    if not VALIDATION_REGISTRY.is_file():
        # The synchronizer is also used by generic asset-package tests and
        # external skill bundles. Only validate actions when this project opts
        # into the registry by providing it.
        return []
    try:
        registry = json.loads(VALIDATION_REGISTRY.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [{"group": "validation-registry", "kind": "invalid-registry",
                 "path": f"shared/assets/validation-registry.json: {error.msg}"}]
    groups = {group["group"]: group for group in manifest["assets"]}
    problems: list[dict] = []
    seen_actions: set[str] = set()

    def check_skill_copies(label: str, skills: list[str], dependency: str) -> None:
        group = groups.get(dependency)
        if group is None:
            problems.append({"group": "validation-registry", "kind": "unknown-dependency",
                             "path": f"{label}: {dependency}"})
            return
        copies = group["copies"]
        for skill in skills:
            prefix = f"{skill}/"
            if not any(copy.startswith(prefix) for copy in copies):
                problems.append({"group": "validation-registry", "kind": "missing-dependency-copy",
                                 "path": f"{label}: {skill} needs {dependency}"})

    for action in registry.get("actions", []):
        action_id = action.get("id")
        if not isinstance(action_id, str) or not action_id:
            problems.append({"group": "validation-registry", "kind": "invalid-registry",
                             "path": "action without id"})
            continue
        if action_id in seen_actions:
            problems.append({"group": "validation-registry", "kind": "invalid-registry",
                             "path": f"duplicate action: {action_id}"})
        seen_actions.add(action_id)
        skills = action.get("skills", [])
        dependencies = action.get("dependencies", [])
        writes = action.get("writes", [])
        impact_paths = action.get("default_paths", [])
        kinds = action.get("kinds", [])
        if not skills or not dependencies or not writes or not impact_paths or not kinds:
            problems.append({"group": "validation-registry", "kind": "invalid-registry",
                             "path": f"action lacks skills, kinds, writes, impact paths, or dependencies: {action_id}"})
            continue
        for dependency in dependencies:
            check_skill_copies(action_id, skills, dependency)

    for entry in registry.get("standalone", []):
        entry_id = entry.get("id")
        if not isinstance(entry_id, str) or not entry_id:
            problems.append({"group": "validation-registry", "kind": "invalid-registry",
                             "path": "standalone entry without id"})
            continue
        if entry_id in seen_actions:
            problems.append({"group": "validation-registry", "kind": "invalid-registry",
                             "path": f"duplicate validator id: {entry_id}"})
        seen_actions.add(entry_id)
        skills = entry.get("skills", [])
        script = entry.get("script")
        writes = entry.get("writes", [])
        if not skills or not script or not writes:
            problems.append({"group": "validation-registry", "kind": "invalid-registry",
                             "path": f"standalone entry lacks skills, script, or writes: {entry_id}"})
            continue
        check_skill_copies(entry_id, skills, script)
        for dependency in entry.get("dependencies", []):
            check_skill_copies(entry_id, skills, dependency)
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="verify copies against shared/")
    mode.add_argument("--write", action="store_true", help="regenerate copies from shared/")
    parser.add_argument("--json", help="write the report to this path")
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    output: list[dict] = []
    for group in manifest["assets"]:
        output.extend(check_group(group) if args.check else write_group(group))
    registry_problems = check_validation_registry(manifest)
    structural_problems: list[dict] = []
    structural_problems.extend(check_group_skills(manifest))
    structural_problems.extend(check_group_requires(manifest))
    structural_problems.extend(check_reference_extracts(manifest))
    structural_problems.extend(check_script_dependencies(manifest))
    structural_problems.extend(check_undeclared_copies(manifest))
    output.extend(registry_problems)
    output.extend(structural_problems)
    if args.json:
        Path(args.json).write_text(json.dumps({"changes": output}, ensure_ascii=False, indent=2),
                                   encoding="utf-8")
    for entry in output:
        print(f"[{entry['kind']}] {entry['path']} ({entry['group']})")
    print(f"mode={'check' if args.check else 'write'} groups={len(manifest['assets'])} "
          f"entries={len(output)}")
    return 1 if ((args.check and output) or registry_problems or structural_problems) else 0


if __name__ == "__main__":
    raise SystemExit(main())
