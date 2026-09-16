---
name: review-tech-learning
description: Execute optional explicit practice, review, or assessment for a selected task package or topic from the fixed tech_vault, optionally in a named Notebook or source file. Use for 开始练习、给我练习、开始复习、复习这个任务、批量复习、验收、测试我、练习加验收. Build learner-owned causal prediction, fault-localization, transfer, and retention checks. Activate only from an explicit user choice; never use review as a default task-progress gate or write Vault evidence.
---

# Review technical learning

Run practice and assessment only after the user explicitly chooses this mode.

## Load the contract

Bind the Vault first: resolve it per `references/tech-vault-schema.md`; if it is missing or uninitialized, ask the user to initialize it with `direct-tech-learning` or `study-tech-learning` before reading.

Read `references/tech-vault-schema.md`, `references/review-session-protocol.md`, `references/review-policy.md`, `10-术语规范.md`, `20-学习主线/`, relevant atomic notes and review banks, `70-复习队列.md`, and the selected task's learning snapshot when present. Never write to the Vault.

## Resolve the target

Use the user's explicit unit/topic first, then an explicitly selected review bank, then the active queue. For an atomic-mirror bank, begin with its declared `primary_atomic`; for an extra bank, use its declared `review_kind` plus `related_atomics` or `task_units`. Queue dates are priorities, not automatic triggers or proof.

State the tested boundary and observable completion conditions. Do not change the task route. Missing review evidence never blocks ordinary task progress.

For a task-package review, use the snapshot's covered-slice table, structured mechanisms, online-interaction statuses, and unresolved issues to avoid testing material that was never taught. Snapshot content establishes generated study coverage only; it is not an attempt, result, readiness claim, or completion evidence.

## Build practice and assessment

Follow `review-session-protocol.md`:

1. group two to four tightly related checks when coherent;
2. prefer causal prediction, fault localization, changed-context transfer, and later retention;
3. leave critical answers, implementation, correction, and transfer decisions to the learner;
4. provide executable assertions or exact observable checks;
5. request one consolidated result report.

Do not fill learner-owned work before an attempt unless the user asks. Give progressive hints when blocked. After an attempt, provide only the corrective explanation needed to interpret the result.

## Evidence boundary

Generated questions, expected answers, tests, and dates are not evidence. Never update review records, the queue, weekly facts, mainline, position, or terminology. Hand actual attempts and results to `record-tech-learning`; it alone records the result and may update derived queue state.

## Mode boundary

Do not expand review into a new course block. Hand substantial new input to `study-tech-learning`, focused blockers to `answer-tech-learning`, and persistent task-route changes to `direct-tech-learning`.
