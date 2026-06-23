#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Essential Software & Drivers
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/00-utils.sh"

check_root

log ">>> Starting Phase 2: Essential Software & Drivers"

# Step 1: Audio & Video
section "Step 1/7" "Audio & Video"

log "Installing firmware..."
exe pacman -S --noconfirm --needed sof-firmware alsa-ucm-conf alsa-firmware

log "Installing Pipewire stack..."
exe pacman -S --noconfirm --needed pipewire lib32-pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack

exe systemctl --global enable pipewire pipewire-pulse wireplumber

log "Installing sound themes..."
exe pacman -S --noconfirm --needed sound-theme-freedesktop
success "Audio setup complete."

# Step 2: Locale
section "Step 2/7" "Locale Configuration"

NEED_GENERATE=false

if locale -a | grep -iq "en_US.utf8"; then
    success "English locale (en_US.UTF-8) is active."
else
    log "Enabling en_US.UTF-8..."
    sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    NEED_GENERATE=true
fi

if locale -a | grep -iq "zh_CN.utf8"; then
    success "Chinese locale (zh_CN.UTF-8) is active."
else
    log "Enabling zh_CN.UTF-8..."
    sed -i 's/^#\s*zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
    NEED_GENERATE=true
fi

if [ "$NEED_GENERATE" = true ]; then
    log "Generating locales..."
    if exe locale-gen; then
        success "Locales generated successfully."
    else
        error "Locale generation failed."
    fi
else
    success "All locales are already up to date."
fi

# Step 3: Input Method
section "Step 3/7" "Input Method (Fcitx5)"

exe pacman -S --noconfirm --needed fcitx5-im fcitx5-rime rime-ice-git
success "Fcitx5 installed."

# Step 4: Bluetooth
section "Step 4/7" "Bluetooth"

log "Detecting Bluetooth hardware..."
exe pacman -S --noconfirm --needed usbutils pciutils

BT_FOUND=false

if lsusb | grep -qi "bluetooth"; then BT_FOUND=true; fi
if lspci | grep -qi "bluetooth"; then BT_FOUND=true; fi
if rfkill list bluetooth >/dev/null 2>&1; then BT_FOUND=true; fi

if [ "$BT_FOUND" = true ]; then
    info_kv "Hardware" "Detected"
    
    log "Installing Bluez..."
    exe pacman -S --noconfirm --needed bluez bluetui
    
    exe systemctl enable --now bluetooth
    success "Bluetooth service enabled."
else
    info_kv "Hardware" "Not Found"
    warn "No Bluetooth device detected. Skipping installation."
fi

# Step 5: Power Management
section "Step 5/7" "Power Management"

exe pacman -S --noconfirm --needed power-profiles-daemon
exe systemctl enable --now power-profiles-daemon
success "Power profiles daemon enabled."

# Step 6: Fastfetch & Fun
section "Step 6/7" "Fastfetch & Fun"

exe pacman -S --noconfirm --needed fastfetch gdu btop cmatrix lolcat sl
success "Fastfetch installed."

# Step 7: Flatpak
section "Step 7/7" "Flatpak"

exe pacman -S --noconfirm --needed flatpak
exe flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

CURRENT_TZ=$(readlink -f /etc/localtime)
IS_CN_ENV=false
if [[ "$CURRENT_TZ" == *"Shanghai"* ]] || [ "$CN_MIRROR" == "1" ]; then
    IS_CN_ENV=true
    info_kv "Region" "China Optimization Active"
fi

if [ "$IS_CN_ENV" = true ]; then
    select_flathub_mirror
else
    log "Using Global Sources."
fi

# Deploy Chinese fonts from resources
FONT_SRC="$PARENT_DIR/resources/windows-sim-fonts"
if [ -d "$FONT_SRC" ]; then
    section "Extra" "Deploying Chinese Fonts"
    log "Installing Windows-simulated Chinese fonts (宋体/黑体/楷体/仿宋)..."
    exe mkdir -p /usr/share/fonts/TTF/
    exe cp "$FONT_SRC"/*.ttf "$FONT_SRC"/*.ttc /usr/share/fonts/TTF/ 2>/dev/null || true
    exe fc-cache -fv
    success "Chinese fonts deployed."
fi

log "Module 02-musthave completed."
