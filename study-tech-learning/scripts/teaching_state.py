"""Study-owned paths for the runtime teaching checkpoint."""
from pathlib import Path

from vault_common import UNIT


def state_dir(vault):
    return Path(vault).resolve() / '25-资源区' / '学习快照' / '.study-state'


def state_path(vault, unit):
    if not UNIT.fullmatch(unit):
        raise ValueError('Invalid unit')
    base = Path(vault).resolve() / '25-资源区' / '学习快照'
    candidate = state_dir(vault) / f'{unit}.json'
    if not candidate.resolve().is_relative_to(base.resolve()):
        raise ValueError('State path escapes snapshot directory')
    return candidate
