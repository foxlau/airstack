# AirStack

## 📝 Overview

AirStack makes self-hosting as simple as serverless - just one script to set up your entire production environment. Perfect for developers who want to deploy quickly on affordable VPS servers.

### ✨ Key Features

- One-command production stack deployment
- Cost-effective VPS hosting
- Production-ready security defaults
- Automated stack configuration:
  - Node.js (Latest LTS)
  - Nginx (with optimized configurations)
  - MySQL/PostgreSQL
  - Redis
  - Fail2ban
  - PM2
  - Let's Encrypt SSL

## ✅ Verified Environments

- DigitalOcean: 1vCPU/512MB VPS
- Ubuntu 22.04, 24.04 LTS [![Installation & Integration Tests](https://github.com/foxlau/airstack/actions/workflows/integration-tests.yml/badge.svg)](https://github.com/foxlau/airstack/actions/workflows/integration-tests.yml)

## 🛠️ Supported Frameworks

| Framework | Type  | Status    | Repository                                                      |
| --------- | ----- | --------- | --------------------------------------------------------------- |
| Remix.run | React | ✅ Tested | [remix-run/remix](https://github.com/remix-run/remix)           |
| Next.js   | React | ✅ Tested | [vercel/next.js](https://github.com/vercel/next.js)             |
| Umami     | React | ✅ Tested | [umami-software/umami](https://github.com/umami-software/umami) |
| Nuxt.js   | Vue   | ✅ Tested | [nuxt/nuxt](https://github.com/nuxt/nuxt)                       |

## 🏃 Quick Start

```bash
# Clone and install
git clone https://github.com/foxlau/airstack.git
cd airstack
e install.sh uninstall.sh vhost.sh check.sh

# Installation completed! It's recommended to reboot your system before proceeding.
# Installation logs are stored in the `logs/` directory.
sudo ./install.sh

# Configure Nginx virtual hosts
sudo ./vhost.sh

# Uninstall (if needed)
sudo ./uninstall.sh

# Server check
# Performs a comprehensive server health and security check. Detailed reports are saved in the `logs/` directory.
sudo ./check.sh
```

## 📚 Documentation

Detailed documentation is available in multiple languages:

- [English Documentation](docs/en/README.md)
- [中文文档](docs/zh/README.md)
- [日本語ドキュメント](docs/ja/README.md)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
