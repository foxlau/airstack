#!/bin/bash
# Uninstall script for AirStack

# Get script directory and set working directory
AIRSTACK_DIR=$(dirname "`readlink -f $0`")
pushd ${AIRSTACK_DIR} > /dev/null

. lib/utils.sh
. lib/oscheck.sh

# Privilege check
require_sudo

# Welcome message
welcome "Uninstaller"
warning "Please ensure all data is backed up before proceeding with uninstallation."

# Component list
INSTALLED_COMPONENTS=(
    "Node.js (JavaScript Runtime Environment)"
    "Nginx (HTTP Server)"
    "MySQL (Relational Database)"
    "PostgreSQL (Object-Relational Database)"
    "Redis (In-Memory Data Store)"
    "Fail2ban (Intrusion Prevention System)"
)

# Display available components
echo -e "\nSelect components to uninstall:"
for i in "${!INSTALLED_COMPONENTS[@]}"; do
    highlight "$((i+1))) ${INSTALLED_COMPONENTS[$i]}"
done
highlight "q) Exit"

# Main uninstallation loop
while true; do echo
    read -p "Enter component numbers to uninstall (space-separated, e.g., '1 2 3'): " input

    # Input validation
    if [[ -z "$input" ]]; then
        error "No selection made. Please enter at least one component number."
        continue
    fi

    if [[ $input == "q" ]]; then
        warning_plain "Uninstallation cancelled."
        exit 0
    fi

    # Convert input to array
    IFS=' ' read -ra selections <<< "$input"

    # Validate selections
    valid_selections=()
    invalid_selections=()
    for selection in "${selections[@]}"; do
        if [[ $selection =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#INSTALLED_COMPONENTS[@]}" ]; then
            valid_selections+=("$selection")
        else
            invalid_selections+=("$selection")
        fi
    done

    # Display invalid selections if any
    if [ ${#invalid_selections[@]} -ne 0 ]; then
        error "Invalid selections: ${invalid_selections[*]}"
        continue
    fi

    # Confirmation display
    echo
    echo "The following components will be uninstalled:"
    for selection in "${valid_selections[@]}"; do
        highlight "- ${INSTALLED_COMPONENTS[$((selection-1))]}"
    done

    # Final confirmation
    echo
    read -p "Proceed with uninstallation? (y/N): " confirm
    if [[ $confirm = [Yy]* ]]; then
        for selection in "${valid_selections[@]}"; do echo
            component_name="${INSTALLED_COMPONENTS[$((selection-1))]}"
            filename=$(echo "$component_name" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]' | tr -d '.')
            info "Uninstalling ${component_name}..."
            . "lib/installers/${filename}.sh" && uninstall
        done
    else
        warning_plain "Uninstallation cancelled by user."
    fi

    break
done

popd > /dev/null