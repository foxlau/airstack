# AirStack 用户手册

- [安装指南](#安装指南)
- [虚拟主机配置](#虚拟主机配置)
- [卸载指南](#卸载指南)
- [支持的操作系统](#支持的操作系统)
- [安全性建议](#安全性建议)
- [故障排除](#故障排除)

## 安装指南

AirStack 为 Ubuntu 上的 Web 应用程序提供了全面的堆栈部署解决方案。安装脚本（`install.sh`）指导您设置完整的生产环境。

### 系统要求

- Ubuntu 22.04 LTS 或 24.04 LTS
- Root 或 sudo 权限
- 至少 512MB 内存
- 最小 10GB 磁盘空间

### 安装步骤

1. 克隆仓库并使脚本可执行：

```bash
git clone https://github.com/foxlau/airstack.git
cd airstack
chmod +x install.sh uninstall.sh vhost.sh
```

2. 运行安装脚本：

```bash
sudo ./install.sh
```

3. 按照交互式提示进行操作：

- **Web 服务器堆栈**：安装 Nginx、Node.js 和 PM2（进程管理器）
- **数据库**：选择 MySQL 或 PostgreSQL
- **Redis**：可选的内存数据存储
- **Fail2ban**：强烈推荐安装的入侵防御系统，用于保障服务器安全

4. 安装后重启系统：

```bash
sudo reboot
```

### 组件详情

#### Web 服务器堆栈

- **Nginx**：高性能 HTTP 服务器
- **Node.js**：最新的 LTS 版本
- **PM2**：Node.js 应用程序的进程管理器

#### 数据库选项

- **MySQL**：流行的关系型数据库

  - 默认 root 密码：`rootair`（安装后立即更改）
  - 配置文件：`/etc/mysql/`

- **PostgreSQL**：高级对象关系型数据库
  - 默认超级用户密码：`rootair`（安装后立即更改）
  - 配置文件：`/etc/postgresql/`

#### 附加组件

- **Redis**：内存数据结构存储

  - 配置文件：`/etc/redis/`

- **Fail2ban**：入侵防御框架（强烈推荐）
  - 保护服务器免受暴力攻击
  - 监控日志并阻止可疑 IP 地址
  - 生产服务器安全的必要组件
  - 配置文件：`/etc/fail2ban/`

## 虚拟主机配置

`vhost.sh` 脚本为您的 Web 应用程序配置 Nginx 虚拟主机。

### 前提条件

- 已完成 AirStack 安装
- 域名指向您服务器的 IP 地址
- Node.js 应用程序在特定端口上运行

### 配置步骤

1. 运行虚拟主机配置脚本：

```bash
sudo ./vhost.sh
```

2. 按照交互式提示进行操作：

- **主域名**：您的主域名（例如，example.com）
- **辅助域名**：可选的附加域名（例如，www.example.com）
- **域名重定向**：将辅助域名重定向到主域名的选项
- **Node.js 端口**：您的应用程序运行的端口（默认：3000）
- **SSL 选项**：
  - 仅 HTTP
  - 使用 Let's Encrypt 的 HTTPS（自动 SSL 证书）
  - 自定义 SSL 证书

### SSL 配置

#### Let's Encrypt SSL

如果您选择 Let's Encrypt SSL：

1. 提供用于证书通知的电子邮件地址
2. 脚本将：
   - 验证域名所有权
   - 生成 SSL 证书
   - 配置自动续期（每天凌晨 3:00 运行）

#### 自定义 SSL 证书

如果您选择自定义 SSL：

1. 将您的 SSL 证书上传到：`/etc/nginx/ssl/your-domain/`
2. 所需文件：
   - `fullchain.pem`：完整证书链
   - `privkey.pem`：私钥文件

## 卸载指南

AirStack 提供了一个脚本，可在需要时删除已安装的组件。

### 卸载步骤

1. 运行卸载脚本：

```bash
sudo ./uninstall.sh
```

2. 选择要卸载的组件：

   - Node.js（JavaScript 运行时环境）
   - Nginx（HTTP 服务器）
   - MySQL（关系型数据库）
   - PostgreSQL（对象关系型数据库）
   - Redis（内存数据存储）
   - Fail2ban（入侵防御系统）

3. 确认您的选择

### 数据备份

**重要**：卸载前，备份任何重要数据：

- MySQL 数据库
- PostgreSQL 数据库
- 应用程序文件
- 配置文件

## 支持的操作系统

AirStack 在以下系统上测试和支持：

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

## 安全性建议

AirStack 包含了 Fail2ban 用于基本安全防护，但对于生产环境，还建议采取其他安全措施。

### 防火墙配置

**重要**：AirStack 目前不配置防火墙。强烈建议在您的服务器上设置防火墙以增强安全性。

#### 使用 UFW（简易防火墙）

UFW 是 Ubuntu 推荐的防火墙。以下是设置方法：

1. 如果尚未安装 UFW，请安装：

```bash
sudo apt-get install ufw
```

2. 设置默认策略：

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

3. 允许必要的服务：

```bash
# 允许 SSH 以防止被锁定
sudo ufw allow ssh

# 允许 HTTP/HTTPS 用于 Web 服务器
sudo ufw allow http
sudo ufw allow https

# 可选：如果需要，允许应用程序的特定端口
sudo ufw allow 3000/tcp
```

4. 启用防火墙：

```bash
sudo ufw enable
```

5. 检查状态：

```bash
sudo ufw status verbose
```

### 其他安全措施

- 定期更新系统：

```bash
sudo apt-get update && sudo apt-get upgrade
```

- 考虑设置日志监控
- 实施定期安全审计
- 为所有服务使用强密码
- 考虑禁用 SSH 密码认证，改用基于密钥的认证

## 故障排除

### 常见问题

#### 安装失败

- 检查 `logs` 目录中的安装日志
- 确保您的系统满足最低要求
- 验证安装期间的互联网连接

#### 虚拟主机配置问题

- 确保您的域名指向您服务器的 IP 地址
- 检查 DNS 传播是否完成
- 使用 `nginx -t` 验证 Nginx 配置

#### SSL 证书问题

- 对于 Let's Encrypt 故障，检查 Certbot 日志
- 确保互联网可访问端口 80
- 验证域名所有权

### 获取帮助

如果您遇到本文档未涵盖的问题：

- 检查 GitHub 仓库中的公开问题
- 打开一个新的问题，详细说明您的问题
- 包含相关日志和错误消息
