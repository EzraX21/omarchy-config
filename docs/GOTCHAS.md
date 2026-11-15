# 踩坑记录（都是实测出来的，不是推测）

本项目在 2026-11 的一次实际配置中诞生，下面每一条都对应一次真实的失败与验证。

## fastfetch

### 1. `logo.type` 是渲染协议，不是文件类型

```jsonc
"type": "file",                            // ❌ 把图片当文本读 → 屏幕上打印 "PNG" / "JFIF"
"type": "sixel",                           // ✅ 真图（foot / 支持 sixel 的终端）
"type": "kitty",                           // ✅ kitty / ghostty / wezterm
"type": "chafa",                           // ✅ 字符块，兼容性最好
"type": "auto",                            // ⚠️ 管道/非交互环境下不渲染
```

`file` 的语义是「按文本读取 logo 文件」，用 Omarchy 的 `about.txt` 那种 ASCII art 才对；给图片就会把二进制头当文字打出来。

### 2. `preserveAspectRatio` 只对 iTerm 生效

fastfetch 官方 schema 原文：

> `preserveAspectRatio` — Whether to preserve the aspect ratio of the logo. **Supported by iTerm image protocol only**

所以对 sixel 无效。真正决定比例的是**不要同时给 `width` 和 `height`**——
两个都给，图会被拉伸填满那个字格矩形；只给 `width`，高度跟随图片比例。

立绘多为竖图（实测缓存 1490×2048 ~ 2077×3035），塞进 `25×20` 这种横框必然变形。

### 3. `--pipe` 模式忽略所有 logo 尺寸参数

`--logo-width` / `--logo-height` / 配置里的 `width`/`height`，在 `fastfetch --pipe` 下全部无效（实测输出几何完全一样）。
所以**不能用管道输出验证比例**，只能在真实终端里看。

### 4. 配置查找顺序与 `HOME` 无关

`~/.config/fastfetch/config.jsonc` 覆盖 `/etc/fastfetch/config.jsonc`，但 fastfetch 通过 passwd 解析用户目录，
**用 `HOME=... fastfetch` 不会切换配置来源**。想测试另一份配置要用 `-c <file>` 或 `XDG_CONFIG_HOME`。

顺带：`~/.config/fastfetch/config.jsonc` 不存在时，`/etc` 那份（Omarchy 的 Hardware/Software 三栏框）会自动接管。

### 5. 配置文件是 JSONC

带 `//` 注释和尾逗号，fastfetch 能解析，但 `jq` / 严格 JSON 工具会报错。

### 6. `AGE` 模块在拿不到 btime 时会显示约 20000 天

上游配置用 `stat -c %W /` 取根分区创建时间，命令失败返回 `0` → `(now-0)/86400`。btrfs 上正常。

## 图源

### 7. 三个图源里两个在国内不可达

实测（Asia/Shanghai）：

| 图源 | 结果 |
|---|---|
| `api.waifu.im` | `HTTP 000` |
| `api.waifu.pics` | `HTTP 000` |
| `nekos.best` | `HTTP 200` |

上游脚本 `RANDOM % 3` 随机选一个，且**空缓存时只尝试一次** → 抽到不可达的源就整个失败（不下载、不生成 `current.jpg`，配置静默回退到内置 Arch logo）。本项目已改成「按序遍历直到成功」。

### 8. 下游脚本没有 shebang 且权限 644

上游 `fastfetch-random-wife.sh` 第一行是注释、权限 `rw-r--r--`，`cp` 之后直接 `./script` 会 permission denied。本项目已补 shebang + 755。

### 9. 上游脚本传 `--logo` 会绕过配置

`fastfetch --logo <file>` 会覆盖配置里的 `logo` 段，所以 `width` / `type` 都不再生效。本项目改用 `bin/ff`：只维护 `current.jpg`，然后 `exec fastfetch`，渲染完全交给配置。

## Omarchy / 字体

### 10. `omarchy font set` 会整份覆写 `~/.config/fontconfig/fonts.conf`

它只写一条 `monospace` 规则。所以：

- 想同时改 `sans-serif` / `serif` / `system-ui`，必须在它**之后**写完整版；
- 以后每次执行 `omarchy font set`，自定义规则都会丢，需要重跑 `./install.sh font`。

### 11. 切主题不会改字体

`/usr/share/omarchy/default/themed/*.tpl`（foot.ini.tpl、alacritty.toml.tpl、ghostty.conf.tpl…）里**没有任何 font 行**，
所以 `omarchy theme set` 不碰字体设置。

### 12. Maple 的 family 名要动态探测

包里是 `Maple Mono NF CN`，但硬编码有风险（官方可能改命名）。
本项目在装完后用 `fc-list : family | grep '^Maple Mono'` 取实际名字再写配置。

### 12b. `system-ui` 无法通过 fontconfig 重映射

`<test name="family"><string>system-ui</string></test>` 实测**不生效**：
加规则前后 `fc-match system-ui` 都是 `Liberation Sans`。
浏览器/Electron 的 `system-ui` 由自身映射，要改得改应用内设置（如 Chrome 的 `--font-render-hinting`、各 App 的 UI 字体选项）。
真正会生效的是 `sans-serif` / `serif` / `monospace` 三个泛用族。

### 13. 字体是等宽字体

Maple Mono 当 `sans-serif` 用在所有 GUI 上会得到明显的等宽观感。只想换终端和代码字体，
就不要第 4、5 步（`scripts/font-setup.sh --no-gtk`，并跳过 fonts.conf 写入）。

## 其他

### 14. 这个环境里 sudo 可能不可用

本项目的 `install.sh font` 需要 `omarchy pkg add`（即 sudo）。在受限沙箱里会因
`no new privileges` 标志失败，必须在用户自己的终端里执行。

### 15. `/tmp` 在多次工具调用之间不保证保留

调试时把临时文件放工作区而不是 `/tmp`，否则下一个命令就找不到。
