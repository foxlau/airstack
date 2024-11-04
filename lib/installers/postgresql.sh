#!/bin/bash

install() {
  if dpkg -l | grep -q postgresql; then
    warning "PostgreSQL is already installed. $(psql -V 2>&1)"
    return 1
  fi

  # Install PostgreSQL and its dependencies
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y postgresql-common postgresql
  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
  systemctl enable --now postgresql

  # Secure PostgreSQL
  if dpkg -l | grep -q postgresql && systemctl is-active --quiet postgresql; then
    secure_postgresql
    success "PostgreSQL installation completed and service is active!"
    return 0
  else
    error "PostgreSQL installation failed or service is inactive!"
    return 1
  fi
}

uninstall() {
  if ! dpkg -l | grep -q postgresql; then
    warning "PostgreSQL is not installed!"
    return
  fi

  # Stop PostgreSQL service & disable on boot
  export DEBIAN_FRONTEND=noninteractive
  systemctl stop postgresql
  systemctl disable postgresql
  
  # Remove PostgreSQL packages
  apt-get remove --purge -y postgresql postgresql-*
  rm -rf /etc/postgresql/ /var/lib/postgresql/ /var/log/postgresql/

  # Remove PostgreSQL user and group
  userdel -r postgres 2>/dev/null
  groupdel postgres 2>/dev/null

  # Clean up
  apt-get autoremove -y
  apt-get clean
  
  success "PostgreSQL uninstallation completed!"
}

secure_postgresql() {
  if [ -z "${POSTGRES_PASSWOR}" ]; then
      error "PostgreSQL root password is not set"
      return 1
  fi

  # Configure PostgreSQL to only listen on localhost
  sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" /etc/postgresql/*/main/postgresql.conf
  
  # Configure authentication method to scram-sha-256 and allow only local connections
  cat > /etc/postgresql/*/main/pg_hba.conf << EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
EOF

  # Combine multiple PostgreSQL commands into a single execution
  sudo -u postgres psql << EOF
ALTER USER postgres WITH ENCRYPTED PASSWORD '$POSTGRES_PASSWOR';
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO postgres;
EOF

  # Restart PostgreSQL to apply changes
  systemctl restart postgresql
}
