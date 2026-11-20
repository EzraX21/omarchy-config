#!/usr/bin/env bash
# 03-vscode/apply.sh — 应用 VS Code 字体设置
#
# 用法:
#   ./apply.sh              合并进现有 settings.json（保留主题等其它设置，默认）
#   ./apply.sh --family "X" 复制时替换字体名（默认 Maple Mono NF CN）
#   ./apply.sh --replace    整体替换（只留字体键，覆盖前备份）
#   ./apply.sh --dry-run
#
# 目标: ${XDG_CONFIG_HOME:-~/.config}/Code/User/settings.json
# 没装 VS Code（无 Code 目录）时跳过；--force 强制创建
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET_DIR="$CONFIG_HOME/Code/User"
TARGET="$TARGET_DIR/settings.json"
SRC="$HERE/settings.json"

MODE="merge"
DRY=0
FORCE=0
FAMILY=""
DEFAULT_FAMILY="Maple Mono NF CN"

while [ $# -gt 0 ]; do
    case "$1" in
        --family)  FAMILY="${2:?--family 需要参数}"; shift ;;
        --replace) MODE="replace" ;;
        --merge)   MODE="merge" ;;
        --force)   FORCE=1 ;;
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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


printf '==> 03 vscode\n'
printf '  源     : %s\n' "${SRC#$HERE/}"
printf '  目标   : %s\n' "$TARGET"
printf '  模式   : %s\n' "$MODE"

if [ ! -d "$CONFIG_HOME/Code" ] && [ "$FORCE" -eq 0 ]; then
    printf '  跳过   : 没找到 %s/Code（VS Code 未安装？加 --force 强制）\n' "$CONFIG_HOME"
    exit 0
fi

run mkdir -p "$TARGET_DIR"
backup_once "$TARGET" "$SRC"

if [ "$MODE" = "replace" ] || [ ! -f "$TARGET" ]; then
    if [ -n "$FAMILY" ] && [ "$FAMILY" != "$DEFAULT_FAMILY" ]; then
        if [ "$DRY" -eq 1 ]; then
            printf '  [dry-run] sed s/%s/%s/ %s > %s\n' "$DEFAULT_FAMILY" "$FAMILY" "$SRC" "$TARGET"
        else
            sed "s|$DEFAULT_FAMILY|$FAMILY|g" "$SRC" > "$TARGET"
        fi
    else
        run cp "$SRC" "$TARGET"
    fi
    printf '  完成   : 已替换\n'
    exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    printf '  警告   : 没有 python3，退回整体替换\n' >&2
    run cp "$SRC" "$TARGET"
    exit 0
fi

if [ "$DRY" -eq 1 ]; then
    printf '  [dry-run] python3 深合并 %s → %s\n' "${SRC#$HERE/}" "$TARGET"
    exit 0
fi

python3 - "$TARGET" "$SRC" "$FAMILY" "$DEFAULT_FAMILY" <<'PY'
import json, pathlib, sys

target_path, src_path = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
family, default_family = sys.argv[3], sys.argv[4]
try:
    target = json.loads(target_path.read_text(encoding="utf-8"))
except json.JSONDecodeError:
    print("  警告   : 现有 settings.json 不是纯 JSON，跳过合并（可用 --replace）", file=sys.stderr)
    raise SystemExit(1)
fragment_text = src_path.read_text(encoding="utf-8")
if family and family != default_family:
    fragment_text = fragment_text.replace(default_family, family)
fragment = json.loads(fragment_text)


def deep_merge(dst, src):
    for key, val in src.items():
        if isinstance(val, dict) and isinstance(dst.get(key), dict):
            deep_merge(dst[key], val)
        else:
            dst[key] = val


deep_merge(target, fragment)
target_path.write_text(json.dumps(target, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print("  完成   : 已合并字体键")
PY
