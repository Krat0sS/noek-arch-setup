#!/bin/bash

# ==============================================================================
# Noek Arch Setup - Emergency System Rollback
# ==============================================================================
# Usage: sudo ./de-undochange.sh
# Description: Reverts system to "Before Desktop Environments" using btrfs-assistant
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TARGET_DESC="Before Desktop Environments"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root (sudo ./de-undochange.sh)${NC}"
    exit 1
fi

if ! command -v snapper &> /dev/null; then
    echo -e "${RED}Error: Snapper is not installed.${NC}"
    exit 1
fi

if ! command -v btrfs-assistant &> /dev/null; then
    echo -e "${RED}Error: btrfs-assistant is not installed.${NC}"
    echo "Cannot perform subvolume rollback."
    exit 1
fi

echo -e "${YELLOW}>>> Initializing Emergency Rollback (Target: '$TARGET_DESC')...${NC}"

perform_rollback() {
    local subvol="$1"
    local snap_conf="$2"
    
    echo -e "Checking config: ${YELLOW}$snap_conf${NC} for subvolume: ${YELLOW}$subvol${NC}..."

    local snap_id=$(snapper -c "$snap_conf" list --columns number,description | grep "$TARGET_DESC" | tail -n 1 | awk '{print $1}')

    if [ -z "$snap_id" ]; then
        echo -e "${RED}  [SKIP] Snapshot '$TARGET_DESC' not found in config '$snap_conf'.${NC}"
        return 1
    fi

    echo -e "  Found Snapshot ID: ${GREEN}$snap_id${NC}"

    local ba_index=$(btrfs-assistant -l | awk -v v="$subvol" -v s="$snap_id" '$2==v && $3==s {print $1}')

    if [ -z "$ba_index" ]; then
        echo -e "${RED}  [FAIL] Could not map Snapper ID $snap_id to Btrfs-Assistant index.${NC}"
        return 1
    fi

    echo -e "  Executing rollback (Index: $ba_index)..."
    if btrfs-assistant -r "$ba_index"; then
        echo -e "  ${GREEN}Success.${NC}"
        return 0
    else
        echo -e "  ${RED}Restore command failed.${NC}"
        return 1
    fi
}

echo -e "${YELLOW}>>> Restoring Root Filesystem...${NC}"
if ! perform_rollback "@" "root"; then
    echo -e "${RED}CRITICAL FAILURE: Failed to restore root partition.${NC}"
    echo "Aborting operation to prevent partial system state."
    exit 1
fi

if snapper list-configs | grep -q "^home "; then
    echo -e "${YELLOW}>>> Restoring Home Filesystem...${NC}"
    if ! perform_rollback "@home" "home"; then
        echo -e "${RED}WARNING: Home rollback failed! Root may have been restored but home was not.${NC}"
        echo -e "${YELLOW}Check your home directory manually after reboot.${NC}"
    fi
else
    echo -e "No 'home' snapper config found, skipping home restore."
fi

echo -e "${GREEN}System rollback successful.${NC}"
echo -e "${YELLOW}Rebooting in 3 seconds...${NC}"
sleep 3
reboot
