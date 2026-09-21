---
name: load-tech-learning-source
description: Resolve a fixed tech_vault task package to its registered learning source, acquire the smallest verified section needed for the current task slice, and return a compact source packet for study-tech-learning. Use for 抓取当前任务包资料、从 FCC 或菜鸟教程提取相关内容、加载主学习源、解析真实课程章节、准备学习资料, or whenever study-tech-learning lacks an accessible exact source section. Support registered public tutorials, official documentation, explicit user-selected web or local material, physical-book locators, bounded gap sources, and declared Agent fallbacks. Remain read-only to the Vault and never silently change the learning route.
---

# Load technical learning source

Load source evidence for one task slice without teaching, assessing, or changing the route.

Prioritize the current situation/goal, concrete objects and relationships, source demonstrations and observable results. Supply principles and boundaries that support those inputs, not a compulsory lecture on internals. Material coverage is not a requirement to teach every stored detail in one response; never fabricate a source example to fill a packet field.

## When to use

- `抓取当前任务包资料`、`从 FCC 或菜鸟教程提取相关内容`、`加载主学习源`、`解析真实课程章节`、`准备学习资料`; whenever study lacks an accessible exact source section.
- Read-only: this mode never writes the snapshot, learner activity, or route state.

## Inputs

- Vault binding: the tracked pointer or the user's explicit path; when missing or uninitialized, ask the user to initialize through `direct-tech-learning` or `study-tech-learning`.
- Priority: explicit task package + source/section -> explicit task package + registered primary source -> homepage `current_unit` + registered primary source, resolved through `scripts/resolve-source.ps1 -VaultRoot <root> [-UnitId <id>]`.
- Reuse before fetching: an exact section already visible in this conversation, an eligible snapshot-cache slice, a selected browser tab, or a named source artifact.
- For a cache candidate run `scripts/build-source-context.py` once; without `--unit` it uses homepage `current_unit` and never reads `.study-state`. Do not repeat the resolver or structural-validation calls.

## Minimal reads

- Read `references/source-loading-protocol.md`; use the resolver output instead of loading the complete mainline and source registry.
- For cache reuse, inspect only the JSON `material_context` fields `target_row`, `target_body`, `source_fields`, and `blockers`; apply the lightweight content screen without loading a second source.
- Read the returned FCC manual only for live FCC acquisition or uncertain course structure.
- If the resolver script is unavailable, read only the matching unit row, source declaration, registry entry, and homepage position.
- Extend only when: the target slice is missing, structurally invalid, `partial`/`blocked`, mismatched with the registered task/source, invalidated by an unresolved issue, or explicitly requested as verbatim/current.

## Allowed writes

- None to the Vault. A verified Markdown source packet is handed to study; source acquisition and generated source packets are never learning activity, completion, or capability evidence.

## Handoff

- A Markdown source packet with `status: verified` on a request that asked to learn -> hand directly to `study-tech-learning` in the same turn without asking again.
- Material-only requests stop after returning the Markdown source packet.
- Source substitution or persistent locator changes -> `direct-tech-learning`; for `partial`/`blocked` report the failed locator, observed evidence, and exact missing capability or user action.

## Done check

- The Markdown source packet has `status: verified`, `partial`, or `blocked` and follows `references/source-loading-protocol.md`; the preceding JSON `material_context` has no such verdict.
- Only a visible section body, or a structurally valid eligible cache slice passing the content screen, counts as verified; HTTP success, course shells, catalog cards, progress counts, search snippets, and guessed outlines never do.
- Paraphrase source material; quote only short identifying text; never invent course content or infer a stopping position from course progress.
