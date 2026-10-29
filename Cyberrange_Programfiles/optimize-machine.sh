#!/usr/bin/env bash
# ==============================================================================
#   CYBERRANGE 2.0 // MACHINE OPTIMIZER & CLEANUP
#   Removes unnecessary packages, GUI, bloat, and optimizes for SSH-only usage
#   Run: sudo ./optimize-machine.sh
# ==============================================================================

set -eo pipefail

NC='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NEON_GREEN='\033[38;5;48m'
NEON_CYAN='\033[38;5;51m'
WHITE='\033[1;37m'
BOLD='\033[1m'

# Root check
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Run as root: sudo ./optimize-machine.sh${NC}"
    exit 1
fi

echo ""
echo -e "${NEON_CYAN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}${BOLD}  CYBERRANGE 2.0 // MACHINE OPTIMIZER (SSH-Only Mode)${NC}"
echo -e "${NEON_CYAN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo ""

# ─── 1. SETUP SWAP (if not present) ──────────────────────────────
echo -e "${CYAN}[1/8] Setting Up Swap Space...${NC}"
if swapon --show | grep -q '/swapfile'; then
    echo -e "  ${GREEN}[✓] Swap file already exists.${NC}"
else
    SWAP_SIZE="4G"
    echo -e "  ${YELLOW}[*] Creating ${SWAP_SIZE} swap file...${NC}"
    fallocate -l $SWAP_SIZE /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=4096
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    # Add to fstab if not already present
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    echo -e "  ${GREEN}[✓] ${SWAP_SIZE} swap created and activated.${NC}"
fi
# Optimize swappiness for server workload
sysctl vm.swappiness=10 2>/dev/null || true
if ! grep -q 'vm.swappiness' /etc/sysctl.conf; then
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi

# ─── 2. REMOVE GUI / DESKTOP (SSH-only mode) ─────────────────────
echo -e "${CYAN}[2/8] Removing GUI / Desktop Environment (SSH-only mode)...${NC}"
# Stop display manager
systemctl stop gdm3 2>/dev/null || systemctl stop lightdm 2>/dev/null || systemctl stop sddm 2>/dev/null || true
systemctl disable gdm3 2>/dev/null || systemctl disable lightdm 2>/dev/null || systemctl disable sddm 2>/dev/null || true

# Remove desktop packages (non-interactive)
export DEBIAN_FRONTEND=noninteractive
apt-get remove -y --purge \
    ubuntu-desktop ubuntu-desktop-minimal \
    gdm3 lightdm sddm \
    gnome-shell gnome-session gnome-terminal gnome-control-center \
    nautilus gedit totem eog evince \
    firefox firefox-esr snap snapd \
    libreoffice* thunderbird* \
    gnome-calculator gnome-characters gnome-clocks gnome-contacts \
    gnome-font-viewer gnome-logs gnome-maps gnome-music gnome-photos \
    gnome-screenshot gnome-system-monitor gnome-weather \
    cheese shotwell rhythmbox yelp \
    xserver-xorg xorg x11-common x11-utils \
    pulseaudio pipewire \
    2>/dev/null || true

echo -e "  ${GREEN}[✓] Desktop environment removed.${NC}"

# ─── 3. REMOVE SNAP & FLATPAK ────────────────────────────────────
echo -e "${CYAN}[3/8] Removing Snap & Flatpak (saves disk & RAM)...${NC}"
snap list 2>/dev/null | awk 'NR>1 {print $1}' | while read -r pkg; do
    snap remove --purge "$pkg" 2>/dev/null || true
done
apt-get remove -y --purge snapd flatpak 2>/dev/null || true
rm -rf /snap /var/snap /var/lib/snapd ~/snap 2>/dev/null || true
echo -e "  ${GREEN}[✓] Snap & Flatpak removed.${NC}"

# ─── 4. CLEAN UNNECESSARY SYSTEM DATA ────────────────────────────
echo -e "${CYAN}[4/8] Cleaning Unnecessary System Data...${NC}"

# Clean apt cache
apt-get autoremove -y --purge 2>/dev/null || true
apt-get autoclean -y 2>/dev/null || true
apt-get clean 2>/dev/null || true

# Clear old journal logs (keep only last 2 days)
journalctl --vacuum-time=2d 2>/dev/null || true

# Clear thumbnail cache
rm -rf /home/*/.cache/thumbnails/* 2>/dev/null || true
rm -rf /root/.cache/thumbnails/* 2>/dev/null || true

# Clear old temp files
rm -rf /tmp/* 2>/dev/null || true
rm -rf /var/tmp/* 2>/dev/null || true

# Clear old crash reports
rm -rf /var/crash/* 2>/dev/null || true

# Clear old package lists
rm -rf /var/lib/apt/lists/* 2>/dev/null || true

echo -e "  ${GREEN}[✓] System data cleaned.${NC}"

# ─── 5. OPTIMIZE DOCKER ──────────────────────────────────────────
echo -e "${CYAN}[5/8] Optimizing Docker Storage...${NC}"

# Truncate all Docker container logs
sh -c 'truncate -s 0 /var/lib/docker/containers/*/*-json.log 2>/dev/null' || true

# Configure Docker log rotation
mkdir -p /etc/docker
if [[ ! -f /etc/docker/daemon.json ]] || ! grep -q 'log-opts' /etc/docker/daemon.json 2>/dev/null; then
    cat > /etc/docker/daemon.json << 'DOCKEREOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
DOCKEREOF
    echo -e "  ${GREEN}[✓] Docker log rotation configured (max 10MB × 3 files per container).${NC}"
fi

# Prune unused Docker resources
docker system prune -af --volumes 2>/dev/null || true
echo -e "  ${GREEN}[✓] Docker storage optimized.${NC}"

# ─── 6. DISABLE UNNECESSARY SERVICES ─────────────────────────────
echo -e "${CYAN}[6/8] Disabling Unnecessary Services...${NC}"
SERVICES_TO_DISABLE=(
    "cups" "cups-browsed"           # Printing
    "avahi-daemon"                   # mDNS (not needed for lab)
    "bluetooth"                      # Bluetooth
    "ModemManager"                   # Modem
    "networkd-dispatcher"            # Desktop networking
    "whoopsie"                       # Error reporting
    "apport"                         # Crash reporting
    "unattended-upgrades"            # Auto updates (can interrupt lab)
    "motd-news"                      # Online MOTD news
    "fwupd"                          # Firmware updates
)
for svc in "${SERVICES_TO_DISABLE[@]}"; do
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    systemctl mask "$svc" 2>/dev/null || true
done
echo -e "  ${GREEN}[✓] Unnecessary services disabled.${NC}"

# ─── 7. OPTIMIZE KERNEL FOR LOW-RAM SERVER ────────────────────────
echo -e "${CYAN}[7/8] Tuning Kernel for Lab Server...${NC}"
cat >> /etc/sysctl.conf << 'SYSCTL_EOF'

# CyberRange Optimizations
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
net.core.somaxconn = 1024
net.ipv4.tcp_tw_reuse = 1
SYSCTL_EOF
sysctl -p 2>/dev/null || true
echo -e "  ${GREEN}[✓] Kernel tuning applied.${NC}"

# ─── 8. EXPAND DISK (LVM if available) ───────────────────────────
echo -e "${CYAN}[8/8] Checking Disk Space & LVM Expansion...${NC}"
ROOT_LV=$(df / | tail -1 | awk '{print $1}')
if [[ "$ROOT_LV" == *"/dev/mapper/"* ]]; then
    echo -e "  ${YELLOW}[*] LVM detected ($ROOT_LV). Expanding to use all free space...${NC}"
    lvextend -l +100%FREE "$ROOT_LV" 2>/dev/null || true
    resize2fs "$ROOT_LV" 2>/dev/null || true
    echo -e "  ${GREEN}[✓] LVM expanded.${NC}"
else
    echo -e "  ${YELLOW}[•] Non-LVM partition. Skipping auto-expand.${NC}"
fi

# ─── FINAL REPORT ─────────────────────────────────────────────────
echo ""
echo -e "${NEON_GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}[✓] OPTIMIZATION COMPLETE!${NC}"
echo -e "${NEON_GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${WHITE}Memory:${NC}"
free -h | head -3 | sed 's/^/    /'
echo ""
echo -e "  ${WHITE}Disk:${NC}"
df -h / | sed 's/^/    /'
echo ""
echo -e "  ${WHITE}Swap:${NC}"
swapon --show | sed 's/^/    /'
echo ""
echo -e "${YELLOW}[!] RECOMMENDED: Reboot to fully apply changes:${NC}"
echo -e "    ${WHITE}sudo reboot${NC}"
echo ""
