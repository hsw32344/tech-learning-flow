"""Validate the seven-section study draft and its bounded Agent content review.

Structure checks are mechanical. The compact review lists stable criterion IDs
that passed and carries reasons only for failures; the tool computes the draft
hash, mechanism list, and source order, and never proves semantic correctness.
Owned by study-tech-learning.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

from vault_common import load, plain_lines, run, section, sha, utf8_stdout

HEADINGS = ['一、已核验来源与覆盖范围', '二、应掌握地图', '三、主源忠实讲解',
            '四、结构化知识点', '五、块级总结', '六、岗位/面试映射', '七、事实收尾']
FIELDS = ['机制', '底层规则', '应用例子', '预期结果', '边界/错误', '需要记忆', '需要理解']
CRITERIA = ['question', 'state', 'rule', 'trace', 'boundary', 'understanding']
SOURCE_CHECKS = ['coverage', 'fidelity', 'correctness']


def inspect_draft(text):
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


def validate_review(review, raw, text, source_ids, mechanisms):
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


def build_scaffold(raw, source_ids, mechanisms):
    return {
        'draft_sha256': sha(raw),
        'source_order': source_ids,
        'source_checks': {'pass': [], 'issues': {}},
        'mechanisms': {
            mid: {'pass': [], 'issues': {}} for mid in mechanisms
        },
    }


def execute(args):
    raw = Path(args.draft).read_bytes()
    text = raw.decode('utf-8-sig')
    issues, source_ids, mechanisms = inspect_draft(text)
    scope = 'structure and Agent-review coverage; semantic judgment remains Agent responsibility'
    if args.emit_review:
        if args.review:
            issues.append('--emit-review cannot be combined with --review')
        else:
            scaffold = build_scaffold(raw, source_ids, mechanisms)
            Path(args.emit_review).write_text(
                json.dumps(scaffold, ensure_ascii=False, indent=2), encoding='utf-8')
        return {'valid': not issues, 'issues': issues, 'draft_sha256': sha(raw),
                'mechanisms': list(mechanisms), 'review_scaffold': args.emit_review,
                'semantic_correctness_proven': False, 'scope': scope}
    review = load(args.review) if args.review else {}
    issues.extend(validate_review(review, raw, text, source_ids, mechanisms))
    return {'valid': not issues, 'issues': issues, 'draft_sha256': sha(raw),
            'mechanisms': list(mechanisms), 'semantic_correctness_proven': False, 'scope': scope}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--draft', required=True)
    parser.add_argument('--review')
    parser.add_argument('--emit-review', dest='emit_review',
                        help='write a review skeleton (hash, source order, mechanisms) for this draft')
    args = parser.parse_args()
    return run(lambda: execute(args))


if __name__ == '__main__':
    utf8_stdout()
    raise SystemExit(main())
