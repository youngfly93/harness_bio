# harness_bio

**给定一个生信分析需求，AI Agent 能保质保量完成分析并直接交付客户的工程治具。**

> *Agent 产出质量差是 Harness 问题，不是模型问题。给 Agent 地图，不是手册。*

基于 [Harness Engineering](https://github.com/walkinglabs/awesome-harness-engineering) 理念，从 **116 个真实生信外包 session** 中提炼而成。Agent 无关 — 适用于 Claude Code、Codex、Cursor 或任何遵循 `AGENTS.md` 规范的 AI Agent。

```
32/32 回归测试全绿 · bash 3.x 兼容 · 双 Agent 交叉验证 · 9.6/10 同行评审
```

---

## 它解决什么问题

生信外包中 AI Agent 常见的失败模式：

| 失败模式 | 发生频率 | harness_bio 的应对 |
|---------|---------|-----------------|
| 报告数值与源数据不一致 | 83/116 session | `validate.sh` 自动交叉校验 + `--strict` 交付门控 |
| Agent 选错分析方法 | 49/116 session | 双 Agent 审计 + `known_issues.md` Top10 防护 |
| 只出计划不执行 | 12/116 session | Golden Principle #6 强制执行 |
| AI 关键词残留在交付物中 | 多次 | `ai_scan.sh` 28 关键词扫描（含 docx 解压） |

---

## 整体架构

```
                        ┌─────────────────┐
                        │   AGENTS.md     │  ← Agent 入口（77行）
                        │  6 Golden Rules │     给地图，不给手册
                        │  + 导航地图      │
                        └────────┬────────┘
                                 │
           ┌─────────────────────┼─────────────────────┐
           │                     │                     │
     ┌─────▼─────┐        ┌─────▼─────┐        ┌─────▼─────┐
     │   Specs    │        │   Types   │        │  Quality  │
     │  需求规格   │        │ 分析类型   │        │  质量门控  │
     ├───────────┤        ├───────────┤        ├───────────┤
     │plan_template│       │scrnaseq   │        │validate.sh│
     │preflight.sh│        │bulk_rnaseq│        │ai_scan.sh │
     │exec_log    │        │multi_omics│        │run_audit  │
     └─────┬─────┘        │report     │        │fig_review │
           │               └─────┬─────┘        └─────┬─────┘
           │                     │                     │
           └─────────────────────┼─────────────────────┘
                                 │
                        ┌────────▼────────┐
                        │    Delivery     │
                        │  交付 + 打包     │
                        ├─────────────────┤
                        │ package.sh      │  validate --strict
                        │  → ai_scan.sh   │  → AI 扫描
                        │  → ZIP + MD5    │  → 打包交付
                        └────────┬────────┘
                                 │
                        ┌────────▼────────┐
                        │   Scaffold      │
                        │  项目脚手架      │
                        ├─────────────────┤
                        │ scaffold.sh     │  一条命令生成
                        │  → plan.md      │  完整项目结构
                        │  → CLAUDE.md    │
                        │  → exec_log     │
                        └─────────────────┘
```

---

## 执行循环

```
┌──────────┐    ┌──────────┐    ┌──────────────────────────────┐
│ Preflight│───▶│  Execute │───▶│         5-Dim Audit          │
│ Spec预检  │    │ 逐步执行  │    │                              │
└──────────┘    │ 逐步验证  │    │  脚本层        交叉验证层      │
                └──────────┘    │  ┌────────┐  ┌────────────┐  │
                                │  │validate │  │  Codex     │  │
                                │  │完整性    │  │  方法合理性  │  │
                                │  │准确性    │  │  图表质量   │  │
                                │  │交付规范  │  │ (只读审查)  │  │
                                │  └────────┘  └────────────┘  │
                                └──────────┬───────────────────┘
                                           │
                          ┌────────────────▼────────────────┐
                          │          Deliver                │
                          │  validate --strict → ai_scan    │
                          │  → ZIP → MD5 → Tailscale 传输   │
                          └─────────────────────────────────┘
```

**门控语义**：`PASS` = 全部通过 · `PASS_WITH_WARN` = 交叉验证未完成 · `FAIL` = 阻断交付

---

## 快速开始

### 1. 生成项目脚手架

```bash
bash harness/scaffold/scaffold.sh ./my_project bulk_rnaseq human "心衰转录组分析"
```

产出：`plan.md`（含 QC 断言）+ `CLAUDE.md` + `execution_log.md` + 标准目录结构

### 2. 填写 plan.md 并预检

```bash
# 编辑 plan.md，替换所有 ? 占位符
vim my_project/plan.md

# 预检：占位符、空字段、模糊词、参数完整性
bash harness/specs/preflight_check.sh ./my_project
```

### 3. 执行分析（Agent 接管）

Agent 读取 `AGENTS.md` → 按 `plan.md` 逐步执行 → 每步验证 → 五维审计

### 4. 打包交付

```bash
# 一键打包：validate --strict → AI扫描 → ZIP → MD5
bash harness/delivery/package.sh ./my_project/delivery ./my_project_delivery.zip
```

---

## 项目结构

```
harness_bio/
│
├── AGENTS.md                     # Agent 入口（77行）：6条金色原则 + 导航地图
├── CLAUDE.md                     # Claude Code 行为配置
│
├── harness/
│   ├── specs/                    # ── 需求规格层 ──
│   │   ├── plan_template.md      #   plan.md 标准模板 + QC 断言语法
│   │   ├── preflight_check.sh    #   Spec 可执行性预检
│   │   └── execution_log_template.md
│   │
│   ├── types/                    # ── 分析类型指南（按需加载）──
│   │   ├── scrnaseq.md           #   单细胞 RNA-seq（35 session 经验）
│   │   ├── bulk_rnaseq.md        #   Bulk RNA-seq / 转录组
│   │   ├── multi_omics.md        #   多组学整合
│   │   └── report.md             #   Word 报告生成
│   │
│   ├── quality/                  # ── 质量门控层 ──
│   │   ├── audit.md              #   五维审计体系
│   │   ├── validate.sh           #   数值校验 + QC 断言解析 + --strict 模式
│   │   ├── fig_review.md         #   图表审查协议
│   │   ├── audit_schema.json     #   审计输出 JSON Schema
│   │   └── auditor/              #   bio-result-auditor
│   │       ├── PROMPT.md         #     sub-agent 行为规范
│   │       └── run_audit.sh      #     审计运行器 → JSON 输出
│   │
│   ├── delivery/                 # ── 交付层 ──
│   │   ├── package.sh            #   一键打包（5步门控链）
│   │   ├── ai_scan.sh            #   AI 痕迹扫描（28关键词 + docx）
│   │   ├── read_config.sh        #   YAML 配置解析器
│   │   └── standards.md          #   交付包结构 + 命名规范
│   │
│   ├── scaffold/                 # ── 项目脚手架 ──
│   │   ├── scaffold.sh           #   一条命令生成完整项目
│   │   └── defaults/             #   4种分析类型默认步骤
│   │
│   ├── delivery_config.yaml      # 交付配置（关键词 + 排除规则）
│   ├── loop.md                   # 自主执行循环协议
│   └── known_issues.md           # 116 session Top10 高频错误防护
│
└── tests/                        # 32/32 回归测试全绿
    ├── run_tests.sh
    └── fixture_*/                # 5 个测试 fixture
```

---

## 核心概念

### 渐进式披露（Progressive Disclosure）

Agent 不需要前期加载全部文档。只读 **AGENTS.md（77行）** 作为入口，按当前阶段导航到对应的 1 个深层文档：

| 阶段 | 读什么 |
|------|--------|
| 接到需求 | `specs/plan_template.md` + `preflight_check.sh` |
| 开始分析 | `types/{scrnaseq,bulk_rnaseq,...}.md` |
| 完成分析 | `quality/{audit,validate,fig_review}` |
| 准备交付 | `delivery/{standards,ai_scan,package}` |
| 遇到问题 | `known_issues.md` |

### 六条金色原则

1. **plan.md 是唯一真相源** — 固定参数不可自行修改
2. **数值必须程序化提取** — 禁止手动输入
3. **先验证再推进** — 每 Step 验证，全部完成后五维审计
4. **交付物零 AI 痕迹** — 打包前强制扫描
5. **失败时诊断，不盲试** — 同一错误最多 3 次
6. **复杂任务先微计划，确认后立即执行** — 不停在规划阶段

### QC 断言

在 `plan.md` 的每个 Step 中写机器可读的验收条件：

```markdown
### Step 1: 数据准备
- 输出：results/normalized_counts.csv
- QC: sample_total == 12
- QC: gene_count > 10000
- QC: results/normalized_counts.csv exists
```

`validate.sh` 自动解析这些行，对比 `numeric_reference.tsv` 中的实际值。

| 操作符 | 含义 | 示例 |
|--------|------|------|
| `==` | 等于 | `sample_total == 12` |
| `>` `>=` `<` `<=` | 比较 | `gene_count > 10000` |
| `~` | 范围 | `deg_total ~ 50-5000` |
| `exists` | 文件存在 | `results/deg.csv exists` |

### 双 Agent 交叉验证

| 维度 | 执行者 | 方式 |
|------|--------|------|
| 完整性 | `validate.sh` | 脚本（机械化） |
| 数据准确性 | `validate.sh` | 脚本（QC 断言 + 数值比对） |
| **方法合理性** | **Codex（GPT-5.4）** | **只读交叉验证** |
| **图表质量** | **Codex（GPT-5.4）** | **只读交叉验证** |
| 交付规范 | `ai_scan.sh` | 脚本（28 关键词） |

避免"自己批改自己作业"。Codex 不可用时退化为 `PASS_WITH_WARN`，不假装通过。

---

## 可执行脚本

| 脚本 | 用途 | 关键特性 |
|------|------|---------|
| [`validate.sh`](harness/quality/validate.sh) | 数值交叉校验 | QC 断言解析、`--strict` 模式、plan.md 交付清单提取 |
| [`ai_scan.sh`](harness/delivery/ai_scan.sh) | AI 痕迹扫描 | 关键词从 config 读取、docx 解压失败=不安全 |
| [`package.sh`](harness/delivery/package.sh) | 一键打包 | validate --strict → AI 扫描 → ZIP → MD5 |
| [`scaffold.sh`](harness/scaffold/scaffold.sh) | 项目脚手架 | 4 种类型模板、物种注释库自动填充 |
| [`preflight_check.sh`](harness/specs/preflight_check.sh) | Spec 预检 | 占位符/空字段/模糊词/参数完整性 |
| [`run_audit.sh`](harness/quality/auditor/run_audit.sh) | 审计运行器 | validate → 维度分类 → 结构化 JSON |

全部 bash 3.x 兼容（macOS 默认 shell）。

---

## 测试

```bash
bash tests/run_tests.sh
```

```
PASS: 32 / FAIL: 0 — ALL TESTS PASSED
```

| 类别 | 数量 | 覆盖 |
|------|------|------|
| validate.sh | 2 | 正常 + 异常路径 |
| ai_scan.sh | 3 | 检出 + 清洁 + 异常 |
| package.sh | 4 | 打包 + ZIP + MD5 + 边界 |
| QC 断言 | 4 | pass / fail / malformed / log |
| preflight | 2 | 完整 plan + 占位符拦截 |
| scaffold | 8 | 文件 + 内容 + 结构 + 边界 |
| 负向 + 交叉验证 | 9 | strict / Codex PASS/FAIL/WARN / schema / config |

---

## 支持的分析类型

| 类型 | 指南 | 典型步骤 | 经验来源 |
|------|------|---------|---------|
| **scRNA-seq** | [`scrnaseq.md`](harness/types/scrnaseq.md) | QC → 聚类 → 注释 → DE → 富集 | 35 session |
| **Bulk RNA-seq** | [`bulk_rnaseq.md`](harness/types/bulk_rnaseq.md) | QC → DESeq2 → 火山图 → GO/KEGG | 12 session |
| **多组学** | [`multi_omics.md`](harness/types/multi_omics.md) | 单组学 → ID匹配 → 整合 → 联合可视化 | 8 session |
| **报告生成** | [`report.md`](harness/types/report.md) | 数值提取 → Word → 图片嵌入 → 校验 | 25 session |
| **自定义** | `scaffold.sh custom` | 最小 3 步骨架 | — |

---

## 经验数据

基于 **116 个 Claude Code session** 的真实生信外包工作分析：

- **最高频摩擦**：buggy code（83次）、wrong approach（49次）、止于规划（12次）
- **Top 10 防护规则**：见 [`known_issues.md`](harness/known_issues.md)，每条都来自真实踩坑
- **审计目标**：从平均 3-4 轮降到 ≤ 2 轮全部 PASS

---

## 设计参考

- [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/) — 渐进式披露、~100 行入口、"文档不足时提升为代码"
- [Anthropic: Effective harnesses for long-running agents](https://docs.anthropic.com/) — 初始化、自验证、跨上下文交接产物
- [awesome-harness-engineering](https://github.com/walkinglabs/awesome-harness-engineering) — 精选资源索引

---

## License

MIT
