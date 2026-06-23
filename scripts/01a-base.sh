#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Base System Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-utils.sh"

check_root

log "Starting Phase 1: Base System Configuration..."

# Step 1: Global Default Editor
section "Step 1/6" "Global Default Editor"

TARGET_EDITOR="vim"

if command -v nvim &> /dev/null; then
    TARGET_EDITOR="nvim"
    log "Neovim detected."
elif command -v nano &> /dev/null; then
    TARGET_EDITOR="nano"
    log "Nano found."
else
    log "Installing Vim..."
    if ! command -v vim &> /dev/null; then
        exe pacman -Syu --noconfirm gvim
    fi
fi

log "Setting EDITOR=$TARGET_EDITOR in /etc/environment..."
if grep -q "^EDITOR=" /etc/environment; then
    exe sed -i "s/^EDITOR=.*/EDITOR=${TARGET_EDITOR}/" /etc/environment
else
    echo "EDITOR=${TARGET_EDITOR}" >> /etc/environment
fi
success "Global EDITOR set to: ${TARGET_EDITOR}"

# Step 2: Enable Multilib Repository
section "Step 2/6" "Multilib Repository"

if grep -q "^\[multilib\]" /etc/pacman.conf; then
    success "[multilib] is already enabled."
else
    log "Uncommenting [multilib]..."
    exe sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
    log "Refreshing database..."
    exe pacman -Syu --noconfirm
    success "[multilib] enabled."
fi

# Step 3: Install Base Fonts
section "Step 3/6" "Base Fonts"

log "Installing base fonts..."
exe pacman -S --noconfirm --needed noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd otf-font-awesome

log "Installing terminus-font for TTY..."
exe pacman -S --noconfirm --needed terminus-font

log "Setting font for current session..."
exe setfont ter-v28n

log "Configuring permanent vconsole font..."
if [ -f /etc/vconsole.conf ] && grep -q "^FONT=" /etc/vconsole.conf; then
    exe sed -i 's/^FONT=.*/FONT=ter-v28n/' /etc/vconsole.conf
else
    echo "FONT=ter-v28n" >> /etc/vconsole.conf
fi

log "Restarting systemd-vconsole-setup..."
exe systemctl restart systemd-vconsole-setup
success "TTY font configured (ter-v28n)."

# Step 4: Configure ArchLinuxCN Repository
section "Step 4/6" "ArchLinuxCN Repository"

if grep -q "\[archlinuxcn\]" /etc/pacman.conf; then
    success "archlinuxcn repository already exists."
else
    log "Adding archlinuxcn mirrors to pacman.conf..."
    
    LOCAL_TZ=""
    if [ -L /etc/localtime ]; then
        LOCAL_TZ=$(readlink -f /etc/localtime)
    fi
    
    echo "" >> /etc/pacman.conf
    echo "[archlinuxcn]" >> /etc/pacman.conf
    
    if [[ "$LOCAL_TZ" == *"Asia/Shanghai"* ]]; then
        log "Timezone is Asia/Shanghai. Applying mainland mirrors..."
        cat <<EOT >> /etc/pacman.conf
Server = https://mirrors.ustc.edu.cn/archlinuxcn/\$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch
Server = https://mirrors.hit.edu.cn/archlinuxcn/\$arch
Server = https://repo.huaweicloud.com/archlinuxcn/\$arch
EOT
    else
        log "Non-Shanghai timezone. Preending global mirror..."
        cat <<EOT >> /etc/pacman.conf
Server = https://repo.archlinuxcn.org/\$arch
Server = https://mirrors.ustc.edu.cn/archlinuxcn/\$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch
EOT
    fi
    success "Mirrors added based on timezone."
fi

log "Installing archlinuxcn-keyring..."
exe pacman -Syu --noconfirm archlinuxcn-keyring
success "ArchLinuxCN configured."

# Step 5: Install AUR Helpers
section "Step 5/6" "AUR Helpers"

log "Installing yay and paru..."
exe pacman -S --noconfirm --needed base-devel yay paru
success "Helpers installed."

# Step 6: Enable Pacman Candy Progress Bar
section "Step 6/6" "Pacman Candy"

if grep -q "^ILoveCandy" /etc/pacman.conf; then
    success "Pacman candy progress bar is already enabled."
else
    log "Enabling pacman candy progress bar..."
    if grep -q "^#[[:space:]]*ILoveCandy" /etc/pacman.conf; then
        exe sed -i 's/^#[[:space:]]*ILoveCandy/ILoveCandy/' /etc/pacman.conf
    elif grep -q "^# Misc options" /etc/pacman.conf; then
        exe sed -i '/^# Misc options/a ILoveCandy' /etc/pacman.conf
    else
        echo "ILoveCandy" >> /etc/pacman.conf
    fi
    success "Pacman candy progress bar enabled."
fi

log "Module 01a-base completed."
