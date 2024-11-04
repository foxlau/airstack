#! /bin/bash
# Install script for AirStack
# Supports installation of Node.js, Nginx, MySQL, PostgreSQL, Redis, and Fail2ban on Ubuntu20+

# Check if user is root
if [ "$(id -u)" != "0" ]; then
    error "This script requires root privileges. Please run with sudo."
    exit 1
fi

# Get script directory and set working directory
AIRSTACK_DIR=$(dirname "`readlink -f $0`")
pushd ${AIRSTACK_DIR} > /dev/null

. lib/utils.sh
. lib/oscheck.sh

welcome

# Common variables
LOG_FILE="${AIRSTACK_DIR}/logs/install_$(date +%Y%m%d_%H%M%S).log"
MYSQL_ROOT_PASSWORD="rootair"
POSTGRES_PASSWOR="rootair"
SELECTED_INSTALLATIONS=()
SUCCESSFUL_INSTALLATIONS=()

# Ask for Node.js stack installation
while true; do echo
    read -p "Do you want to install the web server stack? (Y/n): " yn
    case $yn in
        [Yy]*|"" ) 
            SELECTED_INSTALLATIONS+=("nginx" "nodejs")
            highlight "The following components will be installed:"
            highlight "- Nginx (HTTP Server)"
            highlight "- Node.js (JavaScript Runtime Environment)"
            highlight "- PM2 (Process Manager for Node.js)"
            break;;
        [Nn]* ) 
            highlight "Web server stack installation skipped."
            break;;
        * ) 
            error "Invalid input. Please enter 'y' for yes or 'n' for no."
    esac
done

# Database selection
while true; do echo
    echo "Select a database management system to install:"
    highlight "1) MySQL (Relational Database)"
    highlight "2) PostgreSQL (Object-Relational Database)"
    highlight "n) Skip database installation"
    read -p "Select an option (1-2/n): " db_choice
    case $db_choice in
        1)
            SELECTED_INSTALLATIONS+=("mysql")
            highlight "MySQL selected. Default root password: $MYSQL_ROOT_PASSWORD"
            break;;
        2)
            SELECTED_INSTALLATIONS+=("postgresql")
            highlight "PostgreSQL selected. Default superuser password: $POSTGRES_PASSWOR"
            break;;
        [Nn]*|"")
            highlight "Database installation skipped."
            break;;
        *)
            error "Invalid input. Please enter 1, 2, or n."
    esac
done

# Ask for Redis installation
while true; do echo
    read -p "Do you want to install Redis (in-memory data store)? (y/N): " yn
    case $yn in
        [Yy]* )
            SELECTED_INSTALLATIONS+=("redis")
            highlight "Redis in-memory data store will be installed."
            break;;
        [Nn]*|"" )
            highlight "Redis installation skipped."
            break;;
        * ) 
            error "Invalid input. Please enter 'y' for yes or 'n' for no."
    esac
done

# Ask for Fail2ban installation
while true; do echo
    read -p "Do you want to install Fail2ban (Intrusion Prevention System)? (y/N): " yn
    case $yn in
        [Yy]* )
            SELECTED_INSTALLATIONS+=("fail2ban")
            highlight "Fail2ban will be installed."
            break;;
        [Nn]*|"" )
            highlight "Fail2ban installation skipped."
            break;;
        * ) 
            error "Invalid input. Please enter 'y' for yes or 'n' for no."
    esac
done

# Installation confirmation
if [ ${#SELECTED_INSTALLATIONS[@]} -gt 0 ]; then
    while true; do echo
        read -p "Review selections and proceed with installation? (Y/n): " confirm
        case $confirm in
            [Yy]*|"" ) 
                echo "(${OS_TYPE} ${OS_VERSION}) - $(date '+%Y-%m-%d %H:%M:%S') - Initiating installation of: [${SELECTED_INSTALLATIONS[@]}]" >> ${LOG_FILE}
                break;;
            [Nn]* ) 
                warning_plain "Installation cancelled by user."
                exit 0;;
            * ) 
                error "Invalid input. Please enter 'y' for yes or 'n' for no."
        esac
    done
else
    warning_plain "No components selected for installation."
    exit 0
fi

# Perform installation
do_installation() {
    start_time=$(date +%s)
    mkdir -p "${AIRSTACK_DIR}/logs"

    if [ ! -f ~/.airstack ]; then
        echo
        info "Configuring system..."
        . lib/osconfig.sh
    fi

    # TODO: This may not be the best practice
    for item in "${SELECTED_INSTALLATIONS[@]}"; do echo
        info "Installing ${item^}..."
        . "lib/installers/${item}.sh"
        if install; then
            SUCCESSFUL_INSTALLATIONS+=("$item")
        fi
    done
}

# Display installation summary
show_installation_summary() {
    echo -e "\n--------------------------------------------------------------------------------------"
    info "Installed Software:"

    for item in "${SUCCESSFUL_INSTALLATIONS[@]}"; do echo
        case $item in
            "nginx")
                highlight "- Nginx"
                echo "  Config files: /etc/nginx/"
                echo "  Usage: systemctl {start|stop|restart} nginx"
                ;;
            "nodejs")
                highlight "- Node.js"
                echo "  Global config: $(npm config get prefix 2>/dev/null || echo 'Not found')"
                echo "  PM2 usage: pm2 {start|stop|restart|status}"
                ;;
            "mysql")
                highlight "- MySQL"
                echo "  Config files: /etc/mysql/"
                warning_plain "  Root Password: ${MYSQL_ROOT_PASSWORD}, Please change it after installation!"
                echo "  Usage: systemctl {start|stop|restart|status} mysql"
                ;;
            "postgresql")
                highlight "- PostgreSQL"
                echo "  Config files: /etc/postgresql/"
                warning_plain "  Password: ${MYSQL_ROOT_PASSWORD}, Please change it after installation!"
                echo "  Usage: systemctl {start|stop|restart|status} postgresql"
                ;;
            "redis")
                highlight "- Redis"
                echo "  Config files: /etc/redis/"
                echo "  Usage: systemctl {start|stop|restart|status} redis"
                ;;
            "fail2ban")
                highlight "- Fail2ban"
                echo "  Usage: fail2ban-client status"
                ;;
        esac
    done

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))

    echo -e "\nInstallation time: ${minutes}m ${seconds}s"
    echo -e "Installation log: $LOG_FILE\n"
    success "Installation Complete."
    echo -e "--------------------------------------------------------------------------------------\n"
}

# Perform installation
do_installation > >(tee -a "${LOG_FILE}") 2>&1

# Display installation summary
if [ ${#SUCCESSFUL_INSTALLATIONS[@]} -gt 0 ]; then
    show_installation_summary 2>&1 | tee -a ${LOG_FILE}
    read -p "Do you want to reboot the system now? (y/N): " reboot_choice
    if [[ "${reboot_choice,,}" =~ ^y(es)?$ ]]; then
        success "System will reboot now..."
        /sbin/reboot
    else
        warning_plain "Please remember to reboot your system later to ensure all changes take effect."
    fi
else
    exit 1
fi

popd > /dev/null