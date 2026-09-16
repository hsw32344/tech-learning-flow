---
name: load-tech-learning-source
description: Resolve a fixed tech_vault task package to its registered learning source, acquire the smallest verified section needed for the current task slice, and return a compact source packet for study-tech-learning. Use for 抓取当前任务包资料、从 FCC 或菜鸟教程提取相关内容、加载主学习源、解析真实课程章节、准备学习资料, or whenever study-tech-learning lacks an accessible exact source section. Support registered public tutorials, official documentation, explicit user-selected web or local material, physical-book locators, bounded gap sources, and declared Agent fallbacks. Remain read-only to the Vault and never silently change the learning route.
---

# Load technical learning source

Load source evidence for one task slice without teaching, assessing, or changing the route.

## Resolve locally first

Bind the Vault first: resolve it from the tracked pointer `%USERPROFILE%\.agents\tech-learning-flow\vault-path.txt` or the user's explicit path; if it is missing or uninitialized, ask the user to initialize it with `direct-tech-learning` or `study-tech-learning`.

Read `references/source-loading-protocol.md`. Run `scripts/resolve-source.ps1` with the bound Vault root and the user's explicit unit ID. Omit `-UnitId` only when the active homepage unit should be used.

Use the resolver output instead of loading the complete mainline and source registry into context. If the script is unavailable, read only the matching unit row, source declaration, registry entry, and homepage position.

For live FCC acquisition or uncertain source structure, read the returned FCC manual. For a cache candidate, use `scripts/build-packet.py` to extract only the target slice; do not read the whole snapshot or storage guide. A target slice whose packet and bounded content check satisfy `references/study-session-protocol.md` is prior verified source evidence for its covered target slice; an ineligible snapshot remains routing and stopping/next-locator context only.

Use this priority:

1. the user's explicit task package and source or section;
2. the user's explicit task package and its registered primary source;
3. the homepage `current_unit` and its registered primary source.

An explicitly selected source applies only to the current request unless `direct-tech-learning` persists a route change.

## Reuse before fetching

Reuse an exact source section already visible in the current conversation, an eligible snapshot-cache slice, selected browser tab, or explicitly named source artifact when its URL or path, heading, and body are still identifiable. Do not fetch the same section again merely to restate it.

For a snapshot-cache candidate, reuse the current `scripts/build-packet.py` result or run it once; it already resolves the task/source and runs structural validation. Do not repeat those calls. Inspect only its target and relevant source/blocker fields. Apply the lightweight Agent screen from `references/study-session-protocol.md`: check required-field/causal-chain completeness and obvious correctness conflicts without loading a second source. When it passes, return a `verified` source packet with `retrieval_mode: snapshot-cache`, the original locator, `source_verified_at`, and `agent_cache_check: passed`; do not access the network. When source evidence is uncertain or failed, acquire only the disputed or missing fragment. When source evidence is sufficient but causal teaching is shallow, hand the explanation gap to study for local repair without fetching again. Pending source interaction does not invalidate the cache.

Do not search unrelated workspaces or infer a stopping position from course progress. For material preparation use the snapshot material locator. For teaching use the explicit user/conversation location or independent teaching checkpoint; never infer it from the material cursor. Read task-scoped records only when needed and accept a user-selected position without evidence. The resumed source body must still pass the evidence gate.

## Acquire one bounded slice

Follow `references/source-loading-protocol.md`:

1. derive a coverage checklist from the task's canonical content, causal model, and expected artifact;
2. open the registered or user-selected locator with the least expensive available tool;
3. verify the actual URL or path, title, section heading, and relevant body or code;
4. collect only one coherent section cluster needed for the current task slice;
5. use the declared gap source only for its named gap;
6. use official documentation only to verify version-sensitive behavior or when it is the declared primary source;
7. stop when a verified source packet can support one useful study boundary.

For an `FCC-*` primary source, use the FCC manual's structure-first repository flow: resolve the superblock from `curriculum.json`, take ordered block IDs from the superblock structure JSON, enumerate the exact block directory, then verify each challenge body and `challengeType`. Never guess a block name. Treat lecture blocks as study slices and exclude workshop, lab, review, quiz, and exam blocks from automatic study as the manual specifies.

Treat an HTTP success, course shell, catalog card, progress count, search snippet, or guessed outline as insufficient source evidence. For dynamic or authenticated material, use a browser surface that can expose the user's available session. If that surface is unavailable, return `blocked` rather than inventing course content.

## Return a source packet

Return the compact Markdown packet defined in `references/source-loading-protocol.md`. Mark it exactly `verified`, `partial`, or `blocked`.

- Use `verified` only when the actual section body is visible and sufficient for the declared task slice.
- A structurally valid eligible snapshot target whose lightweight Agent screen passes counts as a previously visible and verified body for that slice. The screen is an ephemeral filter, not proof of correctness, current freshness, or verbatim wording, and is never persisted to the snapshot, route, logs, review state, or validator schema.
- Use `partial` when some source evidence is real but cannot yet support a coherent study slice.
- Use `blocked` when the declared source cannot be accessed, located, or matched.

Paraphrase source material. Quote only short text needed to identify or explain the section; never reproduce a whole lesson or page.

A new live-source packet marked `verified` is eligible for `study-tech-learning`'s snapshot materialization gate before teaching. This loader remains read-only: it hands off the packet and never writes the snapshot, learner activity, or route state itself.

## Hand off cleanly

If the user asked only to prepare material, return the packet and stop. If the same request explicitly asks to start or continue learning, pass a `verified` packet directly to `study-tech-learning` in the same turn without asking again.

For `partial` or `blocked`, report the failed locator, observed evidence, and exact missing capability or user action. Hand a source replacement or persistent locator change to `direct-tech-learning`; do not choose a new primary tutorial silently.

Never write Vault progress, logs, terminology, mainline, source registry, or review state. Source acquisition and generated packets are not learning activity, completion, or capability evidence.
