---
name: analyze-job-requirements
description: Analyze user-supplied HR messages, job descriptions, interview requirements, and recruiter capability lists for data-analyst roles; separate explicit requirements from inference, map them to the fixed tech_vault task-package interview mainline, identify framework coverage and gaps, and prepare a reviewable route-change handoff. Use for 分析HR要求、分析JD、岗位要求需要学什么、对照主线、把招聘要求纳入主线、根据面试官要求调整路线. Analysis is read-only by default; preserve source text when explicitly asked to save it, and never edit the mainline or task progress directly.
---

# Analyze job requirements

Turn user-supplied job requirements into a traceable, evidence-bounded mainline change proposal.

## When to use

- `分析HR要求`、`分析JD`、`岗位要求需要学什么`、`对照主线`、`把招聘要求纳入主线`、`根据面试官要求调整路线`.
- Read-only by default; saving a requirement note or changing the mainline requires an explicit user request and confirmation.

## Inputs

- Vault binding: explicit path or the tracked pointer; ask the user to initialize when missing or uninitialized.
- Source: pasted HR text, an explicitly named file, or an available URL/file; preserve supplied wording and record company, role, date, channel, and source URL only when reported or visible; mark missing metadata unknown.
- One job is evidence about that job; repeated demand requires distinct counted sources.

## Minimal reads

- Read `references/job-requirement-analysis.md`, `references/jobnote-storage-contract.md`, `10-术语规范.md`, `20-学习主线/` (unit rows), and the homepage for mapping.
- Read existing notes under `20-学习主线/岗位分析/` only when comparison or accumulation matters.
- Read `references/curriculum-sources.md` only when proposing source changes.
- Read `90-模板/岗位需求分析模板.md` only when saving a note.

## Allowed writes

- Nothing by default. When the user explicitly asks to save: one note under `20-学习主线/岗位分析/` from `90-模板/岗位需求分析模板.md`, `type: job-requirement-analysis`, after previewing the exact filename and retained source text and getting confirmation.
- Never edit `20-学习主线/`, `10-术语规范.md`, `00-首页.md`, weekly ledgers, or task progress directly.

## Handoff

- A confirmed route-change set with affected unit IDs, terminology, homepage mirrors, source codes, and dependency costs -> `direct-tech-learning` for the write and validation.
- Facts -> `record-tech-learning`; study -> `study-tech-learning`; explicit practice/mock interview -> `review-tech-learning`; focused technical questions -> `answer-tech-learning`.

## Done check

- Separate source facts, derived mapping, recommendations, and unknowns; classify each item (covered-current / covered-later / reprioritize / candidate-new / job-specific / non-learning-gate / uncertain) with evidence, dependency cost, and confidence.
- Never invent APIs, algorithms, company details, or market frequency; never treat KPIs, salary, degree, or years of experience as curriculum units or achieved impact.
- After any approved requirement-note write run `scripts/validate-jobnote.ps1`; job text never activates review or advances progress.
- The note validator checks the note and its declared template dependency, not unrelated Vault history.
