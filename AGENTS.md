# Harness Engineering for Bio Outsourcing

> Agent 产出质量差是 Harness 问题，不是模型问题。
> 给 Agent 地图，不是手册。

---

## Golden Principles（不可违反）

1. **plan.md 是唯一真相源** — 固定参数不可自行修改，模糊处必须停下询问
2. **数值必须程序化提取** — 报告中的每个数字都从源数据文件读取，禁止手动输入或编造
3. **先验证再推进** — 每个 Step 完成后验证产出，全部完成后五维审计，不跳步
4. **交付物零 AI 痕迹** — 打包前强制扫描，blocking check
5. **失败时诊断，不盲试** — 读错误 → 定位根因 → 修复，同一错误最多 3 次尝试
6. **复杂任务先微计划，确认后立即执行** — 高风险任务先给 3-5 点方法概要；常规任务不得只停留在规划阶段

违反以上任意一条 → 产出无效，必须回退。

---

## 导航地图

Agent 根据当前阶段，按需查阅对应文档：

```
你在哪个阶段？
│
├─ 📋 接到新需求 → harness/specs/plan_template.md    （plan.md 模板 + 质量检查清单）
│                    harness/specs/execution_log_template.md （长任务/跨会话日志模板）
│
├─ 🔬 开始分析 → harness/types/{type}.md             （按分析类型选择）
│   ├─ scrnaseq.md    单细胞RNA-seq
│   ├─ bulk_rnaseq.md Bulk RNA-seq / 转录组
│   ├─ multi_omics.md 多组学整合
│   └─ report.md      报告生成
│
├─ ✅ 完成分析 → harness/quality/                     （质量门控）
│   ├─ audit.md        五维审计体系 + 触发规则
│   ├─ validate.sh     数值交叉校验脚本
│   └─ fig_review.md   图表审查协议
│
├─ 📦 准备交付 → harness/delivery/                    （交付标准）
│   ├─ standards.md    交付包结构 + 命名规范
│   ├─ ai_scan.sh      AI 痕迹扫描脚本
│   └─ package.sh      打包 + 传输脚本
│
└─ 🔧 遇到问题 → harness/known_issues.md             （从116次历史session提炼的Top10防护规则）
```

---

## 执行循环（一句话版）

```
Spec检查 → 高风险任务微计划 → 逐步执行+逐步验证
→ 五维审计：脚本(完整性/准确性/交付) + Codex交叉验证(方法/图表)
→ 报告+数值校验 → AI扫描 → 打包(含validate --strict) → 交付
```

详细协议见 `harness/loop.md`。

---

## 环境约束（始终生效）

```yaml
shell: bash 3.x（macOS 默认，禁止 declare -A）
figure: 白底 | 无网格 | 300dpi | PDF+PNG | 舒适配色
report: 中文 | 黑体/宋体 + Times New Roman
delivery: ZIP | Windows兼容 | MD5校验 | Tailscale传输
```

---

## 人工介入触发条件

**必须停下**：生物学争议 · 数据质量危及结论 · 参数与惯例冲突 · 审计5轮未通 · 临床判断
**可以自主**：配色排版 · 代码bug · 文件命名 · 标准QC · 通路过滤
