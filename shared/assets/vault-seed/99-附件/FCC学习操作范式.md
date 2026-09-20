---
type: attachment-index
updated: 2026-09-01
---

# FCC 学习操作范式（来源适配器）

本页只负责“主源为 freeCodeCamp”时的来源定位、课程结构和源内交互规则。所有来源共用的教学输出顺序、机制解释深度、证据边界和事实收尾，以插件 `references/study-session-protocol.md` 为唯一权威；通用快照结构以 [学习快照使用说明](../25-资源区/学习快照/学习快照使用说明.md) 为准。本页不是新 Skill，不写日志、主线、复习库或用户 Notebook。

## 何时加载

任务包解析出的 `primary_source` 以 `FCC-` 开头时，`load-tech-learning-source`、`study-tech-learning` 及需要解析下一 locator 的环节加载本页。非 FCC 主源不得套用这里的 `superblock`、`block`、`challenge`、`challengeType` 或在线题状态。

## FCC 来源定位

从 freeCodeCamp 开源 GitHub 仓库取得精确正文：

`curriculum/challenges/english/blocks/<block-id>/<challenge-id>.md`

仓库正文是教学输入；在线页面只作为用户交互与进度锚点。产出的来源包至少包含 unit、source、source_role、status、actual_locator、task_slice、retrieved_at、coverage、learning input 和 resume。只有 URL、目录壳或课程卡片时状态只能是 `partial`，必须停止教学，不自行降级或另造课程。

不知道 block 名时按以下顺序定位，不猜名称：

1. 读取 `curriculum/structure/curriculum.json`，确认认证对应的 superblock，例如 `python-v9`。
2. 读取 `curriculum/structure/superblocks/<superblock>.json`，取得真实 module、block 列表和顺序。
3. 通过 GitHub contents API 列出 `curriculum/challenges/english/blocks/<block-id>` 下的 challenge 文件与 raw URL。
4. 读取目标 challenge 正文，以 frontmatter 的 `title`、`challengeType` 和正文核验内容。
5. block 名、challenge 类型和顺序都以结构文件及正文为准；不得由自然语言标题推断。

## FCC 块类型

| 块前缀 | challengeType | 性质 | 默认处置 |
|---|---:|---|---|
| `lecture-*` | 19 | 视频讲座；多个知识点 challenge 和源内核验题 | 作为 study 学习切片，按源顺序讲解 |
| `workshop-*` | 20 | 引导式项目 | 站内自助练习；除非用户明确选择，否则不转入 review |
| `lab-*` | 27 | 自主项目；user stories 与测试 | 站内自助练习；实际作品才可能形成活动证据 |
| `review-*` | 31 | 模块回顾 | 仅在显式 review 或查漏请求中使用 |
| `quiz-*` | 8 | 模块测验 | 站内自检，不自动启动 |
| `exam-*` | 30 且 `isExam: true` | 认证考试 | 可选，不自动启动 |

`challengeType` 必须以 challenge 正文 frontmatter 为准。课程中的 workshop、lab、review、quiz 或 exam 是否跳过、保留或进入其他模式，只记录事实性 locator，不据此声称学习完成。

## FCC 教学输出适配

教学输出、来源标签、内容验收和断点续接统一服从插件 `references/study-session-protocol.md`，本页不重复定义。在线完成与提交产物不是学习推进条件。已核验缓存不必重新加载本页；仅实际获取 FCC 来源或结构不明时读取。

## FCC 快照字段

使用来源中立的快照模板，其中：

- `源内容单元` 写 `<block-id> / <challenge-id>`；
- `源锚点` 写在线课程页或 raw/GitHub 精确锚点；
- `源内交互` 只能根据事实写 `待用户完成`、`用户已完成（有事实依据）`、`无/不适用` 或 `未知/待核验`；
- `源内核验` 写实际核验题锚点与讲解边界；不得由快照或 Agent 输出推断用户已完成在线题；
- 停止位置与下一 locator 精确到 block/challenge；跳过的项目块如实列在遗留项。

快照写后运行 `scripts/validate-snapshot.ps1 -Snapshot <path>`。机器校验只证明结构和禁用结论检查通过；是否忠实覆盖 FCC 正文仍需对照 verified 来源包人工/语义复核。

## 新会话续接

继续生成材料时使用快照资料 locator；继续学习时使用用户明确指定、当前对话断点或独立讲解状态。不得把已生成材料当作已讲解内容，也不要求 FCC 完成佐证。仅缓存缺失或来源冲突时拉取精确 challenge。
