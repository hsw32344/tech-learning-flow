---
name: study-tech-learning
description: Teach or continue source-backed technical learning, or prepare a cumulative learning snapshot. Use for 开始学习、继续学习、下一片、从这里接着学、准备学习快照. Explain core causal logic, resume within a slice, and advance on user choice without FCC completion or artifact evidence. Practice and assessment are explicit-only.
---

# Study technical learning

Teach or continue source-backed learning; materialize only new or changed material.

## When to use

- `开始学习`、`继续学习`、`下一片`、`从这里接着学`、`准备学习快照`。
- User choice (continue / skip / location) is sufficient to move the teaching position; never require FCC completion, a runnable submission, a closed-loop artifact, a quiz, or proof of understanding.

## Inputs

- Vault binding: the tracked pointer `%USERPROFILE%\.agents\tech-learning-flow\vault-path.txt` or the user's explicit path; when missing, run `scripts/init-vault.ps1` to create the minimal valid skeleton.
- Selection priority: explicit user selection -> latest visible conversation position -> saved teaching checkpoint -> explicit task-scoped stopping record. Never use the material cursor to choose a teaching position; if unresolved, ask one short location question.
- For teaching or continuation run `scripts/build-study-context.py --vault <root>` with an explicit Python interpreter. For snapshot-only preparation run `scripts/build-source-context.py --vault <root>`. Pass `--unit`, `--slice`, or `--locator` when known. Only the teaching entry reads `.study-state`.
- Context reuse: reuse a visible `study_context` or `material_context` when its unit, source, target, and version still match; `study -> load -> study` handoffs must not re-resolve the same task and source. A JSON context is not a Markdown source packet and carries no `verified`/`partial`/`blocked` verdict.

## Minimal reads

- Read `references/study-session-protocol.md` once per conversation; reload only if it changed or is no longer available.
- Inspect only the returned JSON context: target row/body, source fields, blockers, and, for `study_context` only, the runtime checkpoint.
- Read `25-资源区/学习快照/学习快照使用说明.md` and `90-模板/学习快照模板.md` on demand, only when writing new or corrected material.
- Read `99-附件/FCC学习操作范式.md` only for live FCC acquisition or unresolved FCC structure.
- Extend only when: no eligible cache target exists, source facts are disputed, verbatim wording is required, or material must be written.

## Allowed writes

- The bound cumulative snapshot, the `25-资源区/学习快照/.study-state` runtime sidecar, scratch draft/review files under `97-临时/`, and explicitly selected source files only.
- Snapshot gate: for new or corrected material require a Markdown source packet with `status: verified`, run the content screen, preserve existing slices, then run `scripts/validate-snapshot.ps1`; only after it passes may the same request continue into teaching.
- Never rewrite an unchanged cache; never alter homepage/mainline, terminology, logs, review queues, or learner evidence from study; never convert examples into required user deliverables.

## Handoff

- Focused follow-up questions -> `answer-tech-learning` with the parent cursor preserved.
- Explicit practice -> `review-tech-learning`; explicit activity recording -> `record-tech-learning`; route changes -> `direct-tech-learning`. No silent mode changes.
- A pending why-question is resolved before advancing unless the user explicitly skips it.

## Done check

- The exact draft plus its bounded Agent content review pass `scripts/check-draft.py` before sending; fix only deficient mechanisms and rerun after changes.
- Persist resume state with `scripts/write-checkpoint.py` using the `study_context.state_revision`; a position becomes usable only when the response is actually visible in the conversation.
- Keep review details in temporary artifacts; report semantic checking as Agent judgment, never as machine proof.
