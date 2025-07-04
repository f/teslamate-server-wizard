#!/bin/bash

# TeslaMate Server Prerequisites Installer
# This script installs Docker, Git, and other requirements for TeslaMate

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}  TeslaMate Prerequisites Installer ${NC}"
echo -e "${BLUE}====================================${NC}\n"

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}⚠️  Please don't run this script as root${NC}"
   echo -e "\nYou need to create a regular user first:"
   echo -e "${YELLOW}adduser tesla${NC}              # Create a new user"
   echo -e "${YELLOW}usermod -aG sudo tesla${NC}     # Add user to sudo group"
   echo -e "${YELLOW}su - tesla${NC}                 # Switch to the new user"
   echo -e "\nThen run this installer again as the new user."
   exit 1
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    echo -e "${RED}Error: sudo is not installed${NC}"
    echo "Please install sudo first"
    exit 1
fi

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install basic requirements
echo -e "\n${YELLOW}Installing basic requirements...${NC}"
sudo apt install -y curl git wget ca-certificates gnupg lsb-release

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo -e "\n${YELLOW}Installing Docker...${NC}"
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo -e "${GREEN}✓ Docker installed successfully${NC}"
else
    echo -e "${GREEN}✓ Docker is already installed${NC}"
    
    # Ensure docker compose plugin is installed
    if ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}Installing Docker Compose plugin...${NC}"
        sudo apt install -y docker-compose-plugin
    fi
fi

# Add current user to docker group
echo -e "\n${YELLOW}Adding user to docker group...${NC}"
sudo usermod -aG docker $USER
echo -e "${GREEN}✓ User added to docker group${NC}"

# Check Tesla auth endpoint
echo -e "\n${YELLOW}Checking if Tesla allows connections from this server...${NC}"
TESLA_CHECK=$(curl -s -o /dev/null -w "%{http_code}" -I https://auth.tesla.com || echo "000")

if [ "$TESLA_CHECK" = "403" ]; then
    echo -e "${RED}⚠️  WARNING: Tesla is blocking this server!${NC}"
    echo -e "${RED}This server's IP range is blocked by Tesla.${NC}"
    echo -e "${RED}TeslaMate will NOT work from this server.${NC}"
    echo -e "\nYou need to use:"
    echo -e "- A different VPS provider (not AWS, GCP, Azure, DigitalOcean)"
    echo -e "- Your home computer with port forwarding"
    echo -e "- A local/regional VPS provider"
    exit 1
elif [ "$TESLA_CHECK" = "000" ]; then
    echo -e "${YELLOW}⚠️  Could not verify Tesla connectivity${NC}"
    echo -e "Please check your internet connection"
else
    echo -e "${GREEN}✓ Tesla connection check passed (HTTP $TESLA_CHECK)${NC}"
fi

# Clone TeslaMate setup repository
echo -e "\n${YELLOW}Downloading TeslaMate setup wizard...${NC}"
if [ ! -d "teslamate-server" ]; then
    git clone https://github.com/f/teslamate-server.git
    echo -e "${GREEN}✓ TeslaMate setup wizard downloaded${NC}"
else
    echo -e "${GREEN}✓ TeslaMate setup wizard already exists${NC}"
fi

# Final instructions
echo -e "\n${GREEN}====================================${NC}"
echo -e "${GREEN}    Installation Complete!${NC}"
echo -e "${GREEN}====================================${NC}\n"

echo -e "${YELLOW}⚠️  IMPORTANT: You need to logout and login again for Docker permissions${NC}"
echo -e "\nNext steps:"
echo -e "1. Logout: ${BLUE}exit${NC}"
echo -e "2. Login again to your server"
echo -e "3. Run the setup wizard:"
echo -e "   ${BLUE}cd teslamate-server${NC}"
echo -e "   ${BLUE}./run.sh${NC}"

echo -e "\n${YELLOW}After logging back in, you can verify Docker works with:${NC}"
echo -e "${BLUE}docker --version${NC}"

# Check if we can run docker without sudo (won't work until re-login)
if ! docker ps &> /dev/null; then
    echo -e "\n${RED}Remember: You MUST logout and login again before running the setup!${NC}"
fi 