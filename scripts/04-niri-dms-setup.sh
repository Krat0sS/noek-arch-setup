#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Niri + DMS Setup
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/00-utils.sh"

check_root
detect_target_user

section "Phase 4" "Niri + DMS Setup"

SUDO_TEMP_FILE="/etc/sudoers.d/99_noek_installer_temp"
echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" >"$SUDO_TEMP_FILE"
chmod 440 "$SUDO_TEMP_FILE"

cleanup_sudo() { rm -f "$SUDO_TEMP_FILE"; }
trap cleanup_sudo EXIT INT TERM

critical_failure_handler() {
    local failed_reason="$1"
    trap - ERR
    echo -e "\n\033[0;31m[CRITICAL FAILURE] $failed_reason\033[0m\n"
    exit 1
}
trap 'critical_failure_handler "Script Error at Line $LINENO"' ERR

# Step 1: Install DMS Core Package
section "Step 1/4" "Install DMS Core Package"

AUR_HELPER="yay"
CORE_PKG="shorin-dms-niri-git"
PRE_PKGS="xdg-desktop-portal-gnome"

log "Installing pre-requisites..."
if ! as_user "$AUR_HELPER" -S --noconfirm --needed $PRE_PKGS; then
    critical_failure_handler "Failed to install pre-requisites: $PRE_PKGS"
fi

log "Installing $CORE_PKG and all its dependencies via AUR..."
if ! as_user "$AUR_HELPER" -S --noconfirm --needed "$CORE_PKG"; then
    critical_failure_handler "Failed to install '$CORE_PKG' from AUR."
fi

success "DMS core package installed."

# Step 2: Install Niri Ecosystem
section "Step 2/4" "Install Niri Ecosystem"

log "Installing Niri ecosystem packages..."
NIRI_PKGS=(
    # Terminal & Shell
    "kitty" "fish" "starship" "eza" "zoxide" "bat" "fzf" "jq"
    # Screenshot & Recording
    "satty" "slurp" "wf-recorder" "wl-screenrec-git"
    # Launcher & Bar
    "fuzzel" "niri-sidebar-git"
    # File Manager
    "thunar" "thunar-archive-plugin" "thunar-volman" "tumbler"
    "ffmpegthumbnailer" "gvfs-smb" "gvfs-mtp" "gvfs-gphoto2"
    "poppler-glib" "webp-pixbuf-loader" "libgsf"
    # Media
    "imv" "mpv"
)

for pkg in "${NIRI_PKGS[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        log "Installing $pkg..."
        exe as_user "$AUR_HELPER" -S --noconfirm --needed "$pkg"
    fi
done

success "Niri ecosystem installed."

# Step 3: Install Theming
section "Step 3/4" "Install Theming"

log "Installing theming packages..."
THEME_PKGS=(
    "matugen" "adw-gtk-theme" "nwg-look" "breeze-cursors"
    "flatpak" "bazaar"
)

for pkg in "${THEME_PKGS[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        log "Installing $pkg..."
        exe as_user "$AUR_HELPER" -S --noconfirm --needed "$pkg"
    fi
done

success "Theming packages installed."

# Step 4: Initialize Environment
section "Step 4/4" "Initialize Environment"

log "Creating user directories..."
as_user mkdir -p "/home/$TARGET_USER/.config/niri/dms" 2>/dev/null || true
as_user mkdir -p "/home/$TARGET_USER/Pictures/Screenshots" 2>/dev/null || true

log "Deploying wallpapers..."
WALLPAPER_SOURCE_DIR="$PARENT_DIR/resources/Wallpapers"
WALLPAPER_DIR="/home/$TARGET_USER/Pictures/Wallpapers"
if [ -d "$WALLPAPER_SOURCE_DIR" ]; then
    as_user mkdir -p "$WALLPAPER_DIR"
    cp -r "$WALLPAPER_SOURCE_DIR/." "$WALLPAPER_DIR/" 2>/dev/null || true
    chown -R "$TARGET_USER:" "$WALLPAPER_DIR"
fi

success "Niri + DMS setup completed."

# Create usage guide
as_user cat > "$HOME_DIR/必看-Niri使用方法.txt" << 'GUIDE'
═══════════════════════════════════════════
  Niri + DMS 快速使用指南
═══════════════════════════════════════════

【窗口操作】
  Super + H/J/K/L       窗口聚焦（左/下/上/右）
  Super + Shift + H/J/K/L  移动窗口
  Super + Enter          打开终端 (kitty)
  Super + Q              关闭窗口
  Super + R              切换大小
  Super + Space          切换布局

【截图】
  Super + P              截取区域
  Super + Shift + P      截取全屏
  截图自动保存: ~/Pictures/Screenshots/

【启动器】
  Super + D              打开 fuzzel 应用启动器
  Super + Shift + D        显示快捷键列表

【文件 & 终端】
  Super + T              打开文件管理器 (yazi)
  Super + Shift + T        打开图形文件管理器 (thunar)

【常用软件】
  kitty                 终端模拟器
  thunar                图形文件管理器
  yazi                  终端文件管理器
  mpv                   视频播放器
  imv                   图片查看器
  niri-binds            查看所有快捷键绑定

【Niri 配置】
  config: ~/.config/niri/config.kdl
  修改后自动热重载

【更新 / 快照】
  sudo pacman -Syu      更新系统
  quickload             恢复系统快照

═══════════════════════════════════════════
GUIDE
chown "$TARGET_USER:" "$HOME_DIR/必看-Niri使用方法.txt"
success "Usage guide created ~/必看-Niri使用方法.txt"

log "Module 04-niri-dms completed."
