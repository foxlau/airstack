#!/bin/bash
# Server Check Script for AirStack

# Source utility functions
# Ensure lib/utils.sh is in the same directory or adjust the path
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

. "$SCRIPT_DIR/lib/utils.sh"

# Privilege check - Most security checks require sudo
require_sudo

# --- Log directory for reports ---
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR" # Ensure log directory exists

# --- SYSTEM INFORMATION ---
get_system_info() {
    print_title "SYSTEM INFORMATION"
    local hostname_val
    hostname_val=$(hostname)
    local os_val
    os_val=$(source /etc/os-release && echo "$PRETTY_NAME")
    local kernel_val
    kernel_val=$(uname -r)
    local uptime_val
    uptime_val=$(uptime -p)
    local current_date
    current_date=$(date)

    printf "%-20s: %s\n" "Hostname" "$(bold "$hostname_val")"
    printf "%-20s: %s\n" "Operating System" "$os_val"
    printf "%-20s: %s\n" "Kernel Version" "$kernel_val"
    printf "%-20s: %s\n" "System Uptime" "$uptime_val"
    printf "%-20s: %s\n" "Current Date" "$current_date"
}

# --- RESOURCE USAGE ---
get_resource_usage() {
    print_title "RESOURCE USAGE"

    local top_output
    top_output=$(top -bn1) 

    local cpu_info_line
    cpu_info_line=$(echo "$top_output" | grep '%Cpu(s)')
    local cpu_user_val cpu_system_val cpu_idle_val cpu_used_percent_val
    if [[ "$cpu_info_line" =~ us,([[:space:]]*[0-9.]+)[[:space:]]*sy,([[:space:]]*[0-9.]+).*ni,([[:space:]]*[0-9.]+)[[:space:]]*id ]]; then 
      cpu_user_val=$(echo "$cpu_info_line" | awk -F'[ ,]+' '{print $2}') 
      cpu_system_val=$(echo "$cpu_info_line" | awk -F'[ ,]+' '{print $4}') 
      cpu_idle_val=$(echo "$cpu_info_line" | awk -F'[ ,]+' '{print $8}') 
    elif [[ "$cpu_info_line" =~ Cpu\(s\):([[:space:]]*[0-9\.]+)%us,([[:space:]]*[0-9\.]+)%sy, ]]; then 
      cpu_user_val=$(echo "$cpu_info_line" | awk -F'[:% ,]+' '{print $3}')
      cpu_system_val=$(echo "$cpu_info_line" | awk -F'[:% ,]+' '{print $5}')
      cpu_idle_val=$(echo "$cpu_info_line" | awk -F'[:% ,]+' '{print $11}') 
    else
      warning "Could not parse CPU info from top accurately."
      cpu_user_val="N/A"; cpu_system_val="N/A"; cpu_idle_val="N/A"
    fi

    if [[ "$cpu_idle_val" != "N/A" ]]; then
        cpu_used_percent_val=$(awk -v idle="$cpu_idle_val" 'BEGIN { printf "%.0f", 100 - idle }')
    else
        cpu_used_percent_val="N/A"
    fi
    
    local cpu_bar_val
    cpu_bar_val=$(print_bar "$cpu_used_percent_val" 20)
    printf "%-10s: %b %-4s%% %s\n" "CPU" "$cpu_bar_val" "$cpu_used_percent_val" "$(highlight "(User: ${cpu_user_val}%, Sys: ${cpu_system_val}%)")"
    
    local tasks_info_line tasks_summary_val
    tasks_info_line=$(echo "$top_output" | grep 'Tasks:')
    tasks_summary_val=$(echo "$tasks_info_line" | awk -F': ' '{print $2}' | sed 's/,   */, /g' | sed 's/, 0 stopped//g' | sed 's/, 0 zombie//g')
    printf "%-10s: %s\n" "Tasks" "$(bold "$tasks_summary_val")"

    local load_avg_val
    load_avg_val=$(uptime | awk -F'load average: ' '{print $2}')
    printf "%-10s: %s\n" "Load Avg" "$(bold "$load_avg_val")"

    local mem_info_line mem_total_val mem_available_val mem_used_val mem_percent_val
    mem_info_line=$(free -m | grep Mem:)
    mem_total_val=$(echo "$mem_info_line" | awk '{print $2}')
    mem_available_val=$(echo "$mem_info_line" | awk '{print $7}') 
    
    mem_used_val=$((mem_total_val - mem_available_val))
    mem_percent_val=0
    if [ "$mem_total_val" -gt 0 ]; then
        mem_percent_val=$((mem_used_val * 100 / mem_total_val))
    fi
    local mem_bar_val
    mem_bar_val=$(print_bar "$mem_percent_val" 20)
    printf "%-10s: %b %-4s%% %s\n" "Memory" "$mem_bar_val" "$mem_percent_val" "$(highlight "(${mem_used_val}M / ${mem_total_val}M used)")"

    local swap_info_line swap_total_val swap_used_val swap_percent_val
    swap_info_line=$(free -m | grep Swap:)
    swap_total_val=$(echo "$swap_info_line" | awk '{print $2}')
    swap_used_val=$(echo "$swap_info_line" | awk '{print $3}')
    swap_percent_val=0
    if [ "$swap_total_val" -gt 0 ]; then
        swap_percent_val=$((swap_used_val * 100 / swap_total_val))
    fi
    local swap_bar_val
    swap_bar_val=$(print_bar "$swap_percent_val" 20)
    printf "%-10s: %b %-4s%% %s\n" "Swap" "$swap_bar_val" "$swap_percent_val" "$(highlight "(${swap_used_val}M / ${swap_total_val}M used)")"
}

# --- DISK USAGE ---
get_disk_usage() {
    print_title "DISK USAGE"
    df -hT --exclude-type=tmpfs --exclude-type=squashfs --exclude-type=devtmpfs
}

# --- TOP PROCESSES ---
get_top_processes() {
    print_title "TOP 10 PROCESSES"
    highlight "By CPU Usage:"
    ps -eo pcpu,user:15,pid,comm --sort=-pcpu | head -n 11
    echo ""
    highlight "By Memory Usage:"
    ps -eo pmem,user:15,pid,comm --sort=-pmem | head -n 11
}

# --- SERVICE STATUS ---
get_service_status() {
    print_title "SERVICE STATUS"
    declare -A services_to_check
    services_to_check=(
        ["Nginx"]="nginx"
        ["Apache2"]="apache2"
        ["MySQL"]="mysql" # Will be resolved to mysql or mysqld or mariadb
        ["PostgreSQL"]="postgresql"
        ["Redis Server"]="redis-server"
        ["PHP-FPM"]="php[0-9]\.[0-9]-fpm" # Regex for PHP-FPM versions
        ["Cron Daemon"]="cron" # Or "crond" on some systems like CentOS/RHEL
    )

    for display_name in "${!services_to_check[@]}"; do
        local service_pattern="${services_to_check[$display_name]}"
        local actual_service_name_found=""
        local service_status_text

        # --- Logic to find the actual service name ---
        if [[ "$service_pattern" == *"["*"]"* ]]; then # Regex pattern (e.g., PHP-FPM)
            actual_service_name_found=$(systemctl list-units --type=service --all --no-legend --plain | \
                                      awk '{print $1}' | grep -E "^${service_pattern}\.service$" | head -n 1)
        elif [ "$service_pattern" = "mysql" ]; then # MySQL/MariaDB variants
            if systemctl list-units --type=service --all | grep -qiw "mysql.service"; then
                actual_service_name_found="mysql.service"
            elif systemctl list-units --type=service --all | grep -qiw "mysqld.service"; then
                actual_service_name_found="mysqld.service"
            elif systemctl list-units --type=service --all | grep -qiw "mariadb.service"; then
                actual_service_name_found="mariadb.service"
            fi
        elif [ "$service_pattern" = "cron" ]; then # Cron variants
            if systemctl list-units --type=service --all | grep -qiw "cron.service"; then
                actual_service_name_found="cron.service"
            elif systemctl list-units --type=service --all | grep -qiw "crond.service"; then # For CentOS/RHEL
                actual_service_name_found="crond.service"
            fi
        # Removed specific SSHD check block as it's no longer in services_to_check
        else # Standard service check (for others like nginx, postgresql, redis-server etc.)
            local potential_match
            # --plain removes special characters from unit names sometimes seen with `list-units`
            potential_match=$(systemctl list-units --type=service --all --no-legend --plain | \
                                awk '{print $1}' | grep -i "^${service_pattern}\.service$" | head -n 1)
            if [ -n "$potential_match" ]; then
                if systemctl cat "$potential_match" &>/dev/null; then 
                    actual_service_name_found="$potential_match"
                fi
            fi
        fi
        # --- End of logic to find service name ---

        if [ -n "$actual_service_name_found" ]; then
            if systemctl is-active --quiet "$actual_service_name_found"; then
                service_status_text="${GREEN}● Running${RESET}"
            elif systemctl is-enabled --quiet "$actual_service_name_found"; then
                 service_status_text="${YELLOW}○ Enabled but Stopped${RESET}"
            else 
                if systemctl is-failed --quiet "$actual_service_name_found"; then
                    service_status_text="${RED}✗ Failed${RESET}"
                else
                    service_status_text="${RED}○ Inactive/Disabled${RESET}"
                fi
            fi
            printf "%-20s: %b\n" "$display_name" "$service_status_text"
        # else: Service unit not found, print nothing for it.
        fi
    done
    
    # --- PM2 Daemon ---
    local pm2_daemon_status_text
    if pgrep -f "PM2.*God Daemon" > /dev/null; then
        pm2_daemon_status_text="${GREEN}● Running${RESET}"
    else
        pm2_daemon_status_text="${RED}○ Stopped${RESET}"
    fi
    printf "%-20s: %b\n" "PM2 Daemon" "$pm2_daemon_status_text"

    # --- Fail2ban ---
    if command -v fail2ban-client &> /dev/null; then
        local f2b_status_text_val
        if fail2ban-client status &> /dev/null; then 
            f2b_status_text_val="${GREEN}● Running${RESET}"
        else
            if systemctl list-units --type=service --all | grep -qiw "fail2ban.service"; then
                 f2b_status_text_val="${RED}○ Installed but Stopped/Failed${RESET}"
            else
                 f2b_status_text_val="${YELLOW}○ Client found, Service Unit Missing?${RESET}" 
            fi
        fi
        printf "%-20s: %b\n" "Fail2ban" "$f2b_status_text_val"
    fi
}

# --- PM2 MANAGED APPLICATIONS ---
get_pm2_apps() {
    if pgrep -f "PM2.*God Daemon" > /dev/null; then
        print_title "PM2 MANAGED APPLICATIONS"
        local pm2_instance_users
        pm2_instance_users=$(ps -eo user:15,command | grep "[P]M2.*God Daemon" | awk '{print $1}' | sort -u)

        if [ -n "$pm2_instance_users" ]; then
            for pm2_user in $pm2_instance_users; do
                highlight "PM2 instance for user: $(bold "$pm2_user")"
                if ! sudo -i -u "$pm2_user" bash -c 'command -v pm2 &>/dev/null'; then
                    warning "User '$pm2_user' is running PM2, but 'pm2' command is not in their interactive PATH."
                    warning "Attempting to list PM2 apps anyway, but this might fail or show incomplete info."
                fi
                local pm2_list_output
                pm2_list_output=$(sudo -i -u "$pm2_user" bash -c 'pm2 list' 2>&1)
                if [ $? -eq 0 ] && [[ "$pm2_list_output" != *"PM2
[ERROR]"* ]] && [[ "$pm2_list_output" == *"PM2 list"* || "$pm2_list_output" == *"┌───"* ]]; then
                    echo "$pm2_list_output"
                elif [[ "$pm2_list_output" == *"No such file or directory"* || "$pm2_list_output" == *"command not found"* ]]; then
                    error "Could not execute 'pm2 list' for user '$pm2_user'. PM2 might not be correctly set up in their PATH."
                elif [[ "$pm2_list_output" == *"No processes managed by pm2"* || "$pm2_list_output" == *"PM2 [LIST] No GPMD"* || "$pm2_list_output" == *"[PM2] Spawning PM2 daemon with pm2_home"* ]]; then
                     info "User '$pm2_user' has no active PM2 managed processes."
                else
                    warning "Could not retrieve PM2 list for user '$pm2_user', or list was empty/error."
                    echo "Raw output:"
                    echo "$pm2_list_output" | head -n 5 
                fi
                echo "" 
            done
        else
            info "PM2 daemon process found, but could not determine user ownership for instances."
        fi
    fi
}

# -----------------------------------------------------------------------------
# --- SECURITY AUDIT SECTION ---
# -----------------------------------------------------------------------------
SECURITY_AUDIT_REPORT_CONTENT="" # Global for security audit report
SECURITY_AUDIT_ERRORS=0
SECURITY_AUDIT_WARNINGS=0
SECURITY_AUDIT_INFO_ITEMS=0 # To track informational items for summary

# Helper to add to the security audit report string
add_to_sec_report() {
    local type_icon="$1"
    local message="$2"
    # Append with a newline for readability in the report file
    SECURITY_AUDIT_REPORT_CONTENT+="${type_icon} ${message}\n"
    if [[ "$type_icon" == *"✗"* ]]; then
        SECURITY_AUDIT_ERRORS=$((SECURITY_AUDIT_ERRORS + 1))
    elif [[ "$type_icon" == *"!"* ]]; then
        SECURITY_AUDIT_WARNINGS=$((SECURITY_AUDIT_WARNINGS + 1))
    elif [[ "$type_icon" == *"ℹ"* ]]; then # Assuming info uses an info icon
        SECURITY_AUDIT_INFO_ITEMS=$((SECURITY_AUDIT_INFO_ITEMS + 1))
    fi
}

# --- 1. User Account ---
audit_user_accounts() {
    print_title "USER ACCOUNTS"
    SECURITY_AUDIT_REPORT_CONTENT+="\n1. User Accounts\n================\n"

    info "Checking for multiple UID 0 users..."
    local root_users_list
    root_users_list=$(awk -F: '$3==0 {print $1}' /etc/passwd)
    if [ "$root_users_list" = "root" ]; then
        success "Only 'root' user has UID 0."
        add_to_sec_report "[✓]" "Only 'root' user has UID 0."
    else
        local other_uid0_users
        other_uid0_users=$(echo "$root_users_list" | grep -vw "root" | xargs)
        if [ -n "$other_uid0_users" ]; then
            error "HIGH RISK: Users other than 'root' also have UID 0: $(bold "$other_uid0_users")"
            add_to_sec_report "[✗]" "HIGH RISK: Users other than 'root' also have UID 0: $other_uid0_users"
        else 
            success "Only 'root' user has UID 0."
            add_to_sec_report "[✓]" "Only 'root' user has UID 0."
        fi
    fi

    info "Checking user password status..."
    local uid_min_val
    uid_min_val=$(awk '/^\s*UID_MIN\s+[0-9]+/ { print $2 }' /etc/login.defs 2>/dev/null)
    [ -z "$uid_min_val" ] && uid_min_val=1000 

    declare -A user_details_map 
    while IFS=: read -r u_name _ u_uid _ _ _ u_shell; do
        user_details_map["$u_name"]="${u_uid}:${u_shell}"
    done < /etc/passwd

    local empty_pass_regulars="" empty_pass_systems="" locked_pass_regulars=""
    local issues_found_in_pass_check=false

    if [ ! -r "/etc/shadow" ]; then
        error "Cannot read /etc/shadow. Password status check incomplete."
        add_to_sec_report "[✗]" "Cannot read /etc/shadow. Password status check incomplete."
    else
        while IFS=: read -r sh_uname sh_pass _; do
            [ -z "${user_details_map[$sh_uname]}" ] && continue 

            IFS=: read -r current_user_uid current_user_shell <<< "${user_details_map[$sh_uname]}"
            local is_regular_login=false
            if [ "$current_user_uid" -ge "$uid_min_val" ]; then
                case "$current_user_shell" in
                    "/sbin/nologin"|"/bin/false"|"/usr/sbin/nologin"|"") ;; 
                    *) is_regular_login=true ;;
                esac
            fi

            if [ -z "$sh_pass" ]; then 
                issues_found_in_pass_check=true
                if $is_regular_login; then
                    empty_pass_regulars+="${sh_uname} "
                else
                    empty_pass_systems+="${sh_uname} "
                fi
            elif [[ "$sh_pass" == "!" || "$sh_pass" == "*" ]]; then 
                if $is_regular_login; then
                    locked_pass_regulars+="${sh_uname} "
                fi
            fi
        done < /etc/shadow
    fi

    empty_pass_regulars=$(echo "$empty_pass_regulars" | xargs)
    empty_pass_systems=$(echo "$empty_pass_systems" | xargs)
    locked_pass_regulars=$(echo "$locked_pass_regulars" | xargs)

    if [ -n "$empty_pass_regulars" ]; then
        error "HIGH RISK: Regular login users with empty passwords: $(bold "$empty_pass_regulars")"
        add_to_sec_report "[✗]" "HIGH RISK: Regular login users with empty passwords: $empty_pass_regulars"
    fi
    if [ -n "$empty_pass_systems" ]; then
        warning "System/service accounts with empty passwords: $(bold "$empty_pass_systems") (Should be '!' or '*')"
        add_to_sec_report "[!]" "System/service accounts with empty passwords: $empty_pass_systems (Should be '!' or '*')"
    fi
    if ! $issues_found_in_pass_check && [ -r "/etc/shadow" ]; then
         success "No users found with empty password fields."
         add_to_sec_report "[✓]" "No users found with empty password fields."
    fi
    if [ -n "$locked_pass_regulars" ]; then
        warning "Regular login users with disabled passwords ('!' or '*'): $(bold "$locked_pass_regulars") (Verify if intended)"
        add_to_sec_report "[!]" "Regular login users with disabled passwords ('!' or '*'): $locked_pass_regulars (Verify if intended)"
    fi

    info "Checking sudo permissions (excluding root)..."
    declare -A sudo_users_set
    for group in sudo admin wheel; do 
        local members_str
        members_str=$(getent group "$group" 2>/dev/null | cut -d: -f4)
        if [ -n "$members_str" ]; then
            IFS=',' read -ra members_arr <<< "$members_str"
            for member_item in "${members_arr[@]}"; do
                if [[ -n "$member_item" && "$member_item" != "root" ]]; then
                    sudo_users_set["$member_item"]=1
                fi
            done
        fi
    done

    local sudoers_scan_paths=()
    [ -f "/etc/sudoers" ] && sudoers_scan_paths+=("/etc/sudoers")
    if [ -d "/etc/sudoers.d" ]; then
        while IFS= read -r -d $'\0' file_item; do
            [ -f "$file_item" ] && sudoers_scan_paths+=("$file_item")
        done < <(find /etc/sudoers.d -type f -print0 2>/dev/null)
    fi
    if [ ${#sudoers_scan_paths[@]} -gt 0 ]; then
        local direct_sudoers_list
        direct_sudoers_list=$(grep -hE "^[^#%D][^[:space:]]+" "${sudoers_scan_paths[@]}" 2>/dev/null | \
                                   grep -E "ALL\s*=\s*\([^)]+\)\s*(NOPASSWD:\s*)?ALL" | \
                                   awk '$1 != "root" && $1 !~ /^%/ {print $1}')
        for sudo_user_item in $direct_sudoers_list; do
            if id "$sudo_user_item" >/dev/null 2>&1; then 
                 sudo_users_set["$sudo_user_item"]=1
            fi
        done
    fi

    local final_sudo_users_str=""
    if [ ${#sudo_users_set[@]} -gt 0 ]; then
        final_sudo_users_str=$(printf "%s," "${!sudo_users_set[@]}" | sort -u | sed 's/,$//')
    fi

    if [ -n "$final_sudo_users_str" ]; then
        # Changed from warning to info as requested
        info "Users with sudo privileges (excluding root): $(bold "$final_sudo_users_str") (For your review)"
        add_to_sec_report "[ℹ]" "Users with sudo privileges (excluding root): $final_sudo_users_str (For your review)"
    else
        success "No other users (besides root) found with broad sudo privileges via common groups/sudoers."
        add_to_sec_report "[✓]" "No other users (besides root) found with broad sudo privileges (basic check)."
    fi
}

# --- 2. File Permissions ---
audit_file_permissions() {
    print_title "FILE PERMISSIONS"
    SECURITY_AUDIT_REPORT_CONTENT+="\n2. File Permissions\n===================\n"
    info "Checking critical file permissions..."

    declare -A critical_file_checks
    critical_file_checks=(
        ["/etc/passwd"]="644 root:root error"
        ["/etc/group"]="644 root:root error"
        ["/etc/shadow"]="000 root:root error" 
        ["/etc/gshadow"]="000 root:root error" 
        ["/etc/sudoers"]="440 root:root error"
    )
    if [ -d "/etc/sudoers.d" ]; then
        while IFS= read -r -d $'\0' sudo_d_file; do
            if [ -f "$sudo_d_file" ] && ! echo "$sudo_d_file" | grep -qE "README$"; then
                 critical_file_checks["$sudo_d_file"]="440 root:root warn" 
            fi
        done < <(find /etc/sudoers.d -type f -print0 2>/dev/null)
    fi

    for file_to_check in "${!critical_file_checks[@]}"; do
        if [ -e "$file_to_check" ]; then 
            local expected_settings="${critical_file_checks[$file_to_check]}"
            local expected_perms expected_owner_group severity
            read -r expected_perms expected_owner_group severity <<< "$expected_settings"
            
            local current_perms current_owner_group
            current_perms=$(stat -c "%a" "$file_to_check")
            current_owner_group=$(stat -c "%U:%G" "$file_to_check")

            local is_correct=true
            if [[ "$file_to_check" == "/etc/shadow" || "$file_to_check" == "/etc/gshadow" ]]; then
                if ! ( ( [[ "$current_perms" == "000" || "$current_perms" == "400" || "$current_perms" == "600" ]] && [[ "$current_owner_group" == "root:root" ]] ) || \
                       ( [[ "$current_perms" == "040" || "$current_perms" == "640" ]] && [[ "$current_owner_group" == "root:shadow" ]] ) ); then
                    is_correct=false
                    expected_perms="000/400/600 (root:root) or 040/640 (root:shadow)" 
                fi
            elif [[ "$current_perms" != "$expected_perms" || "$current_owner_group" != "$expected_owner_group" ]]; then
                is_correct=false
            fi

            if $is_correct; then
                success "$(basename "$file_to_check"): Permissions ($current_perms) and ownership ($current_owner_group) are correct."
                add_to_sec_report "[✓]" "$(basename "$file_to_check"): Permissions ($current_perms) and ownership ($current_owner_group) correct."
            else
                local msg_prefix="${file_to_check}: Incorrect state. "
                local report_msg="${file_to_check}: Incorrect. Current: $current_perms $current_owner_group. Expected: $expected_perms $expected_owner_group."
                if [ "$severity" = "error" ]; then
                    error "${msg_prefix}Current: $(bold "$current_perms $current_owner_group") Expected: $(bold "$expected_perms $expected_owner_group")"
                    add_to_sec_report "[✗]" "$report_msg"
                else 
                    warning "${msg_prefix}Current: $(bold "$current_perms $current_owner_group") Expected: $(bold "$expected_perms $expected_owner_group")"
                    add_to_sec_report "[!]" "$report_msg"
                fi
            fi
        else
            warning "$(basename "$file_to_check"): File not found, skipping check."
            add_to_sec_report "[!]" "$(basename "$file_to_check"): File not found."
        fi
    done

    info "Checking for potentially risky SUID/SGID files..."
    local risky_suid_patterns="^(cp|mv|rm|chown|chmod|find|dd|awk|gawk|nawk|perl|python[0-9.]*|php[0-9.]*|ruby[0-9.]*|bash|sh|ash|zsh|nc|netcat|ncat|socat|nmap|tcpdump|strace|gdb)$"
    local safe_suid_paths=(
        "/bin/mount" "/bin/umount" "/bin/su" "/bin/ping" "/usr/bin/sudo" "/usr/bin/passwd"
        "/usr/bin/chsh" "/usr/bin/chfn" "/usr/bin/newgrp" "/usr/bin/gpasswd" "/usr/bin/pkexec"
        "/usr/lib/dbus-1.0/dbus-daemon-launch-helper" "/usr/lib/polkit-1/polkit-agent-helper-1"
    )
    local safe_suid_regex
    safe_suid_regex=$(printf "|%s" "${safe_suid_paths[@]}")
    safe_suid_regex="^(${safe_suid_regex#|})$"

    local found_risky_suid_files=""
    find / -xdev \( -perm -4000 -o -perm -2000 \) -type f -ls 2>/dev/null | while read -r suid_line; do
        local suid_filepath suid_basename suid_perms
        suid_filepath=$(echo "$suid_line" | awk '{print $11}') 
        suid_perms=$(echo "$suid_line" | awk '{print $3}') 
        suid_basename=$(basename "$suid_filepath")

        if echo "$suid_basename" | grep -qE "$risky_suid_patterns"; then
            if ! echo "$suid_filepath" | grep -qE "$safe_suid_regex"; then
                found_risky_suid_files+="\n  ${suid_perms} ${suid_filepath}"
            fi
        fi
    done

    if [ -n "$found_risky_suid_files" ]; then
        error "Found potentially risky SUID/SGID files (verify legitimacy):"
        echo -e "$found_risky_suid_files"
        add_to_sec_report "[✗]" "Found potentially risky SUID/SGID files (verify legitimacy):$found_risky_suid_files"
    else
        success "No SUID/SGID files matching common risky patterns (outside whitelist) found."
        add_to_sec_report "[✓]" "No SUID/SGID files matching common risky patterns (outside whitelist) found."
    fi
}

# --- 3. Network ---
audit_network_security() {
    print_title "NETWORK"
    SECURITY_AUDIT_REPORT_CONTENT+="\n3. Network\n==========\n"
    info "Checking listening ports and firewall status..."

    local external_ports_list
    if command -v ss >/dev/null 2>&1; then
        external_ports_list=$(ss -tulnp 2>/dev/null | awk 'NR>1 && ($5 ~ /0\.0\.0\.0:/ || $5 ~ /\*:/ || $5 ~ /\[::\]:/) {print $5 " (" $7 ")" }' | sort -u)
    elif command -v netstat >/dev/null 2>&1; then
        external_ports_list=$(netstat -tulnp 2>/dev/null | awk 'NR>2 && ($4 ~ /0\.0\.0\.0:/ || $4 ~ /\*:/ || $4 ~ /:::/) {print $4 " (" $7 ")"}' | sort -u)
    else
        external_ports_list="N/A (ss/netstat not found)"
    fi

    if [ -n "$external_ports_list" ] && [ "$external_ports_list" != "N/A (ss/netstat not found)" ]; then
        # Changed from warning to info as requested
        info "Externally listening TCP/UDP ports (verify necessity):"
        echo "$external_ports_list" | sed 's/^/  /' 
        add_to_sec_report "[ℹ]" "Externally listening TCP/UDP ports (verify necessity):\n$(echo "$external_ports_list" | sed 's/^/  /')\n"
    elif [ "$external_ports_list" == "N/A (ss/netstat not found)" ]; then
        warning "Could not determine externally listening ports (ss/netstat missing)."
        add_to_sec_report "[!]" "Could not determine externally listening ports (ss/netstat missing)."
    else
        success "No TCP/UDP ports found listening on all interfaces (0.0.0.0, ::, *)."
        add_to_sec_report "[✓]" "No TCP/UDP ports found listening on all interfaces."
    fi

    local fw_active=false fw_tool_name="None"
    if command -v ufw >/dev/null 2>&1; then
        fw_tool_name="UFW"
        if ufw status | grep -qiw "Status: active"; then fw_active=true; fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        fw_tool_name="Firewalld"
        if systemctl is-active --quiet firewalld; then fw_active=true; fi
    elif command -v iptables >/dev/null 2>&1; then 
        fw_tool_name="iptables"
        if ! (iptables -L INPUT -n 2>/dev/null | head -n 1 | grep -q "policy ACCEPT" && \
              [ "$(iptables -L INPUT -n --line-numbers 2>/dev/null | tail -n +3 | wc -l)" -eq 0 ]); then
            fw_active=true
        fi
    fi

    if $fw_active; then
        success "Firewall ($fw_tool_name) appears to be active/configured."
        add_to_sec_report "[✓]" "Firewall ($fw_tool_name) appears to be active/configured."
        if [[ "$fw_tool_name" == "UFW" ]]; then
            local ufw_rules_verbose
            ufw_rules_verbose=$(ufw status verbose 2>/dev/null)
            add_to_sec_report "[i]" "UFW Rules (verbose):\n$ufw_rules_verbose"
            info "UFW rules (see report file for full list):"
            echo "$ufw_rules_verbose" | head -n 10 | sed 's/^/  /'
        elif [[ "$fw_tool_name" == "Firewalld" ]]; then
            local firewalld_active_zones firewalld_rules_details=""
            firewalld_active_zones=$(firewall-cmd --get-active-zones 2>/dev/null | grep -v "interfaces:" | grep -v "sources:" | xargs)
            if [ -z "$firewalld_active_zones" ]; then firewalld_active_zones=$(firewall-cmd --get-default-zone 2>/dev/null); fi
            for zone_item in $firewalld_active_zones; do
                firewalld_rules_details+="Zone: $zone_item\n$(firewall-cmd --zone="$zone_item" --list-all 2>/dev/null)\n\n"
            done
            add_to_sec_report "[i]" "Firewalld Rules:\n$firewalld_rules_details"
            info "Firewalld rules (see report file for full list for zone(s): $firewalld_active_zones)."
        fi
    else
        error "HIGH RISK: No active firewall (UFW, Firewalld) detected or iptables seems unconfigured."
        add_to_sec_report "[✗]" "HIGH RISK: No active firewall detected or iptables seems unconfigured."
    fi
}

# --- 4. Services and Processes ---
audit_services_processes() {
    print_title "SERVICES & PROCESSES"
    SECURITY_AUDIT_REPORT_CONTENT+="\n4. Services and Processes\n=========================\n"
    info "Checking for suspicious processes and executables in temp..."

    local ps_output suspicious_proc_patterns_audit safe_proc_patterns_audit suspicious_procs_list
    ps_output=$(ps aux) 
    suspicious_proc_patterns_audit='(\b(nc|ncat|netcat|socat|খনন|xmr|miner)\b|/(tmp|var/tmp|dev/shm)/[^[:space:]/\.]+[[:alnum:]]+)'
    safe_proc_patterns_audit='(systemd|postgres|mysql|apache|nginx|sshd|dbus|cron|rsyslog|polkit|snapd|kubelet|journald)' 
    
    suspicious_procs_list=$(echo "$ps_output" | tail -n +2 | grep -Ei "$suspicious_proc_patterns_audit" | grep -Eiv "$safe_proc_patterns_audit" | grep -v "grep -Ei ${suspicious_proc_patterns_audit}")

    if [ -n "$suspicious_procs_list" ]; then
        error "Found suspicious processes (based on name/path patterns, verify):"
        echo "$suspicious_procs_list" | head -n 5 | sed 's/^/  /' 
        add_to_sec_report "[✗]" "Found suspicious processes (verify):\n$suspicious_procs_list"
    else
        success "No obvious suspicious processes found based on current patterns."
        add_to_sec_report "[✓]" "No obvious suspicious processes found based on current patterns."
    fi

    info "Checking for executables in temporary directories..."
    local temp_exec_list
    temp_exec_list=$(find /tmp /var/tmp /dev/shm -maxdepth 2 -type f -executable \( -size +1k -o -name ".*" \) -ls 2>/dev/null | head -n 10)
    if [ -n "$temp_exec_list" ]; then
        warning "Found executables in temporary directories (verify legitimacy):"
        echo "$temp_exec_list" | sed 's/^/  /'
        add_to_sec_report "[!]" "Found executables in temporary directories (verify legitimacy):\n$temp_exec_list"
    else
        success "No obvious suspicious executables found in /tmp, /var/tmp, /dev/shm."
        add_to_sec_report "[✓]" "No obvious suspicious executables found in temporary directories."
    fi
}

# --- 5. Logs and Login Analysis ---
audit_logs_logins() {
    print_title "LOGS & LOGINS"
    SECURITY_AUDIT_REPORT_CONTENT+="\n5. Logs and Login Analysis\n==========================\n"
    info "Analyzing recent logins and authentication failures..."

    local recent_success_logins
    recent_success_logins=$(last -n 10 -aFw 2>/dev/null) 
    if [ -n "$recent_success_logins" ]; then
        info "Last 10 successful logins (sample):"
        echo "$recent_success_logins" | head -n 5 | sed 's/^/  /'
        add_to_sec_report "[i]" "Last 10 successful logins:\n$recent_success_logins"
    else
        warning "Could not retrieve recent login records."
        add_to_sec_report "[!]" "Could not retrieve recent login records."
    fi

    local auth_fail_log_path auth_fail_output
    if [ -f "/var/log/auth.log" ]; then auth_fail_log_path="/var/log/auth.log"; 
    elif [ -f "/var/log/secure" ]; then auth_fail_log_path="/var/log/secure"; fi

    if command -v journalctl &>/dev/null; then
        auth_fail_output=$(journalctl --since "24 hours ago" 2>/dev/null | grep -Ei "Failed password|Failed publickey|Authentication failure|Invalid user" | tail -n 20)
    elif [ -n "$auth_fail_log_path" ] && [ -r "$auth_fail_log_path" ]; then
        auth_fail_output=$(tail -n 5000 "$auth_fail_log_path" 2>/dev/null | grep -Ei "Failed password|Failed publickey|Authentication failure|Invalid user" | tail -n 20)
    fi

    if [ -n "$auth_fail_output" ]; then
        local fail_count_val
        fail_count_val=$(echo "$auth_fail_output" | wc -l)
        warning "Found $fail_count_val recent authentication failure attempts (sample below):"
        echo "$auth_fail_output" | tail -n 5 | sed 's/^/  /'
        add_to_sec_report "[!]" "Found $fail_count_val recent authentication failure attempts (sample):\n$auth_fail_output"

        local top_fail_ips
        top_fail_ips=$(echo "$auth_fail_output" | \
            grep -oP '(?<=from\s)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|(?<=rhost=)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' | \
            sort | uniq -c | sort -nr | head -n 5)
        if [ -n "$top_fail_ips" ]; then
            warning "Top source IPs for authentication failures:"
            echo "$top_fail_ips" | sed 's/^/    /'
            add_to_sec_report "[!]" "Top source IPs for authentication failures:\n$top_fail_ips"
        fi
    else
        success "No significant authentication failures found in recent logs."
        add_to_sec_report "[✓]" "No significant authentication failures found in recent logs."
    fi

    if command -v fail2ban-client &>/dev/null; then
        info "Checking Fail2ban status..."
        if fail2ban-client status &>/dev/null; then
            success "Fail2ban service is running."
            add_to_sec_report "[✓]" "Fail2ban service is running."
            local active_jails_str banned_ips_report_detail=""
            active_jails_str=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed -e 's/.*Jail list:[[:space:]]*//' | tr -d ' ')
            if [ -n "$active_jails_str" ]; then
                info "Fail2ban active jails: $(bold "$active_jails_str")" # Changed from warning
                add_to_sec_report "[i]" "Fail2ban active jails: $active_jails_str"
                
                IFS=',' read -ra unique_jails_arr <<< "$(echo "$active_jails_str" | tr ',' '\n' | sort -u | tr '\n' ',')"
                for jail_n in "${unique_jails_arr[@]}"; do
                    local jail_name_trmd=${jail_n// /} 
                    if [ -n "$jail_name_trmd" ]; then
                        local jail_banned_ips_list
                        jail_banned_ips_list=$(fail2ban-client status "$jail_name_trmd" 2>/dev/null | grep "Banned IP list:" | sed 's/.*Banned IP list:[[:space:]]*//')
                        if [ -n "$jail_banned_ips_list" ]; then
                             local num_banned
                             num_banned=$(echo "$jail_banned_ips_list" | wc -w)
                             info "  Jail '$jail_name_trmd': $num_banned IPs banned. (See report for full list)" # Changed from warning
                             banned_ips_report_detail+="\n  Jail '$jail_name_trmd' ($num_banned IPs banned):\n    ${jail_banned_ips_list}\n"
                        fi
                    fi
                done
                if [ -n "$banned_ips_report_detail" ]; then
                     add_to_sec_report "[i]" "Fail2ban Banned IPs Details:$banned_ips_report_detail\n  (Fail2ban log typically at /var/log/fail2ban.log)"
                fi
            fi
        else
            warning "Fail2ban service is installed but not running or failed."
            add_to_sec_report "[!]" "Fail2ban service is installed but not running or failed."
        fi
    else
        info "Fail2ban is not installed." # Changed from warning
        add_to_sec_report "[i]" "Fail2ban is not installed."
    fi
}

# --- 6. System Updates ---
audit_system_updates() {
    print_title "SYSTEM UPDATES"
    SECURITY_AUDIT_REPORT_CONTENT+="\n6. System Updates\n=================\n"
    info "Checking for pending system updates..."

    local updates_avail=false pkg_mgr_name="Unknown" updates_count=0 pkg_list_sample=""

    if command -v apt &>/dev/null; then
        pkg_mgr_name="apt (Debian/Ubuntu)"
        local apt_upgradable_output
        apt_upgradable_output=$(apt list --upgradable 2>/dev/null)
        updates_count=$(echo "$apt_upgradable_output" | grep -vc "Listing...")
        if [ "$updates_count" -gt 0 ]; then
            updates_avail=true
            pkg_list_sample=$(echo "$apt_upgradable_output" | grep -v "Listing..." | head -n 5)
        fi
    elif command -v yum &>/dev/null; then
        pkg_mgr_name="yum (CentOS/RHEL)"
        local yum_upgradable_output
        yum_upgradable_output=$(yum check-update -q 2>/dev/null) 
        updates_count=$(echo "$yum_upgradable_output" | grep -Ec "\S+\s+\S+\s+\S+")
        if [ "$updates_count" -gt 0 ]; then
            updates_avail=true
            pkg_list_sample=$(echo "$yum_upgradable_output" | head -n 5)
        fi
    elif command -v dnf &>/dev/null; then
        pkg_mgr_name="dnf (Fedora/RHEL)"
        local dnf_upgradable_output
        dnf_upgradable_output=$(dnf check-update -q 2>/dev/null)
        updates_count=$(echo "$dnf_upgradable_output" | grep -Ec "\S+\s+\S+\s+\S+")
        if [ "$updates_count" -gt 0 ]; then
            updates_avail=true
            pkg_list_sample=$(echo "$dnf_upgradable_output" | head -n 5)
        fi
    fi

    if $updates_avail; then
        warning "$updates_count pending system updates found via $pkg_mgr_name (check local cache timing)."
        add_to_sec_report "[!]" "$updates_count pending system updates found via $pkg_mgr_name.\nSample:\n$pkg_list_sample"
        info "Sample of upgradable packages:"
        echo "$pkg_list_sample" | sed 's/^/  /'
    elif [ "$pkg_mgr_name" != "Unknown" ]; then
        success "No pending system updates found (based on $pkg_mgr_name local cache)."
        add_to_sec_report "[✓]" "No pending system updates found (based on $pkg_mgr_name local cache)."
    else
        warning "Could not determine package manager to check for updates."
        add_to_sec_report "[!]" "Could not determine package manager to check for updates."
    fi

    if [ -f /var/run/reboot-required ]; then
        warning "System requires a reboot, likely for kernel or critical library updates."
        add_to_sec_report "[!]" "System requires a reboot (/var/run/reboot-required exists)."
        if [ -f /var/run/reboot-required.pkgs ]; then
            local reboot_pkgs_list
            reboot_pkgs_list=$(cat /var/run/reboot-required.pkgs | tr '\n' ' ' | xargs)
            info "Packages triggering reboot: $(bold "$reboot_pkgs_list")"
            add_to_sec_report "[i]" "Packages triggering reboot: $reboot_pkgs_list"
        fi
    fi
}

# --- 7. Disk Capacity ---
audit_disk_full_issues() {
    print_title "DISK CAPACITY" 
    SECURITY_AUDIT_REPORT_CONTENT+="\n7. Disk Capacity\n================\n"
    info "Checking for critically full disk partitions..."
    local disk_critical_threshold=90 

    local high_space_usage_partitions
    high_space_usage_partitions=$(df -hP | awk -v th="$disk_critical_threshold" 'NR>1 {gsub(/%/, "", $5); if($5 > th) print $0}')
    if [ -n "$high_space_usage_partitions" ]; then
        error "Disk partitions over $disk_critical_threshold% space full (potential DoS or instability):"
        echo "$high_space_usage_partitions" | sed 's/^/  /'
        add_to_sec_report "[✗]" "Disk partitions over $disk_critical_threshold% space full:\n$high_space_usage_partitions"
    else
        success "Disk space usage on all partitions below $disk_critical_threshold%."
        add_to_sec_report "[✓]" "Disk space usage on all partitions below $disk_critical_threshold%."
    fi

    local high_inode_usage_partitions
    high_inode_usage_partitions=$(df -iP | awk -v th="$disk_critical_threshold" 'NR>1 {gsub(/%/, "", $5); if($5 > th) print $0}')
    if [ -n "$high_inode_usage_partitions" ]; then
        error "Disk partitions over $disk_critical_threshold% inode full (potential DoS or instability):"
        echo "$high_inode_usage_partitions" | sed 's/^/  /'
        add_to_sec_report "[✗]" "Disk partitions over $disk_critical_threshold% inode full:\n$high_inode_usage_partitions"
    else
        success "Inode usage on all partitions below $disk_critical_threshold%."
        add_to_sec_report "[✓]" "Inode usage on all partitions below $disk_critical_threshold%."
    fi
}

# --- 8. System Integrity ---
audit_system_integrity() {
    print_title "SYSTEM INTEGRITY"
    SECURITY_AUDIT_REPORT_CONTENT+="\n8. System Integrity (Basic Checks)\n==================================\n"
    info "Checking for recently modified system files..." # Removed mention of rootkit tools from console

    local critical_sys_paths="/etc /bin /sbin /usr/bin /usr/sbin /lib* /boot /var/spool/cron"
    local exclude_find_paths="-path /etc/mtab -o -path /etc/adjtime -o -path /var/lib/mlocate/* -o -path /var/lib/logrotate/* -o -path /var/lib/systemd/* -o -path /var/cache/* -o -path /var/log/*"
    local recent_mods_list
    recent_mods_list=$(find $critical_sys_paths \( $exclude_find_paths \) -prune -o -type f -mtime -1 -print0 2>/dev/null | head -zc20 | xargs -0 -r ls -ld)

    if [ -n "$recent_mods_list" ]; then
        warning "Found system files modified in the last 24 hours (sample, verify changes):"
        echo "$recent_mods_list" | sed 's/^/  /'
        add_to_sec_report "[!]" "System files modified in last 24h (sample, verify):\n$recent_mods_list"
    else
        success "No critical system files (monitored paths) found modified in the last 24 hours."
        add_to_sec_report "[✓]" "No critical system files (monitored paths) modified in last 24h."
    fi
    # Removed rkhunter, chkrootkit, AIDE installation checks as requested
}

# --- SECURITY AUDIT SUMMARY ---
show_security_audit_summary() {
    print_title "SECURITY AUDIT SUMMARY"
    
    local report_filename="$LOG_DIR/server_check_$(date +%Y%m%d_%H%M%S).txt"
    # Construct initial part of the report file content
    local file_header="Security Audit Report\nDate: $(date)\nHostname: $(hostname)\n============================\n"
    
    # Append collected audit findings
    local full_report_content="${file_header}${SECURITY_AUDIT_REPORT_CONTENT}"

    # Summary message for console
    if [ "$SECURITY_AUDIT_ERRORS" -gt 0 ]; then
        error "Security Audit found $SECURITY_AUDIT_ERRORS HIGH RISK items (✗)!"
    fi
    if [ "$SECURITY_AUDIT_WARNINGS" -gt 0 ]; then
        warning "Security Audit found $SECURITY_AUDIT_WARNINGS warnings (!)."
    fi
    if [ "$SECURITY_AUDIT_ERRORS" -eq 0 ] && [ "$SECURITY_AUDIT_WARNINGS" -eq 0 ]; then
        success "Security Audit: No high risk items or major warnings found in automated checks."
    fi
    info "A detailed security audit report has been saved to: $(bold "$report_filename")"
    info "Please review this file for all findings and recommendations."

    # Construct and append summary & recommendations to the report content for the file
    local report_summary_recommendations="\n\nSecurity Audit Summary & Recommendations\n======================================\n"
    report_summary_recommendations+="Found ${SECURITY_AUDIT_ERRORS} high risk items (✗), ${SECURITY_AUDIT_WARNINGS} warnings (!), and ${SECURITY_AUDIT_INFO_ITEMS} informational items (ℹ).\n\n"
    report_summary_recommendations+="General Recommendations:\n"
    report_summary_recommendations+="1.  Address all [✗] (HIGH RISK) items immediately.\n"
    report_summary_recommendations+="2.  Review all [!] (Warning) items and take appropriate action based on your security policy.\n"
    report_summary_recommendations+="3.  Note [ℹ] (Informational) items for awareness and context.\n"
    report_summary_recommendations+="4.  Ensure regular system updates and patching. Consider automated patching for security updates.\n"
    report_summary_recommendations+="5.  Harden SSH configurations (e.g., disable root login, use key-based authentication, change default port if policy allows, use AllowUsers/AllowGroups).\n"
    report_summary_recommendations+="6.  Implement and enforce strong password policies. Regularly audit user accounts and their privileges.\n"
    report_summary_recommendations+="7.  Regularly review firewall rules and minimize network exposure. Only allow necessary services.\n"
    report_summary_recommendations+="8.  Centralize and monitor system logs for suspicious activity. Consider a SIEM solution for larger environments.\n"
    report_summary_recommendations+="9.  Implement file integrity monitoring (e.g., AIDE or commercial solutions) to detect unauthorized changes.\n"
    report_summary_recommendations+="10. Conduct regular vulnerability scans and penetration tests.\n"
    report_summary_recommendations+="11. Ensure robust backup and disaster recovery plans are in place and tested.\n"

    # Write the complete report to the file
    echo -e "${full_report_content}${report_summary_recommendations}" > "$report_filename"
}

# --- MAIN FUNCTION ---
main() {
    welcome "Server Check" 
    
    get_system_info
    get_resource_usage
    get_disk_usage
    get_top_processes
    get_service_status
    get_pm2_apps

    # Initialize Security Audit section in the report content
    SECURITY_AUDIT_REPORT_CONTENT+="\n--- SECURITY AUDIT FINDINGS ---\n"

    audit_user_accounts
    audit_file_permissions
    audit_network_security
    audit_services_processes
    audit_logs_logins
    audit_system_updates
    audit_disk_full_issues 
    audit_system_integrity

    show_security_audit_summary

    echo 
    success "Server overview and security audit completed."
}

main "$@"