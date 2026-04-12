#!/bin/bash
# bio-result-auditor 运行器
# 用法：bash harness/quality/auditor/run_audit.sh <project_dir> [round]
#
# 说明：
# 1. 先运行 validate.sh 做基础检查
# 2. 输出结构化 JSON 审计结果到 <project_dir>/audit_result.json
# 3. 可选 round 参数标记审计轮次（默认 1）
#
# 注意：这是基础版本（机械化检查），复杂的方法合理性和图表质量
# 仍需 bio-result-auditor sub-agent 做深度审查。

set -e

PROJECT_DIR="${1:-.}"
ROUND="${2:-1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUALITY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT="$PROJECT_DIR/audit_result.json"
TIMESTAMP="$(date '+%Y-%m-%dT%H:%M:%S%z')"

# --- 运行 validate.sh 收集基础结果 ---
validate_exit=0
bash "$QUALITY_DIR/validate.sh" "$PROJECT_DIR" > /dev/null 2>&1 || validate_exit=$?

LOG="$PROJECT_DIR/validation_log.txt"
if [ ! -f "$LOG" ]; then
    echo "ERROR: validate.sh 未产出 validation_log.txt"
    exit 1
fi

# --- 从 validation_log 解析结果 ---
# 计数用 SUMMARY 行（不与逐项 PASS/FAIL 混淆）
pass_count=$(awk '/^SUMMARY_PASS:/ {print $2}' "$LOG")
fail_count=$(awk '/^SUMMARY_FAIL:/ {print $2}' "$LOG")
warn_count=$(awk '/^SUMMARY_WARN:/ {print $2}' "$LOG")
pass_count="${pass_count:-0}"
fail_count="${fail_count:-0}"
warn_count="${warn_count:-0}"

# 分类 FAIL 到维度
completeness_fails=$(grep "^FAIL:" "$LOG" | grep -v "^SUMMARY_" | grep -c -E "缺失|不存在|空文件" 2>/dev/null || true)
accuracy_fails=$(grep "^FAIL:" "$LOG" | grep -v "^SUMMARY_" | grep -c -E "数值|不一致|mismatch|QC 断言" 2>/dev/null || true)
delivery_fails=$(grep "^FAIL:" "$LOG" | grep -v "^SUMMARY_" | grep -c -E "AI|交付模式" 2>/dev/null || true)

# 维度状态
comp_status="PASS"; [ "$completeness_fails" -gt 0 ] && comp_status="FAIL"
acc_status="PASS"; [ "$accuracy_fails" -gt 0 ] && acc_status="FAIL"
deliv_status="PASS"; [ "$delivery_fails" -gt 0 ] && deliv_status="FAIL"
# --- 方法和图表：尝试 Codex 交叉验证 ---
method_status="WARN"
fig_status="WARN"
CODEX_METHOD_FILE="$PROJECT_DIR/.codex_method_review.txt"
CODEX_FIGURE_FILE="$PROJECT_DIR/.codex_figure_review.txt"

# 检查 Codex 审查结果文件是否存在（由外部编排层产出）
# 文件格式：第一行 PASS 或 FAIL，后续行为理由
if [ -f "$CODEX_METHOD_FILE" ]; then
    codex_method_verdict=$(head -1 "$CODEX_METHOD_FILE" | tr -d '[:space:]')
    case "$codex_method_verdict" in
        PASS) method_status="PASS" ;;
        FAIL) method_status="FAIL" ;;
        *)    method_status="WARN" ;;
    esac
fi

if [ -f "$CODEX_FIGURE_FILE" ]; then
    codex_figure_verdict=$(head -1 "$CODEX_FIGURE_FILE" | tr -d '[:space:]')
    case "$codex_figure_verdict" in
        PASS) fig_status="PASS" ;;
        FAIL) fig_status="FAIL" ;;
        *)    fig_status="WARN" ;;
    esac
fi

# 重新计算 fail_count 和 warn_count（加入 Codex 维度）
[ "$method_status" = "FAIL" ] && fail_count=$((fail_count + 1))
[ "$fig_status" = "FAIL" ] && fail_count=$((fail_count + 1))
[ "$method_status" = "WARN" ] && warn_count=$((warn_count + 1))
[ "$fig_status" = "WARN" ] && warn_count=$((warn_count + 1))

# 总体状态：FAIL > PASS_WITH_WARN > PASS
# WARN 维度（如 Codex 不可用）阻止 overall=PASS
overall="PASS"
if [ "$fail_count" -gt 0 ]; then
    overall="FAIL"
elif [ "$method_status" = "WARN" ] || [ "$fig_status" = "WARN" ]; then
    overall="PASS_WITH_WARN"
fi

# JSON string 转义：\ → \\, " → \", 控制字符 → 删除
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr -d '\000-\011\013-\037'
}

# 收集 action items（validate.sh + Codex）
items=""
append_item() {
    local dim="$1" sev="$2" desc="$3" fix="$4"
    desc=$(json_escape "$desc")
    fix=$(json_escape "$fix")
    if [ -n "$items" ]; then items="$items,"; fi
    items="$items{\"dimension\":\"$dim\",\"severity\":\"$sev\",\"description\":\"$desc\",\"fix\":\"$fix\",\"auto_fixable\":false}"
}

# 从 validation_log FAIL 行
while IFS= read -r line; do
    desc=$(echo "$line" | sed 's/^FAIL: //')
    dim="completeness"
    echo "$desc" | grep -qE "数值|不一致|QC" && dim="accuracy"
    echo "$desc" | grep -qE "AI|交付" && dim="delivery"
    sev="P1"
    echo "$desc" | grep -qE "数值|QC" && sev="P0"
    append_item "$dim" "$sev" "$desc" "见 validation_log.txt"
done < <(grep "^FAIL:" "$LOG" | grep -v "^SUMMARY_")

# 从 Codex 审查结果
if [ "$method_status" = "FAIL" ] && [ -f "$CODEX_METHOD_FILE" ]; then
    codex_reason=$(tail -n +2 "$CODEX_METHOD_FILE" | head -3 | tr '\n' '; ')
    append_item "methodology" "P0" "Codex 方法审查未通过" "$codex_reason"
fi
if [ "$fig_status" = "FAIL" ] && [ -f "$CODEX_FIGURE_FILE" ]; then
    codex_reason=$(tail -n +2 "$CODEX_FIGURE_FILE" | head -3 | tr '\n' '; ')
    append_item "figures" "P1" "Codex 图表审查未通过" "$codex_reason"
fi

action_items="[$items]"

# --- 从 validation_log 提取 checks 数组 ---
# 按关键词分类到维度
build_checks() {
    local pattern="$1"
    local first=1
    printf "["
    grep -E "^(PASS|FAIL|WARN):" "$LOG" | grep -v "^SUMMARY_" | grep -E "$pattern" | while IFS= read -r line; do
        status=$(echo "$line" | sed 's/:.*//')
        detail=$(json_escape "$(echo "$line" | sed 's/^[A-Z]*: //')")
        if [ "$first" -eq 1 ]; then first=0; else printf ","; fi
        printf "{\"name\":\"%s\",\"status\":\"%s\",\"detail\":\"%s\"}" "check" "$status" "$detail"
    done
    printf "]"
}

comp_checks=$(build_checks "交付清单|文件非空|空文件|缺失|不存在|stale|图表文件")
acc_checks=$(build_checks "数值|QC 断言|numeric")
deliv_checks=$(build_checks "AI|交付模式|TSV")

# 方法和图表：从 Codex 审查文件构建 checks
build_codex_checks() {
    local file="$1"
    local status="$2"
    if [ ! -f "$file" ]; then
        printf "[]"
        return
    fi
    local detail
    detail=$(json_escape "$(tail -n +2 "$file" | head -5 | tr '\n' '; ')")
    printf "[{\"name\":\"codex_review\",\"status\":\"%s\",\"detail\":\"%s\"}]" "$status" "$detail"
}

method_checks=$(build_codex_checks "$CODEX_METHOD_FILE" "$method_status")
fig_checks=$(build_codex_checks "$CODEX_FIGURE_FILE" "$fig_status")

# --- 输出 JSON ---
cat > "$OUTPUT" << JSON_EOF
{
  "project": "$PROJECT_DIR",
  "timestamp": "$TIMESTAMP",
  "round": $ROUND,
  "dimensions": {
    "completeness": {"status": "$comp_status", "checks": $comp_checks, "summary": "文件完整性检查"},
    "accuracy": {"status": "$acc_status", "checks": $acc_checks, "summary": "数值准确性检查"},
    "methodology": {"status": "$method_status", "checks": $method_checks, "summary": "$([ "$method_status" = "WARN" ] && echo 'Codex 未审查，需人工确认' || echo '方法合理性检查')"},
    "figures": {"status": "$fig_status", "checks": $fig_checks, "summary": "$([ "$fig_status" = "WARN" ] && echo 'Codex 未审查，需人工确认' || echo '图表质量检查')"},
    "delivery": {"status": "$deliv_status", "checks": $deliv_checks, "summary": "交付规范检查"}
  },
  "overall": "$overall",
  "action_items": $action_items,
  "summary": {
    "pass": $pass_count,
    "fail": $fail_count,
    "warn": $warn_count
  }
}
JSON_EOF

echo "审计结果: $OUTPUT (overall=$overall, round=$ROUND)"
echo "  完整性=$comp_status 准确性=$acc_status 方法=$method_status 图表=$fig_status 交付=$deliv_status"

# exit code 反映 overall：FAIL→1, PASS_WITH_WARN→2, PASS→0
case "$overall" in
    FAIL) exit 1 ;;
    PASS_WITH_WARN) exit 2 ;;
    HALT) exit 3 ;;
    *) exit 0 ;;
esac
