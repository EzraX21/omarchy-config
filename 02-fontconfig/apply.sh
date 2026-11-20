#!/usr/bin/env bash
# 02-fontconfig/apply.sh — 替换 fontconfig 的字体别名
#
# 用法:
#   ./apply.sh                   直接替换（文件中写死 Maple Mono NF CN）
#   ./apply.sh --family "Xxx Mono"  复制时替换字体名
#   ./apply.sh --dry-run
#
# 目标: ${XDG_CONFIG_HOME:-~/.config}/fontconfig/fonts.conf
# 覆盖前会备份成 fonts.conf.bak.<时间戳>
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET_DIR="$CONFIG_HOME/fontconfig"
TARGET="$TARGET_DIR/fonts.conf"
SRC="$HERE/fonts.conf"
DEFAULT_FAMILY="Maple Mono NF CN"

FAMILY=""
DRY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --family) FAMILY="${2:?--family 需要参数}"; shift ;;
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf '未知参数: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

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


printf '==> 02 fontconfig\n'
printf '  源     : %s\n' "${SRC#$HERE/}"
printf '  目标   : %s\n' "$TARGET"
[ -n "$FAMILY" ] && printf '  字体   : %s（替换 %s）\n' "$FAMILY" "$DEFAULT_FAMILY"

run mkdir -p "$TARGET_DIR"
backup_once "$TARGET" "$SRC"

if [ -z "$FAMILY" ] || [ "$FAMILY" = "$DEFAULT_FAMILY" ]; then
    run cp "$SRC" "$TARGET"
else
    if [ "$DRY" -eq 1 ]; then
        printf '  [dry-run] sed s/%s/%s/ %s > %s\n' "$DEFAULT_FAMILY" "$FAMILY" "$SRC" "$TARGET"
    else
        sed "s|$DEFAULT_FAMILY|$FAMILY|g" "$SRC" > "$TARGET"
    fi
fi

run fc-cache -f >/dev/null 2>&1 || true
printf '  完成\n'
