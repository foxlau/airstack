# AirStack User Manual

- [Installation Guide](#installation-guide)
- [Virtual Host Configuration](#virtual-host-configuration)
- [Uninstallation Guide](#uninstallation-guide)
- [Supported Operating Systems](#supported-operating-systems)
- [Security Recommendations](#security-recommendations)
- [Troubleshooting](#troubleshooting)

## Installation Guide

AirStack provides a comprehensive stack deployment solution for web applications on Ubuntu. The installation script (`install.sh`) guides you through setting up a complete production environment.

### Prerequisites

- Ubuntu 22.04 LTS or 24.04 LTS
- Root or sudo privileges
- At least 512MB RAM
- Minimum 10GB disk space

### Installation Steps

1. Clone the repository and make scripts executable:

```bash
git clone https://github.com/foxlau/airstack.git
cd airstack
chmod +x install.sh uninstall.sh vhost.sh
```

2. Run the installation script:

```bash
sudo ./install.sh
```

3. Follow the interactive prompts:

- **Web server stack**: Installs Nginx, Node.js, and PM2 (Process Manager)
- **Database**: Choose between MySQL or PostgreSQL
- **Redis**: Optional in-memory data store
- **Fail2ban**: Highly recommended intrusion prevention system for server security

4. Reboot your system after installation:

```bash
sudo reboot
```

### Component Details

#### Web Server Stack

- **Nginx**: High-performance HTTP server
- **Node.js**: Latest LTS version
- **PM2**: Process manager for Node.js applications

#### Database Options

- **MySQL**: Popular relational database

  - Default root password: `rootair` (change immediately after installation)
  - Configuration files: `/etc/mysql/`

- **PostgreSQL**: Advanced object-relational database
  - Default superuser password: `rootair` (change immediately after installation)
  - Configuration files: `/etc/postgresql/`

#### Additional Components

- **Redis**: In-memory data structure store

  - Configuration files: `/etc/redis/`

- **Fail2ban**: Intrusion prevention framework (Strongly Recommended)
  - Protects your server from brute force attacks
  - Monitors logs and blocks suspicious IP addresses
  - Essential for production server security
  - Configuration files: `/etc/fail2ban/`

## Virtual Host Configuration

The `vhost.sh` script configures Nginx virtual hosts for your web applications.

### Prerequisites

- Completed AirStack installation
- Domain name pointing to your server's IP address
- Node.js application running on a specific port

### Configuration Steps

1. Run the virtual host configuration script:

```bash
sudo ./vhost.sh
```

2. Follow the interactive prompts:

- **Primary domain**: Your main domain (e.g., example.com)
- **Secondary domain**: Optional additional domain (e.g., www.example.com)
- **Domain redirect**: Option to redirect secondary to primary domain
- **Node.js port**: The port your application is running on (default: 3000)
- **SSL options**:
  - HTTP only
  - HTTPS with Let's Encrypt (automated SSL certificates)
  - Custom SSL certificate

### SSL Configuration

#### Let's Encrypt SSL

If you choose Let's Encrypt SSL:

1. Provide an email address for certificate notifications
2. The script will:
   - Verify domain ownership
   - Generate SSL certificates
   - Configure automatic renewal (runs daily at 3:00 AM)

#### Custom SSL Certificate

If you choose custom SSL:

1. Upload your SSL certificates to: `/etc/nginx/ssl/your-domain/`
2. Required files:
   - `fullchain.pem`: Full certificate chain
   - `privkey.pem`: Private key file

## Uninstallation Guide

AirStack provides a script to remove installed components when needed.

### Uninstallation Steps

1. Run the uninstallation script:

```bash
sudo ./uninstall.sh
```

2. Select the components you want to uninstall:

   - Node.js (JavaScript Runtime Environment)
   - Nginx (HTTP Server)
   - MySQL (Relational Database)
   - PostgreSQL (Object-Relational Database)
   - Redis (In-Memory Data Store)
   - Fail2ban (Intrusion Prevention System)

3. Confirm your selection

### Data Backup

**Important:** Before uninstalling, back up any important data:

- MySQL databases
- PostgreSQL databases
- Application files
- Configuration files

## Supported Operating Systems

AirStack is tested and supported on:

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

## Security Recommendations

AirStack includes Fail2ban for basic security, but additional measures are recommended for production environments.

### Firewall Configuration

**Important:** AirStack does not currently configure a firewall. It is strongly recommended to set up a firewall on your server for enhanced security.

#### Using UFW (Uncomplicated Firewall)

UFW is the recommended firewall for Ubuntu. Here's how to set it up:

1. Install UFW if not already installed:

```bash
sudo apt-get install ufw
```

2. Set default policies:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

3. Allow essential services:

```bash
# Allow SSH to prevent being locked out
sudo ufw allow ssh

# Allow HTTP/HTTPS for web server
sudo ufw allow http
sudo ufw allow https

# Optional: Allow specific ports for your application if needed
sudo ufw allow 3000/tcp
```

4. Enable the firewall:

```bash
sudo ufw enable
```

5. Check status:

```bash
sudo ufw status verbose
```

### Additional Security Measures

- Regularly update your system:

```bash
sudo apt-get update && sudo apt-get upgrade
```

- Consider setting up log monitoring
- Implement regular security audits
- Use strong, unique passwords for all services
- Consider disabling password authentication for SSH and using key-based authentication instead

## Troubleshooting

### Common Issues

#### Installation Failures

- Check the installation logs in the `logs` directory
- Ensure your system meets the minimum requirements
- Verify internet connectivity during installation

#### Virtual Host Configuration Issues

- Ensure your domain points to your server's IP address
- Check that DNS propagation is complete
- Verify Nginx configuration with `nginx -t`

#### SSL Certificate Issues

- For Let's Encrypt failures, check the Certbot logs
- Ensure port 80 is accessible from the internet
- Verify domain ownership

### Getting Help

If you encounter issues not covered in this documentation:

- Check the GitHub repository for open issues
- Open a new issue with detailed information about your problem
- Include relevant logs and error messages
