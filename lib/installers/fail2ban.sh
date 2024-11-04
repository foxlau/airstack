#!/bin/bash

install() {
  if command -v fail2ban-server >/dev/null 2>&1; then
    warning "Fail2ban is already installed. Current version: $(fail2ban-server -V 2>&1)"
    return 1
  fi

  pushd ${AIRSTACK_DIR}/src > /dev/null
  
  # Download Fail2ban installation package
  local fail2ban_tar_gz="master.tar.gz"
  local src_url="https://github.com/fail2ban/fail2ban/archive/refs/heads/${fail2ban_tar_gz}"
  download_file ${fail2ban_tar_gz} ${src_url}

  # Extract Fail2ban installation package and get the directory name
  local extracted_dir=$(tar tzf ${fail2ban_tar_gz} | head -1 | cut -f1 -d"/")
  tar xzf ${fail2ban_tar_gz}
  pushd ${extracted_dir} > /dev/null

  # Install Fail2ban using Python
  python3 setup.py install || python setup.py install

  # Copy Fail2ban service file and configure Fail2ban
  /bin/cp build/fail2ban.service /lib/systemd/system/
  configure_fail2ban

  # Enable and start Fail2ban service
  systemctl enable fail2ban
  systemctl start fail2ban

  # Remove the extracted directory
  popd > /dev/null
  rm -rf ${extracted_dir}

  # Check if Fail2ban is installed successfully
  if [ -e "/usr/local/bin/fail2ban-server" ]; then
    success "Fail2ban installed successfully!"
    return 0
  else
    error "Fail2ban installation failed, please try again!"
    return 1
  fi
}

uninstall() {
  # Check if Fail2ban is installed
  if ! command -v fail2ban-server >/dev/null 2>&1; then
    warning "Fail2ban is not installed!"
    return
  fi
  
  # Stop and disable the service
  systemctl stop fail2ban
  systemctl disable fail2ban

  # Remove Fail2ban files and directories
  rm -rf /usr/local/bin/fail2ban* \
         /usr/bin/fail2ban* \
         /etc/fail2ban \
         /var/lib/fail2ban \
         /var/log/fail2ban.log* \
         /var/run/fail2ban \
         /lib/systemd/system/fail2ban.service

  # Remove init script if exists
  [ -f /etc/init.d/fail2ban ] && rm -f /etc/init.d/fail2ban

  # Remove logrotate configuration and man pages
  rm -f /etc/logrotate.d/fail2ban
  rm -f /usr/share/man/man1/fail2ban* \
        /usr/share/man/man5/fail2ban*

  success "Fail2ban uninstallation completed!"
}

configure_fail2ban() {
  # Get current SSH port
  [ -z "$(grep ^Port /etc/ssh/sshd_config)" ] && now_ssh_port=22 || now_ssh_port=$(grep ^Port /etc/ssh/sshd_config | awk '{print $2}' | head -1)

  # Create jail.local configuration file
  cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime  = 86400
findtime = 600
maxretry = 5
backend = auto
banaction = %(banaction_allports)s
action = %(action_mwl)s

[sshd]
enabled = true
port    = ${now_ssh_port}
logpath = %(sshd_log)s
EOF

  # Create logrotate configuration
  cat > /etc/logrotate.d/fail2ban << EOF
/var/log/fail2ban.log {
    missingok
    notifempty
    postrotate
      /usr/local/bin/fail2ban-client flushlogs >/dev/null || true
    endscript
}
EOF
}
