#!/usr/bin/env bash
# ==============================================================================
# font-setup.sh — 装 Maple Mono NF，并把系统字体切到它
#
# 流程：
#   1) 安装字体包（omarchy 仓库的 maplemono-nf-cn，系统级 /usr/share/fonts）
#   2) 探测真实 family 名
#   3) omarchy font set（foot / alacritty / kitty / ghostty 四个终端）
#   4) 调用 02-fontconfig 层：写 ~/.config/fontconfig/fonts.conf
#   5) 调用 03-vscode 层：合并 VS Code 字体键
#   6) gsettings：GTK / GNOME 系应用字体
#
# 用法: scripts/font-setup.sh [--dry-run] [--package PKG] [--no-gtk]
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PKG="${MAPLE_PKG:-maplemono-nf-cn}"
DEFAULT_FAMILY="Maple Mono NF CN"
DRY_RUN=0
DO_GTK=1

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --package) PKG="${2:?}"; shift ;;
        --no-gtk)  DO_GTK=0 ;;
        -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
say "2/6 探测字体家族名"
if [ -n "${MAPLE_FAMILY:-}" ]; then
    FAMILY="$MAPLE_FAMILY"
else
    FAMILY=$(fc-list : family 2>/dev/null | tr ',' '\n' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -i '^Maple Mono' | sort -u | head -1 || true)
fi

if [ -z "${FAMILY:-}" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        FAMILY="$DEFAULT_FAMILY"
        printf '  [dry-run] 字体未安装，假定 family 为 %s\n' "$FAMILY"
    else
        die "装了包但 fc-list 找不到 Maple Mono，请检查 $PKG 内容"
    fi
fi
printf '将使用 family: \033[1;33m%s\033[0m\n' "$FAMILY"

# ------------------------------------------------------------------------------
say "3/6 omarchy font set（终端字体）"
if command -v omarchy >/dev/null 2>&1; then
    run omarchy font set "$FAMILY" || echo "  omarchy font set 失败，可稍后手动执行"
else
    echo "  跳过（没有 omarchy 命令）"
fi

# ------------------------------------------------------------------------------
say "4/6 02-fontconfig 层"
fc_args=()
if [ "$DRY_RUN" -eq 1 ]; then fc_args+=(--dry-run); fi
if [ "$FAMILY" != "$DEFAULT_FAMILY" ]; then fc_args+=(--family "$FAMILY"); fi
bash "$ROOT/02-fontconfig/apply.sh" "${fc_args[@]}"

# ------------------------------------------------------------------------------
say "5/6 03-vscode 层"
vs_args=()
if [ "$DRY_RUN" -eq 1 ]; then vs_args+=(--dry-run); fi
bash "$ROOT/03-vscode/apply.sh" "${vs_args[@]}" || echo "  跳过 VS Code（未安装或设置非纯 JSON）"

# ------------------------------------------------------------------------------
if [ "$DO_GTK" -eq 1 ] && command -v gsettings >/dev/null 2>&1; then
    say "6/6 gsettings 字体"
    run gsettings set org.gnome.desktop.interface font-name           "$FAMILY 11"
    run gsettings set org.gnome.desktop.interface document-font-name  "$FAMILY 12"
    run gsettings set org.gnome.desktop.interface monospace-font-name "$FAMILY 11"
else
    say "6/6 跳过 gsettings（--no-gtk 或无 gsettings）"
fi

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
