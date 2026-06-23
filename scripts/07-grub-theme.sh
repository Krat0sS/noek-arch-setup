#!/bin/bash

# ==============================================================================
# Noek Arch Setup - GRUB Theming & Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/00-utils.sh"

check_root

if ! command -v grub-mkconfig >/dev/null 2>&1; then
    echo ""
    warn "GRUB (grub-mkconfig) not found on this system."
    log "Skipping GRUB theme installation."
    exit 0
fi

section "Phase 7" "GRUB Customization & Theming"

set_grub_value() {
    local key="$1"
    local value="$2"
    local conf_file="/etc/default/grub"
    local escaped_value
    escaped_value=$(printf '%s\n' "$value" | sed 's,[\/&],\\&,g')
    
    if grep -q -E "^#\s*$key=" "$conf_file"; then
        exe sed -i -E "s,^#\s*$key=.*,$key=\"$escaped_value\"," "$conf_file"
    elif grep -q -E "^$key=" "$conf_file"; then
        exe sed -i -E "s,^$key=.*,$key=\"$escaped_value\"," "$conf_file"
    else
        log "Appending new key: $key"
        echo "$key=\"$escaped_value\"" >> "$conf_file"
    fi
}

manage_kernel_param() {
    local action="$1"
    local param="$2"
    local conf_file="/etc/default/grub"
    local line
    
    line=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$conf_file" || true)
    
    local params
    params=$(echo "$line" | sed -e 's/GRUB_CMDLINE_LINUX_DEFAULT=//' -e 's/"//g')
    local param_key
    if [[ "$param" == *"="* ]]; then param_key="${param%%=*}"; else param_key="$param"; fi
    params=$(echo "$params" | sed -E "s/\b${param_key}(=[^ ]*)?\b//g")
    
    if [ "$action" == "add" ]; then params="$params $param"; fi
    
    params=$(echo "$params" | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    exe sed -i "s,^GRUB_CMDLINE_LINUX_DEFAULT=.*,GRUB_CMDLINE_LINUX_DEFAULT=\"$params\"," "$conf_file"
}

section "Step 1/4" "Kernel Parameters"

log "Configuring kernel boot parameters..."
manage_kernel_param "remove" "quiet"
manage_kernel_param "remove" "splash"
manage_kernel_param "add" "loglevel=5"
manage_kernel_param "add" "nowatchdog"

CPU_VENDOR=$(LC_ALL=C lscpu 2>/dev/null | awk '/Vendor ID:/ {print $3}' || true)
if [ "${CPU_VENDOR:-}" == "GenuineIntel" ]; then
    log "Intel CPU detected. Disabling iTCO_wdt watchdog."
    manage_kernel_param "add" "modprobe.blacklist=iTCO_wdt"
elif [ "${CPU_VENDOR:-}" == "AuthenticAMD" ]; then
    log "AMD CPU detected. Disabling sp5100_tco watchdog."
    manage_kernel_param "add" "modprobe.blacklist=sp5100_tco"
fi

success "Kernel parameters updated."

section "Step 2/4" "GRUB Theme Selection"

GRUB_CONF="/etc/default/grub"

echo ""
echo -e "${H_PURPLE}╭──────────────────────────────────────────────────────╮${NC}"
echo -e "${H_PURPLE}│${NC}   ${BOLD}选择开机引导主题 (Select GRUB Theme)${NC}"
echo -e "${H_PURPLE}├──────────────────────────────────────────────────────┤${NC}"
echo -e "${H_PURPLE}│${NC} ${H_CYAN}[1]${NC} 默认 (不使用主题)"
echo -e "${H_PURPLE}│${NC} ${H_CYAN}[2]${NC} CyberGRUB-2077 (赛博朋克风格)"
echo -e "${H_PURPLE}│${NC} ${H_CYAN}[3]${NC} Crossgrub (像素风格)"
echo -e "${H_PURPLE}│${NC} ${H_CYAN}[4]${NC} BSOL (简约风格)"
echo -e "${H_PURPLE}│${NC} ${H_CYAN}[5]${NC} Mesugaki-BSOL (动漫风格)"
echo -e "${H_PURPLE}│${NC} ${H_CYAN}[6]${NC} OldBIOS (复古风格)"
echo -e "${H_PURPLE}│${NC} ${H_CYAN}[7]${NC} Minegrub (我的世界风格，需联网下载)"
echo -e "${H_PURPLE}╰──────────────────────────────────────────────────────╯${NC}"
echo ""

read -t 60 -p "$(echo -e "   ${H_YELLOW}请输入选择 [1-7]: ${NC}")" THEME_CHOICE || true
THEME_CHOICE=${THEME_CHOICE:-1}

install_local_theme() {
    local theme_name="$1"
    local theme_dir="$PARENT_DIR/grub-themes/$theme_name"
    local dest_dir="/usr/share/grub/themes/$theme_name"
    
    if [ -d "$theme_dir" ]; then
        exe mkdir -p /usr/share/grub/themes
        exe cp -r "$theme_dir" /usr/share/grub/themes/
        set_grub_value "GRUB_THEME" "$dest_dir/theme.txt"
        success "$theme_name theme installed."
    else
        warn "Theme directory not found: $theme_dir. Skipping."
    fi
}

case $THEME_CHOICE in
    2) install_local_theme "1CyberGRUB-2077" ;;
    3) install_local_theme "Crossgrub" ;;
    4) install_local_theme "bsol" ;;
    5) install_local_theme "Mesugaki-bsol" ;;
    6) install_local_theme "OldBIOS" ;;
    7)
        log "Installing Minegrub theme..."
        if command -v git >/dev/null 2>&1; then
            TEMP_MG_DIR=$(mktemp -d -t minegrub_install_XXXXXX)
            if exe git clone --depth 1 "https://github.com/Lxtharia/double-minegrub-menu.git" "$TEMP_MG_DIR"; then
                if [ -f "$TEMP_MG_DIR/install.sh" ]; then
                    (cd "$TEMP_MG_DIR" && exe ./install.sh)
                    success "Minegrub theme installed."
                fi
            fi
            [ -n "$TEMP_MG_DIR" ] && rm -rf "$TEMP_MG_DIR"
        else
            warn "Git not found. Cannot install Minegrub."
        fi
        ;;
    *)
        log "Using default GRUB appearance."
        ;;
esac

section "Step 3/4" "Power Menu Entries"

log "Adding Power Options to GRUB menu..."
cp /etc/grub.d/40_custom /etc/grub.d/99_custom 2>/dev/null || true
if ! grep -q 'menuentry "Reboot"' /etc/grub.d/99_custom; then
    cat >> /etc/grub.d/99_custom << 'GRUBEOF'
menuentry "Reboot" --class restart {reboot}
menuentry "Shutdown" --class shutdown {halt}
GRUBEOF
    success "Added grub menuentry (Reboot + Shutdown)."
else
    log "Power menu entries already exist, skipping."
fi

section "Step 4/4" "Apply Changes"

log "Generating new GRUB configuration..."
if exe grub-mkconfig -o /boot/grub/grub.cfg; then
    success "GRUB updated successfully."
else
    error "Failed to update GRUB."
    warn "You may need to run 'grub-mkconfig' manually."
fi

log "Module 07-grub-theme completed."
