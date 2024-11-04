#!/bin/bash

# Check if /etc/os-release exists
if [[ ! -e "/etc/os-release" ]]; then
    error_exit "/etc/os-release does not exist!"
fi

# Source OS information
. /etc/os-release

# System identification variables
readonly OS_TYPE=${ID,,}
readonly OS_VERSION=${VERSION_ID%%.*}
readonly OS_ARCH=$(arch)

# Validate OS type
if [[ ! "${OS_TYPE}" =~ ^(ubuntu|debian)$ ]]; then
    error_exit "Does not support this OS (${OS_TYPE})"
fi

# Validate OS version
if [[ "${OS_TYPE}" == "ubuntu" && ${OS_VERSION:-0} -lt 20 ]]; then
    error_exit "Does not support Ubuntu ${OS_VERSION}, Please install Ubuntu 20+"
elif [[ "${OS_TYPE}" == "debian" && ${OS_VERSION:-0} -lt 11 ]]; then
    error_exit "Does not support Debian ${OS_VERSION}, Please install Debian 11+"
fi

# Early architecture validation
if [ "$(getconf WORD_BIT)" == "32" ] && [ "$(getconf LONG_BIT)" == "32" ]; then
    error_exit "32-bit OS are not supported!"
fi

# Architecture detection
IS_ARM=false
if uname -m | grep -Eqi "arm|aarch64"; then
    IS_ARM=true
    if uname -m | grep -Eqi "armv7"; then
        readonly CPU_ARCH="armv7"
    elif uname -m | grep -Eqi "armv8"; then
        readonly CPU_ARCH="arm64"
    elif uname -m | grep -Eqi "aarch64"; then
        readonly CPU_ARCH="aarch64"
    else
        readonly CPU_ARCH="unknown"
    fi
fi

# System architecture variables for different applications
if [ "${CPU_ARCH}" == 'aarch64' ]; then
    readonly MYSQL_ARCH="aarch64"
    readonly NODEJS_ARCH="arm64"
else
    readonly MYSQL_ARCH="x86_64"
    readonly NODEJS_ARCH="x64"
fi

# WSL detection
readonly IS_WSL=$([ "$(uname -r | awk -F- '{print $3}' 2>/dev/null)" == "Microsoft" ] && echo true || echo false)

# System resources
readonly CPU_THREADS=$(lscpu -p | egrep -v '^#' | sort -u -t, -k 2,4 | wc -l)
readonly DISK_SIZE=$(df -h / | awk '/^\/dev/ {print $2}')
readonly MEMORY_MB=$(free -m | awk '/Mem:/ {print $2}')
readonly MEMORY_KB=$(free -k | awk '/Mem:/ {print $2}')
readonly SWAP_MB=$(free -m | awk '/Swap:/ {print $2}')

# SSL version
readonly SSL_VERSION=$([ ${OS_VERSION:-0} -ge 20 ] && echo "ssl111" || echo "ssl102")