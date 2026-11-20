#!/usr/bin/env bash
# ==============================================================================
# bootstrap.sh — 一键安装：拉取仓库快照并执行 install.sh
#
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/EzraX21/omarchy-config/main/bootstrap.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/EzraX21/omarchy-config/main/bootstrap.sh | bash -s -- --dry-run
#   curl -fsSL https://raw.githubusercontent.com/EzraX21/omarchy-config/main/bootstrap.sh | bash -s -- --profile shorin
#
# 固定版本：
#   curl -fsSL https://raw.githubusercontent.com/EzraX21/omarchy-config/main/bootstrap.sh \
#     | OMARCHY_CONFIG_REF=v0.1.1 bash
#
# 只替换配置、不装 ff：把下面的 install.sh 换成 apply-all.sh 的 URL 即可，见 README。
#
# 行为：
#   - 只下载仓库 tarball 到临时目录，运行完自动删除
#   - 不需要 root（例外：--with-font / font 子命令会调 pacman，需要管理员密码）
#   - 写入 ~/.config 前会自动备份；不做任何提权、不改系统文件
# ==============================================================================
set -euo pipefail

REPO="EzraX21/omarchy-config"
REF="${OMARCHY_CONFIG_REF:-main}"

case "$REF" in
    v[0-9]*) URL="https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz" ;;
    *)       URL="https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz" ;;
esac

printf '\033[1;36m==> omarchy-config（%s）\033[0m\n' "$REF"
printf '  下载: %s\n' "$URL"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/omarchy-config.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "$URL" | tar -xz -C "$tmp"

src="$(find "$tmp" -maxdepth 1 -type d -name 'omarchy-config-*' | head -1 || true)"
if [ -z "$src" ]; then
    printf '错误: 解压后找不到 omarchy-config-* 目录\n' >&2
    exit 1
fi

printf '  执行: install.sh %s\n\n' "${*:-}"
bash "$src/install.sh" "$@"
