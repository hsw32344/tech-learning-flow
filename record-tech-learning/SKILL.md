---
name: record-tech-learning
description: Record verified task activity or explicit review results from an explicitly selected workspace or a factual user report into the fixed tech_vault. Use for 把当前工作区内容装入 vault、学习结束、今天学了、记录任务进度、记录问题、记录练习结果、记录验收结果. Keep daily and weekly logs as factual ledgers without using dates as progress units. Logs record literal facts only and never bind plans, quotas, schedules, or expected outputs. Never create review from ordinary study or move the task route automatically.
---

# Record technical learning

Record actual activity while keeping study input, review attempts, generated material, and derived state separate.

Logs are literal records: a ledger never binds a plan, quota, schedule, expected output, or completion date. The only planning unit in this system is the study slice, which belongs to study runtime, never to a log.

## Load the contract

Bind the Vault first: resolve it per `references/tech-vault-schema.md`; if it is missing or uninitialized, ask the user to initialize it with `direct-tech-learning` or `study-tech-learning` before scanning or writing.

Read `references/tech-vault-schema.md`, `references/review-policy.md`, `10-术语规范.md`, `20-学习主线/`, and `70-复习队列.md` before scanning or writing.

## Resolve source scope

- Accept an exact path, named workspace root, or `当前工作区` when one active root is unambiguous.
- Never search unrelated projects.
- A factual report may be recorded without a source workspace when the user supplies enough detail.
- When a workspace is in scope, run `scripts/detect-delta.ps1` without `-Commit` and inspect only eligible changes.

Exclude environments, caches, build output, generated empty packets, Agent-authored explanation, learning snapshots, scaffolding, and stale output from activity evidence. A snapshot may identify where to inspect, but its existence or generated content never proves an attempt or outcome.

## Classify the activity

Separate:

- study input: actual primary/gap source identity, course section or book chapter used, examples followed, code/cells run, output observed, stopping position, questions;
- explicit review/assessment: learner predictions, implementations, corrections, transfer work, hints used, commands/cells, and results;
- Agent-authored material;
- inference and unknowns.

Never reinterpret study as review merely because code was run or a course section ended.

## Preview writes

Before a multi-file write, report exact source, factual delta, proposed notes, terminology changes, atomic notes, review records, weekly facts, queue effect, retained task route, and excluded noise. Wait for confirmation unless execution was already approved.

## Record task activity

- Append actual activity to one daily review per date and to weekly factual sections. These are date-organized ledgers, not progress gates.
- Record task unit IDs, artifacts, observed output, blockers, and factual stopping positions when reported.
- Record only the learning source and exact section/chapter actually reported or observed. Do not infer a tutorial, book edition, source role, or coverage from the task plan. Mark an Agent fallback as Agent-authored input with its reported reason/scope/uncovered boundary; do not record it as a tutorial or completed course.
- Allow one task to continue across several daily records and one daily record to contain several task units.
- Create or update atomic notes only for mechanisms actually encountered and supported by observed material. Assign one stable unique `atomic_id`, one registered `term_id`, one independently answerable question, one primary causal chain, one main conclusion, and one runnable/observable minimum example. Split only when those structural tests show more than one independent question or controlling rule.
- Preserve unknown duration as unknown.
- Do not create review banks, activate queue items, assign review dates, or advance verification levels from ordinary study.

## Record explicit review or assessment

- Maintain exactly one `atomic-mirror` review bank for every atomic ID: it uses `primary_atomic` and an empty `related_atomics`. Extra banks must use a permitted extra kind and name related atomics or task units. Put only actual attempts and outcomes under review-bank `## 复习记录`.
- Distinguish independent, hint-dependent, incomplete, and incorrect results.
- Update `70-复习队列.md` only after the factual result is recorded, following `review-policy.md`.
- Never write mastery state.

## Ownership and validation

Write only learned terminology, cumulative daily reviews, atomic notes, actual review records, topic maps, weekly factual sections, homepage `current_week`/`latest_review` and their factual navigation links, and review queue changes justified by explicit review results.

Preserve the mainline and homepage `current_stage`, `current_unit`, `current_position`, `stage_directions`, their display mirrors, and all learning snapshots; preserve stage/mainline terminology. Weekly/daily calendar boundaries never move or reset the task route. If a factual task handoff may justify position movement, hand the unit ID and stopping boundary to `direct-tech-learning`.

After writing, run the matching artifact validator: `scripts/validate-daily.ps1` (daily review), `scripts/validate-weekly.ps1` (weekly ledger), `scripts/validate-atomic.ps1` (atomic note), `scripts/validate-reviewbank.ps1` (review bank), `scripts/validate-queue.ps1` (review queue). Verify links and scope, then commit the source baseline only after validation succeeds. Report what was recorded and what generated material was excluded; do not prescribe the next task, require assessment, or slow progress because a log is incomplete.
