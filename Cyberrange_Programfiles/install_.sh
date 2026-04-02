#!/bin/bash
set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_banner() {
    local step=$1
    local msg=$2
    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
    echo -e "${CYAN}  [$step] $msg${NC}"
    echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
}

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}âŒ This script must be run as root (use sudo ./install.sh)${NC}" 
   exit 1
fi

print_banner "1/7" "Updating System & Installing Dependencies"
apt-get update -y
apt-get install -y curl wget git net-tools ufw python3 python3-pip apt-transport-https ca-certificates software-properties-common

print_banner "2/7" "Installing Docker & Docker Compose"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}âš ï¸ Docker not found. Installing via official script...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
else
    echo -e "${GREEN}âœ… Docker is already installed.${NC}"
fi

# Add current SUDO_USER to docker group
if [ -n "${SUDO_USER:-}" ]; then
    usermod -aG docker "$SUDO_USER"
    echo -e "${GREEN}âœ… Added $SUDO_USER to docker group.${NC}"
fi
systemctl enable --now docker

print_banner "3/7" "Configuring UFW Firewall"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
# Allow required ports
for port in 22 80 3000 8000 5601 8088 9000; do
    ufw allow "$port"/tcp
done
ufw --force enable
echo -e "${GREEN}âœ… UFW configured and enabled.${NC}"

print_banner "4/7" "Generating .env Configuration"
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ ! -f .env ]; then
    cp .env.example .env
    sed -i "s/SERVER_IP=.*/SERVER_IP=$SERVER_IP/" .env
    # Generate random UUID for Splunk HEC
    HEC_TOKEN=$(cat /proc/sys/kernel/random/uuid)
    sed -i "s/SPLUNK_HEC_TOKEN=.*/SPLUNK_HEC_TOKEN=$HEC_TOKEN/" .env
    echo -e "${GREEN}âœ… Generated .env file with SERVER_IP=$SERVER_IP${NC}"
else
    echo -e "${YELLOW}âš ï¸ .env file already exists, skipping generation.${NC}"
fi

print_banner "5/7" "Setting Up Fail2ban"
apt-get install -y fail2ban
# Create a custom jail for Suricata fast.log
cat << 'EOF' > /etc/fail2ban/jail.d/suricata.local
[suricata]
enabled = true
port = all
filter = suricata
logpath = /var/log/suricata/fast.log
maxretry = 3
bantime = 3600
EOF

# Create basic filter (matches standard Suricata fast.log IP format)
cat << 'EOF' > /etc/fail2ban/filter.d/suricata.conf
[Definition]
failregex = ^.*\[\*\*\] \[\d+:\d+:\d+\] .* \[\*\*\] \[Classification: .*\] \[Priority: \d+\] \{.*\} <HOST>:\d+ -> .*:.*$
ignoreregex =
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban
echo -e "${GREEN}âœ… Fail2ban configured to monitor Suricata.${NC}"

print_banner "6/7" "Setting up Script Permissions"
chmod +x lab-start.sh lab-stop.sh lab-reset.sh
# Fix log directory permissions for Suricata
mkdir -p /var/log/suricata
chmod 777 /var/log/suricata

print_banner "7/7" "Installation Complete!"
echo -e "${GREEN}âœ… All dependencies installed and configured.${NC}"
echo -e "${CYAN}ðŸ“ Info page: http://$SERVER_IP:9000/cyberrange-info.html${NC}"
echo -e "${CYAN}ðŸš€ Start lab: ./lab-start.sh${NC}"
echo -e "${CYAN}ðŸ›‘ Stop lab:  ./lab-stop.sh${NC}"
echo -e "${CYAN}â™»ï¸  Reset lab: ./lab-reset.sh${NC}"
echo -e "${YELLOW}âš ï¸  Note: Please log out and log back in to apply Docker group permissions.${NC}"