"""Write the optimistic teaching checkpoint under 25-资源区/学习快照/.study-state.

Owned by study-tech-learning. Stores only the teaching cursor and unresolved
questions; it is runtime state, never learner evidence.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import tempfile

from vault_common import SLICE, UNIT, load, resolve_vault, run, state_path, utf8_stdout


def checkpoint(args):
    path = state_path(args.vault, args.unit)
    data = load(args.input)
    allowed = {'status', 'source', 'slice', 'locator', 'mechanism', 'delivered_mechanisms',
               'pending_questions', 'next_action', 'next_unit', 'next_slice', 'next_locator', 'target_sha256'}
    if set(data) - allowed:
        raise ValueError('Unsupported state fields: '+', '.join(sorted(set(data)-allowed)))
    if data.get('status') not in {'pending', 'delivered', 'interrupted', 'user-selected'}:
        raise ValueError('Invalid checkpoint status')
    if not data.get('slice') and not data.get('locator'):
        raise ValueError('A slice or locator is required; no completion evidence is required')
    for key in ('slice', 'next_slice'):
        if data.get(key) and not SLICE.fullmatch(data[key]):
            raise ValueError('Invalid '+key)
    for key in ('delivered_mechanisms', 'pending_questions'):
        value = data.get(key, [])
        if not isinstance(value, list) or any(not isinstance(x, str) for x in value):
            raise ValueError(key+' must be a list of strings')
    for key in allowed-{'delivered_mechanisms', 'pending_questions'}:
        if key in data and not isinstance(data[key], str):
            raise ValueError(key+' must be a string')
    if data.get('target_sha256') and not re.fullmatch(r'[a-f0-9]{64}', data['target_sha256']):
        raise ValueError('Invalid target hash')
    if data.get('next_unit') and not UNIT.fullmatch(data['next_unit']):
        raise ValueError('Invalid next unit')
    if len(json.dumps(data, ensure_ascii=False)) > 12000:
        raise ValueError('Checkpoint is too large; keep only location and unresolved questions')
    path.parent.mkdir(parents=True, exist_ok=True)
    lock = path.parent/'state.lock'
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        raise ValueError('Checkpoint is locked; inspect the writer before retrying')
    temp = None
    try:
        os.close(fd)
        current = load(path) if path.exists() else {'revision': 0}
        if current['revision'] != args.expected_revision:
            raise ValueError(f'Revision conflict: expected {args.expected_revision}, actual {current["revision"]}')
        data = {'schema_version': 1, 'unit': args.unit, 'revision': current['revision']+1, **data}
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent,
                                         suffix='.tmp', delete=False) as stream:
            temp = Path(stream.name)
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
        active = path.parent/'active.json'
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent,
                                         suffix='.tmp', delete=False) as stream:
            temp = Path(stream.name)
            json.dump({'schema_version': 1, 'unit': args.unit}, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, active)
        return {'saved': str(path), 'revision': data['revision'], 'status': data['status']}
    finally:
        if temp and temp.exists():
            temp.unlink()
        lock.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vault')
    parser.add_argument('--unit', required=True)
    parser.add_argument('--input', required=True)
    parser.add_argument('--expected-revision', type=int, required=True)
    args = parser.parse_args()
    args.vault = resolve_vault(args.vault)
    return run(lambda: checkpoint(args))


if __name__ == '__main__':
    utf8_stdout()
    raise SystemExit(main())
