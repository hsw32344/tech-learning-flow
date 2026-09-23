# Review queue policy

Use this reference when reading or updating `70-复习队列.md`.

## Separation

- Review banks and learning logs contain actual attempts and outcomes.
- `70-复习队列.md` contains derived operational state only.
- Generated questions, dates, explanations, planned sessions, and queue entries are not evidence.
- Never write a mastery label.

## Bank taxonomy and mirror coverage

- `atomic-mirror` is optional. When one exists it has `related_atomics: []` and tests that atomic note's own question; exactly one mirror may claim an atomic ID.
- An explicit review of an atomic without a mirror bank records its facts in a learning log, naming the tested atomic; never create a bank only to hold a result.
- Extra banks are permitted only as `boundary-comparison`, `error-diagnosis`, `integration-transfer`, `task-performance`, or `retention`. They must name one or more `related_atomics` or `task_units`, and never require a mirror for the referenced atoms.
- An extra bank supplements, never replaces, an atomic mirror. A prompt bank is not an attempt record and does not activate the queue.
- Keep actual learner attempts only under the review-record heading; generated questions and expected checks remain blank until the learner acts.

## Explicit activation

- Study does not create, activate, schedule, or advance review targets.
- `direct-tech-learning` may hand off review only when the user explicitly requests practice, review, or assessment; it never schedules review automatically.
- `review-tech-learning` may read the queue only after an explicit review-mode request.
- A due date, unfinished task or stage, missing capability evidence, ended session, or produced artifact never switches the user from study to review.

## Verification levels

1. Causal prediction.
2. Fault localization and minimum correction.
3. Changed-context transfer.
4. Later retention check.

Use these levels as review design surfaces, never as default validation or mandatory gates for task-package progress or completion.

## Queue update

Only after `record-tech-learning` has recorded an actual review or assessment result:

1. read the latest attempt, result, and hint dependence;
2. derive the next verification level and optional window;
3. update the active, waiting, or exited queue section;
4. cite the factual record used;
5. preserve all prior facts.

Incorrect, incomplete, or hint-dependent results may receive a changed prompt on a later user-selected review session. Successful transfer may receive a later retention check. These are queue suggestions, never automatic calendar entries.
