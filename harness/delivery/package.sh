#!/bin/bash
# 交付打包脚本
# 用法：bash harness/delivery/package.sh <delivery_dir> [zip_path]
#
# 说明：
# 1. 先运行 AI 痕迹扫描
# 2. 生成 ZIP 包
# 3. 生成 MD5 校验文件

set -e

DELIVERY_DIR="${1:-}"
ZIP_PATH="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$DELIVERY_DIR" ]; then
    echo "用法: bash harness/delivery/package.sh <delivery_dir> [zip_path]"
    exit 1
fi

if [ ! -d "$DELIVERY_DIR" ]; then
    echo "ERROR: 目录不存在: $DELIVERY_DIR"
    exit 1
fi

DELIVERY_DIR="$(cd "$DELIVERY_DIR" && pwd)"

if [ -z "$ZIP_PATH" ]; then
    ZIP_PATH="${DELIVERY_DIR%/}.zip"
else
    # 相对路径转绝对路径
    case "$ZIP_PATH" in
        /*) ;;
        *)  ZIP_PATH="$(pwd)/$ZIP_PATH" ;;
    esac
fi

ZIP_PATH_DIR="$(dirname "$ZIP_PATH")"
ZIP_BASENAME="$(basename "$ZIP_PATH")"
ZIP_STEM="${ZIP_BASENAME%.zip}"
MD5_PATH="${ZIP_PATH}.md5"

mkdir -p "$ZIP_PATH_DIR"

QUALITY_DIR="$(cd "$SCRIPT_DIR/../quality" && pwd)"

echo "=== 交付打包 ==="
echo "交付目录: $DELIVERY_DIR"
echo "ZIP 输出: $ZIP_PATH"
echo ""

echo "[1/5] 数值交叉校验（strict 模式）"
bash "$QUALITY_DIR/validate.sh" --strict "$DELIVERY_DIR"

echo ""
echo "[2/5] AI 痕迹扫描"
bash "$SCRIPT_DIR/ai_scan.sh" "$DELIVERY_DIR"

echo ""
echo "[3/5] 创建 ZIP"
rm -f "$ZIP_PATH" "$MD5_PATH"

parent_dir="$(dirname "$DELIVERY_DIR")"
dir_name="$(basename "$DELIVERY_DIR")"

# 构建排除规则临时文件（避免 eval 引号问题）
EXCLUDE_TMP="$(mktemp -t pkg_exclude)"
if [ -f "$SCRIPT_DIR/read_config.sh" ]; then
    . "$SCRIPT_DIR/read_config.sh"
    config_get_excludes > "$EXCLUDE_TMP"
fi
if [ ! -s "$EXCLUDE_TMP" ]; then
    printf '*/._*\n*/__MACOSX/*\n*/.DS_Store\n' > "$EXCLUDE_TMP"
fi

if command -v zip >/dev/null 2>&1; then
    (
        cd "$parent_dir"
        # 用 -x@ 从文件读取排除规则（每行一个 pattern）
        zip -qr "$ZIP_PATH" "$dir_name" -x@"$EXCLUDE_TMP"
    )
elif command -v ditto >/dev/null 2>&1; then
    # fallback: ditto 不带资源 fork
    ditto -c -k --noextattr --norsrc --keepParent "$DELIVERY_DIR" "$ZIP_PATH"
else
    echo "ERROR: zip 和 ditto 都不可用，无法创建 ZIP"
    exit 1
fi

echo ""
echo "[4/5] 校验 ZIP"
if command -v unzip >/dev/null 2>&1; then
    unzip -tq "$ZIP_PATH" >/dev/null
fi

echo ""
echo "[5/5] 生成 MD5"
if command -v md5 >/dev/null 2>&1; then
    checksum="$(md5 -q "$ZIP_PATH")"
elif command -v md5sum >/dev/null 2>&1; then
    checksum="$(md5sum "$ZIP_PATH" | awk '{print $1}')"
else
    echo "ERROR: md5 / md5sum 不可用"
    exit 1
fi

printf "%s  %s\n" "$checksum" "$(basename "$ZIP_PATH")" > "$MD5_PATH"

rm -f "$EXCLUDE_TMP"

echo ""
echo "完成:"
echo "  ZIP: $ZIP_PATH"
echo "  MD5: $MD5_PATH"
