#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Utility Functions
# ==============================================================================

export NC='\033[0m'
export BOLD='\033[1m'
export DIM='\033[2m'
export ITALIC='\033[3m'
export UNDER='\033[4m'
export H_MAGENTA='\033[1;35m'
export H_RED='\033[1;31m'
export H_GREEN='\033[1;32m'
export H_YELLOW='\033[1;33m'
export H_BLUE='\033[1;34m'
export H_PURPLE='\033[1;35m'
export H_CYAN='\033[1;36m'
export H_WHITE='\033[1;37m'
export H_GRAY='\033[1;90m'

export BG_BLUE='\033[44m'
export BG_PURPLE='\033[45m'

export TICK="${H_GREEN}✔${NC}"
export CROSS="${H_RED}✘${NC}"
export INFO="${H_BLUE}ℹ${NC}"
export WARN="${H_YELLOW}⚠${NC}"
export ARROW="${H_CYAN}➜${NC}"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${H_RED}   $CROSS CRITICAL ERROR: Script must be run as root.${NC}"
        exit 1
    fi
}
check_root

detect_target_user() {
    if [[ -f "/tmp/noek_install_user" ]]; then
        TARGET_USER=$(cat "/tmp/noek_install_user")
        HOME_DIR="/home/$TARGET_USER"
        export TARGET_USER HOME_DIR
        return 0
    fi
    
    log "Detecting system users..."
    
    mapfile -t HUMAN_USERS < <(awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/passwd)
    local UID_1000_USER
    UID_1000_USER=$(awk -F: '$3 == 1000 {print $1}' /etc/passwd | head -n 1)
    
    if [[ ${#HUMAN_USERS[@]} -gt 0 ]]; then
        echo -e "   ${H_YELLOW}>>> Existing users detected. Select target or create new:${NC}"
        
        local default_user=""
        local default_idx=""
        
        for i in "${!HUMAN_USERS[@]}"; do
            local mark=""
            local display_idx=$((i + 1))
            
            if [[ "${HUMAN_USERS[$i]}" == "$UID_1000_USER" ]]; then
                mark="${H_CYAN}*${NC}"
                default_user="${HUMAN_USERS[$i]}"
                default_idx="$display_idx"
            elif [[ -z "$default_user" && "${HUMAN_USERS[$i]}" == "${SUDO_USER:-}" ]]; then
                mark="${H_CYAN}*${NC}"
                default_user="${HUMAN_USERS[$i]}"
                default_idx="$display_idx"
            fi
            
            echo -e "       [${display_idx}] ${mark}${HUMAN_USERS[$i]}"
        done
        
        if [[ -z "$default_user" ]]; then
            default_user="${HUMAN_USERS[0]}"
            default_idx="1"
        fi
        
        echo -e "       [0] ${H_GREEN}Create a NEW user ++${NC}"
        
        while true; do
            echo -ne "   ${H_CYAN}Select user ID [0-${#HUMAN_USERS[@]}] (Default ${default_idx}, 30s timeout): ${NC}"
            
            if ! read -t 30 -r idx; then
                echo
                TARGET_USER="$default_user"
                log "Timeout (30s). Auto-selecting default user: ${H_CYAN}${TARGET_USER}${NC}"
                break
            fi
            
            if [[ -z "$idx" && -n "$default_user" ]]; then
                TARGET_USER="$default_user"
                log "Defaulting to user: ${H_CYAN}${TARGET_USER}${NC}"
                break
            fi
            
            if [[ "$idx" == "0" ]]; then
                TARGET_USER=""
                break
            elif [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le "${#HUMAN_USERS[@]}" ]; then
                TARGET_USER="${HUMAN_USERS[$((idx - 1))]}"
                break
            else
                warn "Invalid selection. Please enter a valid number."
            fi
        done
    else
        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            TARGET_USER="$SUDO_USER"
        else
            echo -e "   ${H_YELLOW}No standard user found in the system.${NC}"
            TARGET_USER=""
        fi
    fi
    
    if [[ -z "$TARGET_USER" ]]; then
        while true; do
            echo -ne "   ${H_GREEN}Please enter a username to CREATE:${NC} "
            read -r NEW_USER
            
            if [[ "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                TARGET_USER="$NEW_USER"
                break
            else
                warn "Invalid username format. Use lowercase letters, numbers, '-' or '_'."
            fi
        done
    fi
    
    echo "$TARGET_USER" > "/tmp/noek_install_user"
    HOME_DIR="/home/$TARGET_USER"
    export TARGET_USER HOME_DIR
}

export TEMP_LOG_FILE="/tmp/log-noek-arch-setup.txt"
touch "$TEMP_LOG_FILE" && chmod 600 "$TEMP_LOG_FILE"

write_log() {
    local clean_msg=$(echo -e "$2" | sed 's/\x1b\[[0-9;]*m//g')
    echo "[$(date '+%H:%M:%S')] [$1] $clean_msg" >> "$TEMP_LOG_FILE"
}

hr() {
    printf "${H_GRAY}%*s${NC}\n" "${COLUMNS:-80}" '' | tr ' ' '─'
}

section() {
    local title="$1"
    local subtitle="$2"
    echo ""
    echo -e "${H_PURPLE}╭──────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${H_PURPLE}│${NC} ${BOLD}${H_WHITE}$title${NC}"
    echo -e "${H_PURPLE}│${NC} ${H_CYAN}$subtitle${NC}"
    echo -e "${H_PURPLE}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    write_log "SECTION" "$title - $subtitle"
}

info_kv() {
    local key="$1"
    local val="$2"
    local extra="$3"
    printf "   ${H_BLUE}●${NC} %-15s : ${BOLD}%s${NC} ${DIM}%s${NC}\n" "$key" "$val" "$extra"
    write_log "INFO" "$key=$val"
}

log() {
    echo -e "   $ARROW $1"
    write_log "LOG" "$1"
}

success() {
    echo -e "   $TICK ${H_GREEN}$1${NC}"
    write_log "SUCCESS" "$1"
}

warn() {
    echo -e "   $WARN ${H_YELLOW}${BOLD}WARNING:${NC} ${H_YELLOW}$1${NC}"
    write_log "WARN" "$1"
}

error() {
    echo ""
    echo -e "${H_RED}   ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${H_RED}   ┃  ERROR: $1${NC}"
    echo -e "${H_RED}   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo ""
    write_log "ERROR" "$1"
}

exe() {
    local full_command="$*"
    
    echo -e "   ${H_GRAY}┌──[ ${H_MAGENTA}EXEC${H_GRAY} ]────────────────────────────────────────────────────${NC}"
    echo -e "   ${H_GRAY}│${NC} ${H_CYAN}$ ${NC}${BOLD}$full_command${NC}"
    
    write_log "EXEC" "$full_command"
    
    "$@"
    local status=$?
    
    if [ $status -eq 0 ]; then
        echo -e "   ${H_GRAY}└──────────────────────────────────────────────────────── ${H_GREEN}OK${H_GRAY} ─┘${NC}"
    else
        echo -e "   ${H_GRAY}└────────────────────────────────────────────────────── ${H_RED}FAIL${H_GRAY} ─┘${NC}"
        write_log "FAIL" "Exit Code: $status"
        return $status
    fi
}

exe_silent() {
    "$@" > /dev/null 2>&1
}

select_flathub_mirror() {
    local names=(
        "SJTU (上海交通大学镜像)"
        "USTC (中国科学技术大学镜像)"
        "FlatHub Official (官方源，国外用户)"
    )
    
    local urls=(
        "https://mirror.sjtu.edu.cn/flathub"
        "https://mirrors.ustc.edu.cn/flathub"
        "https://dl.flathub.org/repo/"
    )
    
    echo ""
    echo -e "${H_PURPLE}╭──────────────────────────────────────╮${NC}"
    echo -e "${H_PURPLE}│${NC}   ${BOLD}选择软件源镜像 (Select Flathub Mirror)${NC}"
    echo -e "${H_PURPLE}├──────────────────────────────────────┤${NC}"
    
    for i in "${!names[@]}"; do
        local name="${names[$i]}"
        local display_idx=$((i+1))
        
        if [ "$i" -eq 0 ]; then
            echo -e "${H_PURPLE}│${NC} ${H_CYAN}[$display_idx]${NC} $name - ${H_GREEN}推荐${NC}"
        else
            echo -e "${H_PURPLE}│${NC} ${H_CYAN}[$display_idx]${NC} $name"
        fi
    done
    
    echo -e "${H_PURPLE}╰──────────────────────────────────────╯${NC}"
    echo ""
    
    local choice
    read -t 60 -p "$(echo -e "   ${H_YELLOW}请输入选择 [1-${#names[@]}]: ${NC}")" choice
    if [ $? -ne 0 ]; then echo ""; fi
    choice=${choice:-1}
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#names[@]}" ]; then
        log "无效选择或超时。使用默认: SJTU..."
        choice=1
    fi
    
    local index=$((choice-1))
    local selected_name="${names[$index]}"
    local selected_url="${urls[$index]}"
    
    log "设置 Flathub 镜像为: ${H_GREEN}$selected_name${NC}"
    
    if exe flatpak remote-modify flathub --url="$selected_url"; then
        success "镜像源更新成功。"
    else
        error "镜像源更新失败。"
    fi
}

as_user() {
    runuser -u "$TARGET_USER" -- "$@"
}

check_dm_conflict() {
    if systemctl is-active --quiet display-manager 2>/dev/null; then
        local dm=$(systemctl status display-manager --no-pager | head -1 | awk '{print $2}')
        warn "Display manager ($dm) is currently running."
        warn "You may need to stop it before starting a new desktop environment."
    fi
}
