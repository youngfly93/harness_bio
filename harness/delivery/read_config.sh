#!/bin/bash
# 从 delivery_config.yaml 读取配置值的轻量解析器
# 用法（source 后调用函数）：
#   source harness/delivery/read_config.sh
#   config_get_keywords   → 输出 AI 关键词的 grep -E 正则
#   config_get_excludes   → 输出 zip 排除参数列表
#
# 注意：bash 3.x 兼容，仅解析简单列表项（- value）

_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_CONFIG_FILE="$_CONFIG_DIR/delivery_config.yaml"

# 从 yaml 的 list section 提取值
# 用法：_yaml_list_items <file> <section_key>
# 输出每行一个值
_yaml_list_items() {
    local file="$1"
    local section="$2"
    awk -v sec="$section" '
        $0 ~ sec":" { in_section=1; next }
        in_section && /^[[:space:]]*- / {
            val=$0
            sub(/^[[:space:]]*- /, "", val)
            gsub(/^"|"$/, "", val)
            gsub(/^'\''|'\''$/, "", val)
            print val
            next
        }
        in_section && /^[[:space:]]*[a-z]/ && !/^[[:space:]]*-/ { in_section=0 }
        in_section && /^[a-z]/ { in_section=0 }
    ' "$file"
}

# AI 关键词 → grep -E 正则（用 | 连接）
config_get_keywords() {
    if [ ! -f "$_CONFIG_FILE" ]; then
        echo ""
        return
    fi
    _yaml_list_items "$_CONFIG_FILE" "keywords" | paste -sd'|' -
}

# zip 排除规则 → 每行一个 -x "pattern"
config_get_excludes() {
    if [ ! -f "$_CONFIG_FILE" ]; then
        echo ""
        return
    fi
    _yaml_list_items "$_CONFIG_FILE" "exclude_patterns"
}
