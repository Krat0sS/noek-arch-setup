#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Main Installer
# ==============================================================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
STATE_FILE="$BASE_DIR/.install_progress"

if [ -f "$SCRIPTS_DIR/00-utils.sh" ]; then
    source "$SCRIPTS_DIR/00-utils.sh"
else
    echo "Error: 00-utils.sh not found."
    exit 1
fi

cleanup() {
    rm -f "/tmp/noek_install_user"
    tput cnorm 2>/dev/null || true
}
trap cleanup EXIT

export DEBUG=${DEBUG:-0}
export CN_MIRROR=${CN_MIRROR:-0}

# Unattended mode via environment variables
export UNATTENDED=${UNATTENDED:-0}
export DESKTOP=${DESKTOP:-}
export MODULES=${MODULES:-}
export USERNAME=${USERNAME:-}
export USER_PASSWORD=${USER_PASSWORD:-}
export MIRROR=${MIRROR:-auto}
export LOCALE=${LOCALE:-zh_CN.UTF-8}

if [ "$UNATTENDED" = "1" ]; then
    log ">>> 无人值守模式 (Unattended Mode) 已启用 <<<"
    log "   Desktop: ${DESKTOP:-默认KDE} / Modules: ${MODULES:-默认推荐}"
fi

check_root
chmod +x "$SCRIPTS_DIR"/*.sh

# ==============================================================================
# Pre-install Checks
# ==============================================================================
check_network() {
    echo -e "${H_CYAN}>>> 检测网络连接...${NC}"
    if ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
        echo -e "${H_GREEN}   ✔ 网络连接正常${NC}"
        return 0
    else
        echo -e "${H_RED}   ✘ 网络连接失败！${NC}"
        echo -e "${H_YELLOW}   请确保已连接网络后再运行此脚本。${NC}"
        echo -e "${H_YELLOW}   如果你是离线安装，请设置环境变量: OFFLINE=1${NC}"
        exit 1
    fi
}

confirm_install() {
    echo ""
    echo -e "${H_PURPLE}╭──────────────────────────────────────────────────────╮${NC}"
    echo -e "${H_PURPLE}│${NC}   ${BOLD}安装前确认${NC}"
    echo -e "${H_PURPLE}├──────────────────────────────────────────────────────┤${NC}"
    echo -e "${H_PURPLE}│${NC} ${H_YELLOW}警告: 此脚本将对系统进行以下操作:${NC}"
    echo -e "${H_PURPLE}│${NC}   • 安装/更新软件包"
    echo -e "${H_PURPLE}│${NC}   • 修改系统配置文件"
    echo -e "${H_PURPLE}│${NC}   • 安装桌面环境和驱动"
    echo -e "${H_PURPLE}│${NC}   • 配置 Btrfs 快照"
    echo -e "${H_PURPLE}│${NC} "
    echo -e "${H_PURPLE}│${NC} ${H_CYAN}建议: 安装前使用快照工具备份重要数据${NC}"
    echo -e "${H_PURPLE}╰──────────────────────────────────────────────────────╯${NC}"
    echo ""
    
    if [ "$UNATTENDED" = "1" ]; then
        log ">>> 无人值守模式，跳过安装确认。"
        return 0
    fi
    read -t 30 -p "$(echo -e "   ${H_YELLOW}确认继续安装？[y/N]: ${NC}")" confirm || true
    confirm=${confirm:-N}
    
    if [[ "${confirm,,}" != "y" ]]; then
        echo -e "${H_RED}>>> 安装已取消。${NC}"
        exit 0
    fi
}

# Run pre-install checks
check_network
confirm_install

banner() {
cat << "EOF"
 ██  ██  █████  █████  ██   ██
 ███ ██ ██   ██ ██     ██  ██ 
 ██████ ██   ██ █████  █████  
 ██ ███ ██   ██ ██     ██  ██ 
 ██  ██  █████  █████  ██   ██
EOF
}

show_banner() {
    clear
    echo -e "${H_CYAN}"
    banner
    echo -e "${NC}"
    echo -e "${DIM}   :: Arch Linux Automation ::${NC}"
    echo -e ""
}

select_desktop() {
    # Skip fzf if DESKTOP env var already set
    if [[ -n "${DESKTOP:-}" ]]; then
        case "$DESKTOP" in
            kde|niridms|minimalniri|gnome|none|random) ;;
            *) warn "无效 DESKTOP 值: $DESKTOP，使用默认 KDE"; DESKTOP="kde" ;;
        esac
        export DESKTOP_ENV="$DESKTOP"
        log "Desktop (from env): ${DESKTOP}"
        return 0
    fi
    if [ "$UNATTENDED" = "1" ]; then
        export DESKTOP_ENV="kde"
        log "Desktop (unattended default): kde"
        return 0
    fi
    if ! command -v fzf &> /dev/null; then
        echo -e "   ${DIM}Installing fzf for interactive menu...${NC}"
        pacman -Sy --noconfirm --needed fzf >/dev/null 2>&1
    fi
    
    local MENU_ITEMS=(
        "No_Desktop (不装桌面，只装基础系统)|none"
        "Surprise Me! (随机选一个桌面)|random"
        ""
        "KDE_Plasma ${H_YELLOW}(推荐 - 类似Windows，功能最全)${NC}|kde"
        "Niri + DMS ${H_YELLOW}(推荐 - 现代平铺窗口，美观高效)${NC}|niridms"
        "Minimal_Niri (极简Niri，自己配置，适合折腾党)|minimalniri"
        "GNOME (简洁优雅，类似macOS风格)|gnome"
    )
    
    while true; do
        show_banner
        
        local fzf_list=()
        local idx=1
        for item in "${MENU_ITEMS[@]}"; do
            [[ -z "$item" ]] && continue
            
            local name="${item%%|*}"
            local val="${item##*|}"
            local colored_idx="${H_CYAN}[${idx}]${NC}"
            
            if [ $idx -lt 10 ]; then
                fzf_list+=("${colored_idx}   ${name}\t${val}\t${name}")
            else
                fzf_list+=("${colored_idx}  ${name}\t${val}\t${name}")
            fi
            ((idx++))
        done
        
        local selected
        selected=$(printf "%b\n" "${fzf_list[@]}" | sed '/^[[:space:]]*$/d' | fzf \
            --ansi \
            --delimiter='\t' \
            --with-nth=1 \
            --info=hidden \
            --layout=reverse \
            --border="rounded" \
            --border-label="  选择桌面环境 (Select Desktop Environment)  " \
            --border-label-pos=5 \
            --color="marker:cyan,pointer:cyan,label:yellow" \
            --header=" [J/K] 上下选择 | [Enter] 确认" \
            --pointer=">" \
            --bind 'j:down,k:up,ctrl-c:abort,esc:abort' \
        --height=~20)
        
        local fzf_status=$?
        
        if [ $fzf_status -eq 130 ]; then
            echo -e "\n   ${H_RED}>>> Installation aborted by user.${NC}"
            exit 130
        fi
        
        if [ -z "$selected" ]; then continue; fi
        
        export DESKTOP_ENV="$(echo "$selected" | awk -F'\t' '{print $2}')"
        local selected_name="$(echo "$selected" | awk -F'\t' '{print $3}')"
        
        if [ "$DESKTOP_ENV" == "random" ]; then
            local POOL=()
            for item in "${MENU_ITEMS[@]}"; do
                [[ -z "$item" ]] && continue
                local oid="${item##*|}"
                if [[ "$oid" != "none" && "$oid" != "random" ]]; then
                    POOL+=("$item")
                fi
            done
            
            local rand_idx
            if [ ${#POOL[@]} -gt 0 ]; then
                rand_idx=$(( RANDOM % ${#POOL[@]} ))
                local final_item="${POOL[$rand_idx]}"
                local final_name="${final_item%%|*}"
                export DESKTOP_ENV="${final_item##*|}"
            else
                warn "No desktops available for random. Falling back to KDE."
                export DESKTOP_ENV="kde"
                local final_name="KDE_Plasma"
            fi
            
            echo -e "\n   ${H_CYAN}>>> Randomly selected:${NC} ${BOLD}${final_name}${NC}"
            read -p "$(echo -e "   ${H_YELLOW}Continue with this selection? [Y/n]: ${NC}")" confirm
            
            if [[ "${confirm,,}" == "n" ]]; then continue; else break; fi
        else
            log "Selected: ${selected_name}"
            sleep 0.5
            break
        fi
    done
}

select_optional_modules() {
    # Skip fzf if MODULES env var already set
    if [[ -n "${MODULES:-}" ]]; then
        OPTIONAL_MODULES=()
        local MODULE_MAP
        IFS=',' read -ra MODULE_ARRAY <<< "$MODULES"
        for m in "${MODULE_ARRAY[@]}"; do
            case "$m" in
                iwd)     OPTIONAL_MODULES+=("01b-nm-backend.sh") ;;
                dualboot) OPTIONAL_MODULES+=("02a-dualboot-fix.sh") ;;
                gpu)     OPTIONAL_MODULES+=("03b-gpu-driver.sh") ;;
                grub)    OPTIONAL_MODULES+=("07-grub-theme.sh") ;;
                apps)    OPTIONAL_MODULES+=("99-apps.sh") ;;
                *)       warn "Unknown module: $m (valid: iwd,dualboost,gpu,grub,apps)" ;;
            esac
        done
        log "Modules (from env): ${MODULES}"
        return 0
    fi
    if [ "$UNATTENDED" = "1" ]; then
        OPTIONAL_MODULES=()
        log "Modules (unattended default): skipping all optional modules"
        return 0
    fi
    local OPTIONAL_MENU=(
        "IWD WiFi Backend (WiFi后端优化，提升无线网络性能)|01b-nm-backend.sh"
        "Windows Dualboot Setup (双系统启动，检测Windows)|02a-dualboot-fix.sh"
        "GPU Drivers (自动检测显卡并安装驱动)|03b-gpu-driver.sh"
        "GRUB Theme (开机引导界面美化)|07-grub-theme.sh"
        "Common Apps (常用软件一键安装)|99-apps.sh"
    )
    
    show_banner
    
    local fzf_list=()
    for item in "${OPTIONAL_MENU[@]}"; do
        local name="${item%%|*}"
        local val="${item##*|}"
        fzf_list+=("  ${name}\t${val}")
    done
    
    local selected_raw
    selected_raw=$(printf "%b\n" "${fzf_list[@]}" | fzf \
        --multi \
        --delimiter='\t' \
        --with-nth=1 \
        --layout=reverse \
        --border="rounded" \
        --border-label="  选择可选模块 (Select Optional Modules)  " \
        --border-label-pos=5 \
        --color="marker:cyan,pointer:cyan,label:yellow" \
        --header=" [TAB] 切换选中 | [CTRL-X] 跳过全部 | [ENTER] 确认" \
        --pointer=">" \
        --expect=ctrl-x,enter \
        --bind 'start:select-all,ctrl-a:select-all,ctrl-d:deselect-all,ctrl-c:abort,esc:abort,j:down,k:up' \
    --height=~20)
    
    local fzf_status=$?
    if [ $fzf_status -eq 130 ]; then
        echo -e "\n   ${H_RED}>>> Installation aborted by user.${NC}"
        exit 130
    fi
    
    OPTIONAL_MODULES=()
    
    if [ -n "$selected_raw" ]; then
        local key
        key=$(head -n 1 <<< "$selected_raw")
        local selected_items
        selected_items=$(sed '1d' <<< "$selected_raw")

        if [[ "$key" == "ctrl-x" ]]; then
            log "Skipping all optional modules..."
            sleep 0.5
        else
            if [ -n "$selected_items" ]; then
                mapfile -t OPTIONAL_MODULES < <(echo "$selected_items" | awk -F'\t' '{if ($2 != "") print $2}')
            fi
        fi
    fi
}

sys_dashboard() {
    echo -e "${H_BLUE}╔════ SYSTEM DIAGNOSTICS ══════════════════════════════╗${NC}"
    echo -e "${H_BLUE}║${NC} ${BOLD}Kernel${NC}   : $(uname -r)"
    echo -e "${H_BLUE}║${NC} ${BOLD}User${NC}     : $(whoami)"
    echo -e "${H_BLUE}║${NC} ${BOLD}Desktop${NC}  : ${H_CYAN}${DESKTOP_ENV^^}${NC}"
    echo -e "${H_BLUE}║${NC} ${BOLD}Modules${NC}  : ${#OPTIONAL_MODULES[@]} optional module(s) selected"
    
    if [ "$CN_MIRROR" == "1" ]; then
        echo -e "${H_BLUE}║${NC} ${BOLD}Network${NC}  : ${H_YELLOW}CN Optimized${NC}"
    else
        echo -e "${H_BLUE}║${NC} ${BOLD}Network${NC}  : Global Default"
    fi
    
    if [ -f "$STATE_FILE" ]; then
        done_count=$(wc -l < "$STATE_FILE")
        echo -e "${H_BLUE}║${NC} ${BOLD}Progress${NC} : Resuming ($done_count steps recorded)"
    fi
    echo -e "${H_BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

select_desktop
select_optional_modules
clear
show_banner
sys_dashboard

MANDATORY_MODULES=(
    "00-btrfs-init.sh"
    "01a-base.sh"
    "02-musthave.sh"
    "03a-user.sh"
    "03c-snapshot-before-desktop.sh"
)

ALL_MODULES=("${MANDATORY_MODULES[@]}" "${OPTIONAL_MODULES[@]}")

case "$DESKTOP_ENV" in
    kde)           ALL_MODULES+=("04b-kdeplasma-setup.sh") ;;
    niridms)       ALL_MODULES+=("04-niri-dms-setup.sh") ;;
    minimalniri)   ALL_MODULES+=("04j-minimal-niri.sh") ;;
    gnome)         ALL_MODULES+=("04d-gnome.sh") ;;
    none)          log "跳过桌面环境安装。" ;;
    *)             warn "未知选择，跳过桌面安装。" ;;
esac

# Add verification module
ALL_MODULES+=("05-verify-desktop.sh")

mapfile -t MODULES < <(printf "%s\n" "${ALL_MODULES[@]}" | sort -u)

if [ ! -f "$STATE_FILE" ]; then touch "$STATE_FILE"; fi

TOTAL_STEPS=${#MODULES[@]}
CURRENT_STEP=0

log "Initializing installer sequence..."
sleep 0.5

for MODULE in "${MODULES[@]}"; do
    SCRIPT_PATH="$SCRIPTS_DIR/$MODULE"
    
    export TARGET_USER="${TARGET_USER:-}"
    export HOME_DIR="${HOME_DIR:-}"
    export DESKTOP_ENV
    export CN_MIRROR
    export UNATTENDED
    export USER_PASSWORD
    
    if grep -qxF "$MODULE" "$STATE_FILE"; then
        ((CURRENT_STEP++))
        log "Skipping completed module: $MODULE ($CURRENT_STEP/$TOTAL_STEPS)"
        continue
    fi
    
    ((CURRENT_STEP++))
    echo ""
    echo -e "${H_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${H_CYAN}  [$CURRENT_STEP/$TOTAL_STEPS] Running: $MODULE${NC}"
    echo -e "${H_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    MODULE_START=$(date +%s)
    
    if [ -f "$SCRIPT_PATH" ]; then
        if bash "$SCRIPT_PATH"; then
            MODULE_END=$(date +%s)
            MODULE_DURATION=$((MODULE_END - MODULE_START))
            echo "$MODULE" >> "$STATE_FILE"
            success "Module $MODULE completed. (${MODULE_DURATION}秒)"
        else
            MODULE_END=$(date +%s)
            MODULE_DURATION=$((MODULE_END - MODULE_START))
            error "Module $MODULE failed! (耗时 ${MODULE_DURATION}秒)"
            echo ""
            echo -e "   ${H_YELLOW}>>> 安装停止在模块: $MODULE${NC}"
            echo -e "   ${H_YELLOW}>>> 请检查错误日志: /tmp/log-noek-arch-setup.txt${NC}"
            echo -e "   ${H_YELLOW}>>> 修复问题后重新运行脚本即可继续安装（支持断点续传）${NC}"
            echo -e "   ${H_YELLOW}>>> 或运行: sudo $0 恢复安装${NC}"
            exit 1
        fi
    else
        warn "Script not found: $SCRIPT_PATH. Skipping..."
    fi
done

# ==============================================================================
# Sync Dotfiles
# ==============================================================================
echo ""
echo -e "${H_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${H_CYAN}  Syncing Dotfiles...${NC}"
echo -e "${H_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

DOTFILES_DIR="$BASE_DIR/dotfiles"
if [ -d "$DOTFILES_DIR/.config" ]; then
    # Detect target user
    if [ -f "/tmp/noek_install_user" ]; then
        TARGET_USER=$(cat "/tmp/noek_install_user")
    fi
    
    if [ -n "$TARGET_USER" ]; then
        HOME_DIR="/home/$TARGET_USER"
        log "Syncing dotfiles to $HOME_DIR..."
        
        # Copy .config contents
        if [ -d "$DOTFILES_DIR/.config" ]; then
            for item in "$DOTFILES_DIR/.config"/*; do
                if [ -e "$item" ]; then
                    item_name=$(basename "$item")
                    dest="$HOME_DIR/.config/$item_name"
                    
                    # Backup existing config
                    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
                        backup_dir="$HOME_DIR/.config/backup.noek.$(date +%Y%m%d_%H%M%S)"
                        mkdir -p "$backup_dir"
                        mv "$dest" "$backup_dir/$item_name" 2>/dev/null
                        log "Backed up existing $item_name to $backup_dir"
                    fi
                    
                    # Copy new config
                    if cp -rf "$item" "$dest"; then
                        chown -R "$TARGET_USER:" "$dest" && log "  [OK] $item_name" || warn "  权限设置失败: $item_name"
                    else
                        warn "  复制失败: $item_name"
                    fi
                fi
            done
            success "Dotfiles synced successfully."
        fi
    else
        warn "无法检测目标用户，跳过 dotfiles 同步。"
    fi
else
    log "未找到 dotfiles 目录，跳过同步。"
fi

# ==============================================================================
# Installation Complete - Welcome Screen
# ==============================================================================
echo ""
echo -e "${H_GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${H_GREEN}║                                                              ║${NC}"
echo -e "${H_GREEN}║           🎉 安装完成！Installation Complete!               ║${NC}"
echo -e "${H_GREEN}║                                                              ║${NC}"
echo -e "${H_GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${H_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${H_CYAN}  接下来的步骤 (Next Steps):${NC}"
echo -e "${H_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "   ${H_GREEN}1.${NC} 重启系统: ${BOLD}sudo reboot${NC}"
echo -e "   ${H_GREEN}2.${NC} 在登录界面选择你的桌面环境"
echo -e "   ${H_GREEN}3.${NC} 首次登录后，查看使用文档:"
echo -e "      ${DIM}~/必看-${DESKTOP_ENV^}使用方法.txt${NC}"
echo ""
echo -e "${H_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${H_CYAN}  常用命令 (Quick Commands):${NC}"
echo -e "${H_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "   ${H_YELLOW}更新系统:${NC}       sudo pacman -Syu"
echo -e "   ${H_YELLOW}安装软件:${NC}       yay -S <包名>"
echo -e "   ${H_YELLOW}系统信息:${NC}       fastfetch"
echo -e "   ${H_YELLOW}系统监控:${NC}       btop"
echo -e "   ${H_YELLOW}文件管理:${NC}       yazi"
echo -e "   ${H_YELLOW}创建快照:${NC}       sudo snapper -c root create"
echo -e "   ${H_YELLOW}恢复快照:${NC}       quickload"
echo -e "   ${H_YELLOW}卸载脚本:${NC}       sudo ~/noek-arch-setup/de-undochange.sh"
echo ""
echo -e "${H_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${H_CYAN}  安装日志 (Installation Log):${NC}"
echo -e "${H_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "   ${DIM}/tmp/log-noek-arch-setup.txt${NC}"
echo ""
echo -e "${H_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${H_GREEN}  感谢使用 Noek Arch Setup！${NC}"
echo -e "${H_GREEN}  GitHub: https://github.com/noek-linux/noek-arch-setup${NC}"
echo -e "${H_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Auto reboot prompt
read -t 10 -p "$(echo -e "   ${H_YELLOW}是否现在重启？[y/N] (10秒后自动跳过): ${NC}")" reboot_choice || true
reboot_choice=${reboot_choice:-N}

if [[ "${reboot_choice,,}" != "n" ]]; then
    echo -e "${H_CYAN}>>> 3秒后重启...${NC}"
    sleep 3
    reboot
fi
