#!/bin/bash

install() {
  if dpkg -l | grep -q redis-server; then
    warning "Redis is already installed. $(redis-server -v 2>&1)"
    return 1
  fi

  apt-get install redis-server -y
  
  # Configure Redis to use systemd & listen only on localhost
  sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
  sed -i 's/^# bind 127.0.0.1 ::1/bind 127.0.0.1 ::1/' /etc/redis/redis.conf
  
  # Configure Redis memory
  local redis_maxmemory=$(( MEMORY_MB / 8 ))000000
  if grep -q "^# maxmemory" /etc/redis/redis.conf; then
      sudo sed -i "s/^# maxmemory <bytes>/maxmemory ${redis_maxmemory}/" /etc/redis/redis.conf
  elif ! grep -q "^maxmemory" /etc/redis/redis.conf; then
      echo "maxmemory ${redis_maxmemory}" | sudo tee -a /etc/redis/redis.conf
  fi
  
  # Restart Redis service & enable on boot
  systemctl restart redis-server
  systemctl enable redis-server

  # Verify Redis is running and responding
  if systemctl is-active redis-server >/dev/null 2>&1 && redis-cli ping >/dev/null 2>&1; then
    success "Redis installation completed and service is running!"
    return 0
  else
    error "Redis installation failed or service is not running properly!"
    return 1
  fi
}

uninstall() {
  if ! dpkg -l | grep -q redis-server; then
    warning "Redis is not installed!"
    return
  fi

  # Stop Redis service & disable on boot
  systemctl stop redis-server
  systemctl disable redis-server

  # Remove Redis package
  apt-get remove --purge redis-server -y
  apt-get autoremove -y

  success "Redis uninstallation completed!"
}
