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

- `direct-tech-learning` owns `current_stage`, task-package `current_unit`, `current_position`, `stage_directions`, and the matching display text under `## 当前学习主线` in `00-首页.md`. It updates these mirrors in the same confirmed write as the mainline state and preserves `latest_log`.
- `latest_log` points to the most recent event log under `30-日志/`; display it under `## 最近记录`. Never create a log merely because a date changed.
- `record-tech-learning` owns only `latest_log` and the corresponding factual navigation links on the homepage. It preserves all route mirrors owned by `direct-tech-learning`.
- The homepage route mirrors must agree with `20-学习主线/00-总览.md`. Event logs may describe historical stage context but never mirror, select, advance, complete, or block the current task.

## Event logs

Paths: `30-日志/学习/`, `30-日志/工作/`, and `30-日志/决定/`. Migrated originals live under `30-日志/历史/` as historical records and are never re-validated as new logs.

One log records one actual activity: a study activity, a work or practice activity, or a decision. Several logs may share a date; a log never binds a plan, quota, schedule, expected output, or completion date, and the system never plans in days or weeks. The only planning unit is the study slice, owned by study, never by a log.

Filename: `YYYY-MM-DD-<topic>.md`. Required properties:

```yaml
---
type: learning-log | work-log | decision-log
date: YYYY-MM-DD
duration_minutes: 30 | 时间缺失   # learning/work only
tags: []
---
```

- `type` matches the directory: `learning-log` under `30-日志/学习/`, `work-log` under `30-日志/工作/`, `decision-log` under `30-日志/决定/`.
- `date` must match both the filename date and the actual activity date.
- Learning and work logs require `duration_minutes`: a positive integer of actual minutes, or the literal `时间缺失` when the user was asked and no reliable duration could be reported. Never estimate and never write `0` for unknown time. Decision logs do not carry a duration.
- A stage or mainline-priority switch is a decision log: date, from where to where, the reason, and open items kept. `20-学习主线` and the homepage remain the sole authority for the current route; a decision log preserves history and never re-selects, advances, or blocks a task.
- Keep the body a factual account of what was actually done; link task packages, projects, sources, or artifacts only when factual. Exclude ingestion narration, stale output, generated contexts/source packets, schedules, and environment residue.
- Statistics treat `时间缺失` as a missing value: the log counts as an activity but is excluded from total and average minutes, and summaries report how many logs have a missing duration.

## Review queue

Path: `70-复习队列.md`. Read `review-policy.md`.

Required headings:

1. `## 使用规则`
2. `## 活跃队列`
3. `## 待激活题库`
4. `## 已退出活跃队列`
5. `## 最近更新依据`

The queue is derived operational state, not evidence. Actual attempts remain under review-bank `## 复习记录` and learning logs. `record-tech-learning` updates the queue only after recording actual explicit review or assessment results. Ordinary study never creates, activates, schedules, or advances queue items.

The available verification progression is causal prediction -> fault localization -> context transfer -> retention check. It is used only inside user-selected review mode and is never a task-progress or task-completion gate. Generated questions, suggested dates, and queue entries never prove learning. Do not write mastery labels.

## Atomic knowledge

Path: `40-原子知识/<技术>/<规范核心对象或代码写法> - <知识主题或操作>.md`.

Every atomic note must declare a unique `atomic_id` and exactly one `term_id`. `term_id` must resolve to a registered terminology row. A note covers one retrievable topic with concrete objects, their relationships, and any observable result; examples, principles, and boundaries appear where they support understanding, not as fixed headings.

The body uses a natural layout: headings are chosen for the content, and a conceptual note may exist without a runnable example. Use structural checks only for mechanical defects: a non-empty body, non-empty written code blocks, and resolvable identity metadata. Do not make a semantic claim that an explanation is correct merely because its structure validates. Do not add mastery state.

Split a note when it serves two separately retrievable topics or needs two independently valid examples.

## Review banks

Path: `60-复习/<规范核心对象或代码写法> - <测试目标>复习.md`.

- `atomic-mirror` banks are optional. When a note's review material or results are organized as a mirror bank, exactly one bank with `review_kind: atomic-mirror` and `primary_atomic: <atomic_id>` claims it; it uses `related_atomics: []` and tests the same atomic question. Never create a bank only to hold one result.
- An explicit review without a bank records its facts in a learning log, naming the tested `atomic_id` or task unit; the queue may cite that factual record instead of a bank.
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
- Validate required paths and headings, unit IDs and sources, queue structure, event-log structure, atomic-note structure, duplicate basenames, Wiki links, terminology integrity, naming surfaces, and deprecated aliases.
- Writers validate their own artifacts with the matching action script: `validate-route.ps1` and `validate-terminology.ps1` (direct), `validate-learning.ps1` / `validate-work.ps1` / `validate-decision.ps1` / `validate-atomic.ps1` / `validate-reviewbank.ps1` / `validate-queue.ps1` (record), `validate-jobnote.ps1` (analyze), `validate-snapshot.ps1` (study snapshots), `check-draft.py` (study drafts). `shared/assets/validation-registry.json` is the authority for each action's targets, kinds, write surface, and runtime dependencies; standalone validators are registered there separately. A change must declare its operation: an update or creation target must exist, a delete must be absent, a rename needs its old path, and an atomic delete needs its old identity; a missing path is never guessed as a delete. Every declared target must be covered by a selected kind, and an explicit action path must stay inside that action's write surface. A multi-artifact write batch runs `validate-change.ps1` once with the affected kinds and paths, `-Action`, or a mixed `-ChangeSet`. If its scope cannot be computed, it fails explicitly rather than silently running a full audit. `validate-vault.ps1 -Strict` remains the separate full composed audit and is available only from `direct-tech-learning`.
- Compare final hashes and confirm unrelated notes did not change.
