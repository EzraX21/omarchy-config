#!/usr/bin/env bash
# 04-noctalia/apply.sh — 替换 Noctalia 的 matugen 模板与注册片段
#
# 用法:
#   ./apply.sh              覆盖到 ~/.config/noctalia/（备份已有文件）
#   ./apply.sh --dry-run
#
# 没装 Noctalia（无 ~/.config/noctalia）时跳过；--force 强制创建
#
# 目标:
#   ${XDG_CONFIG_HOME:-~/.config}/noctalia/templates/fastfetch-config.jsonc
#   ${XDG_CONFIG_HOME:-~/.config}/noctalia/user-templates.toml
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET_DIR="$CONFIG_HOME/noctalia"

DRY=0
FORCE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --force)   FORCE=1 ;;
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf '未知参数: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

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


printf '==> 04 noctalia\n'
printf '  目标   : %s\n' "$TARGET_DIR"

if [ ! -d "$TARGET_DIR" ] && [ "$FORCE" -eq 0 ]; then
    printf '  跳过   : 没找到 %s（Noctalia 未安装？加 --force 强制）\n' "$TARGET_DIR"
    exit 0
fi

apply_file() {
    local src="$1" dst="$2"
    [ -f "$src" ] || { printf '  警告   : 缺少 %s\n' "${src#$HERE/}" >&2; return 1; }
    run mkdir -p "$(dirname "$dst")"
    backup_once "$dst" "$src"
    run cp "$src" "$dst"
    printf '  写入   : %s\n' "${dst#$TARGET_DIR/}"
}

apply_file "$HERE/templates/fastfetch-config.jsonc" "$TARGET_DIR/templates/fastfetch-config.jsonc"
apply_file "$HERE/user-templates.toml" "$TARGET_DIR/user-templates.toml"
printf '  完成\n'
