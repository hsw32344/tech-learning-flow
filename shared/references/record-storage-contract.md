## Closed contract

This is the shared structural and handoff contract for:

- `direct-tech-learning`
- `load-tech-learning-source`
- `study-tech-learning`
- `review-tech-learning`
- `record-tech-learning`
- `answer-tech-learning`
- `analyze-job-requirements`

For route, ledger, or schema changes, read this contract. Ordinary study follows the bounded session protocol and loads storage rules only when writing material; it does not preload this full schema. Role packages receive verbatim extracts of this contract for their own storage rules; the full contract file remains the authoritative full-library view, and the asset sync check verifies every extract stays byte-identical to its source section. Do not add undeclared fields, headings, folders, note types, statuses, dashboards, indexes, or automations.

When a request needs an undeclared structure:

1. stop before changing the Vault or a Skill;
2. name every affected contract, template, Skill, validator, index, and existing note;
3. preview retained, removed, renamed, migrated, and excluded content;
4. wait for confirmation;
5. update and validate all affected files together.

## Homepage projection ownership

- `direct-tech-learning` owns `current_stage`, task-package `current_unit`, `current_position`, `stage_directions`, and the matching display text under `## 当前学习主线` in `00-首页.md`. It updates these mirrors in the same confirmed write as the mainline state and preserves `current_week` and `latest_review`.
- `current_week` retains its compatibility field name but points to the latest recorded week, not necessarily the current calendar week. Display it under `## 最近周记录`; never create a new week merely because the date changed.
- `record-tech-learning` owns only `current_week`, `latest_review`, and the corresponding factual navigation links on the homepage. It preserves all route mirrors owned by `direct-tech-learning`.
- The homepage route mirrors must agree with `20-学习主线/00-总览.md`. Weekly and daily ledgers may describe historical stage context but never mirror, select, advance, complete, or block the current task.

## Weekly factual ledger

Path: `30-学习日志/每周/YYYY-Www.md`.

Required properties:

```yaml
---
type: weekly-learning-review
week: YYYY-Www
start: YYYY-MM-DD
end: YYYY-MM-DD
study_days: 0
total_minutes: 0
stage:
stage_directions: []
status: 进行中
---
```

Allowed `status` values are `进行中` and `已结束`. Closing an old week changes only its status; it never rewrites factual sections.

Required headings:

1. `## 任务流转`
2. `## 实际学习记录`
3. `## 已收敛知识`
4. `## 复习证据`
5. `## 能力证据`
6. `## 整理结论`
7. `## 前进方向`

`record-tech-learning` owns the complete weekly ledger. Logs are literal records only: a ledger never binds a plan, quota, schedule, expected output, or completion date, and the system never plans in days or weeks. The only planning unit is the study slice, owned by study, never by a log. `## 任务流转` records only actual dated work against task-package unit IDs, for example:

```markdown
- YYYY-MM-DD｜`<unit-id>`｜<开始/继续/暂停/已形成事实产物>｜<reported artifact or stopping point>
```

Every current task ID must map to a source-backed mainline unit. One task may appear across multiple dates and one date may contain multiple task entries. These relations record facts only and never change route progress. `stage` and `stage_directions` preserve the factual context for that week; they are not mirrors of current route state. `study_days` and `total_minutes` summarize reported activity; unknown duration remains unknown. `## 前进方向` may state only an evidence-bounded stopping point or unknown. Historical files may contain legacy plan fields; treat them as historical facts and neither require nor validate them.

## Review queue

Path: `70-复习队列.md`. Read `review-policy.md`.

Required headings:

1. `## 使用规则`
2. `## 活跃队列`
3. `## 待激活题库`
4. `## 已退出活跃队列`
5. `## 最近更新依据`

The queue is derived operational state, not evidence. Actual attempts remain under review-bank `## 复习记录`, daily reviews, and weekly factual sections. `record-tech-learning` updates the queue only after recording actual explicit review or assessment results. Ordinary study never creates, activates, schedules, or advances queue items.

The available verification progression is causal prediction -> fault localization -> context transfer -> retention check. It is used only inside user-selected review mode and is never a task-progress or task-completion gate. Generated questions, suggested dates, and queue entries never prove learning. Do not write mastery labels.

## Daily learning review

Path: `30-学习日志/学习回顾/YYYY-MM-DD 学习回顾.md`.

Use exactly one review per date and append later activity in actual order. Required headings:

1. `## 今日学习过程`
2. `## 今日形成的理解`
3. `## 今日知识沉淀`
4. `## 今日遇到的问题`

Record what the learner did, predicted, implemented, ran, observed, corrected, explained, or failed to complete, naming relevant task-package unit IDs when known. One task may continue across daily records and one daily record may contain multiple tasks. Exclude ingestion narration, stale output, generated contexts/source packets, schedules, and environment residue. Daily records never move task progress.

## Atomic knowledge

Path: `40-原子知识/<技术>/<规范核心对象或代码写法> - <知识主题或操作>.md`.

Every atomic note must declare a unique `atomic_id` and exactly one `term_id`. `term_id` must resolve to a registered terminology row. A note covers one retrievable topic with concrete objects, their relationships, and any observable result; examples, principles, and boundaries appear where they support understanding, not as fixed headings.

The body uses a natural layout: headings are chosen for the content, and a conceptual note may exist without a runnable example. Use structural checks only for mechanical defects: a non-empty body, non-empty written code blocks, and resolvable identity metadata. Do not make a semantic claim that an explanation is correct merely because its structure validates. Do not add mastery state.

Split a note when it serves two separately retrievable topics or needs two independently valid examples.

## Review banks

Path: `60-复习/<规范核心对象或代码写法> - <测试目标>复习.md`.

- `atomic-mirror` banks are optional. When a note's review material or results are organized as a mirror bank, exactly one bank with `review_kind: atomic-mirror` and `primary_atomic: <atomic_id>` claims it; it uses `related_atomics: []` and tests the same atomic question. Never create a bank only to hold one result.
- An explicit review without a bank records its facts in the daily learning review and the weekly section, naming the tested `atomic_id` or task unit; the queue may cite that factual record instead of a bank.
- Additional review banks may use `boundary-comparison`, `error-diagnosis`, `integration-transfer`, `task-performance`, or `retention`, and must declare at least one `related_atomics` or `task_units` value. Extra banks never require a mirror for their references.
- An atomic mirror may declare only one `primary_atomic`; one atomic ID cannot be claimed by two mirrors. Every declared atomic reference must resolve to an existing atomic note.
- Prefer three verification surfaces: causal prediction, fault localization, and changed-context transfer.
- Put only actual attempts and outcomes under `## 复习记录`.
- Do not prescribe dates inside review banks; dates live only in the derived queue.
- Update an existing bank when new material tests the same target. Generated prompts, expected answers, and empty banks are design material only: they are not learner answers, evidence, or queue activation.

## Vault-wide terminology

Path: `10-术语规范.md`.

- Use canonical names in natural language and registered code forms in code/API contexts.
- Each terminology row has two independent classification axes: `结构角色` is one of `领域`, `阶段`, `任务包`, `主题`, `知识术语`, `标签`, `历史项`; `知识类别` is blank for non-knowledge rows or one of `概念`, `机制`, `语法角色`, `API`, `实践模式` for a `知识术语` row. Do not mix the axes into one `类型` value.
- Do not invent joined parent-child names.
- `direct-tech-learning` owns stage and mainline-node rows.
- `record-tech-learning` owns topic, concept, mechanism, API, syntax, and tag rows.
- Renaming, merging, or deprecating requires a previewed global migration and confirmation.

## Linking and validation

- Use Wiki links inside the validator-indexed Vault. Learning snapshots follow the relative Markdown-link exception in `25-资源区/学习快照/学习快照使用说明.md`.
- Read every target before writing and preserve other Skills' fields.
- Use `apply_patch` for Markdown edits.
- Validate required paths and headings, unit IDs and sources, queue structure, daily uniqueness, atomic-note structure, duplicate basenames, Wiki links, terminology integrity, naming surfaces, and deprecated aliases.
- Writers validate their own artifacts with the matching action script: `validate-route.ps1` and `validate-terminology.ps1` (direct), `validate-daily.ps1` / `validate-weekly.ps1` / `validate-atomic.ps1` / `validate-reviewbank.ps1` / `validate-queue.ps1` (record), `validate-jobnote.ps1` (analyze), `validate-snapshot.ps1` (study snapshots), `check-draft.py` (study drafts). `shared/assets/validation-registry.json` is the authority for each action's targets, kinds, write surface, and runtime dependencies; standalone validators are registered there separately. A change must declare its operation: an update or creation target must exist, a delete must be absent, a rename needs its old path, and an atomic delete needs its old identity; a missing path is never guessed as a delete. Every declared target must be covered by a selected kind, and an explicit action path must stay inside that action's write surface. A multi-artifact write batch runs `validate-change.ps1` once with the affected kinds and paths, `-Action`, or a mixed `-ChangeSet`. If its scope cannot be computed, it fails explicitly rather than silently running a full audit. `validate-vault.ps1 -Strict` remains the separate full composed audit and is available only from `direct-tech-learning`.
- Compare final hashes and confirm unrelated notes did not change.
