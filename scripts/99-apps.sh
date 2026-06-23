#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Common Applications
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/00-utils.sh"

LAZYVIM_DEPS=("neovim" "ripgrep" "fd" "ttf-jetbrains-mono-nerd" "git")

check_root

if ! command -v fzf &> /dev/null; then
    log "Installing dependency: fzf..."
    pacman -S --noconfirm fzf >/dev/null 2>&1
fi

trap 'echo -e "\n   ${H_YELLOW}>>> Operation cancelled by user (Ctrl+C). Cleaning up...${NC}"; cleanup_sudo' INT TERM EXIT

section "Phase 5" "Common Applications"

log "Identifying target user..."
detect_target_user
HOME_DIR="/home/$TARGET_USER"
info_kv "Target" "$TARGET_USER"

as_user() {
  runuser -u "$TARGET_USER" -- "$@"
}

LIST_FILE="$PARENT_DIR/common-applist.txt"

REPO_APPS=()
AUR_APPS=()
FLATPAK_APPS=()
FAILED_PACKAGES=()
INSTALL_LAZYVIM=false

if [ ! -f "$LIST_FILE" ]; then
    warn "File common-applist.txt not found. Skipping."
    trap - INT
    exit 0
fi

if ! grep -q -vE "^\s*#|^\s*$" "$LIST_FILE"; then
    warn "App list is empty. Skipping."
    trap - INT
    exit 0
fi

echo ""
echo -e "   Selected List: ${BOLD}common-applist.txt${NC}"
echo -e "   ${H_YELLOW}>>> Do you want to CUSTOMIZE the application installation?${NC}"
echo ""

read -t 60 -p "   Please select[Y/n]: " choice
READ_STATUS=$?

SELECTED_RAW=""

if [ $READ_STATUS -ne 0 ]; then
    echo "" 
    warn "Timeout reached (60s). Auto-installing ALL applications from list..."
    SELECTED_RAW=$(grep -vE "^\s*#|^\s*$" "$LIST_FILE" | sed -E 's/[[:space:]]+#/\t#/')
else
    choice=${choice:-Y}
    if [[ "$choice" =~ ^[nN]$ ]]; then
        log "User chose to auto-install ALL applications without customization."
        SELECTED_RAW=$(grep -vE "^\s*#|^\s*$" "$LIST_FILE" | sed -E 's/[[:space:]]+#/\t#/')
    else
        clear
        echo -e "\n  Loading application list..."
        
        SELECTED_RAW=$(grep -vE "^\s*#|^\s*$" "$LIST_FILE" | \
            sed -E 's/[[:space:]]+#/\t#/' | \
            fzf --multi \
                --layout=reverse \
                --border \
                --margin=1,2 \
                --prompt="Search App > " \
                --pointer=">>" \
                --marker="* " \
                --delimiter=$'\t' \
                --with-nth=1 \
                --bind 'load:select-all' \
                --bind 'ctrl-a:select-all,ctrl-d:deselect-all,j:down,k:up' \
                --info=inline \
                --header="[TAB] TOGGLE | [ENTER] INSTALL | [CTRL-D] DE-ALL | [CTRL-A] SE-ALL" \
                --preview "echo {} | cut -f2 -d$'\t' | sed 's/^# //'" \
                --preview-window=down:45%:wrap:border-up \
                --color=dark \
                --color=fg+:white,bg+:black \
                --color=hl:blue,hl+:blue:bold \
                --color=header:yellow:bold \
                --color=info:magenta \
                --color=prompt:cyan,pointer:cyan:bold,marker:green:bold \
                --color=spinner:yellow)
        
        clear
        
        if [ -z "$SELECTED_RAW" ]; then
            log "Skipping application installation (User cancelled selection in FZF)."
            trap - INT
            exit 0
        fi
    fi
fi

log "Processing selection..."

while IFS= read -r line; do
    raw_pkg=$(echo "$line" | cut -f1 -d$'\t' | xargs)
    [[ -z "$raw_pkg" ]] && continue

    if [[ "${raw_pkg,,}" == "lazyvim" ]]; then
        INSTALL_LAZYVIM=true
        REPO_APPS+=("${LAZYVIM_DEPS[@]}")
        info_kv "Config" "LazyVim detected" "Setup deferred to Post-Install"
        continue
    fi

    if [[ "$raw_pkg" == flatpak:* ]]; then
        clean_name="${raw_pkg#flatpak:}"
        FLATPAK_APPS+=("$clean_name")
    elif [[ "$raw_pkg" == AUR:* ]]; then
        clean_name="${raw_pkg#AUR:}"
        AUR_APPS+=("$clean_name")
    else
        REPO_APPS+=("$raw_pkg")
    fi
done <<< "$SELECTED_RAW"

info_kv "Scheduled" "Repo: ${#REPO_APPS[@]}" "AUR: ${#AUR_APPS[@]}" "Flatpak: ${#FLATPAK_APPS[@]}"

if [ ${#REPO_APPS[@]} -gt 0 ] || [ ${#AUR_APPS[@]} -gt 0 ]; then
    log "Configuring temporary NOPASSWD for installation..."
    SUDO_TEMP_FILE="/etc/sudoers.d/99_noek_installer_apps"
    echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" > "$SUDO_TEMP_FILE"
    chmod 440 "$SUDO_TEMP_FILE"
fi

cleanup_sudo() {
    if [ -f "$SUDO_TEMP_FILE" ]; then
        rm -f "$SUDO_TEMP_FILE"
        log "Security: Temporary sudo privileges revoked."
    fi
}
if [ ${#REPO_APPS[@]} -gt 0 ]; then
    section "Step 1/3" "Official Repository Packages (Batch)"
    
    REPO_QUEUE=()
    for pkg in "${REPO_APPS[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log "Skipping '$pkg' (Already installed)."
        else
            REPO_QUEUE+=("$pkg")
        fi
    done

    if [ ${#REPO_QUEUE[@]} -gt 0 ]; then
        BATCH_LIST="${REPO_QUEUE[*]}"
        info_kv "Installing" "${#REPO_QUEUE[@]} packages via Pacman/Yay"
        
        if ! exe as_user yay -S --noconfirm --needed --answerdiff=None --answerclean=None $BATCH_LIST; then
            error "Batch installation failed."
            for pkg in "${REPO_QUEUE[@]}"; do
                FAILED_PACKAGES+=("repo:$pkg")
            done
        else
            success "Repo batch installation completed."
        fi
    else
        log "All Repo packages are already installed."
    fi
fi

if [ ${#AUR_APPS[@]} -gt 0 ]; then
    section "Step 2/3" "AUR Packages (Batch)"
    
    AUR_QUEUE=()
    for pkg in "${AUR_APPS[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log "Skipping '$pkg' (Already installed)."
        else
            AUR_QUEUE+=("$pkg")
        fi
    done

    if [ ${#AUR_QUEUE[@]} -gt 0 ]; then
        BATCH_LIST="${AUR_QUEUE[*]}"
        info_kv "Installing" "${#AUR_QUEUE[@]} packages via Yay"
        
        if ! exe as_user yay -S --noconfirm --needed --answerdiff=None --answerclean=None $BATCH_LIST; then
            error "AUR batch installation failed."
            for pkg in "${AUR_QUEUE[@]}"; do
                FAILED_PACKAGES+=("aur:$pkg")
            done
        else
            success "AUR batch installation completed."
        fi
    else
        log "All AUR packages are already installed."
    fi
fi

if [ ${#FLATPAK_APPS[@]} -gt 0 ]; then
    section "Step 3/3" "Flatpak Applications"
    
    for pkg in "${FLATPAK_APPS[@]}"; do
        if flatpak list --columns=application | grep -q "^${pkg}$"; then
            log "Skipping '$pkg' (Already installed)."
        else
            log "Installing $pkg via Flatpak..."
            if ! exe flatpak install -y flathub "$pkg"; then
                error "Failed to install $pkg via Flatpak."
                FAILED_PACKAGES+=("flatpak:$pkg")
            fi
        fi
    done
    success "Flatpak applications processed."
fi

if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo ""
    warn "The following packages failed to install:"
    for pkg in "${FAILED_PACKAGES[@]}"; do
        echo -e "  ${H_RED}- $pkg${NC}"
    done
    echo ""
fi

if [ "$INSTALL_LAZYVIM" = true ]; then
    section "Post-Install" "LazyVim Setup"
    
    if command -v nvim &>/dev/null; then
        log "LazyVim dependencies installed."
        log "初次使用请在终端运行: git clone https://github.com/LazyVim/starter ~/.config/nvim --depth 1"
        log "然后启动 nvim，输入 :Lazy 安装插件"
    fi
fi

success "Application installation completed."
log "Module 99-apps completed."
