# Source loading protocol

Use this reference only for `load-tech-learning-source`.

Build local context with `scripts/build-source-context.py --vault <root> [--unit ID] [--slice N-N] [--locator TEXT]`. Without `--unit` it uses homepage `current_unit`. This entry never reads teaching checkpoints or `active.json`; teaching and material cursors are isolated by implementation, not by an optional flag.

## Data contracts

- `material_context` is the JSON object emitted by `build-source-context.py`. It contains resolver facts, one snapshot projection, structural validation, and cache-candidate facts. It is internal preflight data, not the user-facing result, and has no `verified` / `partial` / `blocked` status.
- `source_packet` is the concise Markdown result defined below. Only load creates its evidence verdict after screening cached material or acquiring source content. It alone has `status`, `retrieval_mode`, coverage, learning input, and resume fields.
- Copying fields from JSON to Markdown does not establish verification. `cache_candidate: true` means only that the cached slice may be screened; it does not imply `source_packet.status: verified`.

## Source classes

- `teaching-open`: load the actual public tutorial section. A dynamic or authenticated course requires a browser surface that exposes the available session.
- `technical-authority`: load the narrow official section when it is primary; otherwise use it only to verify version-sensitive behavior or resolve a conflict.
- `user-selected`: load only the exact URL, file, Notebook, or visible page selected for this request. Do not persist the selection.
- `physical-book`: require a confirmed edition, chapter, and user-accessible excerpt or file. Otherwise return `blocked`.
- `agent-fallback`: fetch nothing. Produce only the declared reason, scope, and uncovered boundary, labelled as Agent-authored input.
- Job evidence and priority decisions are not material sources; keep them in job analysis and route decisions.

A declared `gap_source` may fill only its named gap. Multiple undeclared tutorials must not be stitched into an Agent-designed course.

## FCC operational authority

When the resolved source code starts with `FCC-`, read `99-附件/FCC学习操作范式.md` from the bound Vault and follow it before live acquisition. Resolve curriculum structure from the freeCodeCamp repository rather than guessing block names or relying on a redirect-prone course shell. Verify the superblock, ordered block, challenge file, title, and `challengeType`. Apply the manual's lecture/workshop/lab/review/quiz/exam classification and exclusions. An eligible snapshot-cache slice preserves that prior verified structure; an ineligible snapshot supplies routing only.

## Coverage slice

Build a short checklist from the resolved task row:

1. canonical content needed now;
2. causal state, rule, data or control flow, result, and boundary;
3. minimum artifact supported by this slice;
4. one directly blocking prerequisite, if observed.

Select the earliest coherent source section that covers the current checklist. Preserve the source's actual order. Do not expand easy foundations, later projects, reviews, quizzes, or certification material merely for completeness.

## Acquisition budget

Use the least expensive available source surface:

1. reuse exact content already visible in the current turn or selected artifact;
2. reuse an eligible snapshot-cache target slice;
3. read a stable public page directly when its body is exposed;
4. use the in-app browser for visible navigation;
5. use the user's Chrome session when authentication or existing Chrome state is required.

By default, inspect at most two teaching pages for one source packet and one additional official page when a technical fact needs verification. Stop earlier when the source packet is sufficient. If the budget is insufficient, return the remaining gap instead of crawling the site. Expand only when the user requests a broader capture or the current section links to a directly required continuation.

Do not install dependencies, change browser or Windows proxy settings, or alter login state. Do not save bulk page copies. Save a normalized source packet to an explicitly selected source workspace only when the user requests it.

## Evidence gate

Classify the result:

- `verified`: actual URL or path, page or document title, exact section heading, and relevant body/code are visible; the content supports the declared task slice.
- `partial`: some real body or structure is visible, but the exact section, task match, or coherent slice remains insufficient.
- `blocked`: the locator is missing, inaccessible, authentication-dependent without a usable session, or unsuitable for the task.

A snapshot target is a cache candidate when the packaged validator passes, its unit and primary source match the resolver, the snapshot's `source_packet_status` records an eligible prior Markdown source-packet result, the target row and structured slice are complete, and no unresolved issue invalidates it. Before reuse, screen only that target material for coherent required fields and causal chain, plus obvious contradictions, impossible expected results, or known language/API conflicts. Do not fetch a second source for this screen. Only after this screen may load emit a Markdown source packet with `agent_cache_check: passed`, `retrieval_mode: snapshot-cache`, and `status: verified`. For `uncertain` or `failed`, add a short `agent_cache_notes` and fetch only the disputed or missing minimum fragment. The result is conversational and ephemeral; it is not persisted evidence or proof of correctness, current-source freshness, or verbatim wording.

HTTP status, a front-end shell, metadata, a catalog card, a search snippet, a course progress number, or a generated outline cannot satisfy the gate. Never turn `partial` into a confident lesson by filling missing content from model knowledge.

A Markdown source packet with `retrieval_mode: live-source`, `status: verified`, and coherent complete coverage may cross the snapshot materialization gate. `load-tech-learning-source` hands it to `study-tech-learning`, the sole snapshot writer; the loader does not persist the source packet. Materialization and structural validation occur before teaching that new slice, while learner activity remains a separate state.

## Markdown source packet contract

Return concise Markdown with these fields:

```markdown
## Source packet

- unit: `<task-package-id>`
- source: `<registered-code or user-selected>`
- source_role: `<role>`
- status: `<verified|partial|blocked>`
- retrieval_mode: `<snapshot-cache|live-source|agent-fallback>`
- actual_locator: `<exact URL/path plus section heading, or unknown>`
- source_verified_at: `<YYYY-MM-DD|无/不适用|未知/待核验>`
- agent_cache_check: `<passed|uncertain|failed; snapshot-cache candidates only>`
- agent_cache_notes: `<short disputed/missing fragment or none; snapshot-cache candidates only>`
- task_slice: `<one useful boundary>`
- retrieved_at: `<current date and time zone when live content was read>`

### Coverage
- covered: `<task requirement -> actual source section>`
- remaining: `<uncovered requirement or none>`

### Learning input
- framework: `<where this slice fits>`
- causal_flow: `<state -> rule -> flow -> result -> boundary>`
- key_material: `<compact paraphrase and essential code shape>`
- technical_checks: `<official correction or none>`

### Resume
- next_locator: `<exact next heading/link or unknown>`
- blocker: `<missing access/action or none>`
- excluded: `<material deliberately not loaded>`
```

Omit empty repetition, not the evidence fields. Use short quotations only when wording itself matters. The Markdown source packet is source input, not proof of study, completion, independent performance, or mastery.

## Cursor and adequacy boundary

For study, accept explicit user/conversation location or the independent teaching checkpoint. The snapshot next locator is material-only. Insufficient explanation with sufficient verified source content is repaired by study without refetch; only missing/disputed source content requires acquisition. No FCC completion, runnable submission, or mastery evidence is needed to select or continue a source slice.
