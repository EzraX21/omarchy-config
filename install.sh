#!/usr/bin/env bash
# ==============================================================================
# omarchy-config — 统一入口
#
#   ./install.sh                 安装全部（fastfetch 配置 + ff 包装器）
#   ./install.sh fastfetch       只装 fastfetch 配置
#   ./install.sh ff              只装 ff（随机图 logo 包装器）
#   ./install.sh font            装 Maple Mono NF 并全局应用（需要 sudo）
#   ./install.sh status          查看当前安装状态
#   ./install.sh uninstall       还原（优先用备份回滚）
#
# 选项：
#   --profile <name>    fastfetch 用哪套布局：omarchy(默认) | shorin | plain
#                       | gnome | kde | mint | mint-labwc
#   --with-font         搭配 font 一起装（等于 ./install.sh all）
#   --dry-run           只打印将要执行的操作
#   --yes               不再询问
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo dev)"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="$HOME/.local/bin"
BASHRC="${BASHRC_OVERRIDE:-$HOME/.bashrc}"

FF_DIR="$CONFIG_HOME/fastfetch"
FF_CONFIG="$FF_DIR/config.jsonc"
FF_MARKER="$FF_DIR/.omarchy-config-profile"
FONTS_CONF="$CONFIG_HOME/fontconfig/fonts.conf"

MARK_BEGIN="# >>> omarchy-config >>>"
MARK_END="# <<< omarchy-config <<<"

DRY_RUN=0
ASSUME_YES=0
WITH_FONT=0
PROFILE="omarchy"
CMD=""

# --- 输出 ---------------------------------------------------------------------
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
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}
confirm() {
    if [ "$ASSUME_YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then return 0; fi
    local a
    read -r -p "  $1 [y/N] " a </dev/tty || return 1
    [[ "${a:-}" =~ ^[Yy]$ ]]
}

# --- 布局映射 ------------------------------------------------------------------
profile_path() {
    case "$1" in
        omarchy)    echo "$ROOT/config/fastfetch/omarchy-layout.jsonc" ;;
        shorin)     echo "$ROOT/config/fastfetch/shorin-tree.jsonc" ;;
        plain)      echo "$ROOT/config/fastfetch/plain.jsonc" ;;
        gnome)      echo "$ROOT/config/fastfetch/variants/gnome-kitty.jsonc" ;;
        kde)        echo "$ROOT/config/fastfetch/variants/kde-pink-sixel.jsonc" ;;
        mint)       echo "$ROOT/config/fastfetch/variants/minimal-mint-sixel.jsonc" ;;
        mint-labwc) echo "$ROOT/config/fastfetch/variants/minimal-mint-sixel-labwc.jsonc" ;;
        *) return 1 ;;
    esac
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
install_fastfetch() {
    local src
    src="$(profile_path "$PROFILE")" || die "未知 profile: $PROFILE（可选：omarchy shorin plain gnome kde mint mint-labwc）"
    [ -f "$src" ] || die "找不到配置文件: $src"

    say "安装 fastfetch 配置（profile: $PROFILE）"
    info "源: ${src#$ROOT/}"

    # 先校验 JSONC 能否被 fastfetch 解析，避免装上一份坏配置
    if command -v fastfetch >/dev/null 2>&1 && [ "$DRY_RUN" -eq 0 ]; then
        if ! fastfetch -c "$src" --pipe >/dev/null 2>&1; then
            warn "fastfetch 解析该配置失败，仍继续（请检查语法）"
        else
            info "配置语法校验通过"
        fi
    fi

    run mkdir -p "$FF_DIR"
    # 只在「本工具第一次接管」时备份，避免重复安装把用户原始配置的备份挤掉
    if [ ! -f "$FF_MARKER" ]; then
        backup_file "$FF_CONFIG"
    else
        info "本工具已接管过（profile: $(cat "$FF_MARKER" 2>/dev/null || echo '?')），跳过重复备份"
    fi
    run cp "$src" "$FF_CONFIG"
    if [ "$DRY_RUN" -eq 0 ]; then
        echo "$PROFILE" > "$FF_MARKER"
    fi
    info "→ $FF_CONFIG"
}

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

    if [ -f "$FF_CONFIG" ]; then
        printf '  %-18s %s\n' "fastfetch 配置" "${C_G}已安装${C_N} ($(grep -c . "$FF_CONFIG" 2>/dev/null) 行)"
        [ -f "$FF_MARKER" ] && printf '  %-18s %s\n' "profile" "$(cat "$FF_MARKER")"
    else
        printf '  %-18s %s\n' "fastfetch 配置" "${C_Y}未安装${C_N}"
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

    if [ -f "$FONTS_CONF" ]; then
        printf '  %-18s %s\n' "fonts.conf" "存在 ($FONTS_CONF)"
    fi

    local img="$HOME/.cache/fastfetch_waifu"
    if [ -d "$img" ]; then
        printf '  %-18s %s 张\n' "图片缓存" "$(find "$img" -maxdepth 1 -name 'waifu_*.jpg' 2>/dev/null | wc -l)"
    fi
}

# --- 卸载 ----------------------------------------------------------------------
do_uninstall() {
    say "卸载 omarchy-config"
    confirm "确定还原所有改动？" || die "已取消"

    # 1. fastfetch 配置：优先回滚最新备份
    if [ -f "$FF_CONFIG" ]; then
        local latest
        latest=$(ls -1t "$FF_CONFIG".bak.* 2>/dev/null | head -1 || true)
        if [ -n "$latest" ]; then
            run cp -a "$latest" "$FF_CONFIG"
            info "已回滚到备份: $(basename "$latest")"
        else
            run rm -f "$FF_CONFIG"
            info "已删除 $FF_CONFIG（这是脚本新建的，无备份可回滚；Omarchy 的 /etc 配置会自动接管）"
        fi
    fi
    run rm -f "$FF_MARKER"

    # 2. ff
    if [ -e "$BIN_DIR/ff" ]; then
        run rm -f "$BIN_DIR/ff"
        info "已删除 $BIN_DIR/ff"
    fi

    # 3. shell 集成
    if grep -qF "$MARK_BEGIN" "$BASHRC" 2>/dev/null; then
        if [ "$DRY_RUN" -eq 1 ]; then
            info "[dry-run] 从 $BASHRC 移除 shell 集成"
        else
            backup_file "$BASHRC"
            sed -i "/^${MARK_BEGIN}$/,/^${MARK_END}$/d" "$BASHRC"
            info "已移除 shell 集成"
        fi
    fi

    # 4. 字体（改动面较大，单独确认）
    if [ -f "$FONTS_CONF" ] || fc-list 2>/dev/null | grep -qi 'Maple Mono'; then
        if confirm "同时还原字体设置？（会删 fonts.conf 并切回 JetBrainsMono Nerd Font 或系统默认）"; then
            if [ -f "$FONTS_CONF" ]; then
                run rm -f "$FONTS_CONF"
                info "已删除 $FONTS_CONF"
            fi
            if command -v omarchy >/dev/null 2>&1; then
                if fc-list 2>/dev/null | grep -qi 'JetBrainsMono Nerd Font'; then
                    run omarchy font set "JetBrainsMono Nerd Font" || true
                fi
            fi
            if command -v gsettings >/dev/null 2>&1; then
                run gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11' || true
                run gsettings set org.gnome.desktop.interface monospace-font-name 'Adwaita Mono 11' || true
            fi
            info "字体包本身（$HOME 之外的 /usr/share/fonts）未删除，需要时手动 pacman -Rns"
        else
            info "保留字体设置"
        fi
    fi

    say "完成"
}

# --- 参数解析 ------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        all|fastfetch|ff|font|status|uninstall) CMD="$1" ;;
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
    fastfetch) install_fastfetch ;;
    ff)        install_ff ;;
    font)      install_font ;;
    status)    show_status ;;
    uninstall) do_uninstall ;;
    all)
        install_fastfetch
        install_ff
        if [ "$WITH_FONT" -eq 1 ]; then install_font; fi
        say "完成"
        info "新终端里执行：fastfetch   （首次会自动补 5 张图）"
        if [ "$WITH_FONT" -eq 0 ]; then info "字体未处理；需要时运行：./install.sh font"; fi
        ;;
esac
