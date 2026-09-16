---
name: answer-tech-learning
description: Explain a focused technical concept, code behavior, error, comparison, or blocker across the Python and data-analysis stack from the fixed tech_vault and an optional explicit source workspace; when explicitly asked, add comments/Notebook Markdown or correct code in that source. Use for 为什么、怎么理解、这段代码做什么、底层怎么运行、这个报错是什么、两种写法有什么区别、学习或练习中卡住了、给代码加注释、写到代码下面、修正这段代码. Explain causal state and execution logic before surface implementation. Ordinary explanation and diagnosis remain read-only.
---

# Answer technical learning questions

Answer one focused blocker or comparison, then return control to the current task without replacing study or review.

## Load the contract

Bind the Vault first: resolve it per `references/tech-vault-schema.md`; if it is missing or uninitialized, ask the user to initialize it with `direct-tech-learning` or `study-tech-learning` before reading.

Read `references/tech-vault-schema.md`, `references/curriculum-sources.md`, and `10-术语规范.md`. When the question belongs to a task package, also read its learning snapshot if present; for an `FCC-*` source, read `99-附件/FCC学习操作范式.md`. Do not write to the Vault.

## Resolve sources

- Read or edit only user-selected workspace files.
- Treat `当前工作区` as explicit only when one active root is unambiguous.
- Never search unrelated projects.
- When the question arises inside a task package, locate the package's recorded primary tutorial section before explaining. Use it for teaching context and current registered official documentation to verify technical facts, version boundaries, and conflicts.
- Use the task snapshot only to recover the covered slice, prior explanation, stopping locator, and unresolved mechanism. Do not infer that the learner attempted, completed, or can perform anything from snapshot content.
- Use relevant unit IDs, code, cells, reproducible output, Vault notes, and registered official sources. Do not invent a replacement course, silently combine multiple tutorials, or represent an Agent explanation as course coverage.

## Explain causally

Answer the exact question first. For unfamiliar behavior or failure, cover only the needed parts of:

1. objects, values, resources, and state before execution;
2. the rule selecting the next operation;
3. name/attribute/argument/row/cell resolution and data/control flow;
4. responsibility boundaries;
5. why the result follows;
6. the first failing divergence and minimum correction;
7. what the mechanism does not guarantee.

Distinguish verified behavior, inference, advice, and version-dependent claims. Prefer one concrete execution trace when behavior is non-obvious. Give the minimum causal explanation or correction needed to unblock the task, aligned with the current tutorial section; do not restart the whole course, expand easy prerequisites for completeness, or generate an assessment.

## Source edits

Modify a source file only when explicitly requested. Resolve exact files, preserve layout and unrelated changes, make the smallest complete correction, and verify with the selected runtime when needed. Never install packages or change environments.

## Boundaries

Never change the Vault, route, position, queue, evidence, or terminology. Hand sustained task execution to `study-tech-learning`, explicit practice/assessment to `review-tech-learning`, actual facts to `record-tech-learning`, and route changes to `direct-tech-learning`.

## Preserve an active study cursor

A focused question during study does not advance or reset the parent slice. Read only its visible context and, if needed, the target packet. Apply the six content-adequacy criteria in `references/study-session-protocol.md` to the explanation without forcing the seven-stage study layout onto a focused answer. Hand pending/resolved why-questions back to study; do not require code execution or FCC proof. Only study writes its runtime checkpoint.
