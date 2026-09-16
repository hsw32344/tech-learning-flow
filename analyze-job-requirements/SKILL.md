---
name: analyze-job-requirements
description: Analyze user-supplied HR messages, job descriptions, interview requirements, and recruiter capability lists for data-analyst roles; separate explicit requirements from inference, map them to the fixed tech_vault task-package interview mainline, identify framework coverage and gaps, and prepare a reviewable route-change handoff. Use for 分析HR要求、分析JD、岗位要求需要学什么、对照主线、把招聘要求纳入主线、根据面试官要求调整路线. Analysis is read-only by default; preserve source text when explicitly asked to save it, and never edit the mainline or task progress directly.
---

# Analyze job requirements

Turn one or more user-supplied job requirements into a traceable, evidence-bounded mainline change proposal.

## Load the contract

Bind the Vault first: resolve it per `references/tech-vault-schema.md`; if it is missing or uninitialized, ask the user to initialize it with `direct-tech-learning` or `study-tech-learning` before reading or writing.

Read `references/tech-vault-schema.md`, `references/curriculum-sources.md`, `references/job-requirement-analysis.md`, `10-术语规范.md`, `20-学习主线/`, the homepage, and existing notes under `20-学习主线/岗位分析/` when comparison or accumulation matters.

## Resolve the source

- Accept pasted HR text, a pasted JD, an explicitly named file, or an exact URL/file whose content is available.
- Preserve the supplied wording and identify company, role, date, channel, and source URL only when reported or visible.
- Mark missing metadata as unknown. Never invent the company, seniority, industry, requirement level, or market frequency.
- Treat one job as evidence about that job. Treat multiple independent jobs as repeated demand only after counting distinct sources.

## Analyze

Follow `references/job-requirement-analysis.md`.

1. Separate hard gates, explicit must-haves, preferred items, responsibilities, expected outputs/KPIs, and contextual signals.
2. Normalize technical capabilities to registered task-package units and terminology without erasing the original wording.
3. Classify each item as covered-current, covered-later, reprioritize, candidate-new, job-specific, non-learning-gate, or uncertain.
4. Explain the evidence, dependency cost, interview output, and confidence for every proposed route effect.
5. Distinguish source facts, derived mapping, recommendations, and unknowns.

Do not turn broad wording such as “精通数据分析” into unreported APIs or algorithms. Do not treat salary, degree, years of experience, or personality wording as curriculum units. Do not treat requested KPIs as achieved business impact.

## Report by default

For an ordinary analysis request, stay read-only and return:

- source boundary and missing metadata;
- structured requirements;
- current-mainline mapping;
- gaps and priority effects;
- concrete interview artifacts that would demonstrate the requested work;
- a route-change proposal, if justified.

Do not save the source, edit the Vault, change the route, select task progress, generate review, or record capability unless the user explicitly requests the corresponding action.

## Save a requirement note

When the user explicitly asks to save or retain the supplied requirement:

1. use `90-模板/岗位需求分析模板.md`;
2. preview the exact filename and retained source text;
3. set `type: job-requirement-analysis` and write one note under `20-学习主线/岗位分析/` only after approval when the request includes multiple Vault files;
4. use `YYYY-MM-DD <公司或未知公司>-<岗位或岗位需求 NN>.md`, avoiding duplicate basenames;
5. keep analysis and source text separate, and mark the route-write state accurately.

The saved requirement note is supporting material, not learning activity, review evidence, capability evidence, or proof of market prevalence.

## Hand route changes to direct

Never edit `20-学习主线/`, `10-术语规范.md`, `00-首页.md`, weekly ledgers, or task progress directly.

When the user asks to incorporate the analysis into the mainline:

1. produce a change handoff listing retained, moved, reprioritized, added, skipped, and job-specific items;
2. name affected task-package unit IDs, terminology, homepage mirrors, framework/breadth effects, source codes, and dependency costs;
3. wait for explicit confirmation of the exact multi-file write;
4. hand the confirmed change set and saved-source link to `direct-tech-learning` for the write and validation.

A single explicit must-have may be prioritized for a named target job after user confirmation. A general mainline addition needs repeated independent demand, a demonstrated missing dependency/output, or the user's explicit route choice. Job text never advances task progress. User authority always wins after the effects are shown.

## Boundaries

Hand task selection and route writes to `direct-tech-learning`, study to `study-tech-learning`, explicit practice or mock interview to `review-tech-learning`, actual facts to `record-tech-learning`, and focused technical questions to `answer-tech-learning`.

After any approved requirement-note write, run `scripts/validate-jobnote.ps1`. Never activate review or move the current position from job-description text.
