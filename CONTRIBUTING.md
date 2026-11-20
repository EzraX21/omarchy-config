# 贡献指南

这是个**个人**配置项目，但结构按可维护的项目来做。下面是最小必要的约定。

## 环境

- `bash` ≥ 5（用到数组、`[[ ]]`、`${var,,}`）
- `python3`（配置校验与 VS Code 设置合并）
- 可选：`shellcheck`（CI 会跑，本地建议也跑）

## 改动前先跑这两个

```bash
python3 tests/validate-configs.py config   # 所有 .jsonc 能否被解析
bash tests/smoke.sh                        # 隔离 HOME 里跑完整流程
```

`smoke.sh` 会建一个临时 `HOME`，把 `omarchy` / `gsettings` / `fc-*` 用 stub 替身，
**不会碰你真实的 `~/.config`**。跑完自动清理。当前是 27 项断言。

## 目录职责

| 路径 | 职责 | 注意 |
|---|---|---|
| `install.sh` | 唯一入口，子命令分发 | 所有写操作都要能 `--dry-run` |
| `bin/ff` | 运行时工具（每次换图） | 不放配置，配置在 `config/` |
| `config/fastfetch/` | 布局成品，每种一个文件 | 文件名去掉 `.jsonc` 即 profile 名，见下 |
| `config/noctalia/` | Noctalia 的 matugen 模板与注册片段 | 属于 Noctalia，不要塞进 `fastfetch/` |
| `config/fontconfig/*.tpl` | 模板，`@FAMILY@` 由脚本替换 | 不要写死字体名 |
| `config/vscode/*.jsonc` | VS Code 设置片段，`@FAMILY@` 由脚本替换 | 只放要合并的键 |
| `scripts/` | 较重的独立流程（字体、上游脚本） | 可单独执行并有 `--help` |
| `tests/` | 自测与校验 | CI 跑的就是这两个 |

## 加一套新的 fastfetch 布局

1. 把配置放进 `config/fastfetch/<名字>.jsonc`（或 `variants/`）；
2. 在 `install.sh` 的 `profile_path()` 里加一个 `case` 分支；
3. 更新 `README.md` 的 profile 表格；
4. 跑 `python3 tests/validate-configs.py config` 与 `bash tests/smoke.sh`；
5. 如果这份配置来自第三方仓库，**必须在 `THIRD_PARTY.md` 登记来源与许可**。

`logo` 段请遵守两条硬规则（细节见 [`docs/GOTCHAS.md`](docs/GOTCHAS.md)）：

- `logo.type` 是**渲染协议**（`sixel`/`kitty`/`chafa`），不是文件类型；写 `file` 会把图片当文本读；
- **不要同时给 `width` 和 `height`**，图片会被拉伸；`preserveAspectRatio` 只对 iTerm 有效。

## 改脚本的约定

- `set -euo pipefail`；
- **不要在 `set -e` 下用裸 `[ ... ] && 命令` 当语句** —— 条件为假会直接退出脚本，用 `if`；
- `local x` 与 `x=$(命令)` 分开写（避免 SC2155），也不用 `for x in $(seq n)`（用 `while` 或 C 风格循环）；
- 覆盖用户文件前**必须备份**，且只在「本工具第一次接管」时备份，避免把用户原始备份挤掉；
- 新增的写操作要同时支持 `--dry-run` 与回滚（`uninstall`）；
- 面向用户的输出用 `say` / `info` / `warn` / `die`，不要直接 `echo` 混杂。

## 提交信息

`<type>: <一句话>`，正文写「为什么」而不只是「改了什么」。类型用 `feat` / `fix` / `docs` / `test` / `chore`。

```
feat: 新增 minimal-labwc 布局
fix: 重复安装不再覆盖用户原始配置的备份
docs: GOTCHAS 补 system-ui 无法重映射
```

## 许可注意

本项目是 **MIT + AGPL-3.0 混合**：

- `install.sh`、`bin/ff`、`scripts/font-setup.sh`、`tests/` 是 MIT；
- `config/fastfetch/` 与 `config/noctalia/` 下衍生自 shorin-arch-setup 的配置、以及 `scripts/fastfetch-random-wife.sh` 是 **AGPL-3.0-or-later**。

所以：

- 不要给 AGPL 文件加 MIT 头，也不要反向「洗白」出处；
- 新增的衍生配置要写进 `THIRD_PARTY.md`（上游 URL、许可、你改了哪几行）；
- 引入新依赖时同时更新 `THIRD_PARTY.md`。

## 不要提交的东西

`.testhome/`、`*.bak.*`、任何包含个人路径或主机名的调试产物（都已写进 `.gitignore`）。
提交前 `git status --short` 看一眼。

## 首次推送到 GitHub

```bash
# 已安装 gh CLI 的话（推荐）
gh repo create omarchy-config --public --source=. --remote=origin --push

# 没装 gh：网页上新建空仓库，然后
git remote add origin git@github.com:<你的用户名>/omarchy-config.git
git branch -M main
git push -u origin main
```

推完两件小事：

1. 徽章与 CHANGELOG 里的仓库链接已指向 `EzraX21/omarchy-config`，**fork 或改名后记得同步**；
2. 在仓库 Settings → Topics 里填：
   `omarchy` `archlinux` `fastfetch` `dotfiles` `hyprland` `maple-font`

## 发版流程

```bash
# 1) 改 VERSION 与 CHANGELOG（[未发布] → [x.y.z] + 日期）
# 2) 确认干净
git status --short && bash tests/smoke.sh
# 3) 提交、打标签、推送
git commit -am "chore(release): v0.2.0"
git tag -a v0.2.0 -m "v0.2.0"
git push && git push origin v0.2.0
```

`VERSION` 是脚本读取的单一事实来源（`./install.sh status` 会显示它），
所以改版本时**先改 `VERSION`**，再同步 `CHANGELOG.md` 和 `install.sh` 的提交标题。
