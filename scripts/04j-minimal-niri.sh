#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Minimal Niri Setup
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-utils.sh"

check_root
detect_target_user

section "Phase 4j" "Minimal Niri Setup"

SUDO_TEMP_FILE="/etc/sudoers.d/99_noek_installer_temp"
echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" >"$SUDO_TEMP_FILE"
chmod 440 "$SUDO_TEMP_FILE"

cleanup_sudo() { rm -f "$SUDO_TEMP_FILE"; }
trap cleanup_sudo EXIT INT TERM

log "Installing Minimal Niri..."
exe pacman -S --noconfirm --needed niri xdg-desktop-portal-gnome

success "Minimal Niri installation completed."

# Create usage guide
as_user cat > "$HOME_DIR/必看-Minimalniri使用方法.txt" << 'GUIDE'
═══════════════════════════════════════════
  极简 Niri 快速使用指南
═══════════════════════════════════════════

【窗口操作】
  Super + H/J/K/L       窗口聚焦（左/下/上/右）
  Super + Shift + H/J/K/L  移动窗口
  Super + Enter          打开终端 (kitty)
  Super + Q              关闭窗口
  Super + R              调整窗口大小
  Super + Space          切换布局

【配置】
  配置文件: ~/.config/niri/config.kdl
  修改后自动生效，无需重启

【快捷启动】
  Super + D              启动 fuzzel 启动器

【自定义】
  niri 是滚动平铺窗口管理器
  编辑 config.kdl 绑定自己的快捷键
  参考: https://github.com/YaLTeR/niri

【更新系统】
  sudo pacman -Syu      更新全部软件包

═══════════════════════════════════════════
GUIDE
chown "$TARGET_USER:" "$HOME_DIR/必看-Minimalniri使用方法.txt"
success "Usage guide created ~/必看-Minimalniri使用方法.txt"

log "Module 04j-minimal-niri completed."
