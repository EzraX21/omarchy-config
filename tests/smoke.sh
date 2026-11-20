#!/usr/bin/env bash
# ==============================================================================
# tests/smoke.sh — 隔离环境自测
#
# 在临时 HOME 里跑完整的 4 层替换 / 安装 / 字体 / 卸载流程，
# 真实 ~/.config 一行都不动。omarchy / gsettings / fc-* 用 stub 替身。
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

# 预置 VS Code 与 Noctalia 目录，让 03/04 层不会因为"没装"而跳过
mkdir -p "$HOME_DIR/.config/Code/User" "$HOME_DIR/.config/noctalia/templates"
printf '{\n  "workbench.colorTheme": "Ristretto"\n}\n' > "$HOME_DIR/.config/Code/User/settings.json"

# fc-list 假装什么都没装；omarchy/gsettings/fc-cache 只吞掉调用
for stub in omarchy gsettings fc-cache fc-list fc-match; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/$stub"
    chmod 755 "$STUB/$stub"
done

FF="$HOME_DIR/.config/fastfetch/config.jsonc"
MARKER="$HOME_DIR/.config/fastfetch/.omarchy-config-profile"
FC="$HOME_DIR/.config/fontconfig/fonts.conf"
VS="$HOME_DIR/.config/Code/User/settings.json"
NT="$HOME_DIR/.config/noctalia/templates/fastfetch-config.jsonc"
NTL="$HOME_DIR/.config/noctalia/user-templates.toml"
FF_BIN="$HOME_DIR/.local/bin/ff"

printf '\n\033[1m1. status（干净环境）\033[0m\n'
if run "$ROOT/install.sh" status >/dev/null 2>&1; then ok "status 退出码 0"; else bad "status 退出码非 0"; fi

printf '\n\033[1m2. dry-run 不落盘\033[0m\n'
if run "$ROOT/apply-all.sh" --dry-run >/dev/null 2>&1; then ok "apply-all --dry-run 退出码 0"; else bad "apply-all --dry-run 退出码非 0"; fi
assert_no_file "$FF" "dry-run 未写入 fastfetch 配置"
assert_no_file "$FC" "dry-run 未写入 fonts.conf"

printf '\n\033[1m3. install all（4 层 + ff）\033[0m\n'
if run "$ROOT/install.sh" all >/dev/null 2>&1; then ok "install all 退出码 0"; else bad "install all 退出码非 0"; fi
assert_same "$ROOT/01-fastfetch/config.jsonc" "$FF" "01 fastfetch 落盘且内容一致"
assert_grep "$MARKER" "omarchy" "profile 标记"
assert_same "$ROOT/02-fontconfig/fonts.conf" "$FC" "02 fontconfig 落盘且内容一致"
assert_grep "$VS" "fontFamily" "03 vscode 已合并字体键"
assert_grep "$VS" "Ristretto" "03 vscode 保留了原有设置"
assert_same "$ROOT/04-noctalia/templates/fastfetch-config.jsonc" "$NT" "04 noctalia 模板"
assert_same "$ROOT/04-noctalia/user-templates.toml" "$NTL" "04 noctalia 注册片段"
assert_exec "$FF_BIN" "ff 已安装且可执行"
assert_grep "$HOME_DIR/.bashrc" "omarchy-config" "shell 集成已写入"

printf '\n\033[1m4. 幂等性（重复执行不叠加）\033[0m\n'
run "$ROOT/install.sh" all >/dev/null 2>&1
assert_eq "$(grep -cF 'fastfetch() {' "$HOME_DIR/.bashrc")" 1 "shell 集成不重复"
assert_eq "$(find "$HOME_DIR/.config/fastfetch" -maxdepth 1 -name '*.bak.*' | wc -l)" 0 "重复替换不产生多余备份"

printf '\n\033[1m5. 字体（含 02/03 两层联动）\033[0m\n'
if run env MAPLE_FAMILY="Maple Mono NF CN" "$ROOT/install.sh" font >/dev/null 2>&1; then ok "install font 退出码 0"; else bad "install font 退出码非 0"; fi
assert_same "$ROOT/02-fontconfig/fonts.conf" "$FC" "02 层内容保持一致（字体已是默认）"
assert_grep "$VS" "Maple Mono NF CN" "03 层已写入字体键"

printf '\n\033[1m6. status 反映已替换状态\033[0m\n'
status_out="$(run "$ROOT/install.sh" status 2>&1 || true)"
case "$status_out" in
    *"已替换"*) ok "status 报告层已替换" ;;
    *)          bad "status 未报告层已替换" ;;
esac

printf '\n\033[1m7. uninstall（回滚/删除）\033[0m\n'
if run "$ROOT/install.sh" uninstall --yes >/dev/null 2>&1; then ok "uninstall 退出码 0"; else bad "uninstall 退出码非 0"; fi
assert_no_file "$FF" "fastfetch 配置已移除"
assert_no_file "$FC" "fonts.conf 已移除"
assert_no_file "$NT" "noctalia 模板已移除"
assert_no_file "$NTL" "noctalia 片段已移除"
assert_no_grep "$VS" "fontFamily" "vscode 字体键已回滚"
assert_grep "$VS" "Ristretto" "vscode 原有设置仍在"
assert_no_file "$FF_BIN" "ff 已移除"
assert_no_grep "$HOME_DIR/.bashrc" "omarchy-config" "shell 集成已清理"

printf '\n\033[1m8. 每层可独立替换\033[0m\n'
if run bash "$ROOT/01-fastfetch/apply.sh" --profile shorin >/dev/null 2>&1; then ok "01 层可单独执行"; else bad "01 层单独执行失败"; fi
assert_same "$ROOT/01-fastfetch/profiles/shorin-tree.jsonc" "$FF" "01 层 --profile shorin 生效"
if run bash "$ROOT/02-fontconfig/apply.sh" --family "Test Mono" >/dev/null 2>&1; then ok "02 层可单独执行"; else bad "02 层单独执行失败"; fi
assert_grep "$FC" "Test Mono" "02 层 --family 替换生效"
assert_no_grep "$FC" "Maple Mono NF CN" "02 层默认字体名已被替换"

printf '\n\033[1m9. 配置合法性\033[0m\n'
if python3 "$ROOT/tests/validate-configs.py" >/dev/null 2>&1; then
    ok "仓库内所有 .json/.jsonc 可解析"
else
    bad "有配置解析失败（单独运行 tests/validate-configs.py 查看）"
fi

printf '\n\033[1m结果\033[0m\n'
printf '  %d 通过, %d 失败\n\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
