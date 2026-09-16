"""Build the bounded vault context packet.

Resolves the task-package unit and primary source, projects the target snapshot
slice, reads the independent teaching checkpoint, and reports cache eligibility.
Used by load-tech-learning-source and study-tech-learning.
"""
from __future__ import annotations

import argparse
import re

from vault_common import (ROOT, UNIT, load, ps, read, resolve_source, resolve_vault,
                      run, section, sha, slice_body, state_dir, state_path, utf8_stdout)


def build(args):
    vault = resolve_vault(args.vault)
    selected_unit = args.unit
    if not selected_unit and not args.material_only:
        active_path = state_dir(vault)/'active.json'
        if active_path.exists():
            active = load(active_path)
            if active.get('schema_version') != 1 or not UNIT.fullmatch(active.get('unit', '')):
                raise ValueError('Invalid active checkpoint pointer')
            selected_unit = active['unit']
            prior_path = state_path(vault, selected_unit)
            if prior_path.exists() and not args.slice and not args.locator:
                prior = load(prior_path)
                if prior.get('status') == 'delivered' and not prior.get('pending_questions') and prior.get('next_unit'):
                    selected_unit = prior['next_unit']
                    # Carry the explicit cross-unit handoff, not the new task's material cursor.
                    args = argparse.Namespace(**vars(args))
                    args.slice = prior.get('next_slice')
                    args.locator = prior.get('next_locator')
    resolved = resolve_source(vault, selected_unit)
    unit = resolved['unit']
    path = state_path(vault, unit)
    state = load(path) if path.exists() else None
    if state and (state.get('schema_version') != 1 or state.get('unit') != unit):
        raise ValueError('Incompatible checkpoint; select a position explicitly')
    snapshot = resolved.get('learning_snapshot')
    text = read(snapshot) if snapshot else ''
    selected, locator = args.slice, args.locator
    selection = 'explicit' if selected or locator else None
    warnings = []
    if not selection and args.material_only:
        locator = resolved.get('snapshot_next_locator') or resolved['primary_source']['locator']
        selection = 'material-cursor'
    elif not selection and state:
        if state.get('source') and state['source'] != resolved['primary_source']['code']:
            warnings.append('source_changed: verify target source before reuse')
        can_advance = state['status'] == 'delivered' and not state.get('pending_questions')
        selected = (state.get('next_slice') if can_advance else None) or state.get('slice')
        locator = (state.get('next_locator') if can_advance else None) or state.get('locator')
        # A next locator without a next slice must not accidentally select the old slice.
        if can_advance and state.get('next_locator') and not state.get('next_slice'):
            selected = None
        selection = 'teaching-checkpoint'
        if state['status'] == 'pending':
            warnings.append('delivery_unconfirmed: reconcile visible response; do not skip from an unsent draft')
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
    target_hash = sha((row+'\n'+body).encode('utf-8')) if body else None
    # Compare the saved slice, not a newly selected next slice, with its original hash.
    if state and state.get('target_sha256') and state.get('slice'):
        saved_row = next((line for line in rows if line.split('|')[1].strip() == state['slice']), '')
        saved_body = slice_body(text, state['slice'])
        saved_hash = sha((saved_row+'\n'+saved_body).encode('utf-8')) if saved_body else None
        if saved_hash != state['target_sha256']:
            warnings.append('target_changed: reconcile affected mechanism; unrelated material is not invalidated')
    validation = ps(ROOT/'scripts/validate-snapshot.ps1', '-Snapshot', snapshot) if body else None
    cache = resolved.get('snapshot_cache', {})
    candidate = bool(body and row and validation and validation['valid'] and
                     all(cache.get(k) for k in ('unit_matches', 'primary_source_matches', 'status_eligible')))
    source_fields = section(text, '来源与定位')
    # Only locator/source lines, not whole-task maps and teaching summaries.
    source_fields = '\n'.join(line for line in source_fields.splitlines()
                              if re.match(r'^- (任务包|主源|来源角色|actual_locator|源锚点)[：:]', line))
    # Historical exercise/completion reminders never become acquisition or study gates.
    blockers = '\n'.join(line for line in section(text, '遗留问题与阻塞').splitlines()
                         if not re.match(r'^- (在线站点交互题|引导项目|后续课程中的其他 workshop)', line)) if body else ''
    return {'unit': unit, 'task': resolved['task'], 'source': resolved['primary_source'],
            'gap_source': resolved.get('gap_source'), 'selection': selection or 'needs-position',
            'slice': selected, 'locator': locator, 'material_next_locator': resolved.get('snapshot_next_locator'),
            'teaching_checkpoint': state, 'state_revision': state['revision'] if state else 0,
            'snapshot_path': snapshot, 'cache_candidate': candidate,
            'source_verified_at': cache.get('source_verified_at'), 'source_fields': source_fields,
            'target_row': row, 'target_body': body, 'target_sha256': target_hash,
            'blockers': blockers,
            'validation': validation, 'warnings': warnings,
            'next_action': ('ask_position_once_or_accept_user_selection' if not selection else
                            'review_target_content' if candidate else 'acquire_exact_selected_source'),
            'loaded_characters': len(source_fields)+len(row)+len(body)+len(blockers)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vault')
    parser.add_argument('--unit')
    parser.add_argument('--slice')
    parser.add_argument('--locator')
    parser.add_argument('--material-only', action='store_true')
    args = parser.parse_args()
    return run(lambda: build(args))


if __name__ == '__main__':
    utf8_stdout()
    raise SystemExit(main())
