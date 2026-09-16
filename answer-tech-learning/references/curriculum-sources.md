# Curriculum source registry

Use this reference whenever a Skill resolves a curriculum unit, selects teaching material, checks technical behavior, or validates source codes.

## Teaching path and technical authority

Keep the teaching path separate from technical-fact authority.

### Teaching completion path

Choose material for completing a task package in this order:

1. Material the user explicitly selects for this task.
2. A public online tutorial with a stable URL and continuous sections, such as freeCodeCamp or 菜鸟教程.
3. Current official documentation used as a teaching guide.
4. A physical book the user explicitly provides or confirms owning, with edition and chapter.
5. An explicitly marked Agent fallback.

The first available higher-ranked source is the task package's primary learning source. Do not replace a coherent public tutorial with an Agent-authored course merely because the Agent can explain the material. A user-selected source may be any type, but record its identity and section honestly.

### Technical-fact authority

Current, version-matched official documentation decides language/library/tool behavior, APIs, version boundaries, and failure semantics. It resolves conflicts with tutorials, books, job material, or Agent explanations. Re-check live official documentation when current-version behavior matters.

User-supplied job-requirement material may decide interview priority and target outputs, but it does not establish technical behavior, market prevalence, or capability. Vault records describe what actually happened; they do not silently shrink the curriculum, prove capability, or activate review.

## Registered sources

Every registered source has exactly one machine-readable registry role. `teaching-open` is a public tutorial candidate, `technical-authority` is an official technical source that may be used as the documented fallback teaching path, `priority-evidence` only selects task priority or output, `physical-book` is a user-confirmed edition and chapter, and `agent-fallback` marks bounded Agent-authored input. A source role does not prove that a particular task section is suitable or that the learner accessed it.

This packaged file is only the format paradigm and fallback. The Vault owns the authoritative registry at `20-学习主线/来源注册表.md`; scripts read that file first and fall back here only when it is absent. Register the sources you actually use in the Vault registry by adding one line per source in exactly this format (the indented examples are illustrative and are not registered):

```markdown
    - `<CODE>` | role: `<teaching-open|technical-authority|priority-evidence|physical-book|agent-fallback>` | <Label> — <https://stable-url>
    - `<CODE>` | role: `physical-book` | <Title> — `<edition + chapter>`
    - `<CODE>` | role: `priority-evidence` | <Label> — `<vault-relative path>`
```

Rules:

- `teaching-open` and `technical-authority` entries must carry a stable `<https://…>` URL.
- `physical-book` entries must carry the confirmed edition and chapter.
- `priority-evidence` entries only select priority or target output; they are never teaching material.
- `agent-fallback` marks bounded Agent-authored input and never proves course coverage.

### Built-in fallback marker

- `AGENT-FALLBACK` | role: `agent-fallback` | Agent-authored bounded explanation — no external locator; use only after the higher-ranked teaching sources are unavailable or unsuitable, and always declare reason, scope, and uncovered boundaries in the task package.

## Curriculum-unit requirements

Every stable unit in `20-学习主线/` must declare a stable unit ID, canonical content, prerequisites, underlying causal model, coverage/output, and one primary learning source. The primary source records its source code or stable URL, source type, and exact course section/chapter or documented starting position. It is the sole default completion path for that task package.

Use these machine-parseable, one-line declarations in the mainline source-declaration section. Keep the field names and pipe order unchanged so every declaration is bound to one stable task-package ID:

```markdown
- unit: `<unit-id>` | primary_source: `<registered-code>` | type: `<user-selected|online-tutorial|official-docs|physical-book|agent-fallback>` | locator: `<course section, book edition + chapter, or documented position>`
- unit: `<unit-id>` | gap_source: `<registered-code>` | type: `<online-tutorial|official-docs|physical-book|agent-fallback>` | locator: `<exact section or chapter>` | gap: `<bounded named gap>`
```

`primary_source` occurs exactly once. Omit `gap_source` when no bounded gap exists; otherwise include it exactly once. For `agent-fallback`, append ` | reason: <why higher-ranked sources are unsuitable> | scope: <taught boundary> | uncovered: <known uncovered boundary>` to the same line. A physical-book locator must include the confirmed edition and chapter.

Allow at most one explicitly labelled `gap source` for a bounded, named coverage gap. A gap source does not become a second course path. If a task needs material from two or more tutorials to be complete, split the task package at the source boundary or select a different primary source; never silently stitch an Agent-designed course from fragments.

Use an Agent fallback only after the higher-ranked choices are unavailable or unsuitable for the bounded task. Record the fallback reason, teaching scope, and known uncovered boundaries. Label it as Agent-authored input; it is not a complete or reproducible course.

The mainline owns order, dependencies, unit boundaries, and source-role references. The Vault registry (`20-学习主线/来源注册表.md`) owns registered source identity and URLs; this packaged file only defines their format and acts as a fallback when the Vault registry is absent.

## Input policy

- Default study follows the task package's primary learning source at its recorded section/position. Task-first routing selects the next task; it does not permit an unrecorded self-constructed curriculum.
- Use the recorded gap source only for its named gap. Use official documentation to check technical facts, not to replace the primary tutorial's sequence unless it is itself the primary source.
- Current freeCodeCamp certifications and 菜鸟教程 may serve as primary public tutorials when their coverage fits. Archived tutorials are usable only with an explicit version/coverage boundary and official verification of technical claims.
- Job requirements select priority and expected work products. They do not replace official technical documentation or prove that the learner can perform the work.
- Do not automatically insert Review, Quiz, Certification Exam, recall checks, transfer exercises, or independent assessment into study.
- Projects may be studied as guided input. Only actual learner work and output can later become factual evidence.
- The user may change the route or choose review at any time.
