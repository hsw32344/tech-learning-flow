"""Validate a natural-layout study draft and its version-2 Agent content review.

The tool owns the draft hash and the ordered block spans/hashes (including
code fences); the Agent owns the goal, source declarations, block-to-source
mapping and the six content checks. Legacy seven-section drafts are validated
only when ``--format legacy`` is passed explicitly. Structure and review
coverage are mechanical; semantic judgment remains the Agent's responsibility.
Owned by study-tech-learning.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from vault_common import load, plain_lines, run, section, sha, utf8_stdout

NATURAL_CRITERIA = ['focus', 'model', 'example', 'operation', 'depth', 'source']
LESSON_KINDS = ['operation', 'concept', 'mixed']
SOURCE_ROLES = ['primary', 'supplement', 'fallback']
STATUSES = ['pass', 'fail', 'uncertain', 'not_applicable']

HEADINGS = ['一、已核验来源与覆盖范围', '二、应掌握地图', '三、主源忠实讲解',
            '四、结构化知识点', '五、块级总结', '六、岗位/面试映射', '七、事实收尾']
FIELDS = ['机制', '底层规则', '应用例子', '预期结果', '边界/错误', '需要记忆', '需要理解']
CRITERIA = ['question', 'state', 'rule', 'trace', 'boundary', 'understanding']
SOURCE_CHECKS = ['coverage', 'fidelity', 'correctness']


def split_blocks(text):
    """Ordered evidence blocks bounded by level-1/2 headings; fences are data."""
    lines = text.splitlines(keepends=True)
    mask = plain_lines(text)
    heads = [i for i, line in enumerate(mask) if re.match(r'^#{1,2} ', line.strip())]
    starts = [0] + [h for h in heads if h != 0]
    blocks = []
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else len(lines)
        body = ''.join(lines[start:end])
        if not body.strip():
            continue
        label = ''
        if start < len(mask) and re.match(r'^#{1,2} ', mask[start].strip()):
            label = mask[start].strip()
        else:
            for probe in range(start, end):
                candidate = mask[probe].strip() if probe < len(mask) else ''
                if candidate:
                    label = candidate[:48]
                    break
            if not label:
                label = 'empty block'
        blocks.append({
            'id': 'B%d' % (len(blocks) + 1),
            'span': [start, end],
            'label': label,
            'sha256': sha(body.encode('utf-8')),
        })
    return blocks


def build_natural_scaffold(raw, blocks):
    return {
        'schema_version': 2,
        'draft_sha256': sha(raw),
        'goal': '',
        'lesson_kind': '',
        'sources': [],
        'blocks': {
            block['id']: {'span': block['span'], 'label': block['label'],
                          'sha256': block['sha256'], 'sources': []}
            for block in blocks
        },
        'checks': {
            name: {'status': '', 'evidence': [], 'reason': ''}
            for name in NATURAL_CRITERIA
        },
    }


def validate_natural(review, raw, blocks):
    issues = []
    if not isinstance(review, dict):
        return ['Content review malformed']
    if review.get('schema_version') != 2:
        issues.append('Natural review requires schema_version 2 (use --format legacy for historical drafts)')
    if review.get('draft_sha256') != sha(raw):
        issues.append('Content review missing or stale: draft hash mismatch')
    goal = review.get('goal')
    if not isinstance(goal, str) or not goal.strip():
        issues.append('goal missing or empty')
    kind = review.get('lesson_kind')
    if kind not in LESSON_KINDS:
        issues.append('lesson_kind must be one of: ' + ', '.join(LESSON_KINDS))

    source_ids = []
    sources = review.get('sources')
    if not isinstance(sources, list) or not sources:
        issues.append('sources missing or empty')
    else:
        for item in sources:
            if not isinstance(item, dict):
                issues.append('source entry malformed')
                continue
            sid = item.get('id')
            if not isinstance(sid, str) or not sid.strip():
                issues.append('source id missing')
                sid = str(sid)
            elif sid in source_ids:
                issues.append('duplicate source id: ' + sid)
            else:
                source_ids.append(sid)
            locator = item.get('locator')
            if not isinstance(locator, str) or not locator.strip():
                issues.append(sid + ': source locator missing')
            if item.get('role') not in SOURCE_ROLES:
                issues.append(sid + ': source role must be one of: ' + ', '.join(SOURCE_ROLES))

    expected = {block['id']: block for block in blocks}
    reviewed_blocks = review.get('blocks')
    used_sources = set()
    if not isinstance(reviewed_blocks, dict):
        issues.append('blocks mapping missing')
    else:
        if set(reviewed_blocks) != set(expected):
            issues.append('Review must cover exactly the rendered blocks; re-emit the scaffold after changes')
        for bid, block in expected.items():
            entry = reviewed_blocks.get(bid)
            if not isinstance(entry, dict):
                issues.append(bid + ': block entry missing')
                continue
            if entry.get('sha256') != block['sha256'] or list(entry.get('span') or []) != list(block['span']):
                issues.append(bid + ': block hash or span mismatch (stale review)')
            if entry.get('label') != block['label']:
                issues.append(bid + ': block label mismatch (stale review)')
            mapped = entry.get('sources')
            if not isinstance(mapped, list) or not mapped:
                issues.append(bid + ': no source mapped')
            else:
                for sid in mapped:
                    if sid not in source_ids:
                        issues.append(bid + ': unknown source ' + str(sid))
                    elif isinstance(sid, str):
                        used_sources.add(sid)
        for sid in source_ids:
            if sid not in used_sources:
                issues.append('Declared source is not mapped to any block: ' + sid)

    checks = review.get('checks')
    if not isinstance(checks, dict):
        issues.append('checks missing')
        return issues
    if set(checks) != set(NATURAL_CRITERIA):
        issues.append('checks must cover exactly: ' + ', '.join(NATURAL_CRITERIA))
    block_ids = set(expected)
    for name in NATURAL_CRITERIA:
        entry = checks.get(name)
        if not isinstance(entry, dict):
            issues.append(name + ': unreviewed')
            continue
        status = entry.get('status')
        if status not in STATUSES:
            issues.append(name + ': unreviewed')
            continue
        reason = entry.get('reason')
        if not isinstance(reason, str) or not reason.strip():
            issues.append(name + ': reason missing')
        evidence = entry.get('evidence')
        if not isinstance(evidence, list) or not evidence:
            issues.append(name + ': block evidence missing')
        else:
            for bid in evidence:
                if bid not in block_ids:
                    issues.append(name + ': unknown block ' + str(bid))
        if status == 'not_applicable' and not (name == 'operation' and kind == 'concept'):
            issues.append(name + ': not_applicable is allowed only for operation on a concept lesson')
        if status in ('fail', 'uncertain'):
            issues.append(name + ': marked ' + status + ' and blocks delivery')
    return issues


def inspect_legacy(text):
    issues = []
    headings = [line[3:] for line in plain_lines(text) if line.startswith('## ')]
    if headings != HEADINGS:
        issues.append('Seven teaching headings must occur once in the required order (validate each part separately)')
    for heading in HEADINGS:
        if not section(text, heading):
            issues.append('Empty section: ' + heading)
    source = section(text, HEADINGS[2])
    structured = section(text, HEADINGS[3])
    source_ids = re.findall(r'^### (S\d+)[：:]', '\n'.join(plain_lines(source)), re.M)
    if not source_ids or len(set(source_ids)) != len(source_ids):
        issues.append('Source item IDs missing or duplicated')
    for label in ['[理解补充]', '[官方核验补充]', '[应用映射]']:
        if label in source:
            issues.append('Supplement in source section: ' + label)
    lines, mask = structured.splitlines(), plain_lines(structured)
    starts = [i for i, line in enumerate(mask) if line.startswith('### ')]
    mechanisms = {}
    references = set()
    for pos, start in enumerate(starts):
        end = starts[pos + 1] if pos + 1 < len(starts) else len(lines)
        heading = mask[start]
        match = re.match(r'^### (M\d+)[：:].+（对应：([S\d、, ]+)）$', heading)
        if not match:
            issues.append('Malformed mechanism heading: ' + heading)
            continue
        mid = match[1]
        if mid in mechanisms:
            issues.append('Duplicate mechanism: ' + mid)
        refs = set(re.findall(r'S\d+', match[2]))
        if not refs or not refs.issubset(source_ids):
            issues.append(mid + ': invalid source correspondence')
        references.update(refs)
        body = '\n'.join(lines[start + 1:end])
        mechanisms[mid] = body
        field_starts = []
        for i in range(start + 1, end):
            found = re.match(r'^- (' + '|'.join(map(re.escape, FIELDS)) + r')：(.*)$', mask[i])
            if found:
                field_starts.append((i, found[1], found[2]))
        if [x[1] for x in field_starts] != FIELDS:
            issues.append(mid + ': missing, duplicated, or unordered fields')
        for k, (i, name, first) in enumerate(field_starts):
            stop = field_starts[k + 1][0] if k + 1 < len(field_starts) else end
            value = (first + '\n' + '\n'.join(lines[i + 1:stop])).strip()
            stripped = re.sub(r'\[[^\]]+\]', '', value).strip()
            if not stripped or re.fullmatch(r'(待补|TODO|需要理解.*机制|按.*规则执行)[。.!！]?', stripped):
                issues.append(mid + ': empty or vacuous ' + name)
    if not mechanisms:
        issues.append('No structured mechanism')
    if set(source_ids) - references:
        issues.append('Source items without mechanism coverage: ' + ','.join(sorted(set(source_ids) - references)))
    return issues, source_ids, mechanisms


def compact_criteria_issues(entry, required, prefix):
    """Validate a compact {pass: [...], issues: {...}} entry."""
    issues = []
    if not isinstance(entry, dict):
        return [prefix + ': review entry missing']
    passed = entry.get('pass')
    failed = entry.get('issues', {})
    if not isinstance(passed, list):
        return [prefix + ': pass list missing']
    if not isinstance(failed, dict):
        return [prefix + ': issues must be an object']
    for criterion in required:
        if criterion in failed:
            if not str(failed[criterion]).strip():
                issues.append(prefix + ': repair required for ' + criterion + ' (missing details)')
            else:
                issues.append(prefix + ': repair required for ' + criterion)
        elif criterion not in passed:
            issues.append(prefix + ': incomplete for ' + criterion)
    for name in passed:
        if name not in required:
            issues.append(prefix + ': unknown criterion ' + str(name))
    return issues


def source_evidence_issues(evidence, source_ids, text):
    if evidence in (None, {}):
        return []
    if not isinstance(evidence, dict):
        return ['Source review evidence malformed']
    issues = []
    coverage = evidence.get('coverage')
    if coverage is not None:
        values = coverage.get('sources') if isinstance(coverage, dict) else coverage
        if set(map(str, values or [])) != set(source_ids):
            issues.append('Source review coverage mismatch: coverage')
    fidelity = evidence.get('fidelity')
    if fidelity is not None:
        plain = '\n'.join(plain_lines(text))
        for marker in fidelity.get('markers', []) if isinstance(fidelity, dict) else fidelity:
            if str(marker) not in plain:
                issues.append('Source review marker absent: ' + str(marker))
    correctness = evidence.get('correctness')
    if correctness is not None:
        for name in correctness.get('fields', []) if isinstance(correctness, dict) else correctness:
            if name not in FIELDS:
                issues.append('Source review field reference invalid: ' + str(name))
    return issues


def mechanism_evidence_issues(evidence, mid, body):
    if evidence in (None, {}):
        return []
    if not isinstance(evidence, dict):
        return [mid + ': evidence malformed']
    issues = []
    for criterion, value in evidence.items():
        if criterion not in CRITERIA:
            issues.append(mid + ': unknown evidence criterion ' + str(criterion))
            continue
        field = value.get('field') if isinstance(value, dict) else value
        if field not in FIELDS:
            issues.append(mid + ': field reference invalid for ' + criterion)
    return issues


def check_source_legacy(criterion, item, source_ids, text):
    scope = 'Source review incomplete: ' + criterion
    status = item.get('status')
    if status == 'pass':
        evidence = item.get('evidence')
        if isinstance(evidence, str) and evidence.strip():
            return []
        return [scope]
    if status in ('fail', 'uncertain'):
        if not str(item.get('missing', '')).strip():
            return ['Source review repair required: ' + criterion + ' (missing details)']
        return ['Source review repair required: ' + criterion]
    return [scope]


def check_mechanism_legacy(mid, criterion, item, body):
    scope = mid + ': content repair required for ' + criterion
    status = item.get('status')
    if status == 'pass':
        evidence = item.get('evidence')
        if isinstance(evidence, str) and evidence.strip():
            if evidence not in body:
                return [mid + ': review excerpt absent from mechanism for ' + criterion]
            return []
        return [scope]
    if status in ('fail', 'uncertain'):
        if not str(item.get('missing', '')).strip():
            return [scope + ' (missing details)']
        return [scope]
    return [scope]


def validate_review_legacy(review, raw, text, source_ids, mechanisms):
    issues = []
    if review.get('draft_sha256') != sha(raw):
        issues.append('Content review missing or stale: draft hash mismatch')
    if review.get('source_order') != source_ids:
        issues.append('Reviewed source order differs from draft')

    source_checks = review.get('source_checks', {})
    legacy_source = any(
        isinstance(source_checks.get(c), dict) and 'status' in source_checks.get(c, {})
        for c in SOURCE_CHECKS
    )
    if legacy_source:
        for criterion in SOURCE_CHECKS:
            issues.extend(check_source_legacy(criterion, source_checks.get(criterion, {}), source_ids, text))
    else:
        issues.extend(compact_criteria_issues(source_checks, SOURCE_CHECKS, 'Source review'))
        issues.extend(source_evidence_issues(source_checks.get('evidence'), source_ids, text))

    reviewed = review.get('mechanisms', {})
    if set(reviewed) != set(mechanisms):
        issues.append('Content review must cover exactly the rendered mechanisms')
    for mid, body in mechanisms.items():
        entry = reviewed.get(mid, {})
        legacy_entry = isinstance(entry.get('question'), dict) and 'status' in entry.get('question', {})
        if legacy_entry:
            for criterion in CRITERIA:
                issues.extend(check_mechanism_legacy(mid, criterion, entry.get(criterion, {}), body))
        else:
            issues.extend(compact_criteria_issues(entry, CRITERIA, mid))
            issues.extend(mechanism_evidence_issues(entry.get('evidence'), mid, body))
    return issues


def build_legacy_scaffold(raw, source_ids, mechanisms):
    return {
        'draft_sha256': sha(raw),
        'source_order': source_ids,
        'source_checks': {'pass': [], 'issues': {}},
        'mechanisms': {
            mid: {'pass': [], 'issues': {}} for mid in mechanisms
        },
    }


def execute_natural(args, raw, text):
    blocks = split_blocks(text)
    issues = []
    if not blocks:
        issues.append('Draft has no teachable content')
    scope = 'natural-layout structure and version-2 Agent-review coverage; semantic judgment remains Agent responsibility'
    if args.emit_review:
        if args.review:
            issues.append('--emit-review cannot be combined with --review')
        else:
            scaffold = build_natural_scaffold(raw, blocks)
            Path(args.emit_review).write_text(
                json.dumps(scaffold, ensure_ascii=False, indent=2), encoding='utf-8')
        return {'valid': not issues, 'issues': issues, 'draft_sha256': sha(raw),
                'lesson_format': 'natural', 'blocks': [block['id'] for block in blocks],
                'review_scaffold': args.emit_review,
                'semantic_correctness_proven': False, 'scope': scope}
    review = load(args.review) if args.review else {}
    issues.extend(validate_natural(review, raw, blocks))
    return {'valid': not issues, 'issues': issues, 'draft_sha256': sha(raw),
            'lesson_format': 'natural', 'blocks': [block['id'] for block in blocks],
            'semantic_correctness_proven': False, 'scope': scope}


def execute_legacy(args, raw, text):
    issues, source_ids, mechanisms = inspect_legacy(text)
    scope = 'legacy seven-section structure and Agent-review coverage; semantic judgment remains Agent responsibility'
    if args.emit_review:
        if args.review:
            issues.append('--emit-review cannot be combined with --review')
        else:
            scaffold = build_legacy_scaffold(raw, source_ids, mechanisms)
            Path(args.emit_review).write_text(
                json.dumps(scaffold, ensure_ascii=False, indent=2), encoding='utf-8')
        return {'valid': not issues, 'issues': issues, 'draft_sha256': sha(raw),
                'lesson_format': 'legacy', 'mechanisms': list(mechanisms),
                'review_scaffold': args.emit_review,
                'semantic_correctness_proven': False, 'scope': scope}
    review = load(args.review) if args.review else {}
    issues.extend(validate_review_legacy(review, raw, text, source_ids, mechanisms))
    return {'valid': not issues, 'issues': issues, 'draft_sha256': sha(raw),
            'lesson_format': 'legacy', 'mechanisms': list(mechanisms),
            'semantic_correctness_proven': False, 'scope': scope}


def execute(args):
    raw = Path(args.draft).read_bytes()
    text = raw.decode('utf-8-sig')
    if args.format == 'legacy':
        return execute_legacy(args, raw, text)
    return execute_natural(args, raw, text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--draft', required=True)
    parser.add_argument('--review')
    parser.add_argument('--format', choices=['natural', 'legacy'], default='natural',
                        help='natural: default current layout; legacy: historical seven-section drafts only')
    parser.add_argument('--emit-review', dest='emit_review',
                        help='write a review skeleton (hash, blocks/spans or mechanisms) for this draft')
    args = parser.parse_args()
    return run(lambda: execute(args))


if __name__ == '__main__':
    utf8_stdout()
    raise SystemExit(main())
