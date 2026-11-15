# 更新日志

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

## [0.1.0] - 2026-11-15

首个可用版本。从「一堆散落的配置文件」整理成可安装、可回滚、可测试的项目。

### 新增

- **统一入口 `install.sh`**：子命令 `all` / `fastfetch` / `ff` / `font` / `status` / `uninstall`，
  支持 `--profile`、`--dry-run`、`--yes`、`--with-font`。
- **7 套 fastfetch 布局**：`omarchy`（系统三栏框）/ `shorin`（三段式树形）/ `plain`，
  以及上游四个变体 `gnome` / `kde` / `mint` / `mint-labwc`；另附 Noctalia 的 matugen 模板。
- **`bin/ff`**：每次运行换一张图，库存不足自动补货，按 `nekos.best` → `waifu.im` → `waifu.pics` 依次回退。
- **`scripts/font-setup.sh`**：Maple Mono NF 全局字体（终端 + fontconfig 泛用族 + GTK + VS Code）。
- **`scripts/fastfetch-random-wife.sh`**：上游脚本，修复图源不可达与缺 shebang 两个问题。
- **备份与回滚**：覆盖用户文件前备份，且只在首次接管时备份一次；`uninstall` 优先回滚备份。
- **`tests/smoke.sh`**：隔离 `HOME` 的端到端自测，25 项断言。
- **`tests/validate-configs.py`**：JSONC 容错解析器，逐个报告 `logo.type` 与模块数。
- **CI**：`.github/workflows/check.yml` 四个 job —— `bash -n`、`shellcheck -S warning`、配置校验、smoke。
- **文档**：`docs/GOTCHAS.md`（15 条实测踩坑）、`docs/SHORIN-ANALYSIS.md`（一键脚本审计）、
  `THIRD_PARTY.md`（来源与许可）、`CONTRIBUTING.md`、本更新日志。

### 修复

- `logo.type` 误用 `file` 导致把 PNG 当文本打印出 `PNG` 字样 —— 改用 `sixel`。
- 同时设置 `width` + `height` 导致图片变形 —— 只保留 `width`，高度随比例。
- 移除无效的 `preserveAspectRatio`（只对 iTerm 协议生效）与 `system-ui` 规则（实测无法经 fontconfig 重映射）。
- `set -e` 与裸 `[ ... ] && 命令` 混用导致 `status` 静默以 1 退出 —— 全部改 `if`。
- 重复安装会备份「自己的配置」，使 `uninstall` 回滚到自己的版本 —— 现在只在首次接管时备份。
- 上游脚本三个图源中两个在部分网络不可达，且空缓存只尝试一次 —— 改为按序遍历 + 重试 3 次。

### 已知限制

- 仅面向 Omarchy / Arch + Wayland；`font` 子命令依赖 `omarchy pkg add`（需要 sudo）。
- `shellcheck` job 未能在作者机器上本地验证（无本地 shellcheck），首次 CI 可能出现零星 warning。
- 截图为纯文本渲染（`--pipe`），图形 logo 无法在文本中体现。

[未发布]: https://github.com/OWNER/omarchy-config/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/OWNER/omarchy-config/releases/tag/v0.1.0
