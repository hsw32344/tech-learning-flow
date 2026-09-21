---
name: answer-tech-learning
description: Explain a focused technical concept, code behavior, error, comparison, or blocker across the Python and data-analysis stack from the fixed tech_vault and an optional explicit source workspace; when explicitly asked, add comments/Notebook Markdown or correct code in that source. Use for 为什么、怎么理解、这段代码做什么、底层怎么运行、这个报错是什么、两种写法有什么区别、学习或练习中卡住了、给代码加注释、写到代码下面、修正这段代码. Repair the learner's mental model and explain the current operation with one concrete example. Ordinary explanation and diagnosis remain read-only.
---

# Answer technical learning questions

Answer one focused blocker or comparison, then return control to the current task without replacing study or review.

## When to use

- `为什么`、`怎么理解`、`这段代码做什么`、`底层怎么运行`、`这个报错是什么`、`两种写法有什么区别`，or a focused blocker during study or practice.
- Explicitly requested comments/Notebook Markdown, or a minimal correction in a selected source file.

## Inputs

- Vault binding: an explicit path, or the tracked pointer `%USERPROFILE%\.agents\tech-learning-flow\vault-path.txt`. If neither resolves, ask the user to initialize or bind a Vault; never scan unrelated directories. This mode never writes to the Vault.
- Workspace: only user-selected files, or `当前工作区` when one active root is unambiguous.
- Question context: the exact question, selected code/cells/reproducible output, and, when continuing a task package, the visible parent slice, JSON study/material context, Markdown source packet, or conversation context.
- If the binding mechanics themselves are unclear, read `references/vault-binding.md`; it is never a mandatory preload.

## Minimal reads

- Read only the question, the selected code or target slice, the terminology rows that matter, and the visible parent context.
- Reuse any matching JSON context, Markdown source packet, or teaching context already visible in this conversation; do not re-resolve the task or re-read the whole mainline and snapshot.
- A task snapshot is read only to recover the covered slice, prior explanation, stopping locator, and unresolved mechanism; it never proves an attempt, completion, or ability.
- For an `FCC-*` task read `99-附件/FCC学习操作范式.md` before explaining.
- Extend only when: the source or version is disputed, the question leaves the visible slice, or the user explicitly asks for verification.

## Allowed writes

- No Vault state: never change route, position, queue, evidence, terminology, logs, or snapshots.
- A selected source file only when explicitly requested: smallest complete correction, preserve layout and unrelated changes, verify with the selected runtime when needed; never install packages or change environments.

## Handoff

- Sustained task execution -> `study-tech-learning`; explicit practice/assessment -> `review-tech-learning`; actual facts -> `record-tech-learning`; route changes -> `direct-tech-learning`.
- A focused question during study preserves the parent cursor: hand pending/resolved why-questions back to study, which alone writes the runtime checkpoint.

## Done check

- Conceptual confusion: identify the objects being confused, name their relationship, and use one stable example or diagram. Do not require failure diagnosis or an executable task for a vocabulary question.
- Operational blocker: use the actual starting state, command and observed output to locate the first meaningful divergence and explain the smallest correction. State relevant risks before a destructive operation.
- Explicit depth request: build on the visible model and explain internals as far as requested; do not suppress useful principles merely to shorten the answer.
- If the previous explanation caused ambiguity, correct that wording first. For example, Git branch "position" means the commit it points to, not the repository's address; "远端会离开吗" should not trigger an unsolicited tour of deletion, force-push and pruning.
- "完全没懂" calls for a more concrete model, not more terminology. Tie each new term to the same example; do not manufacture questions or rare counterexamples. Preserve the parent cursor until the issue is answered or explicitly skipped.
- Verified behavior, inference, advice, and version-dependent claims stay distinguishable. Run a minimal experiment only for a material technical uncertainty or explicit verification request, not as a routine concept-answer ritual. Reuse visible context; do not reread full snapshots, terminology tables or implementation scripts for a focused follow-up.
- Keep internal review and tool planning out of the lesson; progress messages report only meaningful findings or blockers.
- Do not restart the whole course, expand easy prerequisites for completeness, or generate an assessment.
