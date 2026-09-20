"""Shared standard-library helpers for the tech-learning vault tools.

No third-party dependencies. These helpers only read files, resolve paths, and
run the packaged PowerShell tools; semantic judgment stays with the Agent.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
UNIT = re.compile(r'^[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-\d{2}$')
SLICE = re.compile(r'^\d+-\d+$')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return Path(path).read_text(encoding='utf-8-sig')


def load(path):
    return json.loads(read(path))


def default_vault():
    env = os.environ.get('TECH_LEARNING_VAULT')
    if env:
        return env
    base = os.environ.get('USERPROFILE') or os.path.expanduser('~')
    pointer = Path(base)/'.agents'/'tech-learning-flow'/'vault-path.txt'
    if pointer.exists():
        value = pointer.read_text(encoding='utf-8').strip()
        if value:
            return value
    return None


def resolve_vault(explicit):
    vault = explicit or default_vault()
    if not vault:
        raise ValueError('No vault bound; pass --vault or create %USERPROFILE%\\.agents\\tech-learning-flow\\vault-path.txt.')
    return vault


def plain_lines(text):
    """Mask code contents while retaining line positions for structural parsing."""
    fence = None
    result = []
    for line in text.splitlines():
        m = re.match(r'^\s*(`{3,}|~{3,})', line)
        if m:
            mark = m[1]
            if fence is None:
                fence = mark
            elif mark[0] == fence[0] and len(mark) >= len(fence):
                fence = None
            result.append('')
        else:
            result.append('' if fence else line)
    return result


def section(text, name):
    lines = text.splitlines()
    mask = plain_lines(text)
    start = next((i+1 for i, line in enumerate(mask) if line == '## '+name), None)
    if start is None:
        return ''
    end = next((i for i in range(start, len(mask)) if mask[i].startswith('## ')), len(lines))
    return '\n'.join(lines[start:end]).strip()


def slice_body(text, slice_id):
    body = section(text, '结构化知识点')
    lines, mask = body.splitlines(), plain_lines(body)
    starts = [i for i, line in enumerate(mask)
              if re.match(r'^### 切片\s+'+re.escape(slice_id)+r'\s*[:：]', line)]
    if len(starts) != 1:
        return ''
    start = starts[0]
    end = next((i for i in range(start+1, len(mask)) if mask[i].startswith('### ')), len(lines))
    return '\n'.join(lines[start:end]).strip()


def ps(script, *args):
    executable = shutil.which('pwsh')
    if not executable:
        raise ValueError('PowerShell 7 (pwsh) is required for the packaged vault tools')
    # Packaged scripts are UTF-8 with BOM, so `-File` preserves $PSScriptRoot and
    # the shared contract dot-source; no source re-decoding workaround is needed.
    command = [executable, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script), *map(str, args)]
    cp = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout = cp.stdout.decode('utf-8-sig', errors='replace').strip()
    try:
        result = json.loads(stdout)
    except json.JSONDecodeError:
        raise ValueError(cp.stderr.decode('utf-8', errors='replace') or stdout)
    if cp.returncode and 'valid' not in result:
        raise ValueError(str(result))
    return result


def resolve_source(vault, unit=None):
    script = ROOT/'scripts/resolve-source.ps1'
    if not script.exists():
        raise ValueError('Packaged unit/source resolver not found: '+str(script))
    args = ['-VaultRoot', vault, '-PluginRoot', ROOT]
    if unit:
        args += ['-UnitId', unit]
    return ps(script, *args)


def emit(result):
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if result.get('valid') is False else 0


def run(handler):
    try:
        return emit(handler())
    except (ValueError, OSError, KeyError, TypeError) as exc:
        print(json.dumps({'error': str(exc)}, ensure_ascii=False))
        return 1


def utf8_stdout():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
