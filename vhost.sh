#!/bin/bash
# Nginx Virtual Host Setup Script for AirStack
# Supports HTTP, HTTPS with Let's Encrypt, and custom SSL certificates

# Get script directory and set working directory
AIRSTACK_DIR=$(dirname "`readlink -f $0`")
pushd ${AIRSTACK_DIR} > /dev/null

. lib/utils.sh
. lib/oscheck.sh

# Privilege check
require_sudo

# Check if nginx is installed and directories exist
if ! command -v nginx &> /dev/null; then
    error_exit "Nginx could not be found"
fi

# Welcome message
welcome "Nginx Virtual Host Setup"
warning "Before proceeding, please ensure:"
warning_plain "  Your domain is pointing directly to this server's IP address"
warning_plain "  DNS propagation is complete (may take up to 24-48 hours)"
warning_plain "  No CDN or proxy services (like Cloudflare) are enabled for the domain"
warning_plain "  Your domain registrar's DNS settings are configured correctly"

# Validate domain name format
validate_domain() {
    local domain_regex="^([a-zA-Z0-9][a-zA-Z0-9-]*\.)*[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z]{2,}$"
    if [[ ! $1 =~ $domain_regex ]]; then
        return 1
    fi
    return 0
}

# Check if domain points to server IP
check_domain_dns() {
    local domain=$1
    local server_ip=$(curl -s ifconfig.me)
    local domain_ips=$(dig +short $domain)
    
    if echo "$domain_ips" | grep -q "^${server_ip}$"; then
        return 0
    fi
    
    warning "Domain ${domain} does not point to this server (${server_ip})"
    warning "Current DNS records:"
    echo "$domain_ips" | while read -r ip; do
        warning "- $ip"
    done
    return 1
}

# Check existing nginx configuration
check_existing_nginx_conf() {
    local domain=$1
    if [ -f "/etc/nginx/sites-available/${domain}" ] || [ -f "/etc/nginx/sites-enabled/${domain}" ]; then
        error "Nginx configuration already exists for domain: ${domain}"
        warning "Please remove or backup these files first:"
        [ -f "/etc/nginx/sites-available/${domain}" ] && warning_plain "- /etc/nginx/sites-available/${domain}"
        [ -f "/etc/nginx/sites-enabled/${domain}" ] && warning_plain "- /etc/nginx/sites-enabled/${domain}"
        return 1
    fi
    return 0
}

# Check server_name conflicts
check_server_name_conflicts() {
    local domain=$1
    
    for config in /etc/nginx/sites-enabled/*; do
        [ -f "$config" ] || continue
        
        while read -r line; do
            line=$(echo "$line" | sed 's/server_name//i' | tr -d ';')
            for name in $line; do
                if [ "$name" = "$domain" ]; then
                    error "Domain ${domain} is already used in ${config}"
                    warning "Conflicting server_name line: server_name${line}"
                    return 1
                fi
            done
        done < <(grep -i "^\s*server_name" "$config")
    done
    return 0
}

# Get primary domain
while true; do echo
    read -p "Please enter primary domain (e.g., example.com): " primary_domain
    if validate_domain "$primary_domain"; then
        break
    else
        error "Invalid domain format"
    fi
done

# Check both nginx conf and server name conflicts
if ! check_existing_nginx_conf "$primary_domain" || ! check_server_name_conflicts "$primary_domain"; then
    exit 1
fi

# Get secondary domain
secondary_domain=""
while true; do echo
    read -p "Would you like to add an additional domain? (y/N): " add_more
    if [[ ! "${add_more,,}" =~ ^[yn]?$ ]]; then
        error "Invalid input. Please enter 'y' for yes or press Enter for no"
        continue
    fi
    if [[ "${add_more,,}" != "y" ]]; then
        break
    fi
    
    while true; do
        read -p "Please enter additional domain (e.g., www.example.com): " secondary_domain
        
        if ! validate_domain "$secondary_domain"; then
            error "Invalid domain format"
            continue
        fi
        
        if [ "$secondary_domain" = "$primary_domain" ]; then
            error "Additional domain cannot be the same as primary domain"
            continue
        fi
        
        break
    done

    break
done

# Ask about domain redirect
if [ -n "$secondary_domain" ]; then
    if ! check_existing_nginx_conf "$secondary_domain"; then
        exit 1
    fi
    
    if ! check_server_name_conflicts "$secondary_domain"; then
        secondary_domain=""
        exit 1
    fi

    while true; do echo
        read -p "Redirect secondary domain to primary domain? (Y/n): " do_redirect
        if [[ ! "${do_redirect,,}" =~ ^[yn]?$ ]]; then
            error "Invalid input. Please enter 'n' for no or press Enter/enter 'y' for yes"
            continue
        fi
        
        if [[ "${do_redirect,,}" == "n" ]]; then
            redirect=false
        else
            redirect=true
            highlight "Redirecting ${secondary_domain} to ${primary_domain}"
        fi
        break
    done

fi

# Check DNS resolution for all domains
# domains_to_check=("$primary_domain")
# [ -n "$secondary_domain" ] && domains_to_check+=("$secondary_domain")

# for domain in "${domains_to_check[@]}"; do
#     if ! check_domain_dns "$domain"; then
#         error_exit "Domain $domain is not pointing to this server"
#     fi
# done

# Get Node.js port
default_port=3000
while true; do echo
    read -p "Please enter Node.js port (default: ${default_port}): " node_port
    
    if [ -z "$node_port" ]; then
        node_port=$default_port
        break
    fi
    
    if ! [[ "$node_port" =~ ^[0-9]+$ ]] || [ "$node_port" -lt 3000 ] || [ "$node_port" -gt 65535 ]; then
        error "Invalid port. Please enter a number between 3000 and 65535"
        continue
    fi
    
    break
done

highlight "Using Node.js port: ${node_port}"

# SSL configuration
echo -e "\nPlease select SSL option:"
PS3="You can input the number of the option: "
ssl_options=(
    "$(highlight "HTTP only")" 
    "$(highlight "HTTPS with Let's Encrypt")" 
    "$(highlight "Custom SSL certificate")"
)
select ssl_option in "${ssl_options[@]}"; do
    case $ssl_option in
        *"HTTP only"*)
            ssl_type="http"
            break
            ;;
        *"HTTPS with Let's Encrypt"*)
            ssl_type="letsencrypt"
            while true; do echo
                read -p "Enter email for SSL notifications: " ssl_email
                if [[ "$ssl_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                    break
                else
                    error "Invalid email format"
                fi
            done
            break
            ;;
        *"Custom SSL certificate"*)
            ssl_type="custom"
            break
            ;;
    esac
done

# Generate common nginx configuration blocks
generate_common_config() {
    local primary_domain=$1
    local node_port=$2

    mkdir -p "/var/log/nginx/${primary_domain}"
    
    cat <<EOF
    # Rate limiting
    limit_req zone=global_rate_limit burst=20 nodelay;

    # Logging
    access_log /var/log/nginx/${primary_domain}/access.log combined;
    error_log /var/log/nginx/${primary_domain}/error.log;

    location / {
        proxy_pass http://localhost:${node_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
EOF
}

# Create HTTP nginx configuration
create_http_config() {
    local primary_domain=$1
    local secondary_domain=$2
    local redirect=${3:-false}
    local config_file="/etc/nginx/sites-available/${primary_domain}"
    
    cat > "$config_file" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${primary_domain}${secondary_domain:+ $secondary_domain};
    
EOF

    if [ "$redirect" = true ]; then
        cat >> "$config_file" <<EOF
    # Redirect secondary domain to primary domain
    if (\$host = ${secondary_domain}) {
        return 301 \$scheme://${primary_domain}\$request_uri;
    }

EOF
    fi

    generate_common_config "$primary_domain" "$node_port" >> "$config_file"

    echo "}" >> "$config_file"
}

# Create HTTPS nginx configuration
create_https_config() {
    local primary_domain=$1
    local secondary_domain=$2
    local redirect=${3:-false}
    local config_file="/etc/nginx/sites-available/${primary_domain}"
    
    cat > "$config_file" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${primary_domain}${secondary_domain:+ $secondary_domain};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${primary_domain}${secondary_domain:+ $secondary_domain};
    
EOF

    if [ "$redirect" = true ]; then
        cat >> "$config_file" <<EOF
    # Redirect secondary domain to primary domain
    if (\$host = ${secondary_domain}) {
        return 301 \$scheme://${primary_domain}\$request_uri;
    }

EOF
    fi
    
    if [ "$ssl_type" = "letsencrypt" ]; then
        cat >> "$config_file" <<EOF
    # Let's Encrypt SSL certificate configuration
    ssl_certificate /etc/letsencrypt/live/${primary_domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${primary_domain}/privkey.pem;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
EOF
    elif [ "$ssl_type" = "custom" ]; then
        cat >> "$config_file" <<EOF
    # Custom SSL certificate configuration
    ssl_certificate /etc/nginx/ssl/${primary_domain}/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/${primary_domain}/privkey.pem;
EOF
    fi

    cat >> "$config_file" <<EOF
    include /etc/letsencrypt/options-ssl-nginx.conf;

EOF

    generate_common_config "$primary_domain" "$node_port" >> "$config_file"

    echo "}" >> "$config_file"
}

# Create initial HTTP configuration
create_initial_http_config() {
    local primary_domain=$1
    local secondary_domain=$2
    local config_file="/etc/nginx/sites-available/${primary_domain}"
    local web_root="/var/www/${primary_domain}"

    info "Creating temporary Nginx virtual host for SSL certificate verification..."
    
    cat > "$config_file" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${primary_domain}${secondary_domain:+ $secondary_domain};

    root ${web_root};
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    mkdir -p "$web_root"
    cat > "${web_root}/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>${primary_domain}</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>Welcome to ${primary_domain}</h1>
    <p>This is a temporary page for domain verification.</p>
</body>
</html>
EOF

    chown -R www-data:www-data "$web_root"
    chmod -R 755 "$web_root"
    ln -sf "$config_file" "/etc/nginx/sites-enabled/"
    nginx -t && systemctl reload nginx

    echo "Waiting for nginx configuration to take effect..."
    sleep 1
}

# Clean up initial configuration
cleanup_initial_config() {
    local primary_domain=$1
    local config_file="/etc/nginx/sites-available/${primary_domain}"
    local web_root="/var/www/${primary_domain}"
    
    warning "Cleaning up temporary configuration..."
    
    rm -f "/etc/nginx/sites-enabled/${primary_domain}"
    rm -f "$config_file"
    rm -rf "$web_root"
}

# Download SSL configuration file if not exists
download_ssl_config() {
    if [ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
        info "Downloading SSL configuration file..."
        if ! wget -q https://raw.githubusercontent.com/certbot/certbot/main/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf -P /etc/letsencrypt/; then
            error_exit "Failed to download SSL configuration file"
        fi
    fi
}

# Setup Let's Encrypt SSL
setup_letsencrypt() {
    local primary_domain=$1
    local secondary_domain=$2
    echo

    if [ -d "/etc/letsencrypt/live/${primary_domain}" ]; then
        info "SSL certificate already exists for ${primary_domain}"
        echo "Using existing certificate..."
        return 0
    fi
    
    create_initial_http_config "$primary_domain" "$secondary_domain"
    
    local http_response=$(curl -s -I "http://${primary_domain}" | grep -i "^HTTP" | head -n1)
    if [[ ! "$http_response" =~ "200 OK" ]]; then
        cleanup_initial_config "$primary_domain"
        error_exit "Initial configuration test failed. Server returned: ${http_response:-'No HTTP response'}"
    fi
    
    if ! command -v certbot &> /dev/null; then
        info "Installing certbot..."
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
    fi
    
    download_ssl_config

    if [ ! -f /etc/letsencrypt/ssl-dhparams.pem ]; then
        info "Generating DH parameters (2048 bit), this might take a moment..."
        if ! openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048; then
            error_exit "Failed to generate DH parameters"
        fi
    fi
    
    local domains_param="--domains ${primary_domain}"
    if [ -n "$secondary_domain" ]; then
        domains_param="${domains_param},${secondary_domain}"
    fi
    
    info "Requesting SSL certificate..."
    if ! certbot certonly --nginx \
        --non-interactive \
        --agree-tos \
        --email "${ssl_email}" \
        ${domains_param}; then

        cleanup_initial_config "$primary_domain"
        error_exit "Failed to obtain SSL certificate"
    fi

    cleanup_initial_config "$primary_domain"

    if ! [ -d "/etc/letsencrypt/live/${primary_domain}" ]; then
        error_exit "SSL certificate directory not found"
    fi
    
    info "Testing automatic renewal process..."
    if ! certbot renew --dry-run; then
        warning "Certificate renewal test failed"
        warning "Please setup certificate renewal manually"
    else
        if ! crontab -l | grep -q "certbot renew"; then
            (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet --renew-hook 'systemctl reload nginx'") | crontab -
            success "Automatic renewal has been configured (runs daily at 3:00 AM)"
        else
            info "Automatic renewal was already configured"
        fi
    fi
}

# Handle SSL certificate (if needed)
if [ "$ssl_type" = "letsencrypt" ]; then
    setup_letsencrypt "$primary_domain" "$secondary_domain"
elif [ "$ssl_type" = "custom" ]; then
    download_ssl_config
    cert_path="/etc/nginx/ssl/${primary_domain}"
    mkdir -p "$cert_path"
fi

# Create nginx configuration
if [ "$ssl_type" = "http" ]; then
    create_http_config "$primary_domain" "$secondary_domain" "$redirect"
else
    create_https_config "$primary_domain" "$secondary_domain" "$redirect"
fi

# Enable site
ln -sf "/etc/nginx/sites-available/${primary_domain}" "/etc/nginx/sites-enabled/"

# Test and reload nginx
echo
if [ "$ssl_type" = "custom" ]; then
    success "Nginx virtual host configuration has been created successfully!"
    warning "Please follow these steps to complete the setup:"
    warning_plain "  1) Upload your SSL certificates to: /etc/nginx/ssl/${primary_domain}/"
    warning_plain "  2) If your SSL certificate files have different names, please update them in: /etc/nginx/sites-available/${primary_domain}"
    warning_plain "     - ssl_certificate     /etc/nginx/ssl/${primary_domain}/fullchain.pem"
    warning_plain "     - ssl_certificate_key /etc/nginx/ssl/${primary_domain}/privkey.pem"
    warning_plain "  3) Test nginx configuration: nginx -t"
    warning_plain "  4) Reload nginx: systemctl reload nginx"
else
    info "Testing nginx configuration..."
    if nginx -t; then
        systemctl reload nginx
        success "Virtual host setup completed successfully!"
    else
        error "Nginx configuration test failed!"
    fi
fi

popd > /dev/null