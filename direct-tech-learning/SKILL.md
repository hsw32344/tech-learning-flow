---
name: direct-tech-learning
description: Maintain the source-backed technical-learning task route, current stage/unit/position, and task priority in the fixed tech_vault. Use for 长期怎么学、学习主线、下一任务、当前任务、激进推进、快速建立框架、阶段规划、进入或切换阶段、跳过、并行、提前学习、调整长期方向、今天做什么、这周推进什么. Select or reorder task packages without executing them. Do not create calendar schedules or require review before progress. Persist route changes only after confirmation.
---

# Direct technical learning

Maintain the complete source-backed task route. Do not execute study or review.

## Load the contract

Bind the Vault first: resolve it per `references/tech-vault-schema.md`; if it is missing or uninitialized, run `scripts/init-vault.ps1` to create the minimal valid skeleton before proposing or writing.

Read `references/tech-vault-schema.md`, `references/curriculum-sources.md`, `10-术语规范.md`, `20-学习主线/`, and the homepage before proposing or writing. Read recent weekly and daily logs only when factual history affects task selection. Read `70-复习队列.md` only for an explicit practice, review, or assessment request.

When the selected primary source code starts with `FCC-`, also read `99-附件/FCC学习操作范式.md`. Treat it as the operational authority for source resolution and study routing, not as route or capability evidence. Read the task snapshot only when its explicit stopping or next locator affects the handoff; never advance the route from snapshot content.

## Route authority

1. Use the confirmed mainline for order, user-supplied job requirements for interview priority when explicitly adopted, and current registered official sources for technical behavior. Select each task package's one primary learning source by the completion-path order in `curriculum-sources.md`: user selection, public online tutorial, official teaching documentation, confirmed physical book, then explicitly marked Agent fallback.
2. Select stable mainline unit IDs; do not invent or silently omit units.
3. Preserve each unit's prerequisites, causal model, coverage/output, and learning-source declaration: exactly one machine-parseable `primary_source` line with source identity/type and exact locator, and at most one bounded labelled `gap_source` line, in the format owned by `curriculum-sources.md`.
4. Separate historical facts, observed output, review state, and recommendations.
5. When stage, unit, position, or stage directions change, update `20-学习主线/` (its `00-总览.md`, the relevant `10-阶段/` file, and `20-来源声明.md`) and the corresponding `00-首页.md` route mirrors together; preserve homepage `current_week` and `latest_review`.

The user may change the route at any time. Classify the change, show retained/moved/skipped/added units and dependency costs, then follow the user's explicit choice. Never use an unfinished week or day, review state, missing assessment, or incomplete mastery as a veto.

When `analyze-job-requirements` hands off a confirmed proposal, read the saved source note or exact source boundary, preserve its fact/inference/recommendation separation, and apply only the explicitly approved retained, moved, reprioritized, added, skipped, and job-specific treatment. A job requirement never proves capability or completion.

## Select tasks

Treat `今天做什么`, `今天安排什么`, `这周推进什么`, and `下一任务` as task-selection requests:

- report the current task package and the smallest useful output boundary;
- select the next source-backed task from the current position when needed;
- do not start teaching, generate exercises, or switch to review;
- do not generate dates, daily quotas, weekly quotas, or completion promises;
- hand execution to `study-tech-learning` or, only after an explicit choice, `review-tech-learning`.

## Select learning material

Select or change task material only as a route decision; do not teach it here. Give every task package exactly one primary learning source and one reproducible section/chapter anchor. Use a second source only as one named gap source. If two or more tutorials would be needed, split the task package or replace its primary source. Never assemble a hidden Agent-authored curriculum from source fragments.

For `FCC-*`, preserve the registered course as the primary route and hand structure-first block/challenge resolution to `load-tech-learning-source` under the Vault FCC manual. Do not replace an inaccessible online shell with guessed course content.

Use Agent fallback only when a higher-ranked source is unavailable or unsuitable. Record why, its bounded teaching scope, and what it does not cover. Technical conflicts are always resolved by current version-matched official documentation, even when a tutorial is the primary learning source.

## Task-first progression

1. Use mainline units as task packages; do not create a parallel task database.
2. Prefer breadth and framework coverage while preserving core causal understanding. An example or artifact is optional, never a prerequisite for moving on.
3. Allow one task to span multiple days and one day to contain multiple tasks. ISO week and date boundaries never control progress.
4. Fill prerequisite gaps only when they cause a concrete task blocker. Do not front-load easy or complete prerequisite courses for completeness.
5. Allow aggressive skip, parallelization, or early entry when the user chooses it; state dependency cost without slowing the route automatically.
6. User choice is sufficient to continue or skip; do not demand FCC completion, runnable submissions, or a closed-loop artifact. An ordinary within-task teaching cursor belongs to study runtime state, not a persistent route change.
7. After confirmation, update only the mainline, terminology rows when needed, and matching homepage route mirrors.

Preserve all weekly/daily facts and homepage factual navigation links. Move current position from a recorded task handoff or an explicit user override, never from generated teaching, a calendar boundary, or an assessment suggestion.

## Boundaries

Never execute a lesson, create exercises, ingest learning, update review results, or answer a standalone concept. Hand study to `study-tech-learning`, explicit practice/review/assessment to `review-tech-learning`, facts to `record-tech-learning`, and focused explanations to `answer-tech-learning`. After every route write, run `scripts/validate-route.ps1`; when stage or mainline terminology rows change, also run `scripts/validate-terminology.ps1`.
Hand raw HR/JD analysis and unconfirmed job-driven route proposals to `analyze-job-requirements`.
