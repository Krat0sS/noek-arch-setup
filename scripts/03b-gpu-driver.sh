#!/bin/bash

# ==============================================================================
# Noek Arch Setup - GPU Driver Installer
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/00-utils.sh" ]; then
    source "$SCRIPT_DIR/00-utils.sh"
else
    echo "Error: 00-utils.sh not found."
    exit 1
fi

check_root

section "Phase 2b" "GPU Driver Setup"

# Check if chwd is available
if ! command -v chwd &>/dev/null; then
    log "chwd not found. Attempting to install..."
    if pacman -S --noconfirm --needed chwd-arch-git 2>/dev/null; then
        success "chwd installed."
    else
        warn "Could not install chwd. Skipping GPU driver setup."
        warn "You can manually install drivers later with: sudo pacman -S nvidia nvidia-utils (for NVIDIA)"
        log "Module 03b-gpu-driver completed (skipped)."
        exit 0
    fi
fi

detect_target_user

SUDO_TEMP_FILE="/etc/sudoers.d/99_noek_installer_temp"
echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" >"$SUDO_TEMP_FILE"
chmod 440 "$SUDO_TEMP_FILE"
log "Temp sudo file created..."

cleanup_sudo() {
    if [ -f "$SUDO_TEMP_FILE" ]; then
        rm -f "$SUDO_TEMP_FILE"
        log "Security: Temporary sudo privileges revoked."
    fi
}
trap cleanup_sudo EXIT INT TERM

log "Running Automated Hardware Detection and Driver Installation..."
chwd -a

if [ $? -eq 0 ]; then
    success "Hardware drivers installed via chwd."
else
    warn "chwd encountered an error. Please check pacman logs."
    warn "You can manually install drivers later."
fi

log "Module 03b-gpu-driver completed."
