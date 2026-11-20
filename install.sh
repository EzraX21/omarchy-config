#!/usr/bin/env bash
# ==============================================================================
# omarchy-config — 统一入口
#
# 配置按 4 层拆分，每层都是一个可直接替换的配置文件 + 一个替换脚本：
#   01-fastfetch/   → ~/.config/fastfetch/config.jsonc
#   02-fontconfig/  → ~/.config/fontconfig/fonts.conf
#   03-vscode/      → ~/.config/Code/User/settings.json
#   04-noctalia/    → ~/.config/noctalia/{templates/fastfetch-config.jsonc,user-templates.toml}
#
#   ./install.sh                   全部：4 层 + ff + shell 集成
#   ./install.sh fastfetch         只替换 01 层（可加 --profile）
#   ./install.sh fontconfig        只替换 02 层
#   ./install.sh vscode            只应用 03 层
#   ./install.sh noctalia          只替换 04 层
#   ./install.sh ff                只装 ff 包装器
#   ./install.sh font              装 Maple 字体包 + 终端字体 + 02/03 两层
#   ./install.sh status            查看当前状态
#   ./install.sh uninstall         还原（优先回滚备份）
#
# 选项：
#   --profile <name>   fastfetch 布局：omarchy(默认) | shorin | plain | gnome | kde | mint | mint-labwc
#   --with-font        搭配 font 一起装（等于 all + font）
#   --dry-run          只打印将要执行的操作
#   --yes              不再询问
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo dev)"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="$HOME/.local/bin"
BASHRC="${BASHRC_OVERRIDE:-$HOME/.bashrc}"

FF_TARGET="$CONFIG_HOME/fastfetch/config.jsonc"
FF_MARKER="$CONFIG_HOME/fastfetch/.omarchy-config-profile"
FC_TARGET="$CONFIG_HOME/fontconfig/fonts.conf"
VSCODE_TARGET="$CONFIG_HOME/Code/User/settings.json"
NOCTALIA_TEMPLATE="$CONFIG_HOME/noctalia/templates/fastfetch-config.jsonc"
NOCTALIA_TOML="$CONFIG_HOME/noctalia/user-templates.toml"

MARK_BEGIN="# >>> omarchy-config >>>"
MARK_END="# <<< omarchy-config <<<"

DRY_RUN=0
ASSUME_YES=0
WITH_FONT=0
PROFILE="omarchy"
CMD=""

if [ -t 1 ]; then
    C_B="\033[1;36m"; C_Y="\033[1;33m"; C_R="\033[1;31m"; C_G="\033[1;32m"; C_N="\033[0m"
else
    C_B=""; C_Y=""; C_R=""; C_G=""; C_N=""
fi
say()  { printf '\n%b==> %s%b\n' "$C_B" "$*" "$C_N"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '  %b!%b %s\n' "$C_Y" "$C_N" "$*"; }
die()  { printf '\n%b错误: %s%b\n' "$C_R" "$*" "$C_N" >&2; exit 1; }
run() {
    if [ "$DRY_RUN" -eq 1 ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi
}
confirm() {
    if [ "$ASSUME_YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then return 0; fi
    local a
    read -r -p "  $1 [y/N] " a </dev/tty || return 1
    [[ "${a:-}" =~ ^[Yy]$ ]]
}

# --- 层调度 --------------------------------------------------------------------

apply_layer() {
    local layer="$1"
    local args=()
    if [ "$DRY_RUN" -eq 1 ]; then args+=(--dry-run); fi
    if [ "$layer" = "01-fastfetch" ]; then args+=(--profile "$PROFILE"); fi
    bash "$ROOT/$layer/apply.sh" "${args[@]}"
}

apply_all_layers() {
    local args=()
    if [ "$DRY_RUN" -eq 1 ]; then args+=(--dry-run); fi
    args+=(--profile "$PROFILE")
    bash "$ROOT/apply-all.sh" "${args[@]}"
}

backup_file() {
    local f="$1"
    [ -e "$f" ] || return 0
    local bak
    bak="$f.bak.$(date +%Y%m%d%H%M%S)"
    if [ "$DRY_RUN" -eq 1 ]; then
        info "[dry-run] 备份 $(basename "$f") → $(basename "$bak")"
    else
        cp -a "$f" "$bak"
        info "已备份 → $(basename "$bak")"
    fi
}

# --- 安装项 --------------------------------------------------------------------
install_ff() {
    say "安装 ff 包装器"
    run mkdir -p "$BIN_DIR"
    run install -m 755 "$ROOT/bin/ff" "$BIN_DIR/ff"
    info "→ $BIN_DIR/ff"

    if [ ! -f "$BASHRC" ]; then
        warn "$BASHRC 不存在，跳过 shell 集成"
        return 0
    fi
    if grep -qF "$MARK_BEGIN" "$BASHRC" 2>/dev/null; then
        info "shell 集成已存在，跳过"
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        info "[dry-run] 往 $BASHRC 追加 fastfetch() 函数"
        return 0
    fi
    backup_file "$BASHRC"
    cat >> "$BASHRC" <<'EOS'

# >>> omarchy-config >>>
# 让 fastfetch 每次运行都换一张图（图片由 ~/.local/bin/ff 维护）
if [ -x "$HOME/.local/bin/ff" ]; then
    fastfetch() { "$HOME/.local/bin/ff" "$@"; }
fi
# <<< omarchy-config <<<
EOS
    info "已写入 shell 集成（新终端生效，或 source ~/.bashrc）"
}

install_font() {
    say "安装字体"
    local args=()
    if [ "$DRY_RUN" -eq 1 ]; then args+=(--dry-run); fi
    bash "$ROOT/scripts/font-setup.sh" "${args[@]}"
}

# --- 状态 ----------------------------------------------------------------------
show_status() {
    say "omarchy-config v$VERSION"
    printf '  %-18s %s\n' "配置目录" "$CONFIG_HOME"

    local layer_label
    if [ -f "$FF_TARGET" ]; then
        layer_label="${C_G}已替换${C_N}"
        [ -f "$FF_MARKER" ] && layer_label="$layer_label（profile=$(cat "$FF_MARKER")）"
    else
        layer_label="${C_Y}未替换${C_N}"
    fi
    printf '  %-18s %s\n' "01 fastfetch" "$layer_label"

    if [ -f "$FC_TARGET" ]; then
        printf '  %-18s %s\n' "02 fontconfig" "${C_G}已替换${C_N}"
    else
        printf '  %-18s %s\n' "02 fontconfig" "${C_Y}未替换${C_N}"
    fi

    if [ -f "$VSCODE_TARGET" ]; then
        printf '  %-18s %s\n' "03 vscode" "${C_G}已应用${C_N}"
    else
        printf '  %-18s %s\n' "03 vscode" "${C_Y}未应用${C_N}"
    fi

    if [ -f "$NOCTALIA_TEMPLATE" ] || [ -f "$NOCTALIA_TOML" ]; then
        printf '  %-18s %s\n' "04 noctalia" "${C_G}已替换${C_N}"
    else
        printf '  %-18s %s\n' "04 noctalia" "${C_Y}未替换${C_N}"
    fi

    if [ -x "$BIN_DIR/ff" ]; then
        printf '  %-18s %s\n' "ff" "${C_G}已安装${C_N} → $BIN_DIR/ff"
    else
        printf '  %-18s %s\n' "ff" "${C_Y}未安装${C_N}"
    fi

    if grep -qF "$MARK_BEGIN" "$BASHRC" 2>/dev/null; then
        printf '  %-18s %s\n' "shell 集成" "${C_G}已启用${C_N} ($BASHRC)"
    else
        printf '  %-18s %s\n' "shell 集成" "${C_Y}未启用${C_N}"
    fi

    if fc-list 2>/dev/null | grep -qi 'Maple Mono'; then
        local fam
        fam=$(fc-list : family 2>/dev/null | tr ',' '\n' | grep -i '^Maple Mono' | sort -u | head -1)
        printf '  %-18s %s\n' "Maple 字体" "${C_G}已安装${C_N} ($fam)"
    else
        printf '  %-18s %s\n' "Maple 字体" "${C_Y}未安装${C_N}"
    fi

    local img="$HOME/.cache/fastfetch_waifu"
    if [ -d "$img" ]; then
        printf '  %-18s %s 张\n' "图片缓存" "$(find "$img" -maxdepth 1 -name 'waifu_*.jpg' 2>/dev/null | wc -l)"
    fi
}

# --- 卸载 ----------------------------------------------------------------------
restore_target() {
    local f="$1" label="$2"
    if [ ! -e "$f" ]; then
        return 0
    fi
    local latest
    latest=$(ls -1t "$f".bak.* 2>/dev/null | head -1 || true)
    if [ -n "$latest" ]; then
        run cp -a "$latest" "$f"
        info "$label: 已回滚 $(basename "$latest")"
    else
        run rm -f "$f"
        info "$label: 已删除（无备份）"
    fi
}

do_uninstall() {
    say "卸载 omarchy-config"
    confirm "确定还原所有改动？" || die "已取消"

    restore_target "$FF_TARGET" "01 fastfetch"
    run rm -f "$FF_MARKER"

    restore_target "$FC_TARGET" "02 fontconfig"
    restore_target "$VSCODE_TARGET" "03 vscode"
    restore_target "$NOCTALIA_TEMPLATE" "04 noctalia 模板"
    restore_target "$NOCTALIA_TOML" "04 noctalia 注册片段"

    if [ -e "$BIN_DIR/ff" ]; then
        run rm -f "$BIN_DIR/ff"
        info "已删除 $BIN_DIR/ff"
    fi

    if grep -qF "$MARK_BEGIN" "$BASHRC" 2>/dev/null; then
        if [ "$DRY_RUN" -eq 1 ]; then
            info "[dry-run] 从 $BASHRC 移除 shell 集成"
        else
            backup_file "$BASHRC"
            sed -i "/^${MARK_BEGIN}$/,/^${MARK_END}$/d" "$BASHRC"
            info "已移除 shell 集成"
        fi
    fi

    if [ -f "$FC_TARGET" ] || fc-list 2>/dev/null | grep -qi 'Maple Mono'; then
        if confirm "同时还原字体设置？（删 fonts.conf 并切回 JetBrainsMono Nerd Font）"; then
            if command -v omarchy >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qi 'JetBrainsMono Nerd Font'; then
                run omarchy font set "JetBrainsMono Nerd Font" || true
            fi
            if command -v gsettings >/dev/null 2>&1; then
                run gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11' || true
                run gsettings set org.gnome.desktop.interface monospace-font-name 'Adwaita Mono 11' || true
            fi
            info "字体包本身（/usr/share/fonts）未删除，需要时手动 pacman -Rns"
        else
            info "保留字体设置"
        fi
    fi

    say "完成"
}

# --- 参数解析 ------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        all|fastfetch|fontconfig|vscode|noctalia|ff|font|status|uninstall) CMD="$1" ;;
        help|-h|--help)
            awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0" \
                | grep -vE '^=+$'
            exit 0 ;;
        --profile)  PROFILE="${2:?--profile 需要参数}"; shift ;;
        --with-font) WITH_FONT=1 ;;
        --dry-run)  DRY_RUN=1 ;;
        --yes|-y)   ASSUME_YES=1 ;;
        *) die "未知参数: $1（试试 ./install.sh help）" ;;
    esac
    shift
done
CMD="${CMD:-all}"

case "$CMD" in
    fastfetch)  apply_layer 01-fastfetch ;;
    fontconfig) apply_layer 02-fontconfig ;;
    vscode)     apply_layer 03-vscode ;;
    noctalia)   apply_layer 04-noctalia ;;
    ff)         install_ff ;;
    font)       install_font ;;
    status)     show_status ;;
    uninstall)  do_uninstall ;;
    all)
        say "替换 4 层配置"
        apply_all_layers
        install_ff
        if [ "$WITH_FONT" -eq 1 ]; then install_font; fi
        say "完成"
        info "新终端里执行：fastfetch   （首次会自动补 5 张图）"
        if [ "$WITH_FONT" -eq 0 ]; then info "字体未处理；需要时运行：./install.sh font"; fi
        ;;
esac
