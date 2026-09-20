"""Role-neutral material context projection for one task package."""
from __future__ import annotations

import re

from vault_common import ROOT, ps, read, section, sha, slice_body


def build_material_context(resolved, selected=None, locator=None, selection=None):
    snapshot = resolved.get('learning_snapshot')
    text = read(snapshot) if snapshot else ''
    rows = [line for line in section(text, '已覆盖切片').splitlines()
            if re.match(r'^\|\s*\d+-\d+\s*\|', line)]
    if locator and not selected:
        candidates = [line for line in rows if locator in line]
        if len(candidates) == 1:
            selected = candidates[0].split('|')[1].strip()
    body = slice_body(text, selected) if selected else ''
    row = next((line for line in rows if line.split('|')[1].strip() == selected), '')
    if row and not locator:
        locator = row.split('|')[2].strip()
    target_hash = sha((row + '\n' + body).encode('utf-8')) if body else None
    validation = ps(ROOT / 'scripts/validate-snapshot.ps1', '-Snapshot', snapshot) if body else None
    cache = resolved.get('snapshot_cache', {})
    candidate = bool(body and row and validation and validation['valid'] and
                     all(cache.get(key) for key in ('unit_matches', 'primary_source_matches',
                                                    'source_role_matches', 'status_eligible')))
    source_fields = section(text, '来源与定位')
    source_fields = '\n'.join(line for line in source_fields.splitlines()
                              if re.match(r'^- (任务包|主源|来源角色|actual_locator|源锚点)[：:]', line))
    blockers = ('\n'.join(
        line for line in section(text, '遗留问题与阻塞').splitlines()
        if not re.match(r'^- (在线站点交互题|引导项目|后续课程中的其他 workshop)', line)
    ) if body else '')
    return {
        'schema_version': 1,
        'kind': 'material_context',
        'unit': resolved['unit'],
        'task': resolved['task'],
        'source': resolved['primary_source'],
        'gap_source': resolved.get('gap_source'),
        'selection': selection or 'needs-position',
        'slice': selected,
        'locator': locator,
        'material_next_locator': resolved.get('snapshot_next_locator'),
        'snapshot_path': snapshot,
        'cache_candidate': candidate,
        'source_verified_at': cache.get('source_verified_at'),
        'source_fields': source_fields,
        'target_row': row,
        'target_body': body,
        'target_sha256': target_hash,
        'blockers': blockers,
        'validation': validation,
        'warnings': [],
        'next_action': ('ask_position_once_or_accept_user_selection' if not selection else
                        'review_target_content' if candidate else 'acquire_exact_selected_source'),
        'loaded_characters': len(source_fields) + len(row) + len(body) + len(blockers),
    }
