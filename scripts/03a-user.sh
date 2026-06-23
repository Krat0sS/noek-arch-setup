#!/bin/bash

# ==============================================================================
# Noek Arch Setup - User Account Setup
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-utils.sh"

check_root

section "Phase 3" "User Account Setup"

if [ -f "/tmp/noek_install_user" ]; then
    rm "/tmp/noek_install_user"
fi
detect_target_user

if id "$TARGET_USER" &>/dev/null; then
    success "Target user '${TARGET_USER}' exists. Proceeding with configuration..."
    SKIP_CREATION=true
else
    log "Preparing to create new user account: '${TARGET_USER}'..."
    SKIP_CREATION=false
fi

section "Step 2/4" "Account & Privileges"

if [ "$SKIP_CREATION" = true ]; then
    log "Ensuring $TARGET_USER belongs to 'wheel' group..."
    if groups "$TARGET_USER" | grep -q "\bwheel\b"; then
        success "User is already in 'wheel' group."
    else
        log "Adding user to 'wheel' group..."
        exe usermod -aG wheel "$TARGET_USER"
    fi
else
    log "Creating user account: ${TARGET_USER}..."
    exe useradd -m -G wheel -s /bin/bash "$TARGET_USER"
    
    if [[ -n "${USER_PASSWORD:-}" ]]; then
        log "Setting password from USER_PASSWORD env var..."
        echo "$TARGET_USER:$USER_PASSWORD" | chpasswd
        success "Password set for ${TARGET_USER}."
    else
        log "Setting password for ${TARGET_USER}..."
        echo "Please set a password for the new user:"
        passwd "$TARGET_USER"
    fi
fi

section "Step 3/4" "Sudo Configuration"

if ! grep -q "^%wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
    log "Enabling sudo for wheel group..."
    echo "%wheel ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers > /dev/null
    success "Sudo access enabled for wheel group."
else
    success "Sudo already configured for wheel group."
fi

section "Step 4/4" "User Environment"

log "Setting up user directories..."
as_user xdg-user-dirs-update --force

success "User account setup completed."
log "Module 03a-user completed."
