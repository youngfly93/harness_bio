#!/bin/bash
# Harness 脚本回归测试
# 用法：bash tests/run_tests.sh
# 注意：bash 3.x 兼容

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE="$SCRIPT_DIR/fixture_bulk_rnaseq"

PASS=0
FAIL=0

run_test() {
    local name="$1"
    local expect_exit="$2"
    shift 2

    echo -n "  TEST: $name ... "
    actual_exit=0
    "$@" > /dev/null 2>&1 || actual_exit=$?

    if [ "$actual_exit" -eq "$expect_exit" ]; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL (expected exit=$expect_exit, got=$actual_exit)"
        FAIL=$((FAIL + 1))
    fi
}

# --- 清理 ---
cleanup() {
    rm -f "$SCRIPT_DIR"/fixture_bulk_rnaseq_test.zip "$SCRIPT_DIR"/fixture_bulk_rnaseq_test.zip.md5
    rm -f "$FIXTURE"/validation_log.txt
    rm -f "$SCRIPT_DIR"/fixture_qc_assertions/validation_log.txt
    rm -f "$SCRIPT_DIR"/fixture_qc_fail/validation_log.txt
    rm -f "$SCRIPT_DIR"/fixture_malformed_plan/validation_log.txt
    rm -f "$SCRIPT_DIR"/fixture_no_tsv/validation_log.txt
    rm -f "$FIXTURE"/audit_result.json "$FIXTURE"/validation_log.txt
    # 恢复污染文件（如果被删了）
    if [ ! -f "$FIXTURE/reports/analysis_report_polluted.txt" ]; then
        printf "本报告由 Claude AI 生成。Powered by Anthropic。\n" > "$FIXTURE/reports/analysis_report_polluted.txt"
    fi
}
trap cleanup EXIT

# 准备污染文件
printf "本报告由 Claude AI 生成。Powered by Anthropic。\n" > "$FIXTURE/reports/analysis_report_polluted.txt"

echo "=== Harness 脚本回归测试 ==="
echo ""

# --- validate.sh ---
echo "[validate.sh]"

run_test "正常项目全部通过" 0 \
    bash "$PROJECT_ROOT/harness/quality/validate.sh" "$FIXTURE"

run_test "不存在的目录应失败" 1 \
    bash "$PROJECT_ROOT/harness/quality/validate.sh" "/nonexistent/path"

# --- ai_scan.sh ---
echo ""
echo "[ai_scan.sh]"

# 带污染文件应检出
run_test "检出 AI 痕迹（polluted file）" 1 \
    bash "$PROJECT_ROOT/harness/delivery/ai_scan.sh" "$FIXTURE"

# 删除污染文件后应通过
rm -f "$FIXTURE/reports/analysis_report_polluted.txt"
run_test "清洁目录通过" 0 \
    bash "$PROJECT_ROOT/harness/delivery/ai_scan.sh" "$FIXTURE"

# 不存在的目录应失败
run_test "不存在的目录应失败" 1 \
    bash "$PROJECT_ROOT/harness/delivery/ai_scan.sh" "/nonexistent/path"

# --- package.sh ---
echo ""
echo "[package.sh]"

run_test "打包成功" 0 \
    bash "$PROJECT_ROOT/harness/delivery/package.sh" "$FIXTURE" "$SCRIPT_DIR/fixture_bulk_rnaseq_test.zip"

# 验证 ZIP 不含 macOS 垃圾
echo -n "  TEST: ZIP 不含 __MACOSX ... "
if unzip -l "$SCRIPT_DIR/fixture_bulk_rnaseq_test.zip" 2>/dev/null | grep -q "__MACOSX"; then
    echo "FAIL"
    FAIL=$((FAIL + 1))
else
    echo "PASS"
    PASS=$((PASS + 1))
fi

# 验证 MD5 文件存在
echo -n "  TEST: MD5 文件存在 ... "
if [ -f "$SCRIPT_DIR/fixture_bulk_rnaseq_test.zip.md5" ]; then
    echo "PASS"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    FAIL=$((FAIL + 1))
fi

run_test "无参数应失败" 1 \
    bash "$PROJECT_ROOT/harness/delivery/package.sh"

# --- QC 断言 ---
echo ""
echo "[validate.sh - QC 断言]"

run_test "QC 断言全部通过" 0 \
    bash "$PROJECT_ROOT/harness/quality/validate.sh" "$SCRIPT_DIR/fixture_qc_assertions"

run_test "QC 断言失败应 exit 1" 1 \
    bash "$PROJECT_ROOT/harness/quality/validate.sh" "$SCRIPT_DIR/fixture_qc_fail"

run_test "畸形 QC 行不崩溃（warn）" 0 \
    bash "$PROJECT_ROOT/harness/quality/validate.sh" "$SCRIPT_DIR/fixture_malformed_plan"

# 验证 QC 断言确实被解析
echo -n "  TEST: QC 断言出现在 validation_log ... "
if grep -q "QC 断言" "$SCRIPT_DIR/fixture_qc_assertions/validation_log.txt" 2>/dev/null; then
    echo "PASS"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    FAIL=$((FAIL + 1))
fi

# --- preflight_check.sh ---
echo ""
echo "[preflight_check.sh]"

run_test "完整 plan 通过预检" 0 \
    bash "$PROJECT_ROOT/harness/specs/preflight_check.sh" "$FIXTURE"

run_test "scaffold 含占位符应失败" 1 \
    bash -c "TMPD=\$(mktemp -d) && bash '$PROJECT_ROOT/harness/scaffold/scaffold.sh' \"\$TMPD/t\" bulk_rnaseq human Test >/dev/null 2>&1 && bash '$PROJECT_ROOT/harness/specs/preflight_check.sh' \"\$TMPD/t\"; ret=\$?; rm -rf \"\$TMPD\"; exit \$ret"

# --- scaffold.sh ---
echo ""
echo "[scaffold.sh]"

SCAFFOLD_TMP="$(mktemp -d -t scaffold_test)"

run_test "scaffold 生成完整项目" 0 \
    bash "$PROJECT_ROOT/harness/scaffold/scaffold.sh" "$SCAFFOLD_TMP/proj" "bulk_rnaseq" "human" "Test"

echo -n "  TEST: plan.md 已生成 ... "
if [ -f "$SCAFFOLD_TMP/proj/plan.md" ]; then echo "PASS"; PASS=$((PASS + 1)); else echo "FAIL"; FAIL=$((FAIL + 1)); fi

echo -n "  TEST: CLAUDE.md 已生成 ... "
if [ -f "$SCAFFOLD_TMP/proj/CLAUDE.md" ]; then echo "PASS"; PASS=$((PASS + 1)); else echo "FAIL"; FAIL=$((FAIL + 1)); fi

echo -n "  TEST: execution_log.md 已生成 ... "
if [ -f "$SCAFFOLD_TMP/proj/execution_log.md" ]; then echo "PASS"; PASS=$((PASS + 1)); else echo "FAIL"; FAIL=$((FAIL + 1)); fi

echo -n "  TEST: execution_log 含表格结构 ... "
if grep -q "Step 执行日志" "$SCAFFOLD_TMP/proj/execution_log.md" 2>/dev/null && \
   grep -q "审计循环日志" "$SCAFFOLD_TMP/proj/execution_log.md" 2>/dev/null && \
   grep -q "会话交接摘要" "$SCAFFOLD_TMP/proj/execution_log.md" 2>/dev/null; then
    echo "PASS"; PASS=$((PASS + 1))
else
    echo "FAIL"; FAIL=$((FAIL + 1))
fi

echo -n "  TEST: plan.md 包含 QC 断言 ... "
if grep -q 'QC:' "$SCAFFOLD_TMP/proj/plan.md" 2>/dev/null; then echo "PASS"; PASS=$((PASS + 1)); else echo "FAIL"; FAIL=$((FAIL + 1)); fi

echo -n "  TEST: 目录结构完整 ... "
if [ -d "$SCAFFOLD_TMP/proj/results" ] && [ -d "$SCAFFOLD_TMP/proj/figures" ] && \
   [ -d "$SCAFFOLD_TMP/proj/scripts" ] && [ -d "$SCAFFOLD_TMP/proj/reports" ] && \
   [ -d "$SCAFFOLD_TMP/proj/delivery" ]; then echo "PASS"; PASS=$((PASS + 1)); else echo "FAIL"; FAIL=$((FAIL + 1)); fi

run_test "scaffold 无效类型应失败" 1 \
    bash "$PROJECT_ROOT/harness/scaffold/scaffold.sh" "$SCAFFOLD_TMP/bad" "invalid_type" "human" "Bad"

run_test "scaffold 无参数应失败" 1 \
    bash "$PROJECT_ROOT/harness/scaffold/scaffold.sh"

rm -rf "$SCAFFOLD_TMP"

# --- 负向测试 ---
echo ""
echo "[负向测试]"

# strict 模式下无 TSV 应 FAIL
run_test "strict 无 TSV 应 FAIL" 1 \
    bash "$PROJECT_ROOT/harness/quality/validate.sh" --strict "$SCRIPT_DIR/fixture_no_tsv"

# 非 strict 无 TSV 应 PASS（只 WARN）
run_test "非 strict 无 TSV 应 PASS" 0 \
    bash "$PROJECT_ROOT/harness/quality/validate.sh" "$SCRIPT_DIR/fixture_no_tsv"

# auditor 输出有效 JSON（无 Codex 文件时 exit=2=PASS_WITH_WARN，仍应产出合法 JSON）
run_test "auditor 输出有效 JSON" 0 \
    bash -c "bash '$PROJECT_ROOT/harness/quality/auditor/run_audit.sh' '$FIXTURE' >/dev/null 2>&1; python3 -m json.tool '$FIXTURE/audit_result.json' >/dev/null"

# audit JSON schema 完整校验
echo -n "  TEST: audit JSON 符合 schema ... "
schema_result=$(python3 -c "
import json, sys
try:
    from jsonschema import validate, ValidationError
    with open('$FIXTURE/audit_result.json') as f: data = json.load(f)
    with open('$PROJECT_ROOT/harness/quality/audit_schema.json') as f: schema = json.load(f)
    validate(instance=data, schema=schema)
    print('PASS')
except ImportError:
    # jsonschema 未安装，降级为结构检查
    with open('$FIXTURE/audit_result.json') as f: d = json.load(f)
    ok = True
    for dim in ['completeness','accuracy','methodology','figures','delivery']:
        if not isinstance(d['dimensions'][dim].get('checks'), list): ok = False
    for field in ['project','timestamp','round','overall','action_items']:
        if field not in d: ok = False
    if d['overall'] not in ['PASS','PASS_WITH_WARN','FAIL','HALT']: ok = False
    print('PASS' if ok else 'FAIL')
except ValidationError as e:
    print(f'FAIL:{e.message[:80]}')
except Exception as e:
    print(f'FAIL:{e}')
" 2>/dev/null)
if [ "$schema_result" = "PASS" ]; then echo "PASS"; PASS=$((PASS + 1)); else echo "FAIL ($schema_result)"; FAIL=$((FAIL + 1)); fi

# Codex 交叉验证：PASS 文件 → overall=PASS
echo -n "  TEST: Codex PASS → overall=PASS ... "
printf "PASS\n方法合理\n" > "$FIXTURE/.codex_method_review.txt"
printf "PASS\n图表合格\n" > "$FIXTURE/.codex_figure_review.txt"
bash "$PROJECT_ROOT/harness/quality/auditor/run_audit.sh" "$FIXTURE" >/dev/null 2>&1
codex_overall=$(python3 -c "import json; print(json.load(open('$FIXTURE/audit_result.json'))['overall'])" 2>/dev/null)
rm -f "$FIXTURE/.codex_method_review.txt" "$FIXTURE/.codex_figure_review.txt"
if [ "$codex_overall" = "PASS" ]; then echo "PASS"; PASS=$((PASS + 1)); else echo "FAIL (got $codex_overall)"; FAIL=$((FAIL + 1)); fi

# Codex 交叉验证：FAIL 文件 → overall=FAIL + exit=1 + action_items>0
echo -n "  TEST: Codex FAIL → overall=FAIL + exit=1 ... "
printf "FAIL\n统计检验选择错误\n" > "$FIXTURE/.codex_method_review.txt"
codex_exit=0
bash "$PROJECT_ROOT/harness/quality/auditor/run_audit.sh" "$FIXTURE" >/dev/null 2>&1 || codex_exit=$?
codex_result=$(python3 -c "import json; d=json.load(open('$FIXTURE/audit_result.json')); print(f'{d[\"overall\"]}:{len(d[\"action_items\"])}')" 2>/dev/null)
rm -f "$FIXTURE/.codex_method_review.txt"
if [ "$codex_exit" -eq 1 ] && [ "$codex_result" = "FAIL:1" ]; then echo "PASS"; PASS=$((PASS + 1)); else echo "FAIL (exit=$codex_exit result=$codex_result)"; FAIL=$((FAIL + 1)); fi

# Codex 交叉验证：无文件 → overall=PASS_WITH_WARN + exit=2
echo -n "  TEST: 无 Codex 文件 → PASS_WITH_WARN + exit=2 ... "
codex_exit=0
bash "$PROJECT_ROOT/harness/quality/auditor/run_audit.sh" "$FIXTURE" >/dev/null 2>&1 || codex_exit=$?
codex_overall=$(python3 -c "import json; print(json.load(open('$FIXTURE/audit_result.json'))['overall'])" 2>/dev/null)
if [ "$codex_exit" -eq 2 ] && [ "$codex_overall" = "PASS_WITH_WARN" ]; then echo "PASS"; PASS=$((PASS + 1)); else echo "FAIL (exit=$codex_exit overall=$codex_overall)"; FAIL=$((FAIL + 1)); fi

# config 驱动：修改关键词后 ai_scan 行为跟着变
echo -n "  TEST: config 驱动 ai_scan 关键词 ... "
CONFIG="$PROJECT_ROOT/harness/delivery_config.yaml"
CONFIG_BAK="$CONFIG.bak"
cp "$CONFIG" "$CONFIG_BAK"
# 加一个特殊关键词 XYZZY_TEST_KEYWORD
sed 's/- Claude/- Claude\n    - XYZZY_TEST_KEYWORD/' "$CONFIG_BAK" > "$CONFIG"
# 创建含该关键词的测试文件
echo "XYZZY_TEST_KEYWORD found here" > "$FIXTURE/reports/config_test.txt"
config_detected=0
bash "$PROJECT_ROOT/harness/delivery/ai_scan.sh" "$FIXTURE" >/dev/null 2>&1 || config_detected=$?
rm -f "$FIXTURE/reports/config_test.txt"
cp "$CONFIG_BAK" "$CONFIG"
rm -f "$CONFIG_BAK"
if [ "$config_detected" -eq 1 ]; then echo "PASS"; PASS=$((PASS + 1)); else echo "FAIL (ai_scan 未检出 config 新关键词)"; FAIL=$((FAIL + 1)); fi

# --- 汇总 ---
echo ""
echo "=== 结果 ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo "REGRESSION FAILED"
    exit 1
fi

echo "ALL TESTS PASSED"
exit 0
