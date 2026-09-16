# Study session protocol

This is the single authority for conversational teaching, content quality, and teaching continuity. Source adapters own source location; the snapshot guide owns material storage. Read this once while unchanged, not again for each slice.

## User control and scope

“继续 / 下一片 / 跳过 / 从这里开始” is sufficient to move the teaching position. Never require FCC completion, a runnable submission, a closed-loop artifact, a quiz, or proof of understanding. Examples support explanation; executing them is optional. Do not automatically record mastery or repeat evidence disclaimers in ordinary lessons. Source fidelity and teaching quality remain the Agent's responsibility.

Preserve source order and existing slice IDs. Default to one coherent slice, but split a dense slice into mechanism-sized parts rather than compress its reasoning. A part ends after a complete causal chain, example result, and relevant boundary. Keep the same slice ID and a stable mechanism ID; never invent a reordered curriculum. Explicit wider requests may cover multiple parts/slices in source order. Validate each exact seven-section part separately with its own review and local S/M IDs, then concatenate the validated parts unchanged; do not submit a multi-part response to the single-part checker.

## Lightweight input

Run `scripts/build-packet.py --vault <root> [--unit ID] [--slice N-N] [--locator TEXT]`. It returns a compact resolver result plus only the target row/body, source fields, blockers, and runtime checkpoint. It may read files locally in full; it must not print unrelated slices. That saves model context, not disk I/O. Do not re-read complete mainline/registry/snapshot after receiving a sufficient packet. Source freshness or missing/disputed source fragments trigger bounded live loading; shallow explanation alone triggers local explanation repair.

## Fixed teaching layout

Use these seven sections in order for a slice or a resumed part:

```markdown
## 一、已核验来源与覆盖范围
## 二、应掌握地图
## 三、主源忠实讲解
### S1：<source item in actual source order>
## 四、结构化知识点
### M1：<core why-question>（对应：S1）
- 机制：<objects and initial state>
- 底层规则：<condition -> controlling rule -> intermediate steps -> result>
- 应用例子：<minimal corresponding example>
- 预期结果：<result derived from the stated steps>
- 边界/错误：<change one decisive condition; explain the changed behavior>
- 需要记忆：<syntax/API names>
- 需要理解：<specific causal relationship that answers the why-question>
## 五、块级总结
## 六、岗位/面试映射
## 七、事实收尾
```

Source items get stable S IDs within the slice; mechanisms get M IDs. On resumed parts keep IDs and include only current coverage. Do not combine or interleave sections three and four. Section three follows real source order and contains only source-backed paraphrase/examples/checks. Section four maps mechanisms to source items and contains causal supplements.

Use `[主源原文]` for faithful paraphrase (not a claim of verbatim wording), `[源内例子]`, `[源内核验锚点]`, `[官方核验补充]`, `[理解补充]`, `[应用映射]`, and `[推迟]` according to provenance. No source check means omit it or say 无/不适用. Do not demand answers to source checks. Agent fallback is labelled as such and cannot use source-original labels.

Keep source/map to a few lines, summary to the decisive relationships, job mapping to one supported application or 无需额外映射, and handoff to position/pending/next. Resumed parts briefly reference prior context; do not replay it. The full reasoning belongs in sections three/four; do not repeat code or causal paragraphs in summary/map/handoff. These are soft length budgets, never permission to omit a crucial causal step.

## Content adequacy gate

Before sending, inspect each core mechanism against these six criteria. A field name, keyword, longer text, or correct final output alone is insufficient.

1. `question`: identifies the specific why-question and actually answers it; reject circular explanations such as “because Python works this way”.
2. `state`: identifies relevant objects/state/context before the operation, including bindings or ownership when they control the outcome.
3. `rule`: explains the concrete trigger and controlling rule, distinguishing similar operations where needed.
4. `trace`: connects intermediate execution/data steps to the example result; reject unexplained jumps or conclusions that cannot be derived from the stated model.
5. `boundary`: changes a decisive condition and explains the resulting difference/error. Do not invent irrelevant implementation trivia; state a genuine scope limit where a counterexample is unsuitable.
6. `understanding`: extracts a reusable causal relationship rather than repeating an API name or “understand X”. Stop at the depth that explains the current behavior and relevant boundary; interpreter internals are conditional, not mandatory.

Also compare all taught S items to verified input for coverage, source order, provenance, and version-sensitive correctness. An accurate but shallow cached lesson fails adequacy and needs supplementation; an unverified source claim needs acquisition. A correct output from running an example verifies that case, not the whole explanation. Run code only when it resolves a material uncertainty, never as a learner gate.

Prepare the exact draft and a compact Agent review under the Vault scratch area `97-临时/` (never write them into the user's source workspace unless the user explicitly asks). Run:

`<explicit-python> scripts/check-draft.py --draft <draft.md> --review <review.json>`

Review format:

```json
{
  "draft_sha256": "SHA256 of exact draft bytes",
  "source_order": ["S1"],
  "source_checks": {
    "coverage": {"status":"pass", "evidence":"specific source anchors compared"},
    "fidelity": {"status":"pass", "evidence":"source and supplement separation checked"},
    "correctness": {"status":"pass", "evidence":"specific rules/version/result reviewed"}
  },
  "mechanisms": {
    "M1": {
      "question": {"status":"pass", "evidence":"exact supporting draft excerpt"},
      "state": {"status":"pass", "evidence":"exact supporting draft excerpt"},
      "rule": {"status":"pass", "evidence":"exact supporting draft excerpt"},
      "trace": {"status":"pass", "evidence":"exact supporting draft excerpt"},
      "boundary": {"status":"pass", "evidence":"exact supporting draft excerpt"},
      "understanding": {"status":"pass", "evidence":"exact supporting draft excerpt"}
    }
  }
}
```

Use `fail` or `uncertain` honestly with the missing step. Repair only failing content, update the review/hash, then rerun. The checker verifies structure, nonempty fields, obvious placeholders, mappings, and review completeness/binding. It cannot certify that the Agent's semantic judgment is right; never describe its success as proof of correctness or user mastery. Do not manufacture passing reviews or add filler to satisfy checks. Do not show the full review ledger in ordinary teaching.

## Resume contract

Material cursor and teaching cursor are independent. Snapshot stop/next fields describe generated material only. Homepage position is route context, not proof of delivered teaching.

Selection priority: explicit user selection (no evidence needed) -> latest identifiable conversation position -> saved teaching checkpoint -> explicit task-scoped stopping record, if needed. Never use the material cursor to skip teaching. If unresolved, ask once for a starting position, accept the answer, and proceed.

Runtime state is `25-资源区/学习快照/.study-state/<unit>.json`, separate from snapshot prose and all learner logs. It stores schema version, unit, source, slice/locator, mechanism, delivered mechanisms, pending questions, next action/unit/slice/locator, target content hash, status, and revision. An atomic `active.json` pointer selects the last teaching task when no unit is supplied; it never changes homepage/mainline. It has no FCC completion, mastery, time quota, or required artifact fields. Use the packet's `state_revision` for optimistic concurrency.

`scripts/write-checkpoint.py --vault <root> --unit ID --input <state.json> --expected-revision N`

Allowed status:
- `user-selected`: user explicitly chooses this position; accept without proof.
- `pending`: draft prepared but delivery not yet established. Do not advance next time from an unsent draft.
- `delivered`: prior response is actually visible in conversation; only then may its next position be used.
- `interrupted`: resume at the incomplete mechanism boundary and preserve pending questions.

Before a final response, save pending state. On the next turn, reconcile it with visible response/user continuation and update delivered state before advancing. If delivery cannot be determined, resume at the recorded mechanism with a short recap instead of skipping. Source/material writes never commit delivery. A follow-up “why” adds/repairs a pending issue and preserves the parent cursor; ordinary “continue” resolves that issue first unless the user explicitly skips it.

Concurrent changes must fail with a revision conflict; reread and reconcile instead of overwriting. A changed target hash/source requires checking the affected slice, not replaying the entire task or treating the stale cache as fresh. A prepared future slice elsewhere in the snapshot must not invalidate the current slice by itself.

## Storage and mode boundaries

Only new/expanded/corrected source-backed material is written and structurally validated before teaching. Cache hits require no rewrite. Snapshot preparation leaves teaching state untouched. Study may persist runtime checkpoints, not learner results or route changes. Focused answers preserve continuity; practice/review remains explicit-only. Reading/continuing/skipping never requires independent performance evidence. Snapshots live in `25-资源区/学习快照/`; temporary drafts and reviews live in `97-临时/`; the source workspace is written only when the user explicitly selects a file.
