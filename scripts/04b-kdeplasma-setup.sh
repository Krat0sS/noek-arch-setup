#!/bin/bash

# ==============================================================================
# Noek Arch Setup - KDE Plasma Setup
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-utils.sh"

check_root
detect_target_user

section "Phase 4b" "KDE Plasma Setup"

SUDO_TEMP_FILE="/etc/sudoers.d/99_noek_installer_temp"
echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" >"$SUDO_TEMP_FILE"
chmod 440 "$SUDO_TEMP_FILE"

cleanup_sudo() { rm -f "$SUDO_TEMP_FILE"; }
trap cleanup_sudo EXIT INT TERM

log "Installing KDE Plasma..."
exe pacman -S --noconfirm --needed plasma-desktop sddm kwrite dolphin ark gwenview okular spectacle konsole

log "Checking for display manager conflicts..."
check_dm_conflict
log "Enabling SDDM..."
exe systemctl enable sddm

success "KDE Plasma installation completed."

# Create usage guide
as_user cat > "$HOME_DIR/必看-Kde使用方法.txt" << 'GUIDE'
═══════════════════════════════════════════
  KDE Plasma 快速使用指南
═══════════════════════════════════════════

【桌面操作】
  Super (Win键)         打开应用启动器
  Super + Tab           切换任务
  Super + 1~9           启动任务栏钉选应用
  Ctrl + F1~F4          切换虚拟桌面

【系统设置】
  systemsettings         打开系统设置
  设置 > 外观 > 全局主题  更换主题
  设置 > 工作区 > 快捷键  自定义快捷键

【常用软件】
  dolphin               文件管理器
  konsole               终端模拟器
  gwenview              图片查看器
  okular                文档查看器
  spectacle             截图工具

【更新系统】
  sudo pacman -Syu      更新全部软件包
  yay -S <包名>         安装AUR软件

【系统快照】
  sudo snapper -c root create  创建系统快照
  quickload                    恢复快照

═══════════════════════════════════════════
GUIDE
chown "$TARGET_USER:" "$HOME_DIR/必看-Kde使用方法.txt"
success "Usage guide created ~/必看-Kde使用方法.txt"

log "Module 04b-kdeplasma completed."
