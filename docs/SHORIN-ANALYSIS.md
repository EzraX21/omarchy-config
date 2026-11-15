# `curl -L shorin.xyz/archsetup | bash` 全面分析报告

> 分析对象：`shorin.xyz/archsetup` → 302 → `https://repo.shorin.xyz/archlinux/strap.sh`（6833 字节，2026-07-31 修改）
> 实际安装逻辑：仓库 `https://github.com/SHORiN-KiWATA/shorin-arch-setup`（`main` 分支 HEAD，未固定 commit）
> 仓库体量：约 7000 行 shell + 6 套 dotfiles + 14MB GRUB 主题 + 49MB Windows 字体

---

## 0. 一句话结论

这是一个**面向全新 Arch 安装**的「桌面环境一键配置器」，不是给已装好桌面的机器用的工具。
它在 root 权限下改写 `pacman.conf`、`sudoers`、`vconsole.conf`、`faillock.conf`、GRUB，引入两个第三方软件源，用作者自己打包的 `fcitx5` 替换官方包，并把整套 `~/.config` **无备份覆盖**。

对你这台 **Omarchy（Hyprland + Limine + sddm）** 机器：**不建议直接运行**。它会覆盖 `~/.config/hypr` 与 `~/.config/omarchy`，`pacman -Rdd` 掉你的 `fcitx5`，永久写入手感极差的免密 sudo 规则；且因为用 Limine 而非 GRUB，脚本中所有 GRUB/主题/双启动环节会静默失效或报错。

---

## 1. 执行链路

```
curl shorin.xyz/archsetup
  └─ 302 → repo.shorin.xyz/archlinux/strap.sh        # 引导器，6833 字节
       ├─ 检验：仅 Linux、仅 x86_64、拒绝 Live 环境（/run/archiso 或 / 是 overlay）
       ├─ 缺则 pacman -S curl tar git pv
       ├─ 选镜像：GitHub / Gitee / Codeberg（时区 Asia/Shanghai 或 ipinfo 返回 CN 则默认 Gitee）
       ├─ 下载 <branch=main>.tar.gz → /tmp/shorin-arch-setup（pv 进度条，3 次重试，chmod 755）
       └─ run_as_root bash install.sh < /dev/tty    # 有 sudo 用 sudo，无 sudo 要求直接 root
            └─ install.sh 逐模块 bash 执行
```

**两处需要注意：**

- 拉的是 `refs/heads/main` 的**实时 HEAD**，不是 tag/commit → 每次执行内容可能不同，且**无任何校验和/签名**（只有 `[shorin-arch]` 源的 GPG key 在 01b 里被验指纹）。
- `strap.sh` 里 `EXPECTED_SIZE="80M"` 只是 pv 的假进度总量，解包后还要再跑第三方安装器，不做完整性校验。

---

## 2. `install.sh` 主控做了什么

| 步骤 | 行为 |
|---|---|
| 前置 | source `00-utils.sh`，该文件**被 source 时即执行 `check_root`** → 全程 root |
| 菜单 1 | fzf 选桌面（No Desktop / Surprise Me / KDE（推荐）/ GNOME / Shorin DMS Niri（推荐）/ Shorin Niri / Minimal Niri / Minimal Labwc / Quickshell: End4、DMS、Caelestia、iNiR） |
| 菜单 2 | fzf 多选可选模块，**默认全选**：shorin-arch 源、IWD 后端、Windows 双启动、硬件驱动、GRUB 主题、常用应用 |
| 断点 | `.install_progress` 记录已完成模块，重跑则跳过；`/tmp/shorin_install_user` 缓存目标用户 |
| 镜像 | reflector `--protocol https -a 12 -f 10 --sort rate --save /etc/pacman.d/mirrorlist`；上海时区默认**不**刷新（60s 超时默认 No），其他时区默认 Yes |
| 升级 | `pacman -Sy archlinux-keyring` → `pacman -Su` → `pacman -Syyu`（中途全量升级） |
| 模块 | 按 `sort -u` 顺序逐个 `bash` 执行，失败即 `exit 1` |
| 收尾 | `pacman -Sc`、删中间快照（保留 "Before Desktop Environments"、"Before Niri Setup"）、清 `/var/cache/pacman/pkg/download-*`、`grub-mkconfig`、日志存 `~/Documents/log-shorin-arch-setup.txt`、**10 秒倒计时自动 reboot** |

必装模块顺序：`00-btrfs-init` → `01a-base` → `02a-user` → `02b-musthave` → `03c-snapshot-before-desktop` → `05-verify-desktop`，再追加所选桌面模块。

---

## 3. 必装模块逐项

### 3.1 `00-btrfs-init.sh` — 快照安全网

- **仅 btrfs**，否则整段跳过（ext4 上等于没有回滚能力）。
- `ensure_grub_dir_link`：GRUB 装在 ESP（`--boot-directory` 布局）时建 `/boot/grub → $ESP/grub` 软链。
- 装 `snapper`，建 `root` / `home` 两个配置：
  - `ALLOW_GROUPS=wheel`、`TIMELINE_CREATE=yes`、每小时留 3 份、`NUMBER_LIMIT=10`、`NUMBER_LIMIT_IMPORTANT=5`、日/周/月/年全为 0
  - 启用 `snapper-cleanup.timer`、`snapper-timeline.timer`
  - 建配置前若存在 `/.snapshots` 会 `umount` + `rm -rf`
- GRUB：`GRUB_DEFAULT=saved`、`GRUB_SAVEDEFAULT=true`（检测到 UKI 时跳过），`grub-editenv - set ok=1` 预留 btrfs env block
- 建快照 `Before Shorin Setup`
- 部署回滚命令 `/usr/local/bin/shorin-undochange`（回滚到 Before Shorin Setup）、`shorin-de-undochange`（回滚到 Before Desktop Environments）——底层是 `btrfs-assistant -r`，**子卷级回滚，不可逆**

### 3.2 `01a-base.sh` — 基础系统

| 项目 | 内容 |
|---|---|
| 编辑器 | 探测 nvim > nano > vim，都没有则装 `gvim`；写 `EDITOR=` 到 `/etc/environment` |
| 32 位库 | 取消 `/etc/pacman.conf` 的 `[multilib]` 注释 + `pacman -Syu` |
| 字体 | `ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd otf-font-awesome`、`terminus-font` |
| TTY 字体 | `setfont ter-v28n` + `/etc/vconsole.conf` 写 `FONT=ter-v28n` + 重启 `systemd-vconsole-setup`（**28px 超大字，TTY 观感会大变**） |
| Locale | 启用 `en_US.UTF-8` + `zh_CN.UTF-8`，`locale-gen` |
| 源 | 新增 `[archlinuxcn]`（上海时区用 USTC/TUNA/HIT/华为云；否则先 repo.archlinuxcn.org），装 `archlinuxcn-keyring` |
| AUR | `base-devel yay paru` |

### 3.3 `02a-user.sh` — 账户与权限

- 交互选用户或新建（`useradd -m -G wheel -s /bin/bash`，`passwd` 交互设密码）
- `/etc/sudoers` 放开 `%wheel ALL=(ALL:ALL) ALL`
- **写 `/etc/sudoers.d/10-shorin-nopasswd`（永久）**：
  ```
  %wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman, /usr/bin/systemctl, /usr/bin/sudoedit
  ```
- **`/etc/security/faillock.conf` → `deny = 0`**（关闭密码错误锁定）
- `xdg-user-dirs`、`~/.local/bin`、`/etc/profile.d/user_local_bin.sh`

### 3.4 `02b-musthave.sh` — 必备软件

- 临时写 `/etc/sudoers.d/99_shorin_installer_temp`（`NOPASSWD: ALL`，440，trap 清理）
- btrfs 时：`btrfs-assistant xorg-xhost less`；有 GRUB 时再装 `grub-btrfs inotify-tools` + `grub-btrfsd`（**快照进启动菜单**）
- 音频：`sof-firmware alsa-ucm-conf alsa-firmware`；PipeWire 全套 `pipewire lib32-pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack rtkit` + `systemctl --global enable`
- **输入法（重点）**：`pacman -Rdd fcitx5`（强制卸载，不查依赖）→ `yay fcitx5-shorin-patched-git`（作者魔改构建）→ `fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-rime rime-ice-git`
- 蓝牙：USB/PCI/rfkill 探测到才装 `bluez bluetui` 并启用
- `power-profiles-daemon`、`fastfetch gdu btop cmatrix lolcat sl`（AMD CPU 加 `rocm-smi-lib`）
- `pacman.conf` 打开 `ILoveCandy`
- `flatpak` + flathub，中国环境让选 SJTU/USTC/官方镜像

### 3.5 可选模块

| 脚本 | 行为 |
|---|---|
| `01b-shorin-arch.sh` | 加 `[shorin-arch]` 源 = `https://repo.shorin.xyz/archlinux/$arch`；用仓库内自带公钥（指纹硬编码校验 `8ED9ABE6…C13B4BA8`）导入并 `lsign` |
| `01c-nm-backend.sh` | 装 `iwd impala`、启用 iwd、写 `/etc/NetworkManager/conf.d/iwd.conf`（`wifi.backend=iwd`），**并 `rm -rfv /etc/NetworkManager/system-connections/*`** |
| `02c-dualboot-fix.sh` | `os-prober exfatprogs fuse3`；检出 Windows 才设 `GRUB_DISABLE_OS_PROBER=false` + 重生 grub |
| `03b-gpu-driver.sh` | AUR `chwd-arch-git` → `chwd -a` 自动装显卡驱动（CachyOS 的工具） |
| `07-grub-theme.sh` | 内核参数：删 `quiet`/`splash`，加 `loglevel=5 nowatchdog`，Intel 黑名单 `iTCO_wdt` / AMD 黑名单 `sp5100_tco`；把 14MB 主题拷到 `/usr/share/grub/themes`；菜单选主题（本地 1CyberGRUB-2077 等 / Minegrub 在线 clone 后跑它的 `install.sh` / 不要）；写 `GRUB_THEME`；**`cp 40_custom 99_custom` 并追加 Reboot/Shutdown 两个启动项**（重复运行会重复追加） |
| `99-apps.sh` | 见第 5 节 |

### 3.6 `05-verify-desktop.sh` — 对账

用 `pacman -T` 核对模块写入 `/tmp/shorin_install_verify.list` 的包是否齐全，缺一个就 `exit 1`；再检查 dotfiles 关键路径是否存在。注意 **04e / 04f / 04g 三个模块不写该清单**，它们的包完整性无法验证。

---

## 4. 12 种桌面方案

全部模块的共同前提：root 运行、写临时 `NOPASSWD: ALL` sudoers、`detect_target_user`、`check_dm_conflict`（探测到 lemurs/ly/gdm/lightdm/lxdm/plasma-login-manager/sddm/greetd 任一已装即 `SKIP_DM=true`，不再装 DM）。

| 方案 | 菜单值 | WM / Shell | DM | 主要包 | dotfiles 来源 |
|---|---|---|---|---|---|
| KDE Plasma | `kde` | Plasma 6 | plasmalogin | `plasma-meta konsole dolphin kate firefox qt6-multimedia-ffmpeg pipewire-jack plasma-login-manager flatpak flatpak-kcm` + kde-applist | 仓库 `kde-dotfiles`（先 tar 备份 `~/.config`） |
| GNOME | `gnome` | GNOME | gdm | `gnome-desktop gnome-backgrounds gnome-tweaks gdm ghostty celluloid loupe gnome-control-center bazaar file-roller nautilus-python qt5/6-wayland firefox nm-connection-editor dnsmasq ttf-jetbrains-mono-nerd miyu` + `gnome-extensions-cli` 装 16 个扩展 | 仓库 `gnome-dotfiles`（无备份） |
| Shorin DMS Niri | `shorindmsgit` | niri + DMS | ly | `quickshell-git shorin-dux-niri-git dux-greeter-bin vulkan-headers xdg-desktop-portal-gnome` | `shorindms init` 生成 |
| DMS (上游) | `dms` | niri + DMS | ly | `curl install.danklinux.com` 黑盒执行 | 上游 + `quickshell-dotfiles`（仅 fcitx5） |
| Shorin Niri | `shorinniri` | niri | ly | AUR `shorin-niri-git` | `shorinniri init` 生成 |
| Minimal Niri | `minimalniri` | niri + waybar | ly | `niri xwayland-satellite fuzzel waybar mako polkit-gnome` + thunar 全家桶 + `hyprlock breeze-cursors nwg-look adw-gtk-theme satty cliphist` | 仓库 `minimal-niri-dotfiles` |
| Minimal Labwc | `minimallabwc` | labwc + waybar | ly | `labwc xdg-desktop-portal-wlr fuzzel waybar mako swaybg waypaper wlr-randr` | 仓库 `minimal-labwc-dotfiles` |
| Shorin Noctalia | `shorinnocniri`（菜单被注释） | niri + noctalia-shell | ly | `noctalia-shell niri niri-sidebar-git satty mpv matugen adw-gtk-theme python-pywalfox firefox` | 仓库 `noctalia-dotfiles` |
| Hyprniri | `hyprniri`（无菜单项） | Hyprland + dux-shell | ly | `quickshell-git dux-shell matugen cava kimageformats` …（会先 `paru -Rns` 卸载 10 个 `hypr*-git`） | 外部仓库 `shorin-dms-hyprniri.git` 覆盖 `$HOME` |
| End4 / illogical-impulse | `end4` | quickshell | ly | `curl ii.clsty.link/get` 黑盒执行 | 上游 |
| Caelestia | `caelestia` | quickshell | ly | `yay -Syu fish` + `git clone caelestia-dots` → `install.fish --noconfirm`（会 `rm -rf ~/.local/share/caelestia`、`chown -R ~/.config`） | 上游 symlink |
| iNiR | `inir` | niri + quickshell | ly | `git clone snowarch/inir` → `setup install -y` 黑盒 | 上游 + 仓库 fcitx5（会盖掉上游写的） |
| ambxst | 未接线 | niri + noctalia-shell | getty autologin | `niri noctalia-shell matugen kitty firefox polkit-gnome` | 无 |

**配置落地方式**：除 KDE 会先打 tar 备份外，其余全部是 `cp -rf <dotfiles>/. → $HOME/` 或 `force_copy`（先尝试删同名再拷，对目录无效）→ **纯覆盖、零备份**。

几个代表方案的配置要点：

- **KDE**：`kdeglobals` 自定义紫色配色 + Adwaita Sans 11；`plasmarc` breeze-dark；面板 44px、透明度 2；plasmoids 含 kickoff/icontasks/weather/kscreen/apdatifier 等；`kwinrc` 开启 wobbly windows、translucency、圆角 8、Xwayland scale 1.6、输入法 `fcitx5-wayland-launcher`；`konsolerc` = fish + Catppuccin-Frappe + JetBrains Maple Mono 15；`gtk-3/4` 仅设 `gtk-im-module=fcitx`
- **GNOME**：改 `/var/lib/AccountsService/users/<u>` 语言为 `zh_CN.UTF-8`；写 `/etc/firefox/policies/policies.json` 强制装 gnome-shell-integration 扩展；gsettings 重绑 `Super+q/h/f/b/t/e`、截图三键、6 条自定义快捷键；启用 16 个扩展（含 blur-my-shell、tilingshell、clipboard-indicator 等）
- **niri 系**：`~/.config/niri/config.kdl` 注入 `environment{}`（fcitx 4 变量 + `LANG=zh_CN.UTF-8` + `GSK_RENDERER=gl` + `EDITOR=vim`）、`spawn-at-startup` polkit-gnome / portal-gnome / mako / waybar / `xhost +si:localuser:root`；`niri-portals.conf` 设 `ScreenCast=gnome`、`Secret=gnome-keyring`
- **共通**：所有方案都埋 `xhost +si:localuser:root`（为截图工具放行 root）

---

## 5. 应用清单（`99-apps.sh`）

fzf 可勾选，60 秒超时 = **全选**。repo 包批量 `yay -Syu`，AUR 逐个装（1 次重试），flatpak 单独装。失败清单写到 `~/Documents/安装失败的软件.txt`。

- `common-applist.txt`：`gdu baobab mission-center gparted gnome-font-viewer fcitx5-mozc rime-wubi firefox transmission-gtk localsend nm-connection-editor gnome-calendar gnome-clocks lutris steam mangohud lact virt-manager lazyvim neovim mpv obs-studio upscaler yazi flatseal pavucontrol mousepad flclash easyeffects foliate`；AUR：`protonplus linuxqq linuxqq-wayland-fix wechat-appimage lsfg-vk-bin mangojuice visual-studio-code-bin pins-git gearlever typora-free`
- `kde-common-applist.txt`：`mission-center btop ksystemlog pacman-contrib lact gwenview upscaler kcalc baobab gnome-disk-utility dosfstools exfatprogs f2fs-tools udftools xfsprogs haruna lutris steam obs-studio gearlever easyeffects foliate`；AUR：`linuxqq wechat-appimage video-downloader typora-free`
- `kde-applist.txt`（KDE 额外）：`fish starship eza zoxide fastfetch imagemagick jq timg bat yazi ark kate plasma-login-manager ttf-jetbrains-mono-nerd`；AUR：`kwin-effects-geometry-change shorin-contrib-git rime-wanxiang-gram-zh-hans shorin-proton-wrapper-git ttf-jetbrains-maple-mono-nf-xx-xx miyu`

**装后自动配置**（检测到对应包才跑）：

- virt-manager → `qemu-full virt-manager swtpm dnsmasq virt-viewer`、加 `libvirt kvm input` 组、`libvirtd`、gsettings 设默认连接 `qemu:///system`、启动 default NAT 网络
- wine → `wine-gecko wine-mono`、`wineboot -u`、把 `resources/windows-sim-fonts`（simsun/simhei/simfang/simkai，49MB）拷进 `drive_c/windows/Fonts`
- lutris → 一堆 32 位游戏依赖
- lazyvim → clone LazyVim starter 到 `~/.config/nvim`（已有则改名备份），追加 fcitx5 输入法自动切中/英的 autocommand
- 隐藏 36 个 `.desktop`（vim、mpv、Nautilus、waypaper…）到 `~/.local/share/applications` 并加 `NoDisplay=true`
- 部署 `~/.config/mozilla`（来自 `resources/firefox`）与 `~/.config/MangoHud/MangoHud.conf`

---

## 6. 对系统的全部改动（速查表）

| 路径 | 改动 |
|---|---|
| `/etc/pacman.conf` | 加 `[multilib]`、`[archlinuxcn]`、`[shorin-arch]`、`ILoveCandy` |
| `/etc/pacman.d/mirrorlist` | reflector 重写 |
| `/etc/environment` | `EDITOR=` |
| `/etc/vconsole.conf` | `FONT=ter-v28n` |
| `/etc/locale.gen` | 启用 en_US / zh_CN UTF-8 |
| `/etc/sudoers` | 放开 `%wheel` |
| `/etc/sudoers.d/10-shorin-nopasswd` | **永久** `NOPASSWD: pacman, systemctl, sudoedit` |
| `/etc/sudoers.d/99_shorin_installer_{temp,apps}` | 临时 `NOPASSWD: ALL`（正常路径会删；SIGKILL 残留） |
| `/etc/security/faillock.conf` | `deny = 0` |
| `/etc/profile.d/user_local_bin.sh` | 新增 |
| `/etc/NetworkManager/conf.d/iwd.conf` | 新增（可选模块） |
| `/etc/NetworkManager/system-connections/*` | **删除全部已保存 WiFi** |
| `/etc/default/grub` | `GRUB_DEFAULT=saved`、`GRUB_SAVEDEFAULT=true`、删 `quiet splash`、加 `loglevel=5 nowatchdog`、`GRUB_THEME`、`GRUB_DISABLE_OS_PROBER=false`、`GRUB_GFXMODE` |
| `/etc/grub.d/99_custom` | 新增 Reboot / Shutdown 菜单项 |
| `/usr/share/grub/themes/*` | 14MB 主题 |
| `/usr/local/bin/shorin-undochange`、`shorin-de-undochange` | 新增 |
| `/usr/local/bin/xterm` | → `kitty` 软链（04i/04k） |
| `/etc/firefox/policies/policies.json` | 强制装扩展（04d/04i/04k） |
| `/var/lib/AccountsService/users/<u>` | 语言改 zh_CN（04d） |
| `/etc/systemd/system/getty@tty1.service.d/autologin.conf` | 04f 写入；04c/04j/04k/04m 删除 |
| 启用的服务 | `snapper-cleanup.timer`、`snapper-timeline.timer`、`bluetooth`、`power-profiles-daemon`、`grub-btrfsd`、`iwd`、`gdm`/`plasmalogin`/`ly@tty1`、`libvirtd`、`pipewire*`（`--global`） |
| 清理 | `pacman -Sc`、删中间快照、删 `/var/cache/pacman/pkg/download-*` |

---

## 7. dotfiles 内容（覆盖到 `~`）

| 目录 | 文件数 | 内容 |
|---|---|---|
| `gnome-dotfiles` | 30 | fastfetch、fcitx5、fish（starship/zoxide/yazi/eza/bat 别名）、fontconfig、ghostty（Matugen 主题、0.88 透明、JetBrains Maple Mono 15）、gtk-3/4、mpv、qq-flags（`--ozone-platform=wayland`）、starship.toml、`.vimrc`、rime custom |
| `kde-dotfiles` | 114 | 上述 + konsole profile、plasma 全套（plasmarc/plasmashellrc/appletsrc/kwinrc/kdeglobals/kglobalshortcutsrc 等）、plasmoids 树 |
| `minimal-niri-dotfiles` | 50 | niri（config/binds/rule/layout + scripts）、waybar、mako、fuzzel、foot、satty、Thunar、xfce4、niri-portals.conf |
| `minimal-labwc-dotfiles` | 45 | labwc（rc.xml/menu.xml/autostart/environment/hyprlock）、waybar、mako、fuzzel、foot、satty |
| `noctalia-dotfiles` | 131 | niri（9 个 kdl 分片）、noctalia（settings/colors/plugins + matugen 模板）、kitty、fuzzel 主题、icons、nwg-look |
| `quickshell-dotfiles` | 10 | 仅 fcitx5 + rime（供 DMS/end4/iNiR 用） |

其中 **fastfetch** 有 4 份静态配置（GNOME/KDE/Minimal×2，仅 logo 协议与配色不同）+ 1 份 Noctalia matugen 模板（动态取色）。

---

## 8. 风险分级

### 🔴 高危（会实质性削弱系统安全或破坏数据）

1. **永久免密 sudo**：`%wheel NOPASSWD: pacman, systemctl, sudoedit`。`sudoedit` 可编辑任意 root 文件 → 任何 wheel 成员一条命令提权到 root。这不是临时配置，写进 `/etc/sudoers.d/` 后一直生效。
2. **`faillock deny=0`**：关闭密码错误锁定，配合上一条 = 无限次爆破 + 提权面。
3. **删除已保存 WiFi**：选 IWD 模块就 `rm -rfv /etc/NetworkManager/system-connections/*`，所有 WiFi 密码消失。
4. **`~/.config` 无备份覆盖**：只有 KDE 会先 tar 备份；其余方案直接覆盖。GNOME/Hyprniri 还会 `chown -R` 整个 `~/.config` 和 `~/.local`。
5. **`pacman -Rdd fcitx5` + 换作者构建**：强拆官方包（不检查依赖），装 `fcitx5-shorin-patched-git`；已有 fcitx5 配置（如 rime）可能被破坏。
6. **04i 会 `paru -Rns` 卸载 10 个 `hypr*-git` 包** → 可能级联删掉依赖它们的其它包。

### 🟠 中危（供应链与不可预期行为）

7. **两个第三方源**：`archlinuxcn`（社区，较常见）+ `[shorin-arch]`（作者私有）。后者提供 `yay`、`paru`、`visual-studio-code-bin`、`linuxqq`、`fcitx5-shorin-patched-git`、`niri-shorin-fork-git`、`quickshell-git`、`nvidia-470xx/580xx`、`proton-ge-linuwux` 等——**构建权在第三方手里**。
8. **运行期执行 4 个未固定的远端安装器**：`install.danklinux.com`（DMS）、`ii.clsty.link/get`（end4）、`caelestia-dots` 的 `install.fish`、`snowarch/inir` 的 `setup install -y`，外加 Minegrub 的 `install.sh`。全部无版本 pin、无校验和。
9. **拉 `main` 分支 HEAD**：每次内容可能不同，且无签名验证。
10. **中途 `pacman -Syyu` 全量升级** + 结束自动重启（10 秒倒计时）。

### 🟡 低危 / 体验问题

11. TTY 字体变 28px 大字；GRUB 去掉 `quiet splash`（开机满屏日志）。
12. 自动改 `GRUB_DEFAULT=saved`（记住上次启动项，双系统下容易误进 Windows）。
13. 结尾 `pacman -Sc` 清缓存、删中间快照（保留两个标记点）。
14. 隐藏 36 个 `.desktop`（含 Nautilus、mpv），可能不符合预期。
15. 多处实现缺陷：`04m` 的 `$DMS_NIRI_CONFIG_FILE` 未定义导致屏幕共享自启行写不进去；`04k` dotfiles 里文件拼写 `xdg-terminials.list` 与脚本写的 `xdg-terminals.list` 不一致；`03c` 变量名拼错（`HYRPLAND_`）导致 Hyprland autostart 服务从不清除；`04f` 未接入菜单且与 `04k` 重复；`07` 重复运行会重复追加 `99_custom`；`force_copy` 的「先删目录」逻辑对目录无效。

---

## 9. 对当前这台机器（Omarchy）的具体影响

环境实测：`ID=omarchy`（Arch 系）、`/` = **btrfs**、`/boot` = **vfat**、**UEFI**、启动器 **Limine**（无 `grub-mkconfig`）、已装 `hyprland`、`sddm`、`quickshell`、`fcitx5`(+chewing/chinese-addons/hangul/mozc/rime/qt/gtk)、`snapper`（已有 `root` 配置）、`yay`；`~/.config` 已有 **6.8 GB**。

逐条影响：

- **GRUB 相关全部失效**：`07-grub-theme.sh` 检测不到 `grub-mkconfig` 直接退出；`02c` 同理；`00-btrfs-init` 的 GRUB 段跳过；`install.sh` 收尾的 `grub-mkconfig` 报 FAIL（`exe` 不中止，所以不会整体失败）。→ 无害但报错噪音。
- **不会装新 DM**：`check_dm_conflict` 探测到 `sddm` → `SKIP_DM=true`，不会启用 `ly`/`gdm`/`plasmalogin`，也不会动你的 sddm 配置。
- **会覆盖 `~/.config/hypr` 与 `~/.config/omarchy`**：任何选了带 dotfiles 的方案，`cp -rf` 都会写进这两个目录（Omarchy 的键位、主题、bar 全部失效）。这是最实际的数据损失。
- **会 `pacman -Rdd fcitx5`**：你现有的 `fcitx5-*` 全家（rime/mozc/chewing/hangul）依赖被强拆，替换成作者构建版本 + `rime-ice`。
- **snapper**：已有 `root` 配置 → 不会重建/改限额，只会多一个 `Before Shorin Setup` 快照（这点倒是好事）。
- **Limine 用户拿不到「快照进启动菜单」**：`grub-btrfs` 只服务 GRUB。
- **`02a` 会改 sudoers 与 faillock**：这是全局性的，影响所有 wheel 用户。
- **`01a` 会改 TTY 字体、开 multilib、加两个源**：可逆，但要手动回退。
- **`04i`（hyprniri）**：你装的是 `hyprland`（非 `-git`），不会被 `-Rns` 直接命中，但它会装 `quickshell-git`/`dux-shell` 并覆盖 `$HOME`，与 Omarchy 的 Hyprland 生态高度冲突。

**结论**：这是给「裸 Arch 装完 base 后一键搭桌面」的脚本。在你这台已经调好的 Omarchy 上运行，收益（换一套桌面）远小于损失（配置被覆盖、输入法被换、权限被削弱、WiFi 可能要重连）。

---

## 10. 建议

**如果只是想用它的某个方案**：
1. 在 **虚拟机**（或另一块盘）里跑一次，看它的实际效果；
2. 或者**只借配置不跑脚本**：直接挑 `kde-dotfiles` / `noctalia-dotfiles` 等目录里的文件，手动拷你想要的那份（Noctalia 的 matugen 模板 + `user-templates.toml` 是最值得单独拿走的）；
3. 想要 `shorin` 生态的 CLI（`shorin-contrib-git`、`miyu`、`linuxqq-wayland-fix`）就单独装这几个 AUR 包，别整包跑。

**如果确实要在现有系统上跑**，至少先做：
```bash
# 1) 备份（脚本不会替你备份）
tar czf ~/backup-config-$(date +%s).tar.gz ~/.config ~/.local/share/applications
nmcli connection export ...        # 或 cp -a /etc/NetworkManager/system-connections 需 root
sudo cp -a /etc/sudoers /etc/sudoers.d /root/sudoers.bak/
# 2) 先建手动快照
sudo snapper -c root create --description "before-shorin-manual"
# 3) 跑完后立刻检查并回退这些
sudo cat /etc/sudoers.d/10-shorin-nopasswd     # 建议直接删掉
sudo grep deny /etc/security/faillock.conf     # 改回 deny = 3
```

**不建议**在已投入使用的桌面机上直接 `curl | bash`：它是 root 级、无签名校验、无备份、且明确以“覆盖现有配置”为前提设计的。
