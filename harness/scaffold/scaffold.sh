#!/bin/bash
# 项目脚手架生成器
# 用法：bash harness/scaffold/scaffold.sh <project_dir> <type> <species> <project_name>
#   type:    bulk_rnaseq | scrnaseq | multi_omics | custom
#   species: human | mouse | custom
#
# 注意：bash 3.x 兼容

set -e

PROJECT_DIR="${1:-}"
TYPE="${2:-}"
SPECIES="${3:-}"
PROJECT_NAME="${4:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULTS_DIR="$SCRIPT_DIR/defaults"

# --- 参数校验 ---
if [ -z "$PROJECT_DIR" ] || [ -z "$TYPE" ] || [ -z "$SPECIES" ] || [ -z "$PROJECT_NAME" ]; then
    echo "用法: bash harness/scaffold/scaffold.sh <project_dir> <type> <species> <project_name>"
    echo "  type:    bulk_rnaseq | scrnaseq | multi_omics | custom"
    echo "  species: human | mouse | custom"
    exit 1
fi

case "$TYPE" in
    bulk_rnaseq|scrnaseq|multi_omics|custom) ;;
    *)
        echo "ERROR: 无效的分析类型 '$TYPE'"
        echo "支持: bulk_rnaseq, scrnaseq, multi_omics, custom"
        exit 1
        ;;
esac

# --- 物种参数映射 ---
case "$SPECIES" in
    human)
        ORG_DB="org.Hs.eg.db"
        SPECIES_LABEL="人（Homo sapiens）"
        ;;
    mouse)
        ORG_DB="org.Mm.eg.db"
        SPECIES_LABEL="小鼠（Mus musculus）"
        ;;
    *)
        ORG_DB="?"
        SPECIES_LABEL="$SPECIES"
        ;;
esac

# --- 类型标签 ---
case "$TYPE" in
    bulk_rnaseq)  TYPE_LABEL="Bulk RNA-seq / 转录组" ;;
    scrnaseq)     TYPE_LABEL="单细胞 RNA-seq" ;;
    multi_omics)  TYPE_LABEL="多组学整合" ;;
    custom)       TYPE_LABEL="自定义分析" ;;
esac

# --- 创建目录 ---
if [ -d "$PROJECT_DIR" ]; then
    echo "WARN: 目录已存在: $PROJECT_DIR"
fi

mkdir -p "$PROJECT_DIR"/{results,figures,scripts,reports,delivery}

# --- 生成 plan.md ---
STEPS_FILE="$DEFAULTS_DIR/${TYPE}_steps.md"
if [ ! -f "$STEPS_FILE" ]; then
    echo "ERROR: 未找到类型模板: $STEPS_FILE"
    exit 1
fi

cat > "$PROJECT_DIR/plan.md" << PLAN_EOF
# $PROJECT_NAME 分析计划

## 一、项目背景
- 物种/样本：$SPECIES_LABEL
- 实验设计：（分组、重复数、处理条件）
- 数据来源：（GEO编号 / 自测数据 / 公开数据库）
- 关键生物学问题：

## 二、成功标准（必须可衡量）
1. [ ] 产出文件清单（明确列出每个预期输出文件）
2. [ ] 数值一致性（报告中数值 = 源数据文件中数值）
3. [ ] 图表标准（白底、无网格、配色舒适、分辨率≥300dpi）
4. [ ] 方法合理性（统计检验选择正确、阈值设定合理）
5. [ ] 交付完整性（ZIP包、中文命名、无AI痕迹）

## 三、固定参数（防止 Agent 自行决定）
- DEG 阈值：|log2FC| > ?, padj < ?
- 富集分析：ORA/GSEA，数据库版本
- 比较组定义：（明确列出每个对比的分组）
- 物种注释库：$ORG_DB

## 四、执行步骤
PLAN_EOF

cat "$STEPS_FILE" >> "$PROJECT_DIR/plan.md"

cat >> "$PROJECT_DIR/plan.md" << 'PLAN_TAIL'

## 五、交付清单
| 序号 | 文件名 | 格式 | 说明 |
|------|--------|------|------|
| 1    |        |      |      |

## 六、风险与限制
-（已知的数据质量问题、方法局限性、需要人工判断的点）
PLAN_TAIL

# --- 生成 CLAUDE.md ---
cat > "$PROJECT_DIR/CLAUDE.md" << CLAUDE_EOF
# CLAUDE.md

$PROJECT_NAME — $TYPE_LABEL 分析项目。

开始工作前先读 \`$HARNESS_ROOT/AGENTS.md\`。
分析类型指南：\`harness/types/${TYPE}.md\`（相对于 harness_bio 根目录）

## 项目参数
- 物种：$SPECIES_LABEL
- 注释库：$ORG_DB
- 分析类型：$TYPE_LABEL

## 默认行为
- 常规任务以执行为目标，不只写计划
- 高风险任务先给 3-5 条方法概要，确认后立即执行
- 每完成一步运行对应验证，再推进下一步
- 报告生成后做数值交叉校验
- 打包前做 AI 痕迹扫描

## 环境
- macOS bash 3.x，禁止 declare -A
- 图表：白底、无网格、300dpi、舒适配色
CLAUDE_EOF

# --- 生成 execution_log.md ---
TEMPLATE="$HARNESS_ROOT/harness/specs/execution_log_template.md"
if [ -f "$TEMPLATE" ]; then
    sed "s|项目名称：|项目名称：$PROJECT_NAME|;s|plan.md 路径：|plan.md 路径：$PROJECT_DIR/plan.md|;s|当前分析类型：|当前分析类型：$TYPE_LABEL|" "$TEMPLATE" > "$PROJECT_DIR/execution_log.md"
else
    cat > "$PROJECT_DIR/execution_log.md" << LOG_EOF
# execution_log.md

## 项目
- 项目名称：$PROJECT_NAME
- plan.md 路径：$PROJECT_DIR/plan.md
- 当前分析类型：$TYPE_LABEL
LOG_EOF
fi

# --- 生成空的 TSV 文件 ---
printf "# key\tvalue\n# 由 validate.sh 使用，填入源数据的标准数值\n" > "$PROJECT_DIR/numeric_reference.tsv"
printf "# key\tvalue\n# 由 validate.sh 使用，填入报告中实际写入的数值\n" > "$PROJECT_DIR/report_claims.tsv"

# --- 输出结果 ---
echo "=== 项目脚手架已生成 ==="
echo "目录: $PROJECT_DIR"
echo "类型: $TYPE_LABEL"
echo "物种: $SPECIES_LABEL"
echo ""
echo "生成的文件:"
echo "  plan.md              ← 填写 ? 占位符后开始执行"
echo "  CLAUDE.md            ← Agent 行为配置"
echo "  execution_log.md     ← 执行/审计日志"
echo "  numeric_reference.tsv← 填入源数据标准数值"
echo "  report_claims.tsv    ← 填入报告中的数值"
echo "  results/ figures/ scripts/ reports/ delivery/"
