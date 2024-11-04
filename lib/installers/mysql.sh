#!/bin/bash

install() {
  if dpkg -l | grep -q mysql-server; then
    warning "MySQL is already installed. $(mysql -V 2>&1)"
    return 1
  fi

  # Install MySQL server
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y mysql-server
  generate_mysql_config

  # Start and enable MySQL service
  systemctl start mysql
  systemctl enable mysql
  secure_mysql_installation

  # Verify installation
  if dpkg -l | grep -q mysql-server && systemctl is-active --quiet mysql; then
    success "MySQL installation completed successfully!"
    return 0
  else
    error "MySQL installation verification failed!"
    return 1
  fi
}

uninstall() {
  if ! dpkg -l | grep -q mysql-server; then
    warning "MySQL is not installed!"
    return
  fi

  # Stop MySQL service
  systemctl stop mysql || true
  systemctl disable mysql || true

  # Remove MySQL packages and configuration
  export DEBIAN_FRONTEND=noninteractive
  apt-get remove --purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
  apt-get autoremove -y
  apt-get autoclean

  # Remove data directories and files
  rm -rf /var/lib/mysql* /var/log/mysql* /etc/mysql /var/run/mysqld
  rm -f ~/.mysql_history ~/.mysqlsh

  # Remove system user and group
  userdel -r mysql >/dev/null 2>&1 || true
  groupdel mysql >/dev/null 2>&1 || true

  # Remove remaining files in common locations
  find /etc -name '*mysql*' -exec rm -rf {} \; >/dev/null 2>&1 || true
  find /var/lib -name '*mysql*' -exec rm -rf {} \; >/dev/null 2>&1 || true
  find /var/log -name '*mysql*' -exec rm -rf {} \; >/dev/null 2>&1 || true

  success "MySQL uninstallation completed!"
}

generate_mysql_config() {
  local mysql_conf_file="/etc/mysql/mysql.conf.d/mysqld.cnf"

  # Backup original configuration
  if [ -f "$mysql_conf_file" ]; then
    cp "$mysql_conf_file" "${mysql_conf_file}.bak"
    echo "Original configuration file has been backed up as ${mysql_conf_file}.bak"
  fi

  # Copy template configuration
  /bin/cp ${AIRSTACK_DIR}/config/mysql/mysqld.cnf "$mysql_conf_file"

  # Adjust settings based on memory
  sed -i "s@max_connections.*@max_connections = $((${MEMORY_MB}/3))@" $mysql_conf_file
  if [ ${MEMORY_MB} -gt 1500 -a ${MEMORY_MB} -le 2500 ]; then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 16@' $mysql_conf_file
    sed -i 's@^myisam_sort_buffer_size.*@myisam_sort_buffer_size = 16M@' $mysql_conf_file
    sed -i 's@^key_buffer_size.*@key_buffer_size = 16M@' $mysql_conf_file
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 128M@' $mysql_conf_file
    sed -i 's@^tmp_table_size.*@tmp_table_size = 32M@' $mysql_conf_file
    sed -i 's@^table_open_cache.*@table_open_cache = 256@' $mysql_conf_file
  elif [ ${MEMORY_MB} -gt 2500 -a ${MEMORY_MB} -le 3500 ]; then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 32@' $mysql_conf_file
    sed -i 's@^myisam_sort_buffer_size.*@myisam_sort_buffer_size = 32M@' $mysql_conf_file
    sed -i 's@^key_buffer_size.*@key_buffer_size = 64M@' $mysql_conf_file
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 512M@' $mysql_conf_file
    sed -i 's@^tmp_table_size.*@tmp_table_size = 64M@' $mysql_conf_file
    sed -i 's@^table_open_cache.*@table_open_cache = 512@' $mysql_conf_file
  elif [ ${MEMORY_MB} -gt 3500 ]; then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 64@' $mysql_conf_file
    sed -i 's@^myisam_sort_buffer_size.*@myisam_sort_buffer_size = 64M@' $mysql_conf_file
    sed -i 's@^key_buffer_size.*@key_buffer_size = 256M@' $mysql_conf_file
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 1024M@' $mysql_conf_file
    sed -i 's@^tmp_table_size.*@tmp_table_size = 128M@' $mysql_conf_file
    sed -i 's@^table_open_cache.*@table_open_cache = 1024@' $mysql_conf_file
  fi
}

secure_mysql_installation() {
    if [ -z "${MYSQL_ROOT_PASSWORD}" ]; then
        error "MySQL root password is not set"
        return 1
    fi

    # Settings MySQL root user password
    mysql -u root <<EOF
CREATE USER 'root'@'127.0.0.1' IDENTIFIED WITH 'caching_sha2_password' BY '$MYSQL_ROOT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY '$MYSQL_ROOT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
}