"""Validate the seven-section study draft and its bounded Agent content review.

Structural and review-coverage checks only; semantic correctness stays an Agent
judgment, never a program proof. Owned by study-tech-learning.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re

from vault_common import load, plain_lines, run, section, sha, utf8_stdout

HEADINGS = ['一、已核验来源与覆盖范围', '二、应掌握地图', '三、主源忠实讲解',
            '四、结构化知识点', '五、块级总结', '六、岗位/面试映射', '七、事实收尾']
FIELDS = ['机制', '底层规则', '应用例子', '预期结果', '边界/错误', '需要记忆', '需要理解']
CRITERIA = ['question', 'state', 'rule', 'trace', 'boundary', 'understanding']


def validate(args):
    raw = Path(args.draft).read_bytes()
    text = raw.decode('utf-8-sig')
    issues = []
    headings = [line[3:] for line in plain_lines(text) if line.startswith('## ')]
    if headings != HEADINGS:
        issues.append('Seven teaching headings must occur once in the required order (validate each part separately)')
    for heading in HEADINGS:
        if not section(text, heading):
            issues.append('Empty section: '+heading)
    source = section(text, HEADINGS[2])
    structured = section(text, HEADINGS[3])
    source_ids = re.findall(r'^### (S\d+)[：:]', '\n'.join(plain_lines(source)), re.M)
    if not source_ids or len(set(source_ids)) != len(source_ids):
        issues.append('Source item IDs missing or duplicated')
    for label in ['[理解补充]', '[官方核验补充]', '[应用映射]']:
        if label in source:
            issues.append('Supplement in source section: '+label)
    lines, mask = structured.splitlines(), plain_lines(structured)
    starts = [i for i, line in enumerate(mask) if line.startswith('### ')]
    mechanisms = {}
    references = set()
    for pos, start in enumerate(starts):
        end = starts[pos+1] if pos+1 < len(starts) else len(lines)
        heading = mask[start]
        match = re.match(r'^### (M\d+)[：:].+（对应：([S\d、, ]+)）$', heading)
        if not match:
            issues.append('Malformed mechanism heading: '+heading)
            continue
        mid = match[1]
        if mid in mechanisms:
            issues.append('Duplicate mechanism: '+mid)
        refs = set(re.findall(r'S\d+', match[2]))
        if not refs or not refs.issubset(source_ids):
            issues.append(mid+': invalid source correspondence')
        references.update(refs)
        body = '\n'.join(lines[start+1:end])
        mechanisms[mid] = body
        field_starts = []
        for i in range(start+1, end):
            found = re.match(r'^- ('+'|'.join(map(re.escape, FIELDS))+r')：(.*)$', mask[i])
            if found:
                field_starts.append((i, found[1], found[2]))
        if [x[1] for x in field_starts] != FIELDS:
            issues.append(mid+': missing, duplicated, or unordered fields')
        for k, (i, name, first) in enumerate(field_starts):
            stop = field_starts[k+1][0] if k+1 < len(field_starts) else end
            value = (first+'\n'+'\n'.join(lines[i+1:stop])).strip()
            stripped = re.sub(r'\[[^\]]+\]', '', value).strip()
            if not stripped or re.fullmatch(r'(待补|TODO|需要理解.*机制|按.*规则执行)[。.!！]?', stripped):
                issues.append(mid+': empty or vacuous '+name)
    if not mechanisms:
        issues.append('No structured mechanism')
    if set(source_ids)-references:
        issues.append('Source items without mechanism coverage: '+','.join(sorted(set(source_ids)-references)))
    review = load(args.review) if args.review else {}
    if review.get('draft_sha256') != sha(raw):
        issues.append('Content review missing or stale: draft hash mismatch')
    if review.get('source_order') != source_ids:
        issues.append('Reviewed source order differs from draft')
    for criterion in ('coverage', 'fidelity', 'correctness'):
        check = review.get('source_checks', {}).get(criterion, {})
        if check.get('status') != 'pass' or not str(check.get('evidence', '')).strip():
            issues.append('Source review incomplete: '+criterion)
    reviewed = review.get('mechanisms', {})
    if set(reviewed) != set(mechanisms):
        issues.append('Content review must cover exactly the rendered mechanisms')
    for mid, body in mechanisms.items():
        for criterion in CRITERIA:
            item = reviewed.get(mid, {}).get(criterion, {})
            evidence = item.get('evidence', '')
            if item.get('status') != 'pass' or not isinstance(evidence, str) or not evidence.strip():
                issues.append(mid+': content repair required for '+criterion)
            elif evidence not in body:
                issues.append(mid+': review excerpt absent from mechanism for '+criterion)
    return {'valid': not issues, 'issues': issues, 'draft_sha256': sha(raw),
            'mechanisms': list(mechanisms), 'semantic_correctness_proven': False,
            'scope': 'structure and Agent-review coverage; semantic judgment remains Agent responsibility'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--draft', required=True)
    parser.add_argument('--review')
    args = parser.parse_args()
    return run(lambda: validate(args))


if __name__ == '__main__':
    utf8_stdout()
    raise SystemExit(main())
