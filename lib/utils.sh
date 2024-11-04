#!/bin/bash

# Check if stdout is a terminal
# If true, define ANSI color codes for output formatting
# If false (e.g. when piping output), use empty strings
if [[ -t 1 ]]; then
    # Basic colors
    RED='\033[0;31m'      # Red color for errors
    GREEN='\033[38;5;2m'  # Green color for success messages
    YELLOW='\033[0;33m'   # Yellow color for warnings
    BLUE='\033[38;5;33m'  # Bright blue color for better visibility
    CYAN="\033[38;5;51m"  # Cyan color for info messages
    BOLD='\033[1m'        # Bold text formatting
    RESET='\033[0m'       # Reset all formatting
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' RESET=''
fi

# Helper functions for formatted output
info() { echo -e "${CYAN}${BOLD}ℹ $*${RESET}"; }
success() { echo -e "${GREEN}${BOLD}✔ $*${RESET}"; }
error() { echo -e "${RED}${BOLD}✘ $*${RESET}"; }
warning() { echo -e "${YELLOW}${BOLD}⚠ $*${RESET}"; }
warning_plain() { echo -e "${YELLOW}$*${RESET}"; }
highlight() { echo -e "${BLUE}${BOLD}$*${RESET}"; }
bold() { echo -e "${BOLD}$*${RESET}"; }

# Welcome message
welcome() {
    # Clear screen
    printf "\033c"

    # ASCII logo
    ascii_logo="--------------------------------------------------------------------------------------
░░      ░░░        ░░       ░░░░░░░░░░      ░░░        ░░░      ░░░░      ░░░  ░░░░  ░
▒  ▒▒▒▒  ▒▒▒▒▒  ▒▒▒▒▒  ▒▒▒▒  ▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒  ▒▒▒▒  ▒▒  ▒▒▒▒  ▒▒  ▒▒▒  ▒▒
▓  ▓▓▓▓  ▓▓▓▓▓  ▓▓▓▓▓       ▓▓▓▓▓▓▓▓▓▓      ▓▓▓▓▓▓  ▓▓▓▓▓  ▓▓▓▓  ▓▓  ▓▓▓▓▓▓▓▓     ▓▓▓▓
█        █████  █████  ███  ███████████████  █████  █████        ██  ████  ██  ███  ██
█  ████  ██        ██  ████  █████████      ██████  █████  ████  ███      ███  ████  █
--------------------------------------------------------------------------------------
※ AirStack - Breeze through your web stack setup on Ubuntu 20.04+!
--------------------------------------------------------------------------------------"
    echo -e "$(bold "${ascii_logo}")"
}

# Function to display error messages and exit
error_exit() {
    error "$1" >&2
    exit 1
}

# Download a file
# $1: file name
# $2: primary url
download_file() {
    local cur_dir=$(pwd)
    if [ -s "$1" ]; then
        echo "$1 [found]"
    else
        echo "Starting download of $1..."
        if ! wget --no-check-certificate --progress=bar:force -cv -t3 -T10 -O ${1} ${2}; then
            rm -f "$1"  # Clean up partial download
            error "Failed to download $1"
            return 1
        fi
        echo "$1 download completed..."
    fi
}