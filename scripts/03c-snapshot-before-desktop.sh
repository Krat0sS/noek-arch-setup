#!/bin/bash

# ==============================================================================
# Noek Arch Setup - System Snapshot Before Desktop
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/00-utils.sh" ]; then
    source "$SCRIPT_DIR/00-utils.sh"
else
    echo "Error: 00-utils.sh not found."
    exit 1
fi

check_root

section "Phase 3c" "System Snapshot"

create_checkpoint() {
    local MARKER="Before Desktop Environments"
    
    if ! command -v snapper &>/dev/null; then
        warn "Snapper tool not found. Skipping snapshot creation."
        return
    fi

    if snapper -c root get-config &>/dev/null; then
        if snapper -c root list --columns description | grep -Fqx "$MARKER"; then
            log "Snapshot '$MARKER' already exists on [root]."
        else
            log "Creating safety checkpoint on [root]..."
            snapper -c root create --description "$MARKER"
            success "Root snapshot created."
        fi
    else
        warn "Snapper 'root' config not configured. Skipping root snapshot."
    fi

    if snapper -c home get-config &>/dev/null; then
        if snapper -c home list --columns description | grep -Fqx "$MARKER"; then
            log "Snapshot '$MARKER' already exists on [home]."
        else
            log "Creating safety checkpoint on [home]..."
            snapper -c home create --description "$MARKER"
            success "Home snapshot created."
        fi
    else
        log "Snapper 'home' config not configured. Skipping home snapshot."
    fi
}

create_checkpoint

success "Snapshot safety net established."
log "Module 03c-snapshot completed."
