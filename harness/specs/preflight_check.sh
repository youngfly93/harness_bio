#!/bin/bash
# plan.md Spec 质量预检脚本
# 用法：bash harness/specs/preflight_check.sh <project_dir>
# 在执行分析前运行，确保 plan.md 可机械执行
#
# 注意：bash 3.x 兼容

set -e

PROJECT_DIR="${1:-.}"
PLAN="$PROJECT_DIR/plan.md"
PASS=0
FAIL=0
WARN=0

log_pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
log_fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
log_warn() { echo "WARN: $1"; WARN=$((WARN + 1)); }

echo "=== plan.md Spec 预检 ==="
echo "项目: $PROJECT_DIR"
echo ""

# --- plan.md 存在 ---
if [ ! -f "$PLAN" ]; then
    echo "FATAL: plan.md 不存在"
    exit 1
fi
log_pass "plan.md 存在"

# --- 未填写的占位符 ---
placeholder_count=$(grep -c '?' "$PLAN" 2>/dev/null || true)
# 排除合法的问号（如中文问号、正则里的）— 只数 ?: 或独立 ? 后跟空格/行尾
raw_placeholders=$(grep -E '(：\s*\?|>\s*\?|<\s*\?|==\s*\?|~\s*\?|\{\{[A-Z_]+\}\})' "$PLAN" 2>/dev/null || true)
if [ -n "$raw_placeholders" ]; then
    count=$(echo "$raw_placeholders" | wc -l | tr -d ' ')
    log_fail "plan.md 含 $count 处未填写的占位符（? 或 {{PLACEHOLDER}}）"
    echo "$raw_placeholders" | head -5 | while IFS= read -r line; do
        echo "  → $line"
    done
else
    log_pass "无未填写占位符"
fi

# --- 固定参数部分存在 ---
if grep -q "## 三、固定参数" "$PLAN" 2>/dev/null; then
    log_pass "固定参数部分存在"
    # 检查 DEG 阈值
    if grep -q "log2FC" "$PLAN" 2>/dev/null; then
        log_pass "DEG 阈值已定义"
    else
        log_warn "未找到 DEG 阈值定义（log2FC）"
    fi
    # 检查比较组
    if grep -q "比较组定义" "$PLAN" 2>/dev/null; then
        log_pass "比较组定义存在"
    else
        log_warn "未找到比较组定义"
    fi
else
    log_fail "缺少固定参数部分（## 三、固定参数）"
fi

# --- 交付清单非空 ---
delivery_files=$(awk '
    /## 五、交付清单/ {in_table=1; next}
    in_table && /^\|/ {
        line=$0
        if (line ~ /文件名/ || line ~ /^\|[-[:space:]]+\|/) next
        n=split(line, a, /\|/)
        if (n >= 4) {
            file=a[3]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", file)
            if (file != "" && file != " ") count++
        }
        next
    }
    in_table && !/^\|/ && $0 !~ /^[[:space:]]*$/ {in_table=0}
    END {print count+0}
' "$PLAN")

if [ "$delivery_files" -gt 0 ]; then
    log_pass "交付清单含 $delivery_files 个文件"
else
    log_fail "交付清单为空或未解析到文件名"
fi

# --- 执行步骤存在 ---
step_count=$(grep -c "^### Step" "$PLAN" 2>/dev/null || true)
if [ "$step_count" -gt 0 ]; then
    log_pass "执行步骤 $step_count 个"
else
    log_fail "未找到执行步骤（### Step N）"
fi

# --- QC 断言存在 ---
qc_count=$(grep -cE '^\s*-\s*QC:\s+' "$PLAN" 2>/dev/null || true)
if [ "$qc_count" -gt 0 ]; then
    log_pass "QC 断言 $qc_count 条"
else
    log_warn "未找到 QC 断言（- QC: key op value）"
fi

# --- 空的输入/输出字段 ---
empty_io=$(grep -cE '^\s*-\s*(输入|输出|操作)：\s*$' "$PLAN" 2>/dev/null || true)
if [ "$empty_io" -gt 0 ]; then
    log_fail "有 $empty_io 个 Step 的 输入/输出/操作 字段为空"
else
    log_pass "所有 Step 的 输入/输出/操作 字段已填写"
fi

# --- 比较组定义非空 ---
group_line=$(grep "比较组定义" "$PLAN" 2>/dev/null || true)
if [ -n "$group_line" ]; then
    # 检查冒号后是否只有空括号或空白
    group_value=$(echo "$group_line" | sed 's/.*比较组定义[：:]\s*//')
    case "$group_value" in
        ""|"（）"|"()"|"（明确列出每个对比的分组）")
            log_fail "比较组定义为空或未填写"
            ;;
        *)
            log_pass "比较组定义已填写"
            ;;
    esac
fi

# --- 模糊词检测（固定参数部分） ---
# 只检查"## 三、固定参数"部分的模糊词，避免在背景描述中误报
params_section=$(awk '/## 三、固定参数/{found=1;next} /^## /{if(found)exit} found{print}' "$PLAN" 2>/dev/null || true)
if [ -n "$params_section" ]; then
    fuzzy_in_params=$(echo "$params_section" | grep -cE '合适的|一般的|常用的|适当的|若干|大约' 2>/dev/null || true)
    if [ "$fuzzy_in_params" -gt 0 ]; then
        log_fail "固定参数部分含 $fuzzy_in_params 处模糊词（合适的/一般的/常用的等），必须替换为具体值"
    else
        log_pass "固定参数部分无模糊词"
    fi
else
    log_pass "未发现模糊词"
fi

# --- 物种/注释库 ---
if grep -q "org\.\(Hs\|Mm\|Rn\|Dm\)" "$PLAN" 2>/dev/null; then
    log_pass "物种注释库已指定"
else
    log_warn "未找到物种注释库（org.Hs.eg.db 等）"
fi

# --- 汇总 ---
echo ""
echo "=== 预检结果 ==="
echo "PASS: $PASS  WARN: $WARN  FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo "PREFLIGHT FAILED: 请修正 $FAIL 项后再开始执行"
    exit 1
fi

echo "PREFLIGHT PASSED: plan.md 可执行"
exit 0
