---
name: record-tech-learning
description: Record verified task activity or explicit review results from an explicitly selected workspace or a factual user report into the fixed tech_vault. Use for 把当前工作区内容装入 vault、学习结束、今天学了、记录任务进度、记录问题、记录练习结果、记录验收结果. Keep daily and weekly logs as factual ledgers without using dates as progress units. Logs record literal facts only and never bind plans, quotas, schedules, or expected outputs. Never create review from ordinary study or move the task route automatically.
---

# Record technical learning

Record actual activity as literal facts while keeping study input, review attempts, generated material, and derived state separate.

## When to use

- `学习结束`、`今天学了`、`记录进度`、`记录问题`、source-ingestion results, or a factual user report.
- Explicit review or assessment results; never reinterpret ordinary study as review, and never create review from study.
- Logs are ledgers: a record never binds a plan, quota, schedule, expected output, or completion date.

## Inputs

- Vault binding: explicit path or the tracked pointer; if it is missing or uninitialized, ask the user to initialize it with `direct-tech-learning` or `study-tech-learning`.
- Scope: an exact path, named workspace root, or `当前工作区` when one active root is unambiguous; a factual report may be recorded without a workspace when the user supplies enough detail.
- When a workspace is in scope, run `scripts/detect-delta.ps1` without `-Commit` and inspect only eligible changes.
- Classify before writing: study input, explicit review/assessment, Agent-authored material, inference and unknowns stay separate.
- Exclude environments, caches, build output, generated empty contexts/source packets, Agent-authored explanation, snapshots, scaffolding, and stale output from activity evidence.

## Minimal reads

- Read `10-术语规范.md`, the target daily/weekly file, relevant atomic notes and IDs, and the homepage facts this role owns.
- Read `references/record-storage-contract.md`; do not load the full Vault contract for a factual record.
- When recording explicit review material or results, read `references/review-policy.md` and `70-复习队列.md`; ordinary records never read the queue.
- Extend only when: a factual task handoff needs route context, or terminology/ID resolution is ambiguous.

## Allowed writes

- Learned terminology; cumulative daily reviews; atomic notes actually supported by observed material; actual review records; topic maps; weekly factual sections; homepage `current_week`/`latest_review` and their factual navigation links; queue changes justified by explicit recorded results.
- Never write route mirrors (`current_stage`/`current_unit`/`current_position`), stage/mainline terminology, snapshots, mastery labels, or review dates outside the derived queue.
- Atomic mirror policy: when recording review material or results for an atomic, ensure exactly one `atomic-mirror` bank claims it (`primary_atomic`, empty `related_atomics`). An atomic created by ordinary study may stay without a mirror until then; never create a bank only to satisfy validation.
- Before a multi-file write, report the exact source, factual delta, proposed artifacts, queue effect, and retained route; wait for confirmation unless execution was already approved.
- After writing, run the matching validator (`validate-daily/weekly/atomic/reviewbank/queue`); when one batch touches several artifacts run `scripts/validate-change.ps1 -Vault <root> -Kinds <kinds> -Paths <written files>` exactly once instead of one scan per artifact, and commit the source baseline only after it passes.
- A delete or rename is declared explicitly (`-Operation delete|rename`, plus `-OldPath`, and `-OldIdentity` when an atomic ID changes); mixed batches use `-ChangeSet "operation|path[|old_path[|old_identity]]"`. A missing path is never guessed as a delete, and every declared target must be covered by the selected kinds. Action validators use the registered targets and dependencies only; unrelated historical Vault defects do not block the recorded fact.

## Handoff

- Route movement justified by a factual handoff -> `direct-tech-learning`; continued study -> `study-tech-learning`; explicit practice -> `review-tech-learning`; focused questions -> `answer-tech-learning`; raw HR/JD -> `analyze-job-requirements`.
- Weekly/daily boundaries never move or reset the task route.

## Done check

- The matching artifact validator passes after the write.
- Report what was recorded and what generated material was excluded; preserve unknown duration as unknown.
- Never prescribe the next task, require assessment, create dates/quotas, or slow progress because a log is incomplete.
