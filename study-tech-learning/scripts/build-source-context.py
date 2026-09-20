"""Build a material context without reading teaching runtime state."""
from __future__ import annotations

import argparse

from material_context import build_material_context
from vault_common import resolve_source, resolve_vault, run, utf8_stdout


def build(args):
    vault = resolve_vault(args.vault)
    resolved = resolve_source(vault, args.unit)
    selected, locator = args.slice, args.locator
    selection = 'explicit' if selected or locator else 'material-cursor'
    if not selected and not locator:
        locator = resolved.get('snapshot_next_locator') or resolved['primary_source']['locator']
    return build_material_context(resolved, selected, locator, selection)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vault')
    parser.add_argument('--unit')
    parser.add_argument('--slice')
    parser.add_argument('--locator')
    return run(lambda: build(parser.parse_args()))


if __name__ == '__main__':
    utf8_stdout()
    raise SystemExit(main())
