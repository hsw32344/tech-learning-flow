---
name: study-tech-learning
description: Teach or continue source-backed technical learning, or prepare a cumulative learning snapshot. Use for 开始学习、继续学习、下一片、从这里接着学、准备学习快照. Explain core causal logic, resume within a slice, and advance on user choice without FCC completion or artifact evidence. Practice and assessment are explicit-only.
---

# Study technical learning

## Load a bounded context

Bind the Vault first: resolve it from the tracked pointer `%USERPROFILE%\.agents\tech-learning-flow\vault-path.txt` or the user's explicit path; if it is missing or uninitialized, run `scripts/init-vault.ps1` to create the minimal valid skeleton.

Read `references/study-session-protocol.md` once per conversation, reloading only if changed or no longer available. It owns teaching, content checks, and resume behavior. Do not preload the schema, terminology, complete mainline, source registry, logs, or whole cumulative snapshot.

Use `scripts/build-packet.py --vault <root>` with an explicit Python interpreter (prefer an existing venv; otherwise resolve and verify an installed interpreter). Pass `--unit`, `--slice`, or `--locator` when the user or visible conversation identifies them. The script invokes the packaged resolver and returns only selected task/source metadata, target slice, necessary blockers, and an independent teaching checkpoint. Add `--material-only` only for snapshot preparation. No installation is required; the runtime uses Python's standard library and PowerShell.

Resolve user's selection first, then the latest visible conversation, then saved teaching state. The homepage selects a task; the snapshot's next locator selects material acquisition only. Neither proves a teaching position. Honor explicit continue/skip/location choices without evidence requests. If only a location without cached content is known, acquire exactly that source. If no teaching location is recoverable, ask one short location question rather than infer it from material completion. User input alone is sufficient.

## Select cache or source

Inspect only the returned target. `cache_candidate` means structural/task/source checks passed; apply the content rubric before treating it as a verified cache. A shallow but source-sufficient explanation needs causal repair, not automatic network refetch. Missing source content, disputed facts, version conflicts, or requests for current/verbatim wording require the smallest live fragment. Never infer provenance from field presence.

For a cache hit, use the original source locator and verification date without fetching or rewriting. If no eligible target exists, use `load-tech-learning-source`. Read the FCC manual only for FCC live acquisition or unresolved FCC structure, not for a verified cached slice. Reuse any packet already visible and sufficient in this turn.

## Materialize only new or changed material

For new/corrected source-backed material, read `25-资源区/学习快照/学习快照使用说明.md` and `90-模板/学习快照模板.md` on demand. Require a verified source packet, perform the content check, preserve existing slices, write the cumulative snapshot, and run `scripts/validate-snapshot.ps1`. Do not rewrite an unchanged cache. Generated supplements must retain their labels and must not falsify the source verification date.

Snapshot-only requests stop after material handoff and never move teaching checkpoints. Requests including learning continue into teaching in this same turn.

## Teach and check

Follow the session protocol and use `scripts/check-draft.py` on the exact draft plus its bounded Agent content review. Fix only deficient mechanisms and rerun after changes. The checker validates structure and review coverage, not semantic truth; the Agent must actually perform the content review. Keep review details in temporary artifacts, not in the lesson or user activity logs.

Persist lightweight resume state through `scripts/write-checkpoint.py` as specified by the protocol. Allowed writes are the bound cumulative snapshot, `25-资源区/学习快照/.study-state` runtime sidecar, scratch draft/review files under `97-临时/`, and explicitly selected source files. Do not alter homepage/mainline, terminology, logs, or review queues from study mode. Never convert examples into required user deliverables.

Focused follow-up questions use `answer-tech-learning` without losing this teaching cursor. Explicit practice uses `review-tech-learning`; only explicit activity recording uses `record-tech-learning`. No silent mode changes.
