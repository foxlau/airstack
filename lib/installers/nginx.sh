#!/bin/bash

install() {
  if dpkg -l | grep -q nginx; then
    warning "Nginx is already installed. $(nginx -v 2>&1)"
    return 1
  fi

  # Install Nginx
  apt-get install -y nginx
  echo "Nginx installation completed, starting to configure Nginx"

  # Backup and modify the default Nginx configuration file
  mv /etc/nginx/nginx.conf{,_bk}
  /bin/rm /etc/nginx/sites-available/default
  /bin/rm /etc/nginx/sites-enabled/default
  /bin/cp ${AIRSTACK_DIR}/config/nginx/nginx.conf /etc/nginx/nginx.conf
  /bin/cp ${AIRSTACK_DIR}/config/nginx/conf.d/* /etc/nginx/conf.d

  # Test Nginx configuration
  if nginx -t; then
    systemctl reload nginx
    success "Nginx configuration test successful, service has started and enabled."
    return 0
  else
    error "Nginx configuration test failed, please check the configuration file."
    return 1
  fi
}

uninstall() {
  if ! dpkg -l | grep -q nginx; then
    warning "Nginx is not installed!"
    return
  fi
  
  # Backup Nginx configuration files
  backup_date=$(date +"%Y%m%d_%H%M%S")
  backup_dir="$HOME/backup/nginx_config_backup_$backup_date"
  mkdir -p "$backup_dir"
  cp -r /etc/nginx "$backup_dir"
  
  # Stop and disable Nginx
  systemctl stop nginx
  systemctl disable nginx
  apt-get remove --purge nginx nginx-common -y
  apt-get autoremove -y

  echo "Nginx configuration files have been backed up to $backup_dir"
  success "Nginx uninstallation completed!"
}
