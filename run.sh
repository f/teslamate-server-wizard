#!/bin/bash

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}    TeslaMate Server Setup Script   ${NC}"
echo -e "${BLUE}====================================${NC}\n"

# Function to generate secure random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to generate htpasswd hash
generate_htpasswd() {
    local username=$1
    local password=$2
    # Using openssl to generate Apache htpasswd compatible hash
    echo -n "$username:"
    openssl passwd -apr1 "$password"
}

# Check if docker and docker-compose are installed
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: Git is not installed. Please install Git first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}\n"

# Clone Teslamate-CustomGrafanaDashboards if not already present
echo -e "${YELLOW}Setting up Grafana custom dashboards...${NC}"
if [ ! -d "Teslamate-CustomGrafanaDashboards" ]; then
    echo "Cloning Teslamate-CustomGrafanaDashboards repository..."
    git clone https://github.com/jheredianet/Teslamate-CustomGrafanaDashboards.git
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully cloned custom dashboards${NC}\n"
    else
        echo -e "${RED}Error: Failed to clone repository${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Custom dashboards directory already exists${NC}\n"
fi

# Collect configuration values
echo -e "${BLUE}Please provide the following configuration:${NC}\n"

# Email for Let's Encrypt
read -e -p "Enter your email address for Let's Encrypt SSL certificates: " LETSENCRYPT_EMAIL
while [[ ! "$LETSENCRYPT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
    echo -e "${RED}Invalid email format. Please try again.${NC}"
    read -e -p "Enter your email address for Let's Encrypt SSL certificates: " LETSENCRYPT_EMAIL
done

# Domain for TeslaMate
echo -e "\n${YELLOW}Domain Configuration Requirements:${NC}"
echo -e "You'll need to create DNS A records pointing to this server's IP address."
echo -e "Your server's IP address is: ${BLUE}$(curl -s ifconfig.me 2>/dev/null || echo 'Unable to detect')${NC}"
echo -e "\n${YELLOW}DNS records needed:${NC}"
echo -e "1. A record for TeslaMate domain → Your server IP"
echo -e "2. A record for Grafana domain → Your server IP"
echo -e "\n${YELLOW}Note: DNS changes can take up to 48 hours to propagate${NC}\n"
read -e -p "Enter the domain for TeslaMate (e.g., yourcarname.yourprivatedomain.com): " DOMAIN
while [[ -z "$DOMAIN" ]]; do
    echo -e "${RED}Domain cannot be empty. Please try again.${NC}"
    read -e -p "Enter the domain for TeslaMate: " DOMAIN
done

# Domain for Grafana stats
# Parse the TeslaMate domain to suggest a smart default for Grafana
if [[ "$DOMAIN" =~ ^([^.]+)\.(.+)$ ]]; then
    # Has subdomain - add "-stats" to the subdomain
    SUBDOMAIN="${BASH_REMATCH[1]}"
    BASE_DOMAIN="${BASH_REMATCH[2]}"
    DEFAULT_STATS_DOMAIN="${SUBDOMAIN}-stats.${BASE_DOMAIN}"
else
    # No subdomain - use "stats" as subdomain
    DEFAULT_STATS_DOMAIN="stats.${DOMAIN}"
fi

read -e -p "Enter the domain for Grafana stats (default: $DEFAULT_STATS_DOMAIN): " STATS_DOMAIN
STATS_DOMAIN=${STATS_DOMAIN:-$DEFAULT_STATS_DOMAIN}
while [[ -z "$STATS_DOMAIN" ]] || [[ "$STATS_DOMAIN" == "$DOMAIN" ]]; do
    if [[ -z "$STATS_DOMAIN" ]]; then
        echo -e "${RED}Domain cannot be empty. Please try again.${NC}"
    elif [[ "$STATS_DOMAIN" == "$DOMAIN" ]]; then
        echo -e "${RED}Grafana stats domain must be different from TeslaMate domain. Please try again.${NC}"
    fi
    read -e -p "Enter the domain for Grafana stats (default: $DEFAULT_STATS_DOMAIN): " STATS_DOMAIN
    STATS_DOMAIN=${STATS_DOMAIN:-$DEFAULT_STATS_DOMAIN}
done

# Basic auth username
echo -e "\n${YELLOW}Setting up basic authentication for web access${NC}"
read -e -p "Enter username for basic authentication: " BASIC_AUTH_USER
while [[ -z "$BASIC_AUTH_USER" ]]; do
    echo -e "${RED}Username cannot be empty. Please try again.${NC}"
    read -e -p "Enter username for basic authentication: " BASIC_AUTH_USER
done

# Timezone
echo -e "\n${YELLOW}Setting timezone for Grafana${NC}"

# Try to detect system timezone
DEFAULT_TZ=""
if [ -f /etc/timezone ]; then
    DEFAULT_TZ=$(cat /etc/timezone)
elif [ -L /etc/localtime ]; then
    # For systems using systemd (like Ubuntu)
    DEFAULT_TZ=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')
elif [ -f /etc/localtime ] && command -v strings &> /dev/null; then
    # For macOS
    DEFAULT_TZ=$(strings /etc/localtime | tail -1)
fi

# Fallback to UTC if detection failed
DEFAULT_TZ=${DEFAULT_TZ:-UTC}

echo -e "Detected system timezone: ${BLUE}$DEFAULT_TZ${NC}"
echo -e "\n${YELLOW}Common timezones:${NC}"
echo -e "${BLUE}Americas:${NC}"
echo -e "  1) America/New_York (Eastern)"
echo -e "  2) America/Chicago (Central)"
echo -e "  3) America/Denver (Mountain)"
echo -e "  4) America/Los_Angeles (Pacific)"
echo -e "  5) America/Toronto"
echo -e "  6) America/Mexico_City"
echo -e "  7) America/Sao_Paulo"
echo -e "\n${BLUE}Europe:${NC}"
echo -e "  8) Europe/London"
echo -e "  9) Europe/Paris"
echo -e " 10) Europe/Berlin"
echo -e " 11) Europe/Rome"
echo -e " 12) Europe/Madrid"
echo -e " 13) Europe/Istanbul"
echo -e " 14) Europe/Moscow"
echo -e "\n${BLUE}Asia:${NC}"
echo -e " 15) Asia/Dubai"
echo -e " 16) Asia/Shanghai"
echo -e " 17) Asia/Hong_Kong"
echo -e " 18) Asia/Tokyo"
echo -e " 19) Asia/Seoul"
echo -e " 20) Asia/Singapore"
echo -e " 21) Asia/Kolkata (India)"
echo -e "\n${BLUE}Pacific:${NC}"
echo -e " 22) Australia/Sydney"
echo -e " 23) Australia/Melbourne"
echo -e " 24) Pacific/Auckland"
echo -e "\n 25) UTC"
echo -e "\nEnter a number (1-25), press Enter for detected timezone, or type a custom timezone"
echo -e "For full list see: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"

read -e -p "Timezone selection (default: $DEFAULT_TZ): " TZ_CHOICE

# Process the choice
case "$TZ_CHOICE" in
    1) TIMEZONE="America/New_York" ;;
    2) TIMEZONE="America/Chicago" ;;
    3) TIMEZONE="America/Denver" ;;
    4) TIMEZONE="America/Los_Angeles" ;;
    5) TIMEZONE="America/Toronto" ;;
    6) TIMEZONE="America/Mexico_City" ;;
    7) TIMEZONE="America/Sao_Paulo" ;;
    8) TIMEZONE="Europe/London" ;;
    9) TIMEZONE="Europe/Paris" ;;
    10) TIMEZONE="Europe/Berlin" ;;
    11) TIMEZONE="Europe/Rome" ;;
    12) TIMEZONE="Europe/Madrid" ;;
    13) TIMEZONE="Europe/Istanbul" ;;
    14) TIMEZONE="Europe/Moscow" ;;
    15) TIMEZONE="Asia/Dubai" ;;
    16) TIMEZONE="Asia/Shanghai" ;;
    17) TIMEZONE="Asia/Hong_Kong" ;;
    18) TIMEZONE="Asia/Tokyo" ;;
    19) TIMEZONE="Asia/Seoul" ;;
    20) TIMEZONE="Asia/Singapore" ;;
    21) TIMEZONE="Asia/Kolkata" ;;
    22) TIMEZONE="Australia/Sydney" ;;
    23) TIMEZONE="Australia/Melbourne" ;;
    24) TIMEZONE="Pacific/Auckland" ;;
    25) TIMEZONE="UTC" ;;
    "") TIMEZONE="$DEFAULT_TZ" ;;  # User pressed Enter
    *) TIMEZONE="$TZ_CHOICE" ;;     # Custom timezone entered
esac

echo -e "${GREEN}✓ Using timezone: $TIMEZONE${NC}"

# Generate passwords
echo -e "\n${YELLOW}Generating secure passwords...${NC}"
ENCRYPTION_KEY=$(generate_password)
DATABASE_PASS=$(generate_password)
BASIC_AUTH_PASS=$(generate_password)

# Generate htpasswd string
BASIC_AUTH=$(generate_htpasswd "$BASIC_AUTH_USER" "$BASIC_AUTH_PASS")

# Get current directory
CURRENT_DIRECTORY=$(pwd)

# Create necessary directories
echo -e "\n${YELLOW}Creating necessary directories...${NC}"
mkdir -p letsencrypt import
echo -e "${GREEN}✓ Directories created${NC}"

# Generate docker-compose.yml from template
echo -e "\n${YELLOW}Generating docker-compose.yml...${NC}"
sed -e "s|{{ LETSENCRYPT_EMAIL }}|$LETSENCRYPT_EMAIL|g" \
    -e "s|{{ ENCRYPTION_KEY }}|$ENCRYPTION_KEY|g" \
    -e "s|{{ DATABASE_PASS }}|$DATABASE_PASS|g" \
    -e "s|{{ DOMAIN }}|$DOMAIN|g" \
    -e "s|{{ STATS_DOMAIN }}|$STATS_DOMAIN|g" \
    -e "s|{{ BASIC_AUTH }}|$BASIC_AUTH|g" \
    -e "s|{{ CURRENT_DIRECTORY }}|$CURRENT_DIRECTORY|g" \
    -e "s|{{ TIMEZONE }}|$TIMEZONE|g" \
    docker-compose.yml.tpl > docker-compose.yml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ docker-compose.yml generated successfully${NC}"
else
    echo -e "${RED}Error: Failed to generate docker-compose.yml${NC}"
    exit 1
fi

# Save credentials to a file
echo -e "\n${YELLOW}Saving credentials...${NC}"
cat > credentials.txt << EOF
===================================
    TeslaMate Server Credentials
===================================
Generated on: $(date)

IMPORTANT: Keep these credentials safe!

Web Access:
-----------
TeslaMate URL: https://$DOMAIN
Grafana URL: https://$STATS_DOMAIN
Username: $BASIC_AUTH_USER
Password: $BASIC_AUTH_PASS

Database:
---------
Database Password: $DATABASE_PASS

Encryption:
-----------
Encryption Key: $ENCRYPTION_KEY

Let's Encrypt Email: $LETSENCRYPT_EMAIL

Configuration:
--------------
Timezone: $TIMEZONE

Grafana Default Login:
---------------------
Initial Username: admin
Initial Password: admin
(You'll be prompted to change this on first login)

DNS Configuration Required:
--------------------------
Create A records pointing both domains to your server IP

===================================
EOF

chmod 600 credentials.txt
echo -e "${GREEN}✓ Credentials saved to credentials.txt (read-only by owner)${NC}"

# Display summary
echo -e "\n${GREEN}====================================${NC}"
echo -e "${GREEN}    Configuration Complete!${NC}"
echo -e "${GREEN}====================================${NC}\n"
echo -e "TeslaMate URL: ${BLUE}https://$DOMAIN${NC}"
echo -e "Grafana URL: ${BLUE}https://$STATS_DOMAIN${NC}"
echo -e "Username: ${BLUE}$BASIC_AUTH_USER${NC}"
echo -e "Password: ${BLUE}$BASIC_AUTH_PASS${NC}"
echo -e "\n${YELLOW}⚠️  These credentials have been saved to 'credentials.txt'${NC}"
echo -e "${YELLOW}⚠️  Make sure to keep this file secure!${NC}"
echo -e "\n${YELLOW}📊 Grafana Default Login:${NC}"
echo -e "Username: ${BLUE}admin${NC}"
echo -e "Password: ${BLUE}admin${NC}"
echo -e "${YELLOW}You'll be prompted to change the password on first login${NC}\n"

# Ask about MCP server
echo -e "\n${YELLOW}MCP Server for AI Integration${NC}"
echo -e "MCP allows AI assistants (like Claude) to query your Tesla data"
read -e -p "Do you want to install the MCP server for AI integration? (y/n): " INSTALL_MCP

if [[ "$INSTALL_MCP" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Setting up MCP server...${NC}"
    
    # Clone the MCP repository
    if [ ! -d "teslamate-mcp" ]; then
        git clone https://github.com/cobanov/teslamate-mcp.git
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Successfully cloned MCP server${NC}"
        else
            echo -e "${RED}Error: Failed to clone MCP repository${NC}"
            INSTALL_MCP="n"
        fi
    else
        echo -e "${GREEN}✓ MCP server directory already exists${NC}"
    fi
    
    if [[ "$INSTALL_MCP" =~ ^[Yy]$ ]]; then
        # Generate auth token for MCP
        MCP_AUTH_TOKEN=$(generate_password)
        
        # Create .env file for MCP
        cat > teslamate-mcp/.env << EOF
DATABASE_URL=postgresql://teslamate:$DATABASE_PASS@database:5432/teslamate
AUTH_TOKEN=$MCP_AUTH_TOKEN
EOF
        
        echo -e "${GREEN}✓ MCP server configured${NC}"
        
        # Determine MCP URL based on domain availability
        if [[ -n "$DOMAIN" ]]; then
            MCP_URL="http://${DOMAIN}:8888/mcp"
        else
            MCP_URL="http://localhost:8888/mcp"
        fi
        
        # Add MCP configuration to credentials file
        cat >> credentials.txt << EOF

MCP Server (AI Integration):
---------------------------
MCP Server URL: $MCP_URL
Auth Token: $MCP_AUTH_TOKEN
Port: 8888 (ensure this port is open in your firewall if using remote access)

To use with Claude Desktop, add to config:
{
  "mcpServers": {
    "TeslaMate": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "$MCP_URL",
        "--allow-http",
        "--header",
        "Authorization:Bearer $MCP_AUTH_TOKEN"
      ]
    }
  }
}

Note: Claude Desktop requires Node.js/npm to be installed locally.
EOF
        
        # Determine port binding based on domain availability
        if [[ -n "$DOMAIN" ]]; then
            # If domain is configured, expose externally
            PORT_BINDING="8888:8888"
            echo -e "${YELLOW}Note: MCP server will be exposed on port 8888 for remote access${NC}"
        else
            # Local access only
            PORT_BINDING="127.0.0.1:8888:8888"
        fi
        
        # Add MCP service to docker-compose.yml after mosquitto service
        # Create a temporary file with the MCP service definition
        cat > .mcp-service-temp.yml << EOF

  teslamate-mcp:
    image: python:3.11-slim
    restart: always
    working_dir: /app
    command: >
      sh -c "apt-get update && apt-get install -y git &&
             pip install --no-cache-dir uv &&
             uv sync &&
             uv run python main_remote.py"
    volumes:
      - ./teslamate-mcp:/app
    ports:
      - "${PORT_BINDING}"
    environment:
      - DATABASE_URL=postgresql://teslamate:${DATABASE_PASS}@database:5432/teslamate
      - AUTH_TOKEN=${MCP_AUTH_TOKEN}
    networks:
      - teslamate
    depends_on:
      - database
EOF
        
        # Insert the MCP service after the mosquitto service (before the networks section)
        # First, split the file at the networks: line
        sed '/^networks:/,$d' docker-compose.yml > .docker-compose-top.yml
        sed -n '/^networks:/,$p' docker-compose.yml > .docker-compose-bottom.yml
        
        # Combine the parts with the MCP service in between
        cat .docker-compose-top.yml .mcp-service-temp.yml .docker-compose-bottom.yml > docker-compose.yml
        
        # Clean up temporary files
        rm -f .mcp-service-temp.yml .docker-compose-top.yml .docker-compose-bottom.yml
        
        echo -e "${GREEN}✓ MCP service added to docker-compose.yml${NC}"
    fi
fi

# Ask to start services
echo -e "\n${YELLOW}Ready to start TeslaMate services.${NC}"
if [[ "$INSTALL_MCP" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}This will also start the MCP server for AI integration.${NC}"
fi
read -e -p "Do you want to start the services now? (y/n): " START_NOW

if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Starting TeslaMate services...${NC}"
    
    docker compose up -d
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}✓ Services started successfully!${NC}"
        echo -e "\n${YELLOW}Note: It may take a few minutes for all services to be fully ready.${NC}"
        echo -e "${YELLOW}You can check the status with: docker compose ps${NC}"
        echo -e "${YELLOW}View logs with: docker compose logs -f${NC}"
    else
        echo -e "${RED}Error: Failed to start services${NC}"
        exit 1
    fi
else
    echo -e "\n${YELLOW}You can start the services later with:${NC}"
    echo -e "docker compose up -d"
fi

echo -e "\n${GREEN}Setup complete!${NC}"
echo -e "\n${YELLOW}⚠️  Important Next Steps:${NC}"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo 'Unable to detect')
echo -e "1. Configure DNS A records to point to: ${BLUE}$SERVER_IP${NC}"
echo -e "   - $DOMAIN → $SERVER_IP"
echo -e "   - $STATS_DOMAIN → $SERVER_IP"
echo -e "2. Wait for DNS propagation (can take up to 48 hours)"
echo -e "3. Access Grafana with username 'admin' and password 'admin' (you'll be prompted to change it)"
echo -e "4. The basic auth credentials above are for accessing TeslaMate and Grafana web interfaces"
echo -e "\n${YELLOW}🔐 Tesla Authentication:${NC}"
echo -e "To connect your Tesla to TeslaMate, you'll need to generate API tokens (UI will guide you through the process)."
echo -e "\n${BLUE}Download the appropriate app on your personal device:${NC}"
echo -e "• ${GREEN}iOS/macOS:${NC} Auth app for Tesla (easy to use)"
echo -e "  https://apps.apple.com/us/app/auth-app-for-tesla/id1552058613"
echo -e "• ${GREEN}Windows/Linux:${NC} Tesla Auth (advanced)"
echo -e "  https://github.com/adriankumpf/tesla_auth"
echo -e "\nUse the app to generate tokens, then add them to TeslaMate at: ${BLUE}https://$DOMAIN${NC}"

if [[ "$INSTALL_MCP" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}🤖 AI Integration (MCP Server):${NC}"
    
    # Use the same MCP_URL logic
    if [[ -n "$DOMAIN" ]]; then
        MCP_URL="http://${DOMAIN}:8888/mcp"
    else
        MCP_URL="http://localhost:8888/mcp"
    fi
    
    if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
        echo -e "Your MCP server is running at: ${BLUE}$MCP_URL${NC}"
    else
        echo -e "Your MCP server will be available at: ${BLUE}$MCP_URL${NC}"
        echo -e "after starting the services"
    fi
    if [[ -n "$DOMAIN" ]]; then
        echo -e "${YELLOW}Important: Ensure port 8888 is open in your firewall${NC}"
    fi
    echo -e "Check ${BLUE}credentials.txt${NC} for Claude Desktop configuration"
    echo -e "${YELLOW}Note: Claude Desktop requires Node.js installed on your local computer${NC}"
    echo -e "Learn more: https://github.com/cobanov/teslamate-mcp"
fi 