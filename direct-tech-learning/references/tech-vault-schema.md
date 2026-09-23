# Tech vault contract

## Closed contract

This is the shared structural and handoff contract for:

- `direct-tech-learning`
- `load-tech-learning-source`
- `study-tech-learning`
- `review-tech-learning`
- `record-tech-learning`
- `answer-tech-learning`
- `analyze-job-requirements`

For route, ledger, or schema changes, read this contract. Ordinary study follows the bounded session protocol and loads storage rules only when writing material; it does not preload this full schema. Role packages receive verbatim extracts of this contract for their own storage rules; the full contract file remains the authoritative full-library view, and the asset sync check verifies every extract stays byte-identical to its source section. Do not add undeclared fields, headings, folders, note types, statuses, dashboards, indexes, or automations.

When a request needs an undeclared structure:

1. stop before changing the Vault or a Skill;
2. name every affected contract, template, Skill, validator, index, and existing note;
3. preview retained, removed, renamed, migrated, and excluded content;
4. wait for confirmation;
5. update and validate all affected files together.

## Vault binding and first-use creation

- Resolve the target Vault in this order: an explicit path the user gives; the `TECH_LEARNING_VAULT` environment variable; the tracked pointer `%USERPROFILE%\.agents\tech-learning-flow\vault-path.txt`; otherwise ask the user once for the Vault path.
- Never infer the target Vault from the current directory and never search unrelated directories for another Vault.
- On first use, `direct-tech-learning` or `study-tech-learning` creates the minimal valid Vault skeleton from its bundled `assets/vault-seed` by running `scripts/init-vault.ps1`; other Skills ask the user to initialize through one of them. The script creates missing directories and files, never overwrites existing content unless `-Force`, records the pointer, writes `.tech-vault.json`, then runs the independent `scripts/validate-ready.ps1` readiness gate and reports `valid`. To bind an existing Vault without copying seed files, use `-Bind`.
- The Vault owns the outermost schema: `.tech-vault.json` embeds the full structural schema plus `schema_version` and instance metadata. The bundle ships only a default seed schema (`assets/vault-schema.json`) used when creating a new Vault. `validate-vault.ps1 -Strict` is the explicit full structural audit maintained by `direct-tech-learning`; it loads the Vault's own schema, falls back to the bundled default with a warning when the schema is absent, verifies the Vault against that schema, and reconciles `schema_version` against the supported version. Routine actions use their registered targets and dependencies instead of this audit. Never silently rewrite user content. The `15-自由笔记/` and `25-资源区/外部/` areas are freeform and never validated; `25-资源区/学习快照/` stores snapshots and `97-临时/` holds scratch files.
- Require an explicitly identified source workspace for source ingestion or editing.
- Treat `当前工作区` as explicit only when one active root is unambiguous.
- Never search unrelated projects to guess a source.
- Environments and source paths are provenance, not Vault runtime state.

## Responsibility contract

| State or artifact | Sole writer | Other Skills |
|---|---|---|
| Source-backed task mainline, task-package unit IDs, primary/gap learning-source roles, confirmed stage, current task and position, plus their homepage mirrors | `direct-tech-learning` | read only |
| Terminology rows for stages and mainline nodes | `direct-tech-learning` | read only |
| Weekly and daily factual ledgers | `record-tech-learning` | route state is read only |
| Markdown source packet for one task slice, with `verified` / `partial` / `blocked` evidence status | `load-tech-learning-source`, conversation | never stored as learning evidence; distinct from JSON material/study contexts |
| Task-first input, explanation, examples, minimum useful artifact and study handoff | `study-tech-learning`, conversation or explicit source artifact | generated content is not learning evidence |
| One cumulative learning snapshot per task package | `study-tech-learning`, `25-资源区/学习快照/<unit-id> 学习快照.md` | other Skills read only; never route or evidence state |
| Explicit practice, review and assessment packet | `review-tech-learning`, conversation or explicit source artifact | never stored in the Vault |
| Technical explanation and explicitly requested source edits | `answer-tech-learning` | no Vault state change |
| User-supplied HR/JD analysis, requirement-source notes, mainline mapping, and route-change handoffs | `analyze-job-requirements` | `direct-tech-learning` receives confirmed route changes; others read only |
| Source delta, daily review, atomic knowledge, review banks and factual weekly evidence | `record-tech-learning` | read only |
| Review queue derived from actual explicit review/assessment attempts | `record-tech-learning` | `direct-tech-learning` and `review-tech-learning` read only |
| Topic maps, homepage current week/latest review, learned-concept terminology | `record-tech-learning` | read only |

There is no milestone index, problem board, project index, source index, mastery ledger, or generated-question evidence.

## Homepage projection ownership

- `direct-tech-learning` owns `current_stage`, task-package `current_unit`, `current_position`, `stage_directions`, and the matching display text under `## 当前学习主线` in `00-首页.md`. It updates these mirrors in the same confirmed write as the mainline state and preserves `current_week` and `latest_review`.
- `current_week` retains its compatibility field name but points to the latest recorded week, not necessarily the current calendar week. Display it under `## 最近周记录`; never create a new week merely because the date changed.
- `record-tech-learning` owns only `current_week`, `latest_review`, and the corresponding factual navigation links on the homepage. It preserves all route mirrors owned by `direct-tech-learning`.
- The homepage route mirrors must agree with `20-学习主线/00-总览.md`. Weekly and daily ledgers may describe historical stage context but never mirror, select, advance, complete, or block the current task.

## Handoff order

- `今天做什么`, `今天安排什么`, `长期怎么学`, `学习路线`, `下一任务`, `调整主线`, `进入阶段`, `切换阶段`, `跳过`, `并行`, `提前学`, `这周推进什么` -> `direct-tech-learning`.
- `开始学习`, `继续任务`, `执行当前任务`, `从当前进度学`, `快速建立框架`, `我有 N 分钟要学习` -> `study-tech-learning`.
- `开始练习`, `给我练习`, `开始复习`, `批量复习`, `验收`, `测试我` -> `review-tech-learning`.
- `学习结束`, `今天学了`, `记录进度`, source ingestion -> `record-tech-learning`.
- `为什么`, `怎么理解`, `这个报错是什么`, a focused blocker, or explicit source correction -> `answer-tech-learning`.
- `分析HR要求`, `分析JD`, `岗位要求需要学什么`, `对照主线`, or `准备纳入主线` -> `analyze-job-requirements`.
- Confirmed job-requirement route proposal -> `direct-tech-learning`; the analyzer never writes the mainline.
- Actual results -> record as facts. A ledger entry never advances, completes, blocks, or selects a task package.
- Task progress changes only through a direct route decision based on an explicit user handoff or override; it is never inferred from a date, duration, generated artifact, or review suggestion.

Never infer a switch between study and review. Continue the current mode only when it is already explicit; otherwise ask the user to choose before execution.

## Source-backed mainline

Path: `20-学习主线/`: `00-总览.md` owns principles and current position; `20-任务包注册表.md` owns task definitions and machine-parseable `primary_source`/`gap_source` bindings; `资料来源注册表.md` owns actual material-source identities and locators; `10-阶段/*.md` owns task ordering; `岗位分析/` owns job-oriented analysis. Scripts read these explicit authorities and never scan arbitrary mainline Markdown for registry data.

The source-backed mainline is composed from the task package registry and stage ordering. It must contain:

1. source hierarchy and conflict rules;
2. current stage, unit, and position;
3. ordered stages and stable unit IDs, with `current_unit` serving as the active task-package ID;
4. each task package's canonical outcome, framework role, prerequisites, underlying causal model, bounded coverage/output, and learning-source binding in `20-任务包注册表.md`: exactly one machine-parseable `primary_source` line with source type and locator, plus at most one machine-parseable, explicitly bounded `gap_source` line. The exact line format is owned by `curriculum-sources.md`;
5. stage practical outputs;
6. conditions and user authority for route changes.

Read `curriculum-sources.md` when changing the route or selecting task input. Choose the primary teaching source by its completion-path order, while using current official documentation to arbitrate technical facts. Do not make a task complete through a stitched or unlabelled Agent-authored course.

The default route is task-first, breadth-first, and framework-first on the first pass. Build broad working surfaces across the interview stack before deep local detail, while preserving only prerequisites that cause real blockers. The user may choose aggressive progress, skip, parallelization, or early entry at any time. `direct-tech-learning` must show dependencies and effects, then follow the user's explicit final choice. An incomplete day, week, stage, review, or mastery assessment cannot veto the change.

Planning, teaching, minimum useful artifacts, logs, and ended sessions do not prove capability or task completion. Missing independent application is an optional assessment target unless it is a concrete prerequisite blocker for the selected task.

## Job requirement analysis

Path: `20-学习主线/岗位分析/`.

`analyze-job-requirements` is read-only by default. When the user explicitly asks to retain supplied HR/JD material, it may write one source note from `90-模板/岗位需求分析模板.md` after the required preview and confirmation. Every saved note keeps source text, structured requirements, mainline mapping, uncertainty, recommendation, and route-write state separate.

One job source describes that job only. Repeated demand requires distinct sources. Job text never proves learning, capability, market prevalence, or achieved KPI. The analyzer prepares route-change handoffs; `direct-tech-learning` remains the sole writer of the mainline, stage terminology, homepage route mirrors, and current task state.

## Weekly factual ledger

Path: `30-学习日志/每周/YYYY-Www.md`.

Required properties:

```yaml
---
type: weekly-learning-review
week: YYYY-Www
start: YYYY-MM-DD
end: YYYY-MM-DD
study_days: 0
total_minutes: 0
stage:
stage_directions: []
status: 进行中
---
```

Allowed `status` values are `进行中` and `已结束`. Closing an old week changes only its status; it never rewrites factual sections.

Required headings:

1. `## 任务流转`
2. `## 实际学习记录`
3. `## 已收敛知识`
4. `## 复习证据`
5. `## 能力证据`
6. `## 整理结论`
7. `## 前进方向`

`record-tech-learning` owns the complete weekly ledger. Logs are literal records only: a ledger never binds a plan, quota, schedule, expected output, or completion date, and the system never plans in days or weeks. The only planning unit is the study slice, owned by study, never by a log. `## 任务流转` records only actual dated work against task-package unit IDs, for example:

```markdown
- YYYY-MM-DD｜`<unit-id>`｜<开始/继续/暂停/已形成事实产物>｜<reported artifact or stopping point>
```

Every current task ID must map to a source-backed mainline unit. One task may appear across multiple dates and one date may contain multiple task entries. These relations record facts only and never change route progress. `stage` and `stage_directions` preserve the factual context for that week; they are not mirrors of current route state. `study_days` and `total_minutes` summarize reported activity; unknown duration remains unknown. `## 前进方向` may state only an evidence-bounded stopping point or unknown. Historical files may contain legacy plan fields; treat them as historical facts and neither require nor validate them.

## Study execution

Read `study-session-protocol.md`.

`study-tech-learning` turns an explicit task package or the active `current_unit` into task-first input along that package's primary learning source and recorded section. It shows the broader framework first, explains only task-needed mechanisms from underlying state and causal execution before syntax, uses examples when helpful without requiring an artifact, and ends with a factual handoff. Official documentation verifies technical facts; it does not silently replace the designated teaching source.

Before fetching a source, build JSON `material_context` and apply the snapshot-cache rules below. An eligible target slice is cached material derived from a prior eligible Markdown source packet; it is an input to load's current screen, not itself a source packet. Sufficient cached content must be reused without reacquisition; shallow explanation is repaired under the session content rubric. An inaccessible, missing, or unsuitable exact section after cache resolution is a source-selection failure, not permission for study mode to invent or silently downgrade the course. `study-tech-learning` stops at that boundary and hands the failed locator and next ranked candidate to `direct-tech-learning`; only direction mode may persist the replacement.

Study does not require prediction, fault localization, independent transfer, retention, quiz, exam, or acceptance checks. Review is never a default task step or task-completion gate. A session boundary does not complete a task; one task may span days and one day may cover multiple tasks. Study does not read or activate the review queue. When an exact source workspace or Notebook is identified, it may update one persistent learning artifact while preserving layout. Without an explicit source, it stays in conversation apart from its cumulative material snapshot and `25-资源区/学习快照/.study-state` runtime checkpoint.

## FCC operation and learning snapshots

Vault authorities:

- `99-附件/FCC学习操作范式.md` owns the operational method whenever the resolved primary source code starts with `FCC-`.
- `25-资源区/学习快照/学习快照使用说明.md` owns snapshot purpose, naming, routing, and completeness.
- `90-模板/学习快照模板.md` owns snapshot structure.

For an `FCC-*` task, `direct-tech-learning`, `load-tech-learning-source`, `study-tech-learning`, and task-scoped `answer-tech-learning` read the FCC manual before acting. The loader follows its structure-first GitHub repository resolution, block classification, evidence gate, and exclusions. `study-tech-learning` follows only `study-session-protocol.md` for teaching and continuity. It maintains one material snapshot per unit and a separate lightweight runtime teaching checkpoint.

A snapshot stores source location, covered slices and honest online-interaction status, complete structured mechanisms with runnable examples and boundaries, interview mapping, stopping and next locators, and unresolved issues. It is generated study output, not a learner attempt, course completion, route position, review result, capability claim, weekly/daily fact, or replacement for the learner's Notebook. Snapshot creation never triggers `record-tech-learning`, changes the mainline, or activates review. `review-tech-learning` and `answer-tech-learning` may read it; `record-tech-learning` must not treat it as evidence.

Snapshot assets and learner activity advance on separate tracks. For a new or expanded live-source slice, `study-tech-learning` first requires a Markdown source packet with `status: verified` whose coverage supports the complete target slice, screens its required fields, causal chain, examples, expected results, and boundaries for coherence and obvious technical conflicts, then writes or updates the cumulative snapshot and runs `validate-snapshot.ps1`. Only after that materialization gate passes may the same request continue into teaching. A snapshot-preparation request may stop after the validated asset handoff without claiming that the user studied it. An eligible cached slice needs no rewrite unless the source-backed content is corrected or extended.

### Verified snapshot cache

A snapshot is an eligible reusable source cache for one target slice only when all of these conditions hold:

1. `scripts/validate-snapshot.ps1` returns `valid: true`;
2. its `unit` and `primary_source` match the current resolver result;
3. `source_packet_status` is `verified`; source identity is separate in `source_role`, including `agent-fallback` for `AGENT-FALLBACK`;
4. the target slice exists in both `已覆盖切片` and `结构化知识点` with the complete source-neutral fields;
5. no unresolved issue declares that target slice's source invalid;
6. the request does not require verbatim source wording, a current-version recheck, or resolution of a source conflict.

Before reuse, run one lightweight Agent screen over only the target row, matching structured slice, and directly relevant source/blocker fields from `material_context`. Record the result in the subsequently emitted Markdown source packet as `agent_cache_check: passed`, `uncertain`, or `failed`: completeness asks whether the required fields and causal chain are present and coherent; correctness asks whether there is an obvious contradiction, impossible expected result, or known language/API conflict. Do not load a second source merely to perform this screen. `passed` permits a current `status: verified` source packet backed by snapshot cache; `uncertain` or `failed` requires acquisition of only the disputed or missing minimum source fragment. A short `agent_cache_notes` may identify that fragment.

This Agent screen is a token-saving runtime filter, not persisted snapshot evidence and not proof of correctness, current-source freshness, learning, or ability. Do not add its result to the snapshot, route, logs, review state, or validator schema.

An eligible slice whose Agent screen passes is reused with `retrieval_mode: snapshot-cache`, its original locator, `source_verified_at`, and `agent_cache_check: passed`. It preserves prior verification rather than proving current freshness. `[主源原文]` means source-faithful cached content and does not by itself claim a verbatim full-text copy. Pending source interaction does not invalidate the cache and never becomes learner evidence.

Call `load-tech-learning-source` for live acquisition only when the target slice is absent, structurally invalid, `partial` or `blocked`, mismatched with the registered task/source, invalidated by an unresolved issue, subject to a material version conflict, or explicitly requested as verbatim/current verification. Acquire only the smallest missing or invalidated source body.

The snapshot directory remains attachment-style and is intentionally outside the current validator index. Use the relative Markdown-link rules declared by the snapshot guide. Do not broaden the validator or rewrite existing links merely to integrate this runtime behavior.

Snapshot format is machine-checked by `scripts/validate-snapshot.ps1` (an independent script for the snapshot guide/template, not a semantic reviewer). `study-tech-learning` runs it after writing or updating a snapshot and reports the snapshot step as done only when it passes.

## Review and assessment execution

Read `review-session-protocol.md` and `review-policy.md`.

`review-tech-learning` runs only after an explicit practice, review, or assessment request. It preserves learner-owned prediction, implementation/correction, and changed-context transfer, and uses executable or observable acceptance conditions.

Review does not expand into a new curriculum block, write evidence, update the queue, establish task completion, or change the route. Hand actual results to `record-tech-learning`.

## Review queue

Path: `70-复习队列.md`. Read `review-policy.md`.

Required headings:

1. `## 使用规则`
2. `## 活跃队列`
3. `## 待激活题库`
4. `## 已退出活跃队列`
5. `## 最近更新依据`

The queue is derived operational state, not evidence. Actual attempts remain under review-bank `## 复习记录`, daily reviews, and weekly factual sections. `record-tech-learning` updates the queue only after recording actual explicit review or assessment results. Ordinary study never creates, activates, schedules, or advances queue items.

The available verification progression is causal prediction -> fault localization -> context transfer -> retention check. It is used only inside user-selected review mode and is never a task-progress or task-completion gate. Generated questions, suggested dates, and queue entries never prove learning. Do not write mastery labels.

## Daily learning review

Path: `30-学习日志/学习回顾/YYYY-MM-DD 学习回顾.md`.

Use exactly one review per date and append later activity in actual order. Required headings:

1. `## 今日学习过程`
2. `## 今日形成的理解`
3. `## 今日知识沉淀`
4. `## 今日遇到的问题`

Record what the learner did, predicted, implemented, ran, observed, corrected, explained, or failed to complete, naming relevant task-package unit IDs when known. One task may continue across daily records and one daily record may contain multiple tasks. Exclude ingestion narration, stale output, generated contexts/source packets, schedules, and environment residue. Daily records never move task progress.

## Atomic knowledge

Path: `40-原子知识/<技术>/<规范核心对象或代码写法> - <知识主题或操作>.md`.

Every atomic note must declare a unique `atomic_id` and exactly one `term_id`. `term_id` must resolve to a registered terminology row. A note covers one retrievable topic with concrete objects, their relationships, and any observable result; examples, principles, and boundaries appear where they support understanding, not as fixed headings.

The body uses a natural layout: headings are chosen for the content, and a conceptual note may exist without a runnable example. Use structural checks only for mechanical defects: a non-empty body, non-empty written code blocks, and resolvable identity metadata. Do not make a semantic claim that an explanation is correct merely because its structure validates. Do not add mastery state.

Split a note when it serves two separately retrievable topics or needs two independently valid examples.

## Review banks

Path: `60-复习/<规范核心对象或代码写法> - <测试目标>复习.md`.

- `atomic-mirror` banks are optional. When a note's review material or results are organized as a mirror bank, exactly one bank with `review_kind: atomic-mirror` and `primary_atomic: <atomic_id>` claims it; it uses `related_atomics: []` and tests the same atomic question. Never create a bank only to hold one result.
- An explicit review without a bank records its facts in the daily learning review and the weekly section, naming the tested `atomic_id` or task unit; the queue may cite that factual record instead of a bank.
- Additional review banks may use `boundary-comparison`, `error-diagnosis`, `integration-transfer`, `task-performance`, or `retention`, and must declare at least one `related_atomics` or `task_units` value. Extra banks never require a mirror for their references.
- An atomic mirror may declare only one `primary_atomic`; one atomic ID cannot be claimed by two mirrors. Every declared atomic reference must resolve to an existing atomic note.
- Prefer three verification surfaces: causal prediction, fault localization, and changed-context transfer.
- Put only actual attempts and outcomes under `## 复习记录`.
- Do not prescribe dates inside review banks; dates live only in the derived queue.
- Update an existing bank when new material tests the same target. Generated prompts, expected answers, and empty banks are design material only: they are not learner answers, evidence, or queue activation.

## Vault-wide terminology

Path: `10-术语规范.md`.

- Use canonical names in natural language and registered code forms in code/API contexts.
- Each terminology row has two independent classification axes: `结构角色` is one of `领域`, `阶段`, `任务包`, `主题`, `知识术语`, `标签`, `历史项`; `知识类别` is blank for non-knowledge rows or one of `概念`, `机制`, `语法角色`, `API`, `实践模式` for a `知识术语` row. Do not mix the axes into one `类型` value.
- Do not invent joined parent-child names.
- `direct-tech-learning` owns stage and mainline-node rows.
- `record-tech-learning` owns topic, concept, mechanism, API, syntax, and tag rows.
- Renaming, merging, or deprecating requires a previewed global migration and confirmation.

## Source and environment boundary

For an explicitly selected source, inspect only relevant files, changed Notebook cells, interpreter hints, kernel metadata, manifests, and reproducible output. Do not install packages, change interpreters, or modify environments. Run the smallest reproduction only when needed and the selected interpreter is known.

Use `scripts/detect-delta.ps1` for incremental ingestion. Store state under `%USERPROFILE%\.agents\tech-learning-flow\state`, keyed by the resolved source-workspace path. Commit the baseline only after Vault validation succeeds.

## Lightweight core and freeform areas

The Vault is intentionally lightweight and extensible. Only the routing core is constrained: the homepage, the mainline, and `current_unit`. Everything else is optional or freeform.

- Enforced by default (core check): every prescribed path exists (`00-首页.md`, `10-术语规范.md`, `15-自由笔记/`, `20-学习主线/`, `25-资源区/`, `30-学习日志/每周/`, `30-学习日志/学习回顾/`, `40-原子知识/`, `50-主题地图/`, `60-复习/`, `70-复习队列.md`, `90-模板/`, `97-临时/`, `99-附件/`); the homepage has `type/current_stage/current_unit/current_position`; the mainline overview has `type/current_unit`; `current_unit` is declared in the mainline. A schema that lacks its required path list fails the core check explicitly. Core only proves the Vault is complete and routable/writable — it never judges freeform content.
- Root numeric prefix uniqueness is enforced only with `-Strict`; a `.tech-vault.json` schema_version mismatch is reported as a warning, never as a core failure.
- Enforced only with `-Strict`: terminology, weekly/daily logs, atomic notes, topic maps, review banks and queue, snapshots, templates, and source-declaration formatting.
- Never validated: `15-自由笔记/` (notes, search results, reflections, ideas) and `25-资源区/外部/` (other people's projects and external sources with their reading notes). Both are freeform; the user or a skill may add any Markdown or supporting files there. `25-资源区/学习快照/` holds per-unit snapshots; `97-临时/` holds scratch draft/review files. All are provenance and personal material, never learner evidence, route state, or capability proof.

## Canonical paths

| Path | Purpose |
|---|---|
| `00-首页.md` | Navigation and current position |
| `10-术语规范.md` | Canonical terminology |
| `15-自由笔记/` | Freeform notes, search results, reflections, ideas; never validated |
| `20-学习主线/` | Source-backed curriculum and position: `00-总览.md`, `10-阶段/`, `20-任务包注册表.md`, `资料来源注册表.md`, `岗位分析/` |
| `25-资源区/` | Resource area: `学习快照/` stores per-unit snapshots (study writes), `外部/` holds other people's projects and external sources (never validated) |
| `30-学习日志/每周/` | Weekly factual ledgers |
| `30-学习日志/学习回顾/` | Cumulative daily facts |
| `40-原子知识/` | Independently retrievable knowledge |
| `50-主题地图/` | Link maps |
| `60-复习/` | Long-lived review banks |
| `70-复习队列.md` | Derived review execution queue |
| `90-模板/` | Human-visible templates |
| `97-临时/` | Scratch draft/review files; never validated |
| `99-附件/` | Supporting files |

Root numeric prefixes must remain unique. Allowed note types include `home`, `terminology-standard`, `learning-mainline`, `weekly-learning-review`, `学习回顾`, `原子知识点`, `复习题`, `topic-map`, `review-queue`, `learning-snapshot-guide`, `learning-snapshot`, `attachment-index`, `job-requirement-analysis`, and `template`.

## Linking and validation

- Use Wiki links inside the validator-indexed Vault. Learning snapshots follow the relative Markdown-link exception in `25-资源区/学习快照/学习快照使用说明.md`.
- Read every target before writing and preserve other Skills' fields.
- Use `apply_patch` for Markdown edits.
- Validate required paths and headings, unit IDs and sources, queue structure, daily uniqueness, atomic-note structure, duplicate basenames, Wiki links, terminology integrity, naming surfaces, and deprecated aliases.
- Writers validate their own artifacts with the matching action script: `validate-route.ps1` and `validate-terminology.ps1` (direct), `validate-daily.ps1` / `validate-weekly.ps1` / `validate-atomic.ps1` / `validate-reviewbank.ps1` / `validate-queue.ps1` (record), `validate-jobnote.ps1` (analyze), `validate-snapshot.ps1` (study snapshots), `check-draft.py` (study drafts). `shared/assets/validation-registry.json` is the authority for each action's targets, kinds, write surface, and runtime dependencies; standalone validators are registered there separately. A change must declare its operation: an update or creation target must exist, a delete must be absent, a rename needs its old path, and an atomic delete needs its old identity; a missing path is never guessed as a delete. Every declared target must be covered by a selected kind, and an explicit action path must stay inside that action's write surface. A multi-artifact write batch runs `validate-change.ps1` once with the affected kinds and paths, `-Action`, or a mixed `-ChangeSet`. If its scope cannot be computed, it fails explicitly rather than silently running a full audit. `validate-vault.ps1 -Strict` remains the separate full composed audit and is available only from `direct-tech-learning`.
- Compare final hashes and confirm unrelated notes did not change.

## Study runtime state

`study-session-protocol.md` owns the lightweight teaching checkpoint in `25-资源区/学习快照/.study-state/<unit>.json`. Study may write this runtime sidecar without recording learner activity or changing route mirrors. User-selected positions require no completion evidence. Material stop/next locators never choose a teaching position. Source and explanation quality checks remain Agent duties; FCC completion, executed code, and closed-loop artifacts are not study gates.
