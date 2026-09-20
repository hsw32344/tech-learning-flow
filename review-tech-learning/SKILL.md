---
name: review-tech-learning
description: Execute optional explicit practice, review, or assessment for a selected task package or topic from the fixed tech_vault, optionally in a named Notebook or source file. Use for 开始练习、给我练习、开始复习、复习这个任务、批量复习、验收、测试我、练习加验收. Build learner-owned causal prediction, fault-localization, transfer, and retention checks. Activate only from an explicit user choice; never use review as a default task-progress gate or write Vault evidence.
---

# Review technical learning

Run practice and assessment only after the user explicitly chooses this mode.

## When to use

- Explicit `开始练习`、`给我练习`、`开始复习`、`复习这个任务`、`批量复习`、`验收`、`测试我`、`练习加验收`.
- Never a default task step, a completion gate, or a calendar-triggered action; ordinary study never enters this mode.

## Inputs

- Vault binding: explicit path or the tracked pointer; if it is missing or uninitialized, ask the user to initialize it with `direct-tech-learning` or `study-tech-learning`. This mode never writes to the Vault.
- Target priority: explicit unit/topic -> explicitly selected review bank -> active queue.
- For an `atomic-mirror` bank start from its declared `primary_atomic`; for an extra bank use its declared `review_kind` plus `related_atomics`/`task_units`.
- An atomic note without a mirror bank may still be tested; `record-tech-learning` creates the mirror when the result is recorded.
- For a task-package review, the snapshot's covered-slice table and structured mechanisms show what was taught; snapshot content is coverage, not ability, readiness, or evidence.

## Minimal reads

- Read `references/review-session-protocol.md` and the selected target: relevant atomic notes, the selected review bank, or the snapshot slice.
- Read `references/review-storage-contract.md` when the tested boundary needs the bank or queue contract; it is an extract of the shared Vault contract.
- Read `references/review-policy.md` and `70-复习队列.md` only when selecting from the queue or reasoning about queue effects.
- Read terminology rows for the tested concepts when naming matters.
- Extend only when: the target is ambiguous, or the user explicitly asks for a whole-topic sweep.

## Allowed writes

- None to the Vault: never update review records, queue, weekly facts, mainline, position, evidence, or terminology.
- Generated questions, expected answers, tests, and dates are not evidence and stay out of the Vault.

## Handoff

- Actual attempts and results -> `record-tech-learning` (it alone records and may update the derived queue).
- Substantial new input -> `study-tech-learning`; focused blockers -> `answer-tech-learning`; persistent route changes -> `direct-tech-learning`.
- Do not expand review into a new course block.

## Done check

- State the tested boundary and observable completion conditions; group two to four tightly related checks when coherent.
- Prefer causal prediction, fault localization, changed-context transfer, and later retention; leave critical answers, implementation/correction, and transfer decisions to the learner.
- Provide executable assertions or exact observable checks, and request one consolidated result report; give progressive hints only when blocked.
- Missing review evidence never blocks ordinary task progress.
