"""Build the bounded study context.

Resolves the task-package unit and primary source, projects the target snapshot
slice, reads the independent teaching checkpoint, and reports cache eligibility.
Owned by study-tech-learning.
"""
from __future__ import annotations

import argparse
import re
from material_context import build_material_context
from vault_common import (UNIT, load, read, resolve_source, resolve_vault, run, section,
                          sha, slice_body, utf8_stdout)
from teaching_state import state_dir, state_path


def build(args):
    vault = resolve_vault(args.vault)
    selected_unit = args.unit
    if not selected_unit:
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
    selected, locator = args.slice, args.locator
    selection = 'explicit' if selected or locator else None
    warnings = []
    if not selection and state:
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
    context = build_material_context(resolved, selected, locator, selection)
    context['kind'] = 'study_context'
    snapshot = resolved.get('learning_snapshot')
    text = read(snapshot) if snapshot else ''
    # Compare the saved slice, not a newly selected next slice, with its original hash.
    if state and state.get('target_sha256') and state.get('slice'):
        rows = [line for line in section(text, '已覆盖切片').splitlines()
                if re.match(r'^\|\s*\d+-\d+\s*\|', line)]
        saved_row = next((line for line in rows if line.split('|')[1].strip() == state['slice']), '')
        saved_body = slice_body(text, state['slice'])
        saved_hash = sha((saved_row+'\n'+saved_body).encode('utf-8')) if saved_body else None
        if saved_hash != state['target_sha256']:
            warnings.append('target_changed: reconcile affected mechanism; unrelated material is not invalidated')
    context['teaching_checkpoint'] = state
    context['state_revision'] = state['revision'] if state else 0
    context['warnings'].extend(warnings)
    return context


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vault')
    parser.add_argument('--unit')
    parser.add_argument('--slice')
    parser.add_argument('--locator')
    args = parser.parse_args()
    return run(lambda: build(args))


if __name__ == '__main__':
    utf8_stdout()
    raise SystemExit(main())
