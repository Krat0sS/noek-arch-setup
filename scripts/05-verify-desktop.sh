#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Desktop Verification
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-utils.sh"

VERIFY_LIST="/tmp/noek_install_verify.list"

section "Verification" "Auditing System State"

if [ -f "$VERIFY_LIST" ]; then
    mapfile -t CHECK_PKGS < <(cat "$VERIFY_LIST" | tr ' ' '\n' | sed '/^[[:space:]]*$/d' | sort -u)
    
    if [ ${#CHECK_PKGS[@]} -gt 0 ]; then
        log "Verifying ${#CHECK_PKGS[@]} explicit packages..."
        MISSING_PKGS=$(pacman -T "${CHECK_PKGS[@]}" 2>/dev/null)
        
        if [ -n "$MISSING_PKGS" ]; then
            echo ""
            error "SOFTWARE INSTALLATION INCOMPLETE!"
            echo -e "   ${DIM}The following packages failed to install:${NC}"
            echo "$MISSING_PKGS" | awk '{print "   \033[1;31m->\033[0m \033[1;33m" $0 "\033[0m"}'
            echo ""
            write_log "FATAL" "Missing packages: $(echo "$MISSING_PKGS" | tr '\n' ' ')"
            error "Cannot proceed with a broken desktop environment."
            echo -e "   ${H_YELLOW}>>> Exiting installer. Please check your network or AUR helpers. ${NC}"
            exit 1
        else
            success "All explicit packages successfully verified."
            rm -f "$VERIFY_LIST"
        fi
    fi
fi

log "Identifying target user for config audit..."
detect_target_user

if [ -z "$TARGET_USER" ]; then
    warn "Could not reliably detect user 1000. Skipping dotfiles audit."
else
    HOME_DIR="/home/$TARGET_USER"
    CONFIG_ERRORS=0
    
    check_config_exists() {
        local path="$1"
        if [ ! -e "$path" ]; then
            echo -e "   \033[1;31m->\033[0m \033[1;33m$path\033[0m is MISSING or BROKEN!"
            CONFIG_ERRORS=$((CONFIG_ERRORS + 1))
        else
            log "  [OK] $path"
        fi
    }
    
    log "Auditing dotfiles for ${DESKTOP_ENV^^}..."
    
    case "$DESKTOP_ENV" in
        niridms)
            check_config_exists "$HOME_DIR/.config/niri"
        ;;
        kde)
            check_config_exists "$HOME_DIR/.config/plasma-workspace"
        ;;
        gnome)
            check_config_exists "$HOME_DIR/.config/dconf"
        ;;
        minimalniri)
            check_config_exists "$HOME_DIR/.config/niri"
        ;;
        *)
            log "No specific config checks mapped for $DESKTOP_ENV. Skipping."
        ;;
    esac
    
    if [ "$CONFIG_ERRORS" -gt 0 ]; then
        echo ""
        error "DOTFILES DEPLOYMENT FAILED!"
        write_log "FATAL" "Dotfiles audit failed. $CONFIG_ERRORS paths missing or broken."
        echo -e "   ${H_YELLOW}>>> Exiting installer. The repository clone or symlink step might have failed. ${NC}"
        exit 1
    else
        success "Configuration files and symlinks deployed correctly."
    fi
fi

exit 0
