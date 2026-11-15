#!/usr/bin/env bash
# ==============================================================================
# tests/smoke.sh — 隔离环境自测
#
# 在临时 HOME 里跑完整的 install / profile 切换 / 字体 / uninstall 流程，
# 真实 ~/.config 一行都不动。omarchy / gsettings / fc-list 用 stub 替身。
#
# 用法：bash tests/smoke.sh
# 退出码：0 全部通过
# ==============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/omarchy-config-test.XXXXXX")"
HOME_DIR="$TMP/home"
STUB="$TMP/bin"
PASS=0
FAIL=0

trap 'rm -rf "$TMP"' EXIT

ok()  { PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %s\n' "$*"; }

assert_file()    { if [ -f "$1" ]; then ok "$2"; else bad "$2（文件不存在: $1）"; fi; }
assert_no_file() { if [ ! -e "$1" ]; then ok "$2"; else bad "$2（仍存在: $1）"; fi; }
assert_exec()    { if [ -x "$1" ]; then ok "$2"; else bad "$2（不可执行: $1）"; fi; }
assert_grep()    { if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$3"; fi; }
assert_no_grep() { if ! grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$3"; fi; }
assert_same()    { if cmp -s "$1" "$2"; then ok "$3"; else bad "$3"; fi; }
assert_eq()      { if [ "$1" -eq "$2" ]; then ok "$3"; else bad "$3（期望 $2，实际 $1）"; fi; }

run() {
    env HOME="$HOME_DIR" \
        XDG_CONFIG_HOME="$HOME_DIR/.config" \
        PATH="$STUB:$PATH" \
        "$@"
}

# --- 环境准备 ------------------------------------------------------------------
mkdir -p "$HOME_DIR/.config" "$STUB"
: > "$HOME_DIR/.bashrc"

# fc-list 假装什么都没装；omarchy/gsettings/fc-cache 只吞掉调用
for stub in omarchy gsettings fc-cache fc-list fc-match; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/$stub"
    chmod 755 "$STUB/$stub"
done

CFG="$HOME_DIR/.config/fastfetch/config.jsonc"
MARKER="$HOME_DIR/.config/fastfetch/.omarchy-config-profile"
FF_BIN="$HOME_DIR/.local/bin/ff"
FONTS_CONF="$HOME_DIR/.config/fontconfig/fonts.conf"

printf '\n\033[1m1. status（干净环境）\033[0m\n'
if run "$ROOT/install.sh" status >/dev/null 2>&1; then ok "status 退出码 0"; else bad "status 退出码非 0"; fi

printf '\n\033[1m2. dry-run 不落盘\033[0m\n'
if run "$ROOT/install.sh" --dry-run all >/dev/null 2>&1; then ok "dry-run 退出码 0"; else bad "dry-run 退出码非 0"; fi
assert_no_file "$CFG" "dry-run 未写入配置"

printf '\n\033[1m3. install all\033[0m\n'
if run "$ROOT/install.sh" all >/dev/null 2>&1; then ok "install all 退出码 0"; else bad "install all 退出码非 0"; fi
assert_file "$CFG" "fastfetch 配置已写入"
assert_same "$ROOT/config/fastfetch/config.omarchy-layout.jsonc" "$CFG" "默认 profile 内容一致"
assert_grep "$MARKER" "omarchy" "profile 标记"
assert_exec "$FF_BIN" "ff 已安装且可执行"
assert_grep "$HOME_DIR/.bashrc" "omarchy-config" "shell 集成已写入"

printf '\n\033[1m4. 幂等性\033[0m\n'
run "$ROOT/install.sh" all >/dev/null 2>&1
assert_eq "$(grep -cF 'fastfetch() {' "$HOME_DIR/.bashrc")" 1 "shell 集成不重复"
assert_eq "$(find "$HOME_DIR/.config/fastfetch" -maxdepth 1 -name '*.bak.*' | wc -l)" 0 "重复安装不产生多余备份"

printf '\n\033[1m5. 切换 profile\033[0m\n'
if run "$ROOT/install.sh" fastfetch --profile shorin >/dev/null 2>&1; then ok "切 profile 退出码 0"; else bad "切 profile 退出码非 0"; fi
assert_same "$ROOT/config/fastfetch/config.shorin-tree.jsonc" "$CFG" "已切到 shorin 布局"
assert_grep "$MARKER" "shorin" "profile 标记已更新"

printf '\n\033[1m6. 字体\033[0m\n'
if run env MAPLE_FAMILY="Test Mono" "$ROOT/install.sh" font >/dev/null 2>&1; then ok "install font 退出码 0"; else bad "install font 退出码非 0"; fi
assert_file "$FONTS_CONF" "fonts.conf 已生成"
assert_grep "$FONTS_CONF" "Test Mono" "字体名已代入"
assert_no_grep "$FONTS_CONF" "@FAMILY@" "模板占位符已替换"

printf '\n\033[1m7. status 反映已安装状态\033[0m\n'
status_out="$(run "$ROOT/install.sh" status 2>&1 || true)"
case "$status_out" in
    *已安装*) ok "status 报告已安装" ;;
    *)        bad "status 未报告已安装" ;;
esac

printf '\n\033[1m8. uninstall\033[0m\n'
if run "$ROOT/install.sh" uninstall --yes >/dev/null 2>&1; then ok "uninstall 退出码 0"; else bad "uninstall 退出码非 0"; fi
assert_no_file "$CFG" "fastfetch 配置已移除"
assert_no_file "$FF_BIN" "ff 已移除"
assert_no_grep "$HOME_DIR/.bashrc" "omarchy-config" "shell 集成已清理"
assert_no_file "$FONTS_CONF" "fonts.conf 已移除"

printf '\n\033[1m9. 配置合法性\033[0m\n'
if python3 "$ROOT/tests/validate-configs.py" "$ROOT/config" >/dev/null 2>&1; then
    ok "config/ 下所有 .jsonc 可解析"
else
    bad "有 .jsonc 解析失败（单独运行 tests/validate-configs.py 查看）"
fi

printf '\n\033[1m结果\033[0m\n'
printf '  %d 通过, %d 失败\n\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
