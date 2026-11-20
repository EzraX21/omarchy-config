# 第三方来源与许可

本项目里的配置与脚本并非全部原创，来源与许可如下。分发或修改前请阅读。

## 衍生自 shorin-arch-setup（AGPL-3.0-or-later）

- 上游：<https://github.com/SHORiN-KiWATA/shorin-arch-setup>
- 许可：GNU Affero General Public License v3.0 or later
- 涉及文件：
  - `config/fastfetch/shorin-tree.jsonc`（上游 `minimal-niri-dotfiles/.config/fastfetch/config.jsonc` 原件）
  - `config/fastfetch/plain.jsonc`（同上）
  - `config/fastfetch/variants/*.jsonc`（上游 gnome / kde / minimal-niri / minimal-labwc 四个变体原件）
  - `config/noctalia/templates/fastfetch-config.jsonc`（上游 Noctalia 的 matugen 模板原件）
  - `config/noctalia/user-templates.fastfetch.toml`（上游片段）
  - `scripts/fastfetch-random-wife.sh`（上游 `gnome-dotfiles/.config/scripts/fastfetch-random-wife.sh`，本项目仅做三处修改，见下）

对上游文件所做的修改（其余逐字节一致）：

1. `fastfetch-random-wife.sh` 增加 `#!/usr/bin/env bash` shebang（原件无 shebang 且权限 644）；
2. `get_random_url` 由「随机三选一 + 只试一次」改为「按序遍历全部图源直到拿到可用 URL」；
3. 空缓存时下载重试 3 次；展示后额外把图复制为 `current.jpg` 供配置使用。

由于包含 AGPL 衍生作品，**分发本项目时请整体遵守 AGPL-3.0-or-later**；本项目自身脚本（`install.sh`、`bin/ff`、`scripts/font-setup.sh`）为 MIT，二者并存时以更严格者为准。

## 衍生自 Omarchy 的默认配置

- `config/fastfetch/omarchy-layout.jsonc` 来自系统文件 `/etc/fastfetch/config.jsonc`（Omarchy 随包提供），
  仅替换了 `logo` 块（3 行）。Omarchy 的许可与条款以其项目仓库为准（<https://github.com/basecamp/omarchy>）。

## 字体：Maple Mono

- 上游：<https://github.com/subframe7536/maple-font>
- 许可：SIL Open Font License 1.1
- 本项目**不打包字体文件**，仅通过脚本调用 Omarchy 仓库的 `maplemono-nf-cn` 包安装。

## fastfetch

- 上游：<https://github.com/fastfetch-cli/fastfetch>
- 许可：MIT
- 本项目只提供配置文件，不包含其代码。

## NeKo / 图片接口

`scripts/fastfetch-random-wife.sh` 与 `bin/ff` 会请求以下第三方接口：

- <https://nekos.best>（可用）
- <https://api.waifu.im>、<https://api.waifu.pics>（部分网络不可达，作为回退）

图片版权归各接口与原作者所有，本项目不存储、不转发这些图片，仅在本地缓存后显示。
