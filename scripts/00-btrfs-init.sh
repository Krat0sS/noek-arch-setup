#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Btrfs Snapshot Initialization
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-utils.sh"

check_root

section "Phase 0" "System Snapshot Initialization"

ROOT_FSTYPE=$(findmnt -n -o FSTYPE /)

if [ "$ROOT_FSTYPE" != "btrfs" ]; then
    warn "Root filesystem is not Btrfs ($ROOT_FSTYPE detected)."
    log "Skipping Btrfs snapshot initialization entirely."
    exit 0
fi

log "Root is Btrfs. Proceeding with Snapper setup..."

log "Installing Snapper..."
exe pacman -Syu --noconfirm --needed snapper

log "Configuring Snapper for Root..."
if ! snapper list-configs | grep -q "^root "; then
    if [ -d "/.snapshots" ]; then
        exe_silent umount /.snapshots
        exe_silent rm -rf /.snapshots
    fi
    if exe snapper -c root create-config /; then
        success "Config 'root' created."
        exe snapper -c root set-config ALLOW_GROUPS="wheel" TIMELINE_CREATE="yes" TIMELINE_CLEANUP="yes" NUMBER_LIMIT="10" NUMBER_MIN_AGE="0" NUMBER_LIMIT_IMPORTANT="5" TIMELINE_LIMIT_HOURLY="3" TIMELINE_LIMIT_DAILY="0" TIMELINE_LIMIT_WEEKLY="0" TIMELINE_LIMIT_MONTHLY="0" TIMELINE_LIMIT_YEARLY="0"
        exe systemctl enable snapper-cleanup.timer
        exe systemctl enable snapper-timeline.timer
    fi
fi

if findmnt -n -o FSTYPE /home | grep -q "btrfs"; then
    log "Home is on Btrfs. Configuring Snapper for Home..."
    if ! snapper list-configs | grep -q "^home "; then
        if [ -d "/home/.snapshots" ]; then
            exe_silent umount /home/.snapshots
            exe_silent rm -rf /home/.snapshots
        fi
        if exe snapper -c home create-config /home; then
            success "Config 'home' created."
            exe snapper -c home set-config ALLOW_GROUPS="wheel" TIMELINE_CREATE="yes" TIMELINE_CLEANUP="yes" NUMBER_LIMIT="10" NUMBER_MIN_AGE="0" NUMBER_LIMIT_IMPORTANT="5" TIMELINE_LIMIT_HOURLY="3" TIMELINE_LIMIT_DAILY="0" TIMELINE_LIMIT_WEEKLY="0" TIMELINE_LIMIT_MONTHLY="0" TIMELINE_LIMIT_YEARLY="0"
            exe systemctl enable snapper-cleanup.timer
            exe systemctl enable snapper-timeline.timer
        fi
    fi
else
    log "Home is not on Btrfs. Skipping Home Snapper config."
fi

log "Installing Btrfs Assistant..."
exe pacman -S --noconfirm --needed btrfs-assistant

success "Btrfs snapshot initialization completed."
log "Module 00-btrfs-init completed."
