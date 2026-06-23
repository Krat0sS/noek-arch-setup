#!/usr/bin/env bash

# ==============================================================================
# Noek Arch Setup - Bootstrap Script
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$(uname -s)" != "Linux" ]; then
    printf "%bError: This installer only supports Linux systems.%b\n" "$RED" "$NC"
    exit 1
fi

ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    printf "%bError: Unsupported architecture: %s%b\n" "$RED" "$ARCH" "$NC"
    exit 1
fi

# ==============================================================================
# Network Check
# ==============================================================================
printf "%b>>> 检测网络连接...%b\n" "$BLUE" "$NC"
if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
    printf "%bError: 网络连接失败！请确保已连接网络。%b\n" "$RED" "$NC"
    exit 1
fi
printf "%b   ✔ 网络连接正常%b\n" "$GREEN" "$NC"

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        if ! command -v sudo >/dev/null 2>&1; then
            printf "%bError: 'sudo' command not found. Please run this script as root.%b\n" "$RED" "$NC"
            exit 1
        fi
        sudo "$@"
    fi
}

TARGET_BRANCH="${BRANCH:-main}"
REPO_URL="${REPO_URL:-https://github.com/Krat0sS/noek-arch-setup}"
GITEE_URL="${GITEE_URL:-https://gitee.com/noek-linux/noek-arch-setup}"
TARBALL_URL="${REPO_URL}/archive/refs/heads/${TARGET_BRANCH}.tar.gz"
GITEE_TARBALL_URL="${GITEE_URL}/archive/refs/heads/${TARGET_BRANCH}.tar.gz"
TARGET_DIR="/tmp/noek-arch-setup"

printf "%b>>> Preparing to install from branch: %s%b\n" "$BLUE" "$TARGET_BRANCH" "$NC"

MISSING_PKGS=()

for cmd in curl tar git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_PKGS+=("$cmd")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    run_as_root pacman -Sy --noconfirm --needed "${MISSING_PKGS[@]}" >/dev/null 2>&1
fi

if [ -d "$TARGET_DIR" ]; then
    run_as_root rm -rf "$TARGET_DIR"
fi
mkdir -p "$TARGET_DIR"

printf "Downloading and extracting repository to %s...\n" "$TARGET_DIR"

download_extract() {
    local url="$1"
    curl -sSLf "$url" | tar -xz -C "$TARGET_DIR" --strip-components=1 2>/dev/null
}

# Try GitHub first, fall back to Gitee
for attempt in 1 2 3; do
    local dl_url="$TARBALL_URL"
    if [ "$attempt" -ge 2 ]; then
        dl_url="$GITEE_TARBALL_URL"
        printf "%b>>> GitHub failed, trying Gitee mirror...%b\n" "$YELLOW" "$NC"
    fi

    if download_extract "$dl_url"; then
        run_as_root chmod 755 "$TARGET_DIR"
        printf "%b\nDownload and extraction successful.%b\n" "$GREEN" "$NC"
        break
    fi
    
    if [ "$attempt" -eq 3 ]; then
        printf "%bError: Failed to download after 3 attempts (GitHub + Gitee).%b\n" "$RED" "$NC"
        printf "%bPlease check your network and try again.%b\n" "$YELLOW" "$NC"
        exit 1
    fi
    
    printf "%bWarning: Download failed (attempt %d/3). Retrying...%b\n" "$RED" "$attempt" "$NC"
    sleep 3
    run_as_root rm -rf "$TARGET_DIR"
    mkdir -p "$TARGET_DIR"
done

cd "$TARGET_DIR"
printf "Starting installer...\n"
run_as_root bash install.sh < /dev/tty
