#!/usr/bin/env bash
# 01-fastfetch/apply.sh — 替换 fastfetch 配置
#
# 用法:
#   ./apply.sh                     用 config.jsonc（默认布局）
#   ./apply.sh --profile shorin    换成 profiles/shorin-tree.jsonc
#   ./apply.sh --profile kde       换成 profiles/variants/kde-pink-sixel.jsonc
#   ./apply.sh --dry-run           只打印，不写文件
#
# 目标: ${XDG_CONFIG_HOME:-~/.config}/fastfetch/config.jsonc
# 覆盖前会把原文件备份成 config.jsonc.bak.<时间戳>
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET_DIR="$CONFIG_HOME/fastfetch"
TARGET="$TARGET_DIR/config.jsonc"
MARKER="$TARGET_DIR/.omarchy-config-profile"

PROFILE="omarchy"
DRY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --profile) PROFILE="${2:?--profile 需要参数}"; shift ;;
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf '未知参数: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

profile_path() {
    case "$1" in
        omarchy)    echo "$HERE/config.jsonc" ;;
        shorin)     echo "$HERE/profiles/shorin-tree.jsonc" ;;
        plain)      echo "$HERE/profiles/plain.jsonc" ;;
        gnome)      echo "$HERE/profiles/variants/gnome-kitty.jsonc" ;;
        kde)        echo "$HERE/profiles/variants/kde-pink-sixel.jsonc" ;;
        mint)       echo "$HERE/profiles/variants/minimal-mint-sixel.jsonc" ;;
        mint-labwc) echo "$HERE/profiles/variants/minimal-mint-sixel-labwc.jsonc" ;;
        *) return 1 ;;
    esac
}

SRC="$(profile_path "$PROFILE")" || {
    printf '未知 profile: %s（可选 omarchy shorin plain gnome kde mint mint-labwc）\n' "$PROFILE" >&2
    exit 1
}
[ -f "$SRC" ] || { printf '配置不存在: %s\n' "$SRC" >&2; exit 1; }

run() {
    if [ "$DRY" -eq 1 ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi
}

# 只在「目标不是我们写进去的内容」且「还没有历史备份」时备份一次
backup_once() {
    local target="$1" src="${2:-}"
    [ -f "$target" ] || return 0
    if [ -n "$src" ] && cmp -s "$target" "$src"; then
        return 0
    fi
    if ls "$target".bak.* >/dev/null 2>&1; then
        printf '  备份   : 已有历史备份，跳过（避免备份套备份）\n'
        return 0
    fi
    local bak
    bak="$target.bak.$(date +%Y%m%d%H%M%S)"
    run cp -a "$target" "$bak"
    printf '  备份   : %s\n' "$(basename "$bak")"
}


printf '==> 01 fastfetch\n'
printf '  源     : %s\n' "${SRC#$HERE/}"
printf '  目标   : %s\n' "$TARGET"

run mkdir -p "$TARGET_DIR"
backup_once "$TARGET" "$SRC"
run cp "$SRC" "$TARGET"
if [ "$DRY" -eq 0 ]; then printf '%s\n' "$PROFILE" > "$MARKER"; fi
printf '  完成   : profile=%s\n' "$PROFILE"
