#!/bin/bash

# Set system environment variables
export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en

# System packages update and security patches
apt-get -y update
apt-get -y autoremove
apt-get -yf install

# critical security updates
grep security /etc/apt/sources.list > /tmp/security.sources.list
apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list

# Set PS1 (only for Ubuntu)
if [ -f /etc/os-release ]; then
    if [ -z "$(grep ^PS1 $HOME/.bashrc)" ]; then
        echo "PS1='\\[\\e[1;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '" >> $HOME/.bashrc
    fi
fi

# Set history timestamp
if [ -z "$(grep history-timestamp $HOME/.bashrc)" ]; then
    echo "PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });user=\$(whoami); echo \$(date \"+%Y-%m-%d %H:%M:%S\"):\$user:\$(pwd)/:\$msg ---- \$(who am i); } >> /tmp/\$(hostname).\$(whoami).history-timestamp'" >> $HOME/.bashrc
fi

# System resource limits configuration
if [ -e /etc/security/limits.d/*nproc.conf ] || \
   [ -z "$(grep 'session required pam_limits.so' /etc/pam.d/common-session)" ] || \
   ! grep -q "^# End of file" /etc/security/limits.conf; then
    [ -e /etc/security/limits.d/*nproc.conf ] && mv /etc/security/limits.d/*nproc.conf{,_bk}
    [ -z "$(grep 'session required pam_limits.so' /etc/pam.d/common-session)" ] && \
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    
    sed -i '/^# End of file/,$d' /etc/security/limits.conf
    cat >> /etc/security/limits.conf <<EOF
# End of file
* soft nproc 1000000
* hard nproc 1000000
* soft nofile 1000000
* hard nofile 1000000
root soft nproc 1000000
root hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF
fi

# Kernel parameters optimization
if [ -z "$(grep 'fs.file-max' /etc/sysctl.conf)" ]; then
    cat >> /etc/sysctl.conf << EOF
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
EOF
    sysctl -p
fi

# Configure swap if needed
if [ ! -e ~/.airstack ] && [ ! -e /swapfile ] && [ ${MEMORY_MB} -le 2048 ]; then
    dd if=/dev/zero of=/swapfile count=2048 bs=1M
    mkswap /swapfile
    swapon /swapfile
    chmod 600 /swapfile
    echo '/swapfile    swap    swap    defaults    0 0' >> /etc/fstab
fi

# Install essential packages
BASIC_PACKAGES=("git" "zip" "unzip" "ufw")
apt-get -y install "${BASIC_PACKAGES[@]}"

# Configure UFW firewall
if command -v ufw &> /dev/null; then
    sed -i 's/IPV6=no/IPV6=yes/' /etc/default/ufw
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
fi

# Reload system configuration
source /etc/profile
source ~/.bashrc

# Mark configuration as completed
echo "System (${OS_TYPE} ${OS_VERSION}) configuration has been completed at $(date '+%Y-%m-%d %H:%M:%S')" > ~/.airstack

# Clear memory cache
sync; echo 3 > /proc/sys/vm/drop_caches