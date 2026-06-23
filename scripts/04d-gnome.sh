#!/bin/bash

# ==============================================================================
# Noek Arch Setup - GNOME Setup
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-utils.sh"

check_root
detect_target_user

section "Phase 4d" "GNOME Setup"

SUDO_TEMP_FILE="/etc/sudoers.d/99_noek_installer_temp"
echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" >"$SUDO_TEMP_FILE"
chmod 440 "$SUDO_TEMP_FILE"

cleanup_sudo() { rm -f "$SUDO_TEMP_FILE"; }
trap cleanup_sudo EXIT INT TERM

log "Installing GNOME..."
exe pacman -S --noconfirm --needed gnome gnome-extra

log "Checking for display manager conflicts..."
check_dm_conflict
log "Enabling GDM..."
exe systemctl enable gdm

success "GNOME installation completed."

# Create usage guide
as_user cat > "$HOME_DIR/必看-Gnome使用方法.txt" << 'GUIDE'
═══════════════════════════════════════════
  GNOME 快速使用指南
═══════════════════════════════════════════

【桌面操作】
  Super (Win键)         打开活动概览
  Super + Tab           切换应用
  Ctrl + Alt + ↑/↓      切换工作区
  Super + L             锁屏

【系统设置】
  gnome-control-center   打开系统设置
  gnome-tweaks           高级设置（需安装）
  设置 > 外观            更换主题/壁纸

【常用软件】
  nautilus              文件管理器
  gnome-terminal        终端模拟器
  eog                   图片查看器
  evince                文档查看器
  gnome-screenshot      截图工具

【更新系统】
  sudo pacman -Syu      更新全部软件包
  yay -S <包名>         安装AUR软件

═══════════════════════════════════════════
GUIDE
chown "$TARGET_USER:" "$HOME_DIR/必看-Gnome使用方法.txt"
success "Usage guide created ~/必看-Gnome使用方法.txt"

log "Module 04d-gnome completed."
