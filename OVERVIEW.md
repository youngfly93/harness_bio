# 生信外包 Agent Harness — 架构概览

> **一句话定义**：给定一个生信分析需求（plan.md），AI Agent 能保质保量完成分析并直接交付客户的工程治具。
>
> **设计哲学**：渐进式披露（Progressive Disclosure）— 给 Agent 地图而非手册。Agent 任意时刻只需读入口文件 + 当前阶段对应的 1 个深层文档。

---

## 目录树

```
harness_bio/
├── AGENTS.md                          ← 入口（~77行），6 条金色原则 + 阶段导航地图
├── CLAUDE.md                          ← Claude Code 专属行为配置
│
├── harness/
│   ├── specs/                         ← 需求规格层
│   │   ├── plan_template.md           ← plan.md 标准模板 + Spec 质量检查 + QC 断言语法
│   │   ├── execution_log_template.md  ← 长任务/跨会话日志模板
│   │   └── preflight_check.sh         ← plan.md 可执行性预检（占位符/空字段/模糊词/参数）
│   │
│   ├── types/                         ← 分析类型深层指南（按需加载）
│   │   ├── scrnaseq.md                ← 单细胞 RNA-seq（35 session 经验）
│   │   ├── bulk_rnaseq.md             ← Bulk RNA-seq / 转录组
│   │   ├── multi_omics.md             ← 多组学整合
│   │   └── report.md                  ← 报告生成（python-docx / officer）
│   │
│   ├── quality/                       ← 质量门控层
│   │   ├── audit.md                   ← 五维审计体系（完整性/准确性/方法/图表/交付）
│   │   ├── audit_schema.json          ← 审计输出 JSON Schema
│   │   ├── audit_example.json         ← 审计输出示例（含 FAIL 场景）
│   │   ├── fig_review.md              ← 图表审查协议（火山图/热图/UMAP 专项检查）
│   │   ├── validate.sh               ← 数值交叉校验（含 QC 断言解析、--strict 交付模式）
│   │   └── auditor/                   ← bio-result-auditor（repo 内资产）
│   │       ├── PROMPT.md              ← sub-agent 行为规范（五维审计 + JSON 输出要求）
│   │       └── run_audit.sh           ← 审计运行器（validate→分类→结构化 JSON 输出）
│   │
│   ├── delivery/                      ← 交付层
│   │   ├── standards.md               ← 交付包目录结构 + 命名规范
│   │   ├── ai_scan.sh                 ← AI 痕迹扫描（关键词从 config 读取，docx 解压失败=不安全）
│   │   ├── package.sh                 ← 一键打包（validate --strict → AI扫描 → ZIP → MD5）
│   │   └── read_config.sh             ← YAML 轻量解析器（供 ai_scan/package 读取 config）
│   │
│   ├── scaffold/                      ← 项目脚手架生成器
│   │   ├── scaffold.sh                ← 输入 type+species+name → 完整项目目录
│   │   └── defaults/                  ← 4 种分析类型的默认执行步骤（含 QC 断言）
│   │       ├── bulk_rnaseq_steps.md
│   │       ├── scrnaseq_steps.md
│   │       ├── multi_omics_steps.md
│   │       └── custom_steps.md
│   │
│   ├── delivery_config.yaml           ← 交付配置（[运行时] 关键词+排除规则 / [参考] 命名+图表+传输）
│   ├── loop.md                        ← 自主执行循环协议（5 Phase + 人工介入规则）
│   └── known_issues.md                ← 116 session 提炼的 Top10 高频错误防护
│
└── tests/                             ← 回归测试（29 case，全绿）
    ├── run_tests.sh                   ← 一键回归
    ├── fixture_bulk_rnaseq/           ← 完整模拟项目（pass 场景 + QC 断言）
    ├── fixture_qc_assertions/         ← QC 断言通过测试
    ├── fixture_qc_fail/               ← QC 断言失败测试
    ├── fixture_malformed_plan/        ← 畸形输入边界测试
    └── fixture_no_tsv/                ← strict 模式无 TSV 失败测试
```

---

## 核心设计

### 1. 渐进式披露架构

```
Agent 读 AGENTS.md（77行入口）
  │
  ├─ 接到需求 → specs/plan_template.md + preflight_check.sh
  ├─ 开始分析 → types/{scrnaseq,bulk_rnaseq,...}.md
  ├─ 完成分析 → quality/{audit,validate,fig_review,auditor/}
  ├─ 准备交付 → delivery/{standards,ai_scan,package}
  └─ 遇到问题 → known_issues.md
```

Agent 在任意时刻只需读**入口 + 1 个深层文档**，不前期加载全部内容。

### 2. 六条金色原则（不可违反）

1. **plan.md 是唯一真相源** — 固定参数不可自行修改
2. **数值必须程序化提取** — 禁止手动输入
3. **先验证再推进** — 每 Step 验证，全部完成后五维审计
4. **交付物零 AI 痕迹** — 打包前强制扫描
5. **失败时诊断，不盲试** — 同一错误最多 3 次
6. **复杂任务先微计划，确认后立即执行** — 不停在规划阶段

### 3. 执行循环

```
preflight → [高风险微计划] → 逐步执行+逐步验证 → 五维审计(≤5轮)
→ 报告+数值校验 → AI扫描 → ZIP打包(含 validate --strict) → 交付
```

### 4. QC 断言（机器可读验收检查）

在 plan.md 的每个 Step 中写：

```markdown
- QC: sample_total == 12
- QC: deg_total ~ 50-5000
- QC: results/deg.csv exists
```

`validate.sh` 自动从 plan.md 解析这些行，对比 `numeric_reference.tsv` 中的实际值，输出 PASS/FAIL。

支持操作符：`==` `>` `>=` `<` `<=` `~`(范围) `exists`(文件存在)

### 5. 项目脚手架

```bash
bash harness/scaffold/scaffold.sh <project_dir> <type> <species> <project_name>
# type: bulk_rnaseq | scrnaseq | multi_omics | custom
```

一条命令生成：plan.md（含预填 QC 断言）+ CLAUDE.md + execution_log.md + TSV + 标准目录。

### 6. 分层审计（双 Agent 交叉验证）

```
五维审计分工：
  ├─ 脚本（机械化，无需 Agent）：
  │   ├─ 完整性 → validate.sh
  │   ├─ 数据准确性 → validate.sh（QC 断言 + 数值比对）
  │   └─ 交付规范 → ai_scan.sh
  │
  └─ Codex / 第二 Agent（只读交叉验证）：
      ├─ 方法合理性 → /codex:rescue（统计检验、归一化、阈值）
      └─ 图表质量 → /codex:rescue（阈值线、legend、配色）
      ⚠️ Codex 不可用时退化为 WARN，不阻断

为什么：避免"自己批改自己作业"，脚本处理可机械化的维度，
        领域判断交给不同模型（GPT-5.4）消除共享盲区
```

### 7. 交付门控链

```
package.sh 内部执行顺序：
  [1/5] validate.sh --strict  ← TSV 缺失 = FAIL，数值不一致 = FAIL
  [2/5] ai_scan.sh            ← 关键词从 delivery_config.yaml 读取，docx 解压失败 = 不安全
  [3/5] ZIP 创建              ← 排除规则从 delivery_config.yaml 读取
  [4/5] ZIP 完整性校验
  [5/5] MD5 生成
```

任一步 FAIL → 整个打包中止，不产出 ZIP。

---

## 可执行脚本

| 脚本 | 用途 | 关键特性 |
|------|------|---------|
| `validate.sh` | 数值交叉校验 | QC 断言解析、`--strict` 模式（TSV 必须存在）、plan.md 交付清单提取 |
| `ai_scan.sh` | AI 痕迹扫描 | 关键词从 config 读取、docx 解压失败=不安全、28 个关键词 |
| `package.sh` | 一键打包 | 先 validate --strict → AI 扫描 → ZIP（config 排除规则）→ MD5 |
| `scaffold.sh` | 项目脚手架 | 4 种类型模板、自动填充物种注释库、execution_log 模板注入 |
| `preflight_check.sh` | Spec 预检 | 占位符/空字段/模糊词/参数/交付清单/QC 断言检查 |
| `run_audit.sh` | 审计运行器 | validate→维度分类→结构化 JSON（含 checks 数组） |
| `read_config.sh` | Config 解析 | 从 delivery_config.yaml 读关键词+排除规则 |

全部 bash 3.x 兼容（macOS 默认），29/29 回归测试全绿。

---

## 测试覆盖

| 类别 | 测试数 | 覆盖内容 |
|------|-------|---------|
| validate.sh 基础 | 2 | 正常通过 + 不存在目录 |
| ai_scan.sh | 3 | 检出污染 + 清洁通过 + 不存在目录 |
| package.sh | 4 | 打包成功 + ZIP 干净 + MD5 存在 + 无参数 |
| QC 断言 | 4 | 全通过 + 失败 + 畸形不崩 + log 验证 |
| preflight | 2 | 完整 plan 通过 + scaffold 占位符拦截 |
| scaffold | 8 | 文件生成 + 内容断言 + 表格结构 + QC + 目录 + 边界 |
| 负向测试 | 6 | strict 无 TSV + 非 strict + auditor JSON + schema checks + config 驱动 |
| **总计** | **29** | |

---

## 经验数据来源

基于 **116 个 Claude Code session** 的使用分析（insights 报告）：
- 最高频分析：scRNA-seq (35次)、报告交付 (25次)、Bulk RNA-seq (12次)
- 最高频摩擦：buggy code (83次)、wrong approach (49次)、止于规划 (12次)
- `known_issues.md` 中的 Top 10 防护规则直接从这些摩擦中提炼

---

## 设计参考

- [OpenAI: Harness Engineering — leveraging Codex](https://openai.com/index/harness-engineering/) — 渐进式披露、~100行入口、"文档不足时提升为代码"
- [Anthropic: Effective harnesses for long-running agents](https://docs.anthropic.com/) — 初始化、自验证、跨上下文交接产物
- [awesome-harness-engineering](https://github.com/walkinglabs/awesome-harness-engineering) — 精选资源索引
