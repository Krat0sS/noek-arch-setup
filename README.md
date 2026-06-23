# noek-arch-setup

Arch Linux 一键安装脚本，支持自动检测硬件、安装桌面环境、配置系统。

## Features

- 自动检测显卡并安装驱动
- 支持多种桌面环境（KDE Plasma, Niri+DMS, GNOME, Minimal Niri）
- 自动配置音频（PipeWire）
- 自动配置输入法（Fcitx5 + Rime）
- Btrfs 快照自动配置（Snapper）
- GRUB 主题和内核参数优化
- 常用软件一键安装（FZF 选择）
- 网络自动优化（GitHub → Gitee 镜像回退）
- 中文界面，小白友好

## Quick Start

### 新安装 Arch Linux 后：

```bash
# 国际用户（GitHub）
bash <(curl -sL https://raw.githubusercontent.com/Krat0sS/noek-arch-setup/main/strap.sh)

# 中国用户（Gitee）
bash <(curl -sL https://gitee.com/noek-linux/noek-arch-setup/raw/main/strap.sh)
```

### 或者克隆仓库后运行：

```bash
git clone https://github.com/Krat0sS/noek-arch-setup.git
cd noek-arch-setup
sudo bash install.sh
```

## Agent 一键安装 (AI Friendly)

**这是本项目的核心特色** - 支持环境变量驱动，AI Agent 可以一键完成安装：

```bash
# Agent 安装 Niri + DMS 桌面（推荐）
DESKTOP=niridms UNATTENDED=1 USER_PASSWORD=你的密码 bash install.sh

# Agent 安装 KDE 桌面
DESKTOP=kde MODULES="gpu,apps" UNATTENDED=1 USER_PASSWORD=你的密码 bash install.sh

# Agent 只装基础系统（不装桌面）
DESKTOP=none UNATTENDED=1 bash install.sh
```

### 环境变量说明

| 变量 | 可选值 | 说明 |
|------|--------|------|
| `DESKTOP` | `kde` `niridms` `minimalniri` `gnome` `none` `random` | 桌面环境 |
| `MODULES` | `iwd,gpu,dualboot,grub,apps` | 逗号分隔可选模块 |
| `UNATTENDED` | `0` `1` | 无人值守模式，跳过所有交互 |
| `USERNAME` | 用户名 | 目标用户 |
| `USER_PASSWORD` | 密码 | 目标用户密码 |
| `MIRROR` | `auto` `cn` `global` | 镜像策略 |
| `CN_MIRROR` | `0` `1` | 强制中国镜像 |

## Why noek-arch-setup?

| 对比项 | 传统方式 | noek-arch-setup |
|--------|----------|-----------------|
| 安装桌面 | 手动选包、手动配置 | 一键选择，自动安装 |
| 显卡驱动 | 手动查型号、手动装 | 自动检测，自动安装 |
| 中文输入法 | 手动装 fcitx5 | 自动配置 |
| 网络问题 | 自己找镜像 | 自动检测，自动切换 |
| AI Agent | 不支持 | **完全支持，一行命令搞定** |
| 配置文件 | 手动拷贝 | 自动同步 dotfiles |

## Optional Modules

- IWD WiFi Backend (WiFi后端优化)
- Windows Dualboot Setup (双系统)
- GPU Drivers (自动显卡驱动)
- GRUB Theme (开机美化)
- Common Apps (常用软件)

## Project Structure

```
noek-arch-setup/
├── strap.sh              # 引导脚本（一键拉取）
├── install.sh            # 主安装脚本
├── scripts/
│   ├── 00-utils.sh       # 工具函数
│   ├── 00-btrfs-init.sh  # Btrfs快照
│   ├── 01a-base.sh       # 基础系统
│   ├── 02-musthave.sh    # 必装软件
│   ├── 03a-user.sh       # 用户账户
│   ├── 03b-gpu-driver.sh # 显卡驱动
│   ├── 04-niri-dms-setup.sh # Niri+DMS
│   ├── 05-verify-desktop.sh # 安装验证
│   ├── 07-grub-theme.sh  # GRUB主题
│   └── 99-apps.sh        # 常用软件
├── dotfiles/             # 通用配置
├── grub-themes/          # GRUB主题
├── resources/            # 资源文件
└── de-undochange.sh      # 卸载脚本
```

## License

```
MIT License

Copyright (c) 2026 Noek

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Credits

本项目参考了以下项目：

- [shorin-arch-setup](https://github.com/SHORiN-KiWATA/shorin-arch-setup) - Shorin Arch Linux 安装脚本
- [aui](https://github.com/helmuthdu/aui) - Arch Linux 安装工具
