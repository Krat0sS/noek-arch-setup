#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Network Backend Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-utils.sh"

check_root

section "Optional" "Network Backend (iwd)"

if pacman -Qi networkmanager &> /dev/null; then
    log "NetworkManager detected. Proceeding with iwd backend configuration..."
    
    log "Configuring NetworkManager to use iwd backend..."
    exe pacman -S --noconfirm --needed iwd
    exe systemctl enable iwd
    
    if [ ! -d /etc/NetworkManager/conf.d ]; then
        mkdir -p /etc/NetworkManager/conf.d
    fi
    
    if [ -f /etc/NetworkManager/conf.d/iwd.conf ]; then
        rm /etc/NetworkManager/conf.d/iwd.conf
    fi
    
    if [ ! -f /etc/NetworkManager/conf.d/iwd.conf ]; then
        echo -e "[device]\nwifi.backend=iwd" >> /etc/NetworkManager/conf.d/iwd.conf
    fi
    
    log "Notice: NetworkManager restart deferred. Changes will apply after reboot."
    success "Network backend configured (iwd)."
else
    log "NetworkManager not found. Skipping iwd configuration."
fi
