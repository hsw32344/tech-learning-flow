---
name: direct-tech-learning
description: Maintain the source-backed technical-learning task route, current stage/unit/position, and task priority in the fixed tech_vault. Use for 长期怎么学、学习主线、下一任务、当前任务、激进推进、快速建立框架、阶段规划、进入或切换阶段、跳过、并行、提前学习、调整长期方向、今天做什么、这周推进什么. Select or reorder task packages without executing them. Do not create calendar schedules or require review before progress. Persist route changes only after confirmation.
---

# Direct technical learning

Maintain the complete source-backed task route. Do not execute study or review.

## When to use

- `长期怎么学`、`学习主线`、`下一任务`、`当前任务`、`调整主线`、`进入阶段`、`切换阶段`、`跳过`、`并行`、`提前学习`、`今天做什么`、`这周推进什么`.
- Select, reorder, or skip task packages after showing dependency costs; user choice is final and never vetoed by an unfinished day/week, review state, or missing assessment.

## Inputs

- Vault binding: explicit path or the tracked pointer; run `scripts/init-vault.ps1` when missing or uninitialized.
- The requested change: classify it, then show retained / moved / skipped / added units and dependency costs before writing.
- Current context: the active unit row, its prerequisites, the stage file, the homepage mirror, and any confirmed job-requirement handoff note or exact source boundary.

## Minimal reads

- Read the sections of `references/tech-vault-schema.md` needed for the write (mainline, source declarations, homepage mirrors); it is never a mandatory full preload.
- Read `references/curriculum-sources.md` when selecting or changing a task package's primary source.
- Read `10-术语规范.md` when stage or mainline terminology rows change; read `99-附件/FCC学习操作范式.md` for `FCC-*` sources.
- Read the full mainline only when reordering stages/units or adding packages; recent event logs only when factual history affects task selection; `70-复习队列.md` only for an explicit practice/review request.

## Allowed writes

- `20-学习主线/` (its `00-总览.md`, `20-任务包注册表.md`, the relevant stage file, and `资料来源注册表.md` when material identities change), the matching `00-首页.md` route mirrors, and stage/mainline-node terminology rows.
- Exactly one machine-parseable `primary_source` line with a reproducible anchor per unit, plus at most one bounded `gap_source`; never assemble a hidden Agent-authored curriculum from fragments.
- Preserve event logs and homepage `latest_log`; never write review results, learner activity, or generated teaching into the route.

## Handoff

- Execution -> `study-tech-learning`; explicit practice/review/assessment -> `review-tech-learning`; facts -> `record-tech-learning`; focused explanations -> `answer-tech-learning`; raw HR/JD -> `analyze-job-requirements`.
- For `FCC-*` sources, hand structure-first block/challenge resolution to `load-tech-learning-source` under the Vault FCC manual.

## Done check

- After every route write run `scripts/validate-route.ps1`; when stage or terminology rows change also run `scripts/validate-terminology.ps1`, or cover both with one `scripts/validate-change.ps1 -Kinds route,terminology` batch.
- `scripts/validate-vault.ps1 -Strict` is the explicit whole-Vault maintenance audit; routine route writes use only their registered action impact surface.
- Unit IDs are stable and complete; content / causal model / output and source declarations stay consistent; homepage mirrors match the mainline exactly.
- Technical conflicts are resolved by current version-matched official documentation; Agent fallback is used only when a higher-ranked source is unavailable, with its reason and bounded scope recorded.
