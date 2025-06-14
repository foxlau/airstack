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
highlight() { echo -e "${CYAN}${BOLD}$*${RESET}"; }
bold() { echo -e "${BOLD}$*${RESET}"; }

# Welcome message
welcome() {
    # Clear screen
    printf "\033c"

    local subtitle
    if [ -n "$*" ]; then
        subtitle="$*"
    else
        subtitle="Breeze through your web stack setup on Ubuntu 20.04+!"
    fi

    # ASCII logo
    ascii_logo="--------------------------------------------------------------------------------------
░░      ░░░        ░░       ░░░░░░░░░░      ░░░        ░░░      ░░░░      ░░░  ░░░░  ░
▒  ▒▒▒▒  ▒▒▒▒▒  ▒▒▒▒▒  ▒▒▒▒  ▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒  ▒▒▒▒  ▒▒  ▒▒▒▒  ▒▒  ▒▒▒  ▒▒
▓  ▓▓▓▓  ▓▓▓▓▓  ▓▓▓▓▓       ▓▓▓▓▓▓▓▓▓▓      ▓▓▓▓▓▓  ▓▓▓▓▓  ▓▓▓▓  ▓▓  ▓▓▓▓▓▓▓▓     ▓▓▓▓
█        █████  █████  ███  ███████████████  █████  █████        ██  ████  ██  ███  ██
█  ████  ██        ██  ████  █████████      ██████  █████  ████  ███      ███  ████  █
--------------------------------------------------------------------------------------
※ AirStack - ${subtitle}
--------------------------------------------------------------------------------------"
    echo -e "$(bold "${ascii_logo}")"
}

# Print a formatted, fixed-width title.
print_title() {
    local title=" $1 "
    local total_width=86
    local line
    line=$(printf "%${total_width}s" | tr ' ' '=')
    local title_len=${#title}

    if [ $title_len -ge $total_width ]; then
        # Fallback for very long titles
        echo -e "\n${BLUE}${BOLD}=== ${title} ===${RESET}"
        return
    fi
    
    local padding_total=$((total_width - title_len))
    local padding_left=$((padding_total / 2))
    
    # Build the title bar with consistent colors
    local left_bar="${line:0:$padding_left}"
    local right_bar_start=$((padding_left + title_len))
    local right_bar="${line:${right_bar_start}}"
    
    echo -e "\n${BLUE}${BOLD}${left_bar}${title}${right_bar}${RESET}"
}

# Helper function to print a progress bar (conservative version).
# Uses only safe ASCII characters to ensure compatibility.
print_bar() {
    local percentage=${1:-0}
    local width=${2:-20}
    
    # Use safe ASCII characters that work everywhere
    local char_filled="#"
    local char_empty="-"
    
    # Ensure percentage is an integer
    percentage=$(printf "%.0f" "$percentage")

    local filled_len=$((percentage * width / 100))
    local empty_len=$((width - filled_len))
    
    local filled=""
    local empty=""
    
    if [ "$filled_len" -gt 0 ]; then
        filled=$(printf "%${filled_len}s" | tr ' ' "$char_filled")
    fi
    if [ "$empty_len" -gt 0 ]; then
        empty=$(printf "%${empty_len}s" | tr ' ' "$char_empty")
    fi
    
    # Simple, reliable output
    printf "[%s%s%s%s]" "${GREEN}" "${filled}" "${RESET}" "${empty}"
}

# Function to display error messages and exit
error_exit() {
    error "$1" >&2
    exit 1
}

# Checks for root privileges and exits if not found.
require_sudo() {
    if [ "$(id -u)" != "0" ]; then
        error_exit "This script requires root privileges. Please run with sudo."
    fi
}

# Checks for root privileges without exiting.
# Returns 0 if user is root, 1 otherwise.
is_sudo() {
    if [ "$EUID" -ne 0 ]; then
        return 1
    else
        return 0
    fi
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