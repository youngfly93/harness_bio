#!/bin/bash
# 数值交叉校验脚本
# 用途：验证交付报告中的关键数值与源数据一致
# 用法：bash harness/quality/validate.sh [--strict] <project_dir>
#   --strict  交付模式：TSV 缺失 = FAIL（package.sh 调用时自动启用）
#
# 注意：bash 3.x 兼容（macOS 默认）
# 推荐准备两个 TSV 文件：
#   numeric_reference.tsv  来源数据的标准数值
#   report_claims.tsv      报告/表格中实际写入的数值
# 格式：key<TAB>value

set -e

STRICT_MODE=0
if [ "$1" = "--strict" ]; then
    STRICT_MODE=1
    shift
fi

PROJECT_DIR="${1:-.}"
LOG_FILE="$PROJECT_DIR/validation_log.txt"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

log_pass() {
    echo "PASS: $1" >> "$LOG_FILE"
    PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
    echo "FAIL: $1" >> "$LOG_FILE"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

log_warn() {
    echo "WARN: $1" >> "$LOG_FILE"
    WARN_COUNT=$((WARN_COUNT + 1))
}

check_non_empty_files() {
    target_dir="$1"
    label="$2"
    found_any=0

    if [ ! -d "$target_dir" ]; then
        log_warn "$label 目录不存在: $target_dir"
        return
    fi

    while IFS= read -r f; do
        [ -z "$f" ] && continue
        found_any=1
        size=$(wc -c < "$f" | tr -d ' ')
        if [ "$size" -eq 0 ]; then
            log_fail "空文件: $f"
        else
            log_pass "$label 文件非空: $f (${size} bytes)"
        fi
    done < <(find "$target_dir" -type f ! -name "._*" -print)

    if [ "$found_any" -eq 0 ]; then
        log_warn "$label 目录存在但没有文件: $target_dir"
    fi
}

check_expected_files_from_plan() {
    plan_file="$PROJECT_DIR/plan.md"
    expected_tmp=""

    if [ ! -f "$plan_file" ]; then
        log_fail "plan.md not found"
        return
    fi

    log_pass "plan.md found"
    expected_tmp="$(mktemp -t plan_expected_files)"

    awk '
        /## 五、交付清单/ {in_table=1; next}
        in_table && /^\|/ {
            line=$0
            if (line ~ /文件名/ || line ~ /^\|[-[:space:]]+\|/) next
            n=split(line, a, /\|/)
            if (n >= 4) {
                file=a[3]
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", file)
                if (file != "") print file
            }
            next
        }
        in_table && !/^\|/ && $0 !~ /^[[:space:]]*$/ {in_table=0}
    ' "$plan_file" > "$expected_tmp"

    if [ ! -s "$expected_tmp" ]; then
        log_warn "plan.md 中未解析到交付清单文件名"
        rm -f "$expected_tmp"
        return
    fi

    while IFS= read -r expected; do
        [ -z "$expected" ] && continue
        if find "$PROJECT_DIR" -type f -name "$expected" | grep -q .; then
            log_pass "交付清单文件存在: $expected"
        else
            log_fail "交付清单文件缺失: $expected"
        fi
    done < "$expected_tmp"

    rm -f "$expected_tmp"
}

check_figures() {
    fig_count=0
    while IFS= read -r fig; do
        [ -z "$fig" ] && continue
        fig_count=$((fig_count + 1))
        size=$(wc -c < "$fig" | tr -d ' ')
        if [ "$size" -eq 0 ]; then
            log_fail "图表文件为空: $fig"
        else
            log_pass "图表文件存在且非空: $fig"
        fi
    done < <(find "$PROJECT_DIR" -type f ! -name "._*" \( -name "*.pdf" -o -name "*.png" \) -print)

    if [ "$fig_count" -eq 0 ]; then
        log_warn "未发现 PDF/PNG 图表文件"
    fi
}

check_stale_outputs() {
    stale_found=0

    while IFS= read -r output_file; do
        [ -z "$output_file" ] && continue
        if find "$PROJECT_DIR" -type f ! -name "._*" \( -name "*.R" -o -name "*.py" -o -name "*.sh" \) -newer "$output_file" | grep -q .; then
            log_fail "疑似 stale output: $output_file 早于某个脚本"
            stale_found=1
        fi
    done < <(find "$PROJECT_DIR" -type f ! -name "._*" \( -path "$PROJECT_DIR/results/*" -o -path "$PROJECT_DIR/figures/*" \) -print)

    if [ "$stale_found" -eq 0 ]; then
        log_pass "未发现明显 stale output"
    fi
}

compare_numeric_tables() {
    compare_tmp=""

    if [ -z "$REFERENCE_FILE" ] || [ -z "$CLAIMS_FILE" ]; then
        if [ "$STRICT_MODE" -eq 1 ]; then
            log_fail "交付模式下 numeric_reference.tsv 和 report_claims.tsv 必须存在"
        else
            log_warn "未找到 numeric_reference.tsv / report_claims.tsv，跳过数值逐项比对"
        fi
        return
    fi

    compare_tmp="$(mktemp -t numeric_compare)"
    awk -F '\t' '
        NR == FNR {
            if (NF >= 2 && $1 !~ /^#/) {
                key=$1
                $1=""
                sub(/^\t/, "", $0)
                ref[key]=$0
            }
            next
        }
        NF >= 2 && $1 !~ /^#/ {
            key=$1
            $1=""
            sub(/^\t/, "", $0)
            claim=$0
            seen[key]=1
            if (!(key in ref)) {
                print "MISSING\t" key "\tNA\t" claim
            } else if (ref[key] != claim) {
                print "MISMATCH\t" key "\t" ref[key] "\t" claim
            } else {
                print "MATCH\t" key "\t" ref[key] "\t" claim
            }
        }
        END {
            for (key in ref) {
                if (!(key in seen)) {
                    print "UNUSED\t" key "\t" ref[key] "\tNA"
                }
            }
        }
    ' "$REFERENCE_FILE" "$CLAIMS_FILE" > "$compare_tmp"

    while IFS="$(printf '\t')" read -r status key expected actual; do
        [ -z "$status" ] && continue
        case "$status" in
            MATCH)
                log_pass "数值一致: $key (expected=$expected, actual=$actual)"
                ;;
            MISSING)
                log_fail "报告包含未登记数值: $key (actual=$actual)"
                ;;
            MISMATCH)
                log_fail "数值不一致: $key (expected=$expected, actual=$actual)"
                ;;
            UNUSED)
                log_warn "源数据数值未在报告中使用: $key (expected=$expected)"
                ;;
        esac
    done < "$compare_tmp"

    rm -f "$compare_tmp"
}

# --- 查找 reference 文件（共享变量） ---
REFERENCE_FILE=""
for candidate in \
    "$PROJECT_DIR/numeric_reference.tsv" \
    "$PROJECT_DIR/results/numeric_reference.tsv" \
    "$PROJECT_DIR/reports/numeric_reference.tsv"; do
    if [ -f "$candidate" ]; then
        REFERENCE_FILE="$candidate"
        break
    fi
done

CLAIMS_FILE=""
for candidate in \
    "$PROJECT_DIR/report_claims.tsv" \
    "$PROJECT_DIR/results/report_claims.tsv" \
    "$PROJECT_DIR/reports/report_claims.tsv"; do
    if [ -f "$candidate" ]; then
        CLAIMS_FILE="$candidate"
        break
    fi
done

check_qc_assertions() {
    plan_file="$PROJECT_DIR/plan.md"
    if [ ! -f "$plan_file" ]; then
        return
    fi

    qc_tmp="$(mktemp -t qc_assertions)"
    grep -E '^\s*-\s*QC:\s+' "$plan_file" | \
        sed 's/^[[:space:]]*-[[:space:]]*QC:[[:space:]]*//' > "$qc_tmp"

    if [ ! -s "$qc_tmp" ]; then
        log_warn "plan.md 中未发现 QC 断言（- QC: key op value 格式）"
        rm -f "$qc_tmp"
        return
    fi

    while IFS= read -r assertion; do
        [ -z "$assertion" ] && continue
        key=$(echo "$assertion" | awk '{print $1}')
        op=$(echo "$assertion" | awk '{print $2}')
        expected=$(echo "$assertion" | awk '{$1=""; $2=""; sub(/^[[:space:]]+/, ""); print}')

        # exists 操作符：检查文件存在
        if [ "$op" = "exists" ]; then
            if [ -e "$PROJECT_DIR/$key" ]; then
                log_pass "QC 断言: $key exists"
            else
                log_fail "QC 断言: $key 文件不存在"
            fi
            continue
        fi

        # 其他操作符：从 numeric_reference.tsv 查实际值
        actual=""
        if [ -n "$REFERENCE_FILE" ]; then
            actual=$(awk -F '\t' -v k="$key" '$1 == k && $1 !~ /^#/ {print $2}' "$REFERENCE_FILE" 2>/dev/null)
        fi

        if [ -z "$actual" ]; then
            log_warn "QC 断言: $key 在 numeric_reference.tsv 中未找到，跳过"
            continue
        fi

        case "$op" in
            "==")
                if [ "$actual" = "$expected" ]; then
                    log_pass "QC 断言: $key == $expected (actual=$actual)"
                else
                    log_fail "QC 断言: $key == $expected 失败 (actual=$actual)"
                fi
                ;;
            "!=")
                if [ "$actual" != "$expected" ]; then
                    log_pass "QC 断言: $key != $expected (actual=$actual)"
                else
                    log_fail "QC 断言: $key != $expected 失败 (actual=$actual)"
                fi
                ;;
            ">"|">="|"<"|"<=")
                result=$(awk -v a="$actual" -v b="$expected" -v op="$op" 'BEGIN {
                    if (op == ">")  print (a+0 > b+0)  ? "1" : "0"
                    if (op == ">=") print (a+0 >= b+0) ? "1" : "0"
                    if (op == "<")  print (a+0 < b+0)  ? "1" : "0"
                    if (op == "<=") print (a+0 <= b+0) ? "1" : "0"
                }')
                if [ "$result" = "1" ]; then
                    log_pass "QC 断言: $key $op $expected (actual=$actual)"
                else
                    log_fail "QC 断言: $key $op $expected 失败 (actual=$actual)"
                fi
                ;;
            "~")
                # 范围：expected 是 min-max
                range_min=$(echo "$expected" | cut -d- -f1)
                range_max=$(echo "$expected" | cut -d- -f2)
                result=$(awk -v a="$actual" -v lo="$range_min" -v hi="$range_max" 'BEGIN {
                    print (a+0 >= lo+0 && a+0 <= hi+0) ? "1" : "0"
                }')
                if [ "$result" = "1" ]; then
                    log_pass "QC 断言: $key ~ $expected (actual=$actual)"
                else
                    log_fail "QC 断言: $key ~ $expected 失败 (actual=$actual)"
                fi
                ;;
            *)
                log_warn "QC 断言: 未知操作符 '$op' (断言: $assertion)"
                ;;
        esac
    done < "$qc_tmp"

    rm -f "$qc_tmp"
}

echo "=== 数值交叉校验 ===" > "$LOG_FILE"
echo "时间: $(date)" >> "$LOG_FILE"
echo "项目: $PROJECT_DIR" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

check_expected_files_from_plan
check_qc_assertions
check_non_empty_files "$PROJECT_DIR/results" "结果目录"
check_non_empty_files "$PROJECT_DIR/figures" "图表目录"
check_figures
check_stale_outputs
compare_numeric_tables

echo "" >> "$LOG_FILE"
echo "=== 汇总 ===" >> "$LOG_FILE"
echo "SUMMARY_PASS: $PASS_COUNT" >> "$LOG_FILE"
echo "SUMMARY_WARN: $WARN_COUNT" >> "$LOG_FILE"
echo "SUMMARY_FAIL: $FAIL_COUNT" >> "$LOG_FILE"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "结果: FAILED (有 $FAIL_COUNT 项未通过)" >> "$LOG_FILE"
    echo "VALIDATION FAILED: $FAIL_COUNT items failed. See $LOG_FILE"
    exit 1
fi

echo "结果: ALL PASSED" >> "$LOG_FILE"
echo "VALIDATION PASSED: $PASS_COUNT checks passed, $WARN_COUNT warnings. See $LOG_FILE"
exit 0
