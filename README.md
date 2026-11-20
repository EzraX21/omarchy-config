# omarchy-config

把 Omarchy 桌面上「好看的那一套」整理成可复现、可回滚的项目：fastfetch 信息面板（带随机立绘 logo）、
终端/应用的全局字体，以及它们背后所有的坑与验证记录。

[![check](https://github.com/EzraX21/omarchy-config/actions/workflows/check.yml/badge.svg)](https://github.com/EzraX21/omarchy-config/actions/workflows/check.yml)
![platform](https://img.shields.io/badge/platform-Omarchy%20%7C%20Arch-1793d1)
![shell](https://img.shields.io/badge/shell-bash%205-4eaa25)
![smoke](https://img.shields.io/badge/smoke-27%20assertions-brightgreen)
![license](https://img.shields.io/badge/license-MIT%20%2B%20AGPL--3.0-blue)


> 面向 **Omarchy（Arch + Hyprland）** 的桌面级配置，不是系统安装脚本。
> 不碰 `/usr/share/omarchy/`，不改包管理器源，不装来路不明的二进制。

```
┌─────────────────────────────────────────────────────────┐
│  fastfetch：Omarchy 原布局 + 随机下载图当 logo            │
│  字体   ：Maple Mono NF 全局替换（终端 + GTK + VS Code）  │
└─────────────────────────────────────────────────────────┘
```

## 快速开始

```bash
cd omarchy-config
./install.sh                 # 装 fastfetch 配置 + ff 包装器
./install.sh font            # 可选：换字体（需要 sudo）
./install.sh status          # 看装了什么
```

装完新开一个终端：

```bash
fastfetch        # 第一次会自动补 5 张图，之后每次换一张
```

## 预览

`omarchy` profile（默认）—— 保留系统原三栏框，只把左侧 logo 换成随机下载图：

```text


  ██████████████████████████████████████████████████████      ┌──────────────────────Hardware──────────────────────┐
  ██████████████████████████████████████████████████████      │ ├: Intel(R) Core(TM) i5-6500 (4) @ 3.60 GHz
  ████                     ████                     ████      │ ├: HD Graphics 530
  ████                     ████                     ████      │ ├󱄄: 1920x1080 in 24", 60 Hz [External]
  ████    █████████████████████         ████████    ████      │ ├󱄄: 1920x1080 @ 1.25x in 31", 60 Hz [External]
  ████    █████████████████████         ████████    ████      │ ├󰋊: 77.69 GiB / 236.46 GiB (33%) - btrfs [Read-only]
  ████    ████                              ████    ████      │ ├: 6.24 GiB / 15.48 GiB (40%)
  ████    ████                              ████    ████      └ └󰓡: 0 B / 30.96 GiB (0%)
  ████    ████                              ████    ████      └────────────────────────────────────────────────────┘
  ████    ████                              ████    ████
  ████    ████                              ████    ████      ┌──────────────────────Software──────────────────────┐
  ████    ████                              ████    ████       OS: Omarchy 4.5.0-3
  ████████████                              ████    ████      │ ├󰔫: unknown / stable
  ████████████                              ████    ████      │ ├: Linux 7.2.15-1-omarchy
  ████    ████                              ████    ████      │ ├: Hyprland 0.57.2 (Wayland)
  ████    ████                              ████    ████      │ ├: dumb
```

`shorin` profile —— 三段式树形（OS/KER/PAK/AGE/USR · WM · 硬件）：

```text

  ██████████████████████████████████  OS Omarchy x86_64
  ██              ██              ██   ├   KER  Linux 7.2.15-1-omarchy
  ██   █████████████       ████   ██   ├   PAK  1180
  ██   ██                    ██   ██   ├   AGE  10 days
  ██   ██                    ██   ██   └   USR  user@host
  ██   ██                    ██   ██
  ██   ██                    ██   ██
  ███████                    ██   ██  WM Hyprland 0.57.2 (Wayland)
  ██   ██                    ██   ██   ├   SHE  bash 5.3.20
  ██   ██                    ██   ██   ├   TER  dumb
  ██   ██                    ██   ██
  ██   ██                    ██   ██
  ██   ████████████████████████   ██   ├   CPU  Intel(R) Core(TM) i5-6500 (4) @ 3.60 GHz
  ██              ██              ██   ├   MEM  6.24 GiB / 15.48 GiB (40%)
  ██████████████████   █████████████   ├   SWP  0 B / 30.96 GiB (0%)
```

> 上面是 `fastfetch --pipe` 的纯文本渲染，所以终端名显示 `dumb`（真实终端里是 `foot`），
> 图形 logo 也只能退化成方块。完整效果运行 `./install.sh` 后自己看。
> 想补真截图：在 foot 里跑 `fastfetch`，用 `omarchy capture screenshot` 存到 `docs/images/` 即可。

## 配置按软件分开

`config/` 下每个目录只服务一个软件，互不混放：

| 目录 | 属于谁 | 内容 | 安装到 |
|---|---|---|---|
| `config/fastfetch/` | fastfetch | 7 套布局（`omarchy-layout` / `shorin-tree` / `plain` + `variants/`） | `~/.config/fastfetch/config.jsonc` |
| `config/noctalia/` | Noctalia | matugen 模板 + `user-templates.toml` 注册片段 | 手动放到 `~/.config/noctalia/`（可选） |
| `config/fontconfig/` | fontconfig | `fonts.conf.tpl`（泛用族别名） | `~/.config/fontconfig/fonts.conf` |
| `config/vscode/` | VS Code | `settings-font.jsonc`（字体键片段） | 深合并进 `~/.config/Code/User/settings.json` |

`install.sh` 只自动装 fastfetch 与 fontconfig；`noctalia` 与 `vscode` 是素材/片段，由对应流程或手动取用。

## 命令一览

| 命令 | 作用 |
|---|---|
| `./install.sh` / `all` | 安装 fastfetch 配置 + `ff` 包装器 + shell 集成 |
| `./install.sh fastfetch` | 只装 fastfetch 配置（覆盖前自动备份） |
| `./install.sh ff` | 只装 `~/.local/bin/ff` 与 `.bashrc` 集成 |
| `./install.sh font` | 装 Maple Mono NF 并全局应用（`omarchy pkg add`，需 sudo） |
| `./install.sh status` | 打印当前安装状态（配置/profile/ff/字体/图片缓存） |
| `./install.sh uninstall` | 还原：优先回滚备份，其次删除；字体单独确认 |
| `./install.sh help` | 用法 |

通用选项：`--profile <name>`、`--dry-run`、`--yes`、`--with-font`。

## fastfetch 布局方案

用 `--profile` 选，默认 `omarchy`：

| profile | 右侧格式 | 来源 |
|---|---|---|
| `omarchy`（默认） | `┌── Hardware ──┐` / `Software` / `Age·Uptime·Update` 三栏框 | 系统 `/etc/fastfetch/config.jsonc`，仅换 logo 块 |
| `shorin` | 三段式树形（OS/KER/PAK/AGE/USR …） | shorin-arch-setup 的 minimal-niri 原件 |
| `plain` | 同 `shorin`，内置 Arch logo | 同上原件 |
| `gnome` / `kde` / `mint` / `mint-labwc` | 其它发行版风格配色与 logo 协议 | 上游四个变体原件 |

```bash
./install.sh fastfetch --profile shorin
```

所有 profile 的 logo 都指向 `~/.cache/fastfetch_waifu/current.jpg`，由 `ff` 维护。

## 图是从哪来的

`bin/ff` 每次运行做三件事：

1. 缓存（`~/.cache/fastfetch_waifu/waifu_*.jpg`）少于 5 张就补货，按 `nekos.best` → `waifu.im` → `waifu.pics` 依次尝试；
2. 随机挑一张拷成 `current.jpg`；
3. `exec fastfetch "$@"` —— **不传 `--logo`**，让配置里的 `type` / `width` 生效。

实测：有缓存时单次 28~31 ms；空缓存首次补 5 张约 9 秒。

`scripts/fastfetch-random-wife.sh` 是上游原版脚本（已修图源与 shebang），保留给「手动跑一次」或 NSFW 场景：

```bash
scripts/fastfetch-random-wife.sh            # 随机一张
scripts/fastfetch-random-wife.sh --nsfw     # NSFW 图源（缓存目录不同）
```

## 字体

`./install.sh font` 会：

1. `omarchy pkg add maplemono-nf-cn`（Omarchy 仓库，NF = Nerd Font 图标，CN = 含中文）；
2. 动态探测真实 family 名；
3. `omarchy font set "<family>"` → foot / alacritty / kitty / ghostty + `monospace`；
4. 用 `config/fontconfig/fonts.conf.tpl` 生成 `~/.config/fontconfig/fonts.conf`，
   把 `sans-serif` / `serif` / `monospace` 全部指向 Maple，并给中文回退 `Noto Sans CJK SC`
   （`system-ui` 无法经 fontconfig 重映射，实测无效，故不处理）；
5. `gsettings` 三个 GTK 字体键；
6. VS Code：把 `config/vscode/settings-font.jsonc` 渲染后**深合并**进 `~/.config/Code/User/settings.json`
   （只覆盖字体相关的键，其它设置保留）。

**顺序不能反**：`omarchy font set` 会整份覆写 `fonts.conf`，所以模板必须在它之后写。
**代价**：Maple Mono 是等宽字体，全局当 sans-serif 用会让 GUI 也是等宽观感。
只想改代码/终端字体：`scripts/font-setup.sh --no-gtk` 并跳过第 4 步。

## 它会改哪些文件

安装（全部可回滚）：

```
~/.config/fastfetch/config.jsonc           ← 覆盖前备份为 config.jsonc.bak.<时间戳>
~/.config/fastfetch/.omarchy-config-profile ← 记录用的是哪个 profile
~/.local/bin/ff                            ← 可执行
~/.bashrc                                  ← 追加一段带 >>> omarchy-config >>> 标记的块
```

字体（`./install.sh font`）：

```
/usr/share/fonts/…                         ← 由 pacman 包安装（系统级）
~/.config/fontconfig/fonts.conf            ← 生成
~/.config/{foot,alacritty,kitty,ghostty}/   ← omarchy font set 写字体行
dconf (gsettings)                          ← GTK 字体键
~/.config/Code/User/settings.json          ← 深合并字体键（仅当该文件是纯 JSON）
```

## 卸载

```bash
./install.sh uninstall
```

- fastfetch 配置：有新备份就回滚，没有就删除（删掉后系统 `/etc` 配置自动接管）；
- `ff` 与 `.bashrc` 集成块：删除；
- 字体：单独确认。删 `fonts.conf`、把 `omarchy font set` 切回 JetBrainsMono、gsettings 回 Adwaita。
  **字体包本身不删除**（`pacman -Rns maplemono-nf-cn` 需自己执行）。

## 自测与 CI

```bash
python3 tests/validate-configs.py config   # 所有 .jsonc 可解析（含 logo.type 提示）
bash tests/smoke.sh                        # 隔离 HOME 跑完整流程，27 项断言
```

`smoke.sh` 用临时 `HOME` + stub 掉的 `omarchy`/`gsettings`/`fc-*`，**不碰真实 `~/.config`**。
CI（`.github/workflows/check.yml`）跑四件事：`bash -n` 全量、`shellcheck -S warning`、
配置解析、以及 `tests/smoke.sh`。

## 文档

- [`docs/GOTCHAS.md`](docs/GOTCHAS.md) —— 16 条实测踩坑：`logo.type` 语义、`preserveAspectRatio` 只支持 iTerm、
  `--pipe` 忽略尺寸、图源可达性、`omarchy font set` 覆写 fonts.conf …
- [`docs/SHORIN-ANALYSIS.md`](docs/SHORIN-ANALYSIS.md) —— 对 `curl -L shorin.xyz/archsetup | bash` 那套一键脚本的完整审计
  （本项目的 fastfetch 素材与部分认知来自该审计）。
- [`THIRD_PARTY.md`](THIRD_PARTY.md) —— 来源、许可与修改点。
- [`CONTRIBUTING.md`](CONTRIBUTING.md) —— 加新布局的步骤、脚本约定、许可注意。
- [`CHANGELOG.md`](CHANGELOG.md) —— 版本变更记录。

## 许可

本项目自身脚本（`install.sh`、`bin/ff`、`scripts/font-setup.sh`）为 MIT；
`config/fastfetch/`、`config/noctalia/` 下衍生自 shorin-arch-setup 的配置与 `scripts/fastfetch-random-wife.sh` 为 **AGPL-3.0-or-later**。
分发时请以更严格者为准，详见 [THIRD_PARTY.md](THIRD_PARTY.md)。
