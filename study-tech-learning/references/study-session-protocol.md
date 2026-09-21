# Study session protocol

This is the single authority for conversational teaching, content quality, and teaching continuity. Source adapters own source location; the snapshot guide owns material storage. Read this once while unchanged, not again for each slice.

## User control and scope

“继续 / 下一片 / 跳过 / 从这里开始” is sufficient to move the teaching position. Never require FCC completion, a runnable submission, a closed-loop artifact, a quiz, or proof of understanding. Examples support explanation; executing them is optional. Do not automatically record mastery or repeat evidence disclaimers in ordinary lessons. Source fidelity and teaching quality remain the Agent's responsibility.

Preserve source order and existing slice IDs. Default to one coherent goal within a slice; split a dense slice at a usable model or operation rather than compressing its explanation. Keep stable internal mechanism IDs for continuity, without requiring them in visible headings. Explicit wider requests may cover multiple parts/slices in source order; review the exact combined response. Do not reorder the curriculum; delivery of a paragraph never overrides a user's report of confusion.

## Lightweight input

Run `scripts/build-study-context.py --vault <root> [--unit ID] [--slice N-N] [--locator TEXT]` for teaching and continuation. It returns JSON with `kind: study_context`: compact material fields plus the runtime teaching checkpoint. Snapshot-only preparation uses `scripts/build-source-context.py`, which returns JSON with `kind: material_context` and never reads `.study-state`. These JSON contexts are internal resolver/projection results, not Markdown source packets and not source-verification verdicts. Neither entry prints unrelated slices. Do not re-read complete registries or snapshots after receiving sufficient context.

## Teaching priorities and natural layout

Priority: build a usable mental model, teach the current operation, then supply principles and boundaries that support those goals. Start with the user's known objects and one concrete situation. The usual flow is situation/goal -> smallest useful model -> demonstration/operation -> observable before/after change -> necessary explanation. This is a teaching sequence, not five mandatory headings.

- Use natural headings, diagrams, code and examples as useful. There is no fixed seven-section layout, mandatory why-question, S/M heading, separate boundary paragraph or job mapping. Do not replace the old template with another compulsory template.
- Tie each new term to a concrete object, visible state or result when introduced. Keep names and examples stable. Explain what vague words such as "position", "reference" and "synchronization" refer to; an analogy must not blur different objects.
- For operations, state the relevant starting conditions, where to run the command, what it acts on and what to observe afterwards. Show the normal path first. A conceptual lesson may establish a relationship through a diagram or example without an executable task.
- Interleave source-backed explanation and clearly attributed supplements around the same operation. Do not lecture on all source facts first and repeat them in a separate mechanism section. Preserve source coverage/order and provenance, not a source-vs-explanation presentation wall.
- Include principles when they explain the current result or decision. Include boundaries when they affect the next operation, explain an observed/common failure, or the user asks. Explain destructive-operation risks before execution. Do not invent rare failures, internal paths or implementation trivia for completeness; an explicit deep question may warrant a deeper answer.
- A demonstration or optional follow-along is learning, not a compulsory quiz or evidence gate. With a user-selected video or sandbox, anchor help to the actual chapter, timestamp, visible diagram or command; ask for the missing locator only when needed. Do not invent what a video shows or silently replace the registered route because the user mentions FCC or Learn Git Branching.

Keep source attribution brief and truthful. Use a short source link/locator and mark Agent examples or corrections when needed; the existing provenance labels remain available, not mandatory on every paragraph. `[主源原文]` is faithful paraphrase, not necessarily verbatim; fallback cannot claim source-original provenance. Do not demand source-check answers. Resume without replaying prior paragraphs; handoff reports only current position, unresolved issue or next action when useful. Do not narrate internal deliberation, review scaffolds or routine tool steps, or repeat mastery disclaimers in ordinary lessons.

## Content adequacy gate

Before sending, make a bounded Agent review of the actual response. Field completeness and correct final output are not evidence of a useful explanation. Review these criteria:

1. `focus`: one identifiable goal, rooted in the learner's visible context, with no unneeded expansion.
2. `model`: concrete objects and relationships; new terms have clear referents. Reject vague analogies and jargon lists.
3. `example`: a coherent example/diagram connecting the model to a result; do not switch scenarios at every definition.
4. `operation`: for operational or mixed lessons, enough starting context, execution location, action and before/after observations to follow. Only a purely conceptual lesson may mark this not applicable, with a reason.
5. `depth`: principles explain the current model/action; boundaries have a reason to appear. Reject both unexplained command recipes and gratuitous internals. Necessary risks precede the action.
6. `source`: verified coverage, source order, faithful attribution and version-sensitive technical accuracy. A source identifier alone is not verification.

Reuse sufficient verified input. Repair unclear teaching without reacquiring sources; acquire only missing/disputed source content. Run code only for material uncertainty or an explicit verification request. Do not reread whole snapshots, registries, terminology tables or tool implementations when visible context suffices.

Prepare the exact draft and internal review under `97-临时/`. Generate a version-2 scaffold; the tool owns the draft hash and ordered block spans/hashes (including code fences). These block IDs are internal evidence anchors, not learner-facing headings or persisted teaching positions:

`<explicit-python> scripts/check-draft.py --draft <draft.md> --emit-review <review.json>`

Fill in statuses and evidence references, then validate:

`<explicit-python> scripts/check-draft.py --draft <draft.md> --review <review.json>`

Fill `goal`, `lesson_kind` (`operation`, `concept` or `mixed`), and the source list in actual teaching order. Each source has a unique `id`, exact `locator` and `role` (`primary`, `supplement` or `fallback`). Retain the generated spans/hashes. For every block set `sources` to the IDs that support it; Agent-authored supplements use an explicit Agent locator and attribution, not a fabricated URL. Example review fields (block hashes/spans/labels come from the scaffold, never hand-authored):

```json
{
  "schema_version": 2,
  "draft_sha256": "generated",
  "goal": "取回团队更新并观察本地分支的变化",
  "lesson_kind": "operation",
  "sources": [{"id": "S1", "locator": "Pro Git 2.5 / verified source packet", "role": "primary"}],
  "blocks": {
    "B1": {"sources": ["S1"]}
  },
  "checks": {
    "model": {"status": "pass", "evidence": ["B1"], "reason": "同一提交图区分本地分支和远端跟踪引用"}
  }
}
```

All six checks require a status, nonempty reason and real block evidence. `fail`, `uncertain` or `unreviewed` block delivery. Only `operation` may be `not_applicable`, and only for `lesson_kind: concept`; explain the absence of a runnable operation. Re-emit and re-review after any draft edit, never refresh only a hash. The tool verifies bindings, spans, coverage and review completeness; Agent judgment establishes whether the example teaches well or the sources really support it. Never manufacture passes or claim semantic correctness from script success.

Historical seven-section drafts can be checked only with `--format legacy` (both scaffold and validation). New lessons use default `--format natural` and schema 2. Legacy readability does not certify new teaching quality; no bulk historical migration is needed.

## Resume contract

Material cursor and teaching cursor are independent. Snapshot stop/next fields describe generated material only. Homepage position is route context, not proof of delivered teaching.

Selection priority: explicit user selection (no evidence needed) -> latest identifiable conversation position -> saved teaching checkpoint -> explicit task-scoped stopping record, if needed. Never use the material cursor to skip teaching. If unresolved, ask once for a starting position, accept the answer, and proceed.

Runtime state is `25-资源区/学习快照/.study-state/<unit>.json`, separate from snapshot prose and all learner logs. It stores schema version, unit, source, slice/locator, mechanism, delivered mechanisms, pending questions, next action/unit/slice/locator, target content hash, status, and revision. An atomic `active.json` pointer selects the last teaching task when no unit is supplied; it never changes homepage/mainline. It has no FCC completion, mastery, time quota, or required artifact fields. Use `study_context.state_revision` for optimistic concurrency.

Keep existing checkpoint fields and mechanism IDs compatible. Internal review block IDs are draft-local and must not replace stable checkpoint IDs. A report of confusion or a wording correction preserves the parent slice; study alone reconciles pending/resolved questions returned by answer-tech-learning. Do not require a quiz to resume.

`scripts/write-checkpoint.py --vault <root> --unit ID --input <state.json> --expected-revision N`

Allowed status:
- `user-selected`: user explicitly chooses this position; accept without proof.
- `pending`: draft prepared but delivery not yet established. Do not advance next time from an unsent draft.
- `delivered`: prior response is actually visible in conversation; only then may its next position be used.
- `interrupted`: resume at the incomplete mechanism boundary and preserve pending questions.

Before a final response, save pending state. On the next turn, reconcile it with visible response/user continuation and update delivered state before advancing. If delivery cannot be determined, resume at the recorded mechanism with a short recap instead of skipping. Source/material writes never commit delivery. A follow-up “why” adds/repairs a pending issue and preserves the parent cursor; ordinary “continue” resolves that issue first unless the user explicitly skips it.

Concurrent changes must fail with a revision conflict; reread and reconcile instead of overwriting. A changed target hash/source requires checking the affected slice, not replaying the entire task or treating the stale cache as fresh. A prepared future slice elsewhere in the snapshot must not invalidate the current slice by itself.

## Storage and mode boundaries

Only new/expanded/corrected source-backed material is written and structurally validated before teaching. Cache hits require no rewrite. Snapshot preparation leaves teaching state untouched. Study may persist runtime checkpoints, not learner results or route changes. Focused answers preserve continuity; practice/review remains explicit-only. Reading/continuing/skipping never requires independent performance evidence. Snapshots live in `25-资源区/学习快照/`; temporary drafts and reviews live in `97-临时/`; the source workspace is written only when the user explicitly selects a file.

Content is reused, not regenerated: verified snapshot fragments may be copied into the draft directly; when the causal explanation is shallow, repair only the deficient mechanism; never reproduce the same full explanation in the snapshot, the draft, and the summary. The validated draft is exactly what is sent to the user.
