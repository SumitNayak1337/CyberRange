#!/usr/bin/env bash
# ==============================================================================
#   CYBERRANGE 2.0 // MASTER INSTALLATION & ENVIRONMENT PROVISIONER
#   Author: CyberRange Team
# ==============================================================================

set -euo pipefail

# Color Codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NEON_CYAN='\033[38;5;51m'
NEON_GREEN='\033[38;5;48m'
NC='\033[0m'

print_step() {
    local step=$1
    local title=$2
    echo -e "\n${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${NEON_CYAN}  [$step] ${title}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
}

# 1. Root Check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This installation script must be run as root (use: sudo ./install.sh)${NC}" 
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_step "1/8" "Updating System Packages & Essential Tooling"
apt-get update -y
apt-get install -y curl wget git net-tools ufw python3 python3-pip apt-transport-https ca-certificates software-properties-common jq bc psmisc

print_step "2/8" "Installing Docker Engine & Compose Plugin"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}[*] Docker not detected. Installing via official Docker installation script...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh
else
    echo -e "${GREEN}[✓] Docker is already installed.${NC}"
fi

# Ensure docker compose plugin
if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}[*] Installing docker-compose-plugin...${NC}"
    apt-get install -y docker-compose-plugin || true
fi

# Add invoking user to docker group
if [ -n "${SUDO_USER:-}" ]; then
    usermod -aG docker "$SUDO_USER"
    echo -e "${GREEN}[✓] Added user '$SUDO_USER' to docker group.${NC}"
fi
systemctl enable --now docker

print_step "3/8" "Configuring UFW Firewall Protection"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Lab service ports:
# 22 (SSH), 80 (HTTP), 8000 (Splunk Web), 8081 (DVWA),
# 8088 (Splunk HEC), 9000 (Dashboard), 3443/3444 (Shuffle UI), 5001 (Shuffle API)
for port in 22 80 3443 3444 5001 8000 8081 8088 9000; do
    ufw allow "$port"/tcp
done
ufw --force enable
echo -e "${GREEN}[✓] UFW firewall configured and activated for all lab ports.${NC}"

print_step "4/8" "Configuring Fail2ban & Suricata NIDS Integration"
apt-get install -y fail2ban
mkdir -p /var/log/suricata
chmod -R 777 /var/log/suricata

cat << 'EOF' > /etc/fail2ban/jail.d/suricata.local
[suricata]
enabled = true
port = all
filter = suricata
logpath = /var/log/suricata/fast.log
maxretry = 3
bantime = 3600
EOF

cat << 'EOF' > /etc/fail2ban/filter.d/suricata.conf
[Definition]
failregex = ^.*\[\*\*\] \[\d+:\d+:\d+\] .* \[\*\*\] \[Classification: .*\] \[Priority: \d+\] \{.*\} <HOST>:\d+ -> .*:.*$
ignoreregex =
EOF

systemctl enable --now fail2ban
systemctl restart fail2ban
echo -e "${GREEN}[✓] Fail2ban configured to monitor Suricata fast.log alerts.${NC}"

print_step "5/8" "Installing 'cyberrange' Master CLI Command"
mkdir -p /etc/cyberrange
echo "$SCRIPT_DIR" > /etc/cyberrange/lab_path

chmod +x "$SCRIPT_DIR/cyberrange"
chmod +x "$SCRIPT_DIR/banner.sh"
chmod +x "$SCRIPT_DIR/cyberrange-lab.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/optimize-machine.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# Symlink to /usr/local/bin/cyberrange
ln -sf "$SCRIPT_DIR/cyberrange" /usr/local/bin/cyberrange
chmod +x /usr/local/bin/cyberrange
echo -e "${GREEN}[✓] 'cyberrange' CLI command installed into /usr/local/bin/cyberrange${NC}"

print_step "6/8" "Installing Systemd Service (Manual Start Only)"
cp "$SCRIPT_DIR/cyberrange.service" /etc/systemd/system/cyberrange.service
systemctl daemon-reload
# NOTE: Service is installed but NOT enabled by default.
# Lab starts ONLY when user runs: cyberrange start
# To enable auto-start on boot: cyberrange autostart enable
echo -e "${GREEN}[✓] CyberRange 2.0 systemd service installed (disabled by default).${NC}"
echo -e "${YELLOW}    Lab will NOT auto-start on login/boot. Use 'cyberrange start' to launch.${NC}"
echo -e "${YELLOW}    To enable boot auto-start: cyberrange autostart enable${NC}"

print_step "7/8" "Installing CyberRange 2.0 ASCII Magic MOTD Login Screen"
# Install into profile.d so any SSH or tty login gets greeted with the banner
cat << 'EOF' > /etc/profile.d/cyberrange-banner.sh
# CyberRange 2.0 Interactive MOTD
if [ -n "$PS1" ] && [ -x /usr/local/bin/cyberrange ]; then
    /usr/local/bin/cyberrange banner
fi
EOF
chmod +x /etc/profile.d/cyberrange-banner.sh

# Also hook into update-motd.d if directory exists
if [ -d /etc/update-motd.d ]; then
    cp "$SCRIPT_DIR/banner.sh" /etc/update-motd.d/99-cyberrange 2>/dev/null || true
    chmod +x /etc/update-motd.d/99-cyberrange 2>/dev/null || true
fi
echo -e "${GREEN}[✓] ASCII Magic Banner installed for SSH and console login.${NC}"

print_step "8/8" "Initializing CyberRange 2.0 Environment"
echo -e "${YELLOW}[*] Launching CyberRange services for the first time...${NC}"
/usr/local/bin/cyberrange start

echo -e "\n${NEON_GREEN}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}[✓] CYBERRANGE 2.0 INSTALLATION COMPLETE!${NC}"
echo -e "${NEON_CYAN}You can now manage your lab from anywhere using:${NC}"
echo -e "  • ${YELLOW}cyberrange start${NC}    - Start all services"
echo -e "  • ${YELLOW}cyberrange stop${NC}     - Stop all services"
echo -e "  • ${YELLOW}cyberrange status${NC}   - Check container health & system resources"
echo -e "  • ${YELLOW}cyberrange fix${NC}      - Self-healing repair & auto-disk expander"
echo -e "  • ${YELLOW}cyberrange restart${NC}  - Quick restart"
echo -e "  • ${YELLOW}cyberrange reset${NC}    - Wipe and restart fresh"
echo -e "${NEON_GREEN}══════════════════════════════════════════════════════════════════════${NC}\n"
