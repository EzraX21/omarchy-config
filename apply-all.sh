#!/usr/bin/env bash
# apply-all.sh — 依次替换全部 4 层配置
#
# 用法:
#   ./apply-all.sh                替换 01 fastfetch → 02 fontconfig → 03 vscode → 04 noctalia
#   ./apply-all.sh --dry-run      只打印每一步会做什么
#   ./apply-all.sh --profile shorin   01 层用指定布局，其余层不受影响
#
# 每层覆盖前都会备份成 *.bak.<时间戳>；某一层失败不影响其它层，最后汇总。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYERS=(01-fastfetch 02-fontconfig 03-vscode 04-noctalia)

DRY=0
PROFILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        --profile) PROFILE="${2:?--profile 需要参数}"; shift ;;
        -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf '未知参数: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

failed=()

for layer in "${LAYERS[@]}"; do
    args=()
    if [ "$DRY" -eq 1 ]; then args+=(--dry-run); fi
    if [ "$layer" = "01-fastfetch" ] && [ -n "$PROFILE" ]; then
        args+=(--profile "$PROFILE")
    fi

    if ! bash "$ROOT/$layer/apply.sh" "${args[@]}"; then
        failed+=("$layer")
    fi
    printf '\n'
done

printf '==> 汇总\n'
if [ ${#failed[@]} -eq 0 ]; then
    printf '  全部替换完成（4/4）\n'
    [ "$DRY" -eq 1 ] && printf '  这是 --dry-run，没有写入任何文件\n'
    exit 0
fi

printf '  失败的层: %s\n' "${failed[*]}" >&2
exit 1
