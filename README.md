# TeslaMate Server Wizard

A simple, automated setup script for hosting your own TeslaMate server to track your Tesla vehicle data privately.

## 🚨 Important: Tesla Provider Restrictions

**Tesla blocks many popular cloud providers!** Before starting, you need to know:

- ❌ **Blocked providers**: DigitalOcean, Amazon AWS, Google Cloud, Microsoft Azure, and most major cloud providers
- ✅ **What works**: Your home computer, local/regional VPS providers, or smaller hosting companies

### How to Check if Your Server is Blocked

Before setting up, test if Tesla has blocked your server:

```bash
curl -I https://auth.tesla.com
```

- ✅ **Good response** (you can proceed):
  ```
  HTTP/2 302
  ```

- ❌ **Blocked response** (find another server):
  ```
  HTTP/2 403
  ```

If you see `403 Forbidden`, Tesla has blocked your server's IP range and TeslaMate won't work there.

## 📋 Prerequisites

### 1. A Compatible Server
- A server/VPS that isn't blocked by Tesla (test with the command above)
- Minimum 2GB RAM, 10GB storage
- Ubuntu 20.04+ or similar Linux distribution
- Your own computer with port forwarding is also an option

### 2. Your Own Domain
- You need to own a domain (e.g., `yourdomain.com`)
- You'll create two subdomains:
  - One for TeslaMate (e.g., `mycar.yourdomain.com`)
  - One for statistics (e.g., `mycar-stats.yourdomain.com`)

### 3. Basic Requirements
- An email address for SSL certificates
- Basic ability to use terminal/command line
- Access to your domain's DNS settings

## 🚀 Quick Start

### Step 1: Connect to Your Server

**For Windows users:**
1. Download [PuTTY](https://www.putty.org/)
2. Enter your server's IP address
3. Click "Open" and login with your credentials

**For Mac/Linux users:**
```bash
ssh your-username@your-server-ip
```

### Step 2: Install Required Software

Copy and paste these commands one by one:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Git
sudo apt install git -y

# Add your user to docker group (replace 'your-username' with your actual username)
sudo usermod -aG docker your-username

# Logout and login again for changes to take effect
exit
```

Login again to your server, then verify Docker is working:
```bash
docker --version
```

### Step 3: Download TeslaMate Setup

```bash
# Clone this repository (replace with your fork if you've made one)
git clone https://github.com/f/teslamate-server.git
cd teslamate-server
```

### Step 4: Run the Setup Script

```bash
# Make the script executable
chmod +x run.sh

# Run the setup
./run.sh
```

The script will ask you for:

1. **Email address**: For SSL certificates (Enter your real email)
2. **TeslaMate domain**: e.g., `mycar.yourdomain.com`
3. **Stats domain**: Will suggest `mycar-stats.yourdomain.com` (just press Enter to accept)
4. **Username**: Choose any username for web access (your secure password will be generated)
5. **Timezone**: Select your timezone from the list or press Enter for default

### Step 5: Configure Your Domain DNS

After the script completes, it will show your server's IP address. You need to:

1. **Login to your domain provider** (GoDaddy, Namecheap, Cloudflare, etc.)
2. **Add two DNS A records:**

   | Type | Name | Value | TTL |
   |------|------|-------|-----|
   | A | mycar | YOUR-SERVER-IP | 3600 |
   | A | mycar-stats | YOUR-SERVER-IP | 3600 |

   (Replace `mycar` with your chosen subdomain and YOUR-SERVER-IP with the IP shown by the script)

3. **Wait**: DNS changes can take 15 minutes to 48 hours to work everywhere

### Step 6: Start TeslaMate

If you didn't start the services during setup:

```bash
cd teslamate-server
docker compose up -d
```

Check if everything is running:
```bash
docker compose ps
```

All services should show as "running" or "healthy".

### Step 7: Get Tesla Authentication Tokens

You need to generate tokens to connect your Tesla:

**Option 1 - Easy (iPhone/Mac users):**
1. Download [Auth app for Tesla](https://apps.apple.com/us/app/auth-app-for-tesla/id1552058613) on your iPhone/Mac
2. Login with your Tesla account
3. The app will show your tokens

**Option 2 - Advanced (Windows/Linux users):**
1. Download [Tesla Auth](https://github.com/adriankumpf/tesla_auth/releases) for your system
2. Run the program and login
3. Copy the generated tokens

### Step 8: Connect Your Tesla to TeslaMate

1. Open your browser and go to `https://mycar.yourdomain.com`
2. Login with the username and password shown during setup
3. Paste your Tesla tokens
4. Save the configuration

## 📊 Access Your Data

- **TeslaMate**: `https://mycar.yourdomain.com` - Main interface
- **Grafana Stats**: `https://mycar-stats.yourdomain.com` - Beautiful dashboards
  - First login: Username `admin`, Password `admin` (you'll be asked to change it)

## 🔒 Security Notes

- Your credentials are saved in `credentials.txt` - keep this file safe!
- The script generates strong random passwords
- All connections use HTTPS encryption
- Your Tesla data stays on your own server

## 🛠️ Troubleshooting

### "Connection Refused" Error
- DNS might not have propagated yet (wait up to 48 hours)
- Check if services are running: `docker compose ps`
- View logs: `docker compose logs -f`

### "403 Forbidden" from Tesla
- Your server is blocked by Tesla
- You need to use a different server/provider

### Can't Access the Websites
1. Check DNS records are correct
2. Ensure ports 80 and 443 are open on your server

### Forgot Credentials
- Check the `credentials.txt` file: `cat teslamate-server/credentials.txt`

## 🔄 Updating TeslaMate

```bash
cd teslamate-server
docker compose pull
docker compose up -d
```

## 🛑 Stopping TeslaMate

```bash
cd teslamate-server
docker compose down
```

## 💾 Backup Your Data

The database is stored in Docker volumes. To backup:

```bash
# Create backup directory
mkdir ~/teslamate-backups

# Backup database
docker exec teslamate-server-database-1 pg_dump -U teslamate teslamate > ~/teslamate-backups/backup-$(date +%Y%m%d).sql
```

## 🆘 Getting Help

1. Check TeslaMate documentation: https://docs.teslamate.org/
2. TeslaMate GitHub issues: https://github.com/adriankumpf/teslamate/issues
3. TeslaMate Discord community

## 📝 Notes

- This setup uses Traefik for automatic SSL certificates
- PostgreSQL database for data storage
- Grafana for visualization
- Mosquitto for real-time updates
- All services run in Docker containers for easy management

---

Remember: Your Tesla data is precious. This setup ensures you own and control your vehicle's data privately on your own server! 