#!/bin/bash

NODEJS_INSTALL_DIR=/usr/local/node

install() {
  if [ -e "${NODEJS_INSTALL_DIR}/bin/node" ]; then
    warning "Nodejs is already installed. current version: $(node -v 2>&1)"
    return 1
  fi
  
  [ ! -d "${AIRSTACK_DIR}/src" ] && mkdir -p "${AIRSTACK_DIR}/src"
  pushd ${AIRSTACK_DIR}/src > /dev/null

  local nodejs_ver="20.18.0"
  local nodejs_filename="node-v${nodejs_ver}-linux-${NODEJS_ARCH}"
  local nodejs_tar="${nodejs_filename}.tar.gz"
  local download_url="https://nodejs.org/dist/v${nodejs_ver}/${nodejs_tar}"
  download_file ${nodejs_tar} ${download_url}

  # Extract and move Nodejs installation package
  tar xzf ${nodejs_tar}
  mkdir -p ${NODEJS_INSTALL_DIR}
  /bin/mv ${nodejs_filename}/* ${NODEJS_INSTALL_DIR}
  /bin/rm -rf ${nodejs_filename}
  
  # Configure Nodejs environment
  if [ -e "${NODEJS_INSTALL_DIR}/bin/node" ]; then
    cat > /etc/profile.d/nodejs.sh << EOF
export NODE_HOME=${NODEJS_INSTALL_DIR}
export PATH=\$NODE_HOME/bin:\$PATH
EOF
    . /etc/profile

    # Install pm2, pnpm, yarn
    echo "Installing pm2, pnpm, yarn..."
    npm install -g pm2@latest
    npm install -g pnpm@latest
    npm install -g yarn@latest

    echo "Current Node.js version: $(node -v)"
    success "Nodejs installed successfully!"
    popd > /dev/null
    return 0
  else
    error "Nodejs install failed!"
    grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    kill -9 $$;
    return 1
  fi
}

uninstall() {
  if [ -e "${NODEJS_INSTALL_DIR}" ]; then
    # Remove pm2, pnpm, yarn
    /usr/local/node/bin/pm2 kill
    npm uninstall -g pm2
    npm uninstall -g pnpm
    npm uninstall -g yarn

    # Remove Nodejs environment variables
    rm -rf $HOME/.pm2 $HOME/.npm
    rm -rf $HOME/.pnpm $HOME/.yarn
    rm -rf ${NODEJS_INSTALL_DIR} /etc/profile.d/nodejs.sh

    success "Nodejs uninstall completed!"
  else
    warning "Nodejs is not installed!"
  fi
}