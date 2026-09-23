## Review and assessment execution

Read `review-session-protocol.md` and `review-policy.md`.

`review-tech-learning` runs only after an explicit practice, review, or assessment request. It preserves learner-owned prediction, implementation/correction, and changed-context transfer, and uses executable or observable acceptance conditions.

Review does not expand into a new curriculum block, write evidence, update the queue, establish task completion, or change the route. Hand actual results to `record-tech-learning`.

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
