#!/usr/bin/env bash
# ==============================================================================
# font-setup.sh — 把 Omarchy 全系统字体换成 Maple Mono NF（终端 + 所有应用）
#
# 用法：scripts/font-setup.sh [--dry-run] [--package PKG] [--no-gtk]
# 说明：字体包系统级安装（/usr/share/fonts，需要 sudo）；其余改动只动当前用户。
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL="$ROOT/config/fontconfig/fonts.conf.tpl"

PKG="${MAPLE_PKG:-maplemono-nf-cn}"
FALLBACK_CJK="${MAPLE_FALLBACK_CJK:-Noto Sans CJK SC}"
DRY_RUN=0
DO_GTK=1

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --package) PKG="${2:?}"; shift ;;
        --no-gtk)  DO_GTK=0 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) printf '未知参数: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m错误: %s\033[0m\n' "$*" >&2; exit 1; }
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
FONTS_CONF="$CONFIG_HOME/fontconfig/fonts.conf"

# ------------------------------------------------------------------------------
# 1. 安装字体包
# ------------------------------------------------------------------------------
say "1/6 检查 Maple 字体"
if fc-list 2>/dev/null | grep -qi 'Maple Mono'; then
    echo "已安装，跳过"
else
    command -v omarchy >/dev/null 2>&1 || die "找不到 omarchy 命令，无法自动装包"
    echo "通过 omarchy 仓库安装 $PKG（会提示输入密码）"
    run omarchy pkg add "$PKG" || die "安装失败。可手动试：yay -S $PKG"
    [ "$DRY_RUN" -eq 1 ] || fc-cache -f >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# 2. 探测真实 family 名（不硬编码）
# ------------------------------------------------------------------------------
say "2/6 探测字体家族名"
if [ -n "${MAPLE_FAMILY:-}" ]; then
    FAMILY="$MAPLE_FAMILY"            # 测试/CI 用：跳过探测
else
    FAMILY=$(fc-list : family 2>/dev/null | tr ',' '\n' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -i '^Maple Mono' | sort -u | head -1 || true)
fi

if [ -z "${FAMILY:-}" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        FAMILY="Maple Mono NF CN"
        printf '  [dry-run] 字体未安装，假定 family 为 %s\n' "$FAMILY"
    else
        die "装了包但 fc-list 找不到 Maple Mono，请检查 $PKG 内容"
    fi
fi
printf '将使用 family: \033[1;33m%s\033[0m\n' "$FAMILY"

# ------------------------------------------------------------------------------
# 3. omarchy 官方设置：终端 + monospace
#    注意：它会覆写 fonts.conf，必须在第 4 步之前跑
# ------------------------------------------------------------------------------
say "3/6 omarchy font set（终端字体）"
if command -v omarchy >/dev/null 2>&1; then
    run omarchy font set "$FAMILY" || echo "  omarchy font set 失败，可稍后手动执行"
else
    echo "  跳过（没有 omarchy 命令）"
fi

# ------------------------------------------------------------------------------
# 4. 泛用族全部指向 Maple —— 这才是"所有应用"生效的关键
# ------------------------------------------------------------------------------
say "4/6 写入 $FONTS_CONF"
run mkdir -p "$(dirname "$FONTS_CONF")"
if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] 用 %s 渲染模板 → %s\n' "$(basename "$TPL")" "$FONTS_CONF"
else
    sed -e "s|@FAMILY@|$FAMILY|g" -e "s|@FALLBACK_CJK@|$FALLBACK_CJK|g" "$TPL" > "$FONTS_CONF"
    fc-cache -f >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# 5. GTK / GNOME 系应用
# ------------------------------------------------------------------------------
if [ "$DO_GTK" -eq 1 ] && command -v gsettings >/dev/null 2>&1; then
    say "5/6 gsettings 字体"
    run gsettings set org.gnome.desktop.interface font-name           "$FAMILY 11"
    run gsettings set org.gnome.desktop.interface document-font-name  "$FAMILY 12"
    run gsettings set org.gnome.desktop.interface monospace-font-name "$FAMILY 11"
else
    say "5/6 跳过 GTK（--no-gtk 或无 gsettings）"
fi

# ------------------------------------------------------------------------------
# 6. VS Code（自己的字体设置，不吃 fontconfig）
# ------------------------------------------------------------------------------
VSCODE_SETTINGS="$CONFIG_HOME/Code/User/settings.json"
if [ -f "$VSCODE_SETTINGS" ] && [ "$DRY_RUN" -eq 0 ]; then
    say "6/6 VS Code 字体"
    python3 - "$VSCODE_SETTINGS" "$FAMILY" <<'PY' || true
import json, sys, pathlib
path, family = pathlib.Path(sys.argv[1]), sys.argv[2]
try:
    data = json.loads(path.read_text(encoding='utf-8'))
except json.JSONDecodeError:
    print("  settings.json 不是纯 JSON（可能带注释），跳过，请手动加：")
    print(f'    "editor.fontFamily": "\'{family}\', monospace"')
    raise SystemExit(0)
stack = f"'{family}', 'Noto Sans Mono CJK SC', monospace"
data.setdefault("editor", {})["fontFamily"] = stack
data.setdefault("editor", {})["fontLigatures"] = True
data.setdefault("terminal", {}).setdefault("integrated", {})["fontFamily"] = stack
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding='utf-8')
print("  已写入 editor.fontFamily / terminal fontFamily")
PY
else
    say "6/6 跳过 VS Code"
fi

# ------------------------------------------------------------------------------
# 验证
# ------------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
    say "验证"
    for generic in sans-serif serif monospace; do
        printf '  %-11s → %s\n' "$generic" "$(fc-match "$generic" 2>/dev/null)"
    done
    if [ -f "$CONFIG_HOME/foot/foot.ini" ]; then
        printf '  foot.ini    → %s\n' "$(grep -m1 '^font=' "$CONFIG_HOME/foot/foot.ini")"
    fi
fi
