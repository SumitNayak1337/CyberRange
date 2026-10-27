# CyberRange 2.0 // SOC Lab (Elite Edition)

```
   ______      __             ____                          ___     ____ 
  / ____/_  __/ /_  ___  ____/ __ \____ _____  ____ ____   |__ \   / __ \
 / /   / / / / __ \/ _ \/ __/ /_/ / __ `/ __ \/ __ `/ _ \  __/ /  / / / /
/ /___/ /_/ / /_/ /  __/ / / _, _/ /_/ / / / / /_/ /  __/ / __/_ / /_/ / 
\____/\__, /_.___/\___/_/ /_/ |_|\__,_/_/ /_/\__, /\___/ /____/(_)____/  
     /____/                                 /____/                       
       S E C U R I T Y   O P E R A T I O N S   C E N T E R   L A B
```

A high-performance, automated Security Operations Center (SOC) lab environment designed for cybersecurity training, attack simulation, and blue team detection engineering.

CyberRange 2.0 features **automatic boot startup (systemd)**, a unified **`cyberrange` CLI command**, a **self-healing auto-repair engine (`cyberrange fix`)**, **terminal ASCII magic MOTD**, and a **next-gen cyberpunk web dashboard**.

---

### 📥 [Click Here to Download `Cyberrange.ovf`](cyberrange%20_docs/Cyberrange.ovf)

---

## 📋 Table of Contents
- [What's New in CyberRange 2.0](#whats-new-in-cyberrange-20)
- [System Architecture](#system-architecture)
- [Quick Start & Installation](#quick-start--installation)
- [Unified CLI Commands (`cyberrange`)](#unified-cli-commands-cyberrange)
- [Automatic Boot Startup (Systemd)](#automatic-boot-startup-systemd)
- [Screenshots](#screenshots)
- [Attack Targets & Defense Tools](#attack-targets--defense-tools)
- [Troubleshooting & Auto-Fix](#troubleshooting--auto-fix)
- [Contributing](#contributing)
- [License](#license)

---

## ⚡ What's New in CyberRange 2.0

- 🚀 **Auto-Start on Boot**: No need to manually start the lab every time you power on the machine. CyberRange starts automatically in the background via `systemd` (`cyberrange.service`).
- 🛠️ **Unified `cyberrange` CLI Tool**: Manage everything with simple global commands from anywhere in your terminal (`cyberrange start`, `stop`, `status`, `fix`, `reset`).
- 🧙‍♂️ **Self-Healing Diagnostics (`cyberrange fix`)**: Automated recovery that diagnoses Docker health, auto-expands LVM partitions, truncates runaway Docker logs, resolves port conflicts, and heals permissions.
- ✨ **ASCII Magic MOTD**: Login splash screen with glowing ANSI gradients, live host IP detection, endpoint directory, and status overview right on SSH login.
- 💻 **Cyberpunk Web Dashboard 2.0**: Redesigned UI with real-time health pings, 1-click credential copying, dark theme scanline aesthetics, and quick cheatsheets.

---

## 🧩 System Architecture

```
                                  [ CyberRange Host Machine ]
                                  IP: Detected LAN IP (e.g., 10.24.175.123)
                                             │
               ┌─────────────────────────────┼─────────────────────────────┐
               │                             │                             │
        [ Port 9000 ]                 [ Port 8081 ]                 [ Port 3000 ]
     Command Deck Dashboard               DVWA                      OWASP Juice Shop
  (Aesthetic SOC Web Portal)      (Web Vulnerability Lab)       (Modern Node.js Sec Lab)
               │                             │                             │
               └─────────────────────────────┼─────────────────────────────┘
                                             │
               ┌─────────────────────────────┴─────────────────────────────┐
               │                                                           │
        [ Port 8000 / 8088 ]                                     [ Host Network ]
      Splunk Enterprise SIEM                                      Suricata NIDS
   (Log Aggregation & SOC Rules)                              (Real-time Packet Sniffer)
```

---

## 🚀 Quick Start & Installation

### Option 1: Using the Pre-Built Virtual Machine (Recommended)

1. **Download the OVF file**: [Cyberrange.ovf](cyberrange%20_docs/Cyberrange.ovf)
2. Import the OVF into VMware Workstation / VirtualBox.
3. Power on the VM.
   - **Username**: `cyberrange`
   - **Password**: `cyberrange`
4. **Auto-Start is enabled by default!** Once the VM turns on, CyberRange 2.0 boots all containers and the dashboard automatically.
5. Access your lab in your browser:
   - **Dashboard**: `http://<VM_IP>:9000`

### Option 2: Deploying CyberRange 2.0 on Existing Ubuntu / Debian Machine

```bash
# Clone the repository
git clone https://github.com/SumitNayak1337/CyberRange.git
cd CyberRange/Cyberrange_Programfiles

# Run the master installer (installs Docker, CLI, systemd autostart & MOTD)
sudo ./install.sh
```

---

## ⚡ Unified CLI Commands (`cyberrange`)

After installation, the `cyberrange` command is available anywhere in your terminal:

| Command | Action |
| :--- | :--- |
| `cyberrange start` | Launches all containers, generates dynamic dashboard, and starts web server |
| `cyberrange stop` | Gracefully stops all lab containers and web server |
| `cyberrange restart` | Performs a clean restart cycle |
| `cyberrange status` | Displays live container status, port health, RAM, and Disk metrics |
| `cyberrange fix` | **Auto-repairs** Docker, expands LVM disk, cleans bloated logs, fixes ports |
| `cyberrange banner` | Displays the ASCII Magic splash screen with live URLs and credentials |
| `cyberrange autostart enable` | Enables automated startup whenever the machine turns on |
| `cyberrange autostart disable`| Disables automated startup on machine boot |
| `cyberrange reset` | Destroys all containers, wipes logs/volumes, and restarts fresh |

> 💡 **Legacy script compatibility**: `./lab-start.sh`, `./lab_stop.sh`, `./lab_reset.sh`, and `./expand_disk.sh` continue to work and seamlessly delegate to the `cyberrange` engine.

---

## 🔄 Automatic Boot Startup (Systemd)

CyberRange 2.0 integrates natively with Linux `systemd`:

- **Service File**: `/etc/systemd/system/cyberrange.service`
- **Enable on Boot**:
  ```bash
  cyberrange autostart enable
  # Or natively:
  sudo systemctl enable cyberrange.service
  ```
- **Disable Boot Startup**:
  ```bash
  cyberrange autostart disable
  # Or natively:
  sudo systemctl disable cyberrange.service
  ```
- **Check Boot Service Status**:
  ```bash
  cyberrange autostart status
  ```

---

## 🎯 Attack Targets & Defense Tools

### 🔴 Red Team Targets (Offensive)

| Target | URL | Default Credentials | Description |
| :--- | :--- | :--- | :--- |
| **DVWA** | `http://<IP>:8081` | `admin` / `password` | PHP/MySQL app for SQLi, XSS, CSRF, and LFI/RFI |
| **OWASP Juice Shop** | `http://<IP>:3000` | *Self-Register inside app* | Modern Angular/Node app covering the OWASP Top 10 |

### 🔵 Blue Team Tools (Defensive)

| Tool | URL | Default Credentials | Description |
| :--- | :--- | :--- | :--- |
| **Splunk Enterprise** | `http://<IP>:8000` | `admin` / `CyberRange@123` | Industry-leading SIEM for log indexing & search |
| **Splunk HEC** | `http://<IP>:8088` | Token in `.env` | HTTP Event Collector for real-time log ingestion |
| **Suricata NIDS** | Host Network | Log: `/var/log/suricata/fast.log` | Deep Packet Inspection & intrusion detection engine |
| **Web Dashboard** | `http://<IP>:9000` | *No auth required* | Central command deck with access cards |

---

## 🔧 Troubleshooting & Auto-Fix

If anything stops working or you run out of disk space, run the automated self-healing command:

```bash
cyberrange fix
```

`cyberrange fix` automatically performs:
1. **Docker Engine Health Check**: Restarts Docker socket/daemon if frozen or down.
2. **Storage Auto-Expansion**: Automatically claims 100% of unallocated disk space on LVM partitions.
3. **Log & Cache De-bloat**: Truncates runaway Docker container logs and prunes dead cache.
4. **Port Clearance**: Clears orphaned Python HTTP servers and zombie processes on port 9000.
5. **Suricata Permissions**: Restores full read/write permissions to `/var/log/suricata`.
6. **Network & Endpoint Re-binding**: Detects new LAN IP leases and updates the dashboard.

---

## 🖼️ Screenshots

![Lab Dashboard](cyberrange%20_docs/Screenshot%202026-03-26%20235835.png)
*CyberRange SOC Lab Dashboard - Main interface showing all services*

![Service Cards](cyberrange%20_docs/Screenshot%202026-03-26%20235902.png)
*Service cards displaying DVWA, Juice Shop, and Splunk with credentials*

![Lab Services](cyberrange%20_docs/Screenshot%202026-03-26%20235919.png)
*Detailed view of running lab services and network configuration*

---

## 🤝 Contributing

Contributions are welcome! Please feel free to open issues or submit Pull Requests for:
- Adding new vulnerable labs (e.g., VulnHub/HackTheBox targets, Active Directory labs)
- Adding new Blue Team tools (e.g., Wazuh, Zeek, Elastic Security, MISP)
- Enhanced threat simulation scripts (e.g., Caldera, Atomic Red Team)

---

## ⚠️ Disclaimer

**CYBERRANGE · EDUCATIONAL USE ONLY · ISOLATED LAB ENVIRONMENT**

This lab contains intentionally vulnerable software. Run it exclusively in isolated networks or virtualized environments. Never expose these ports to public networks without proper authentication and firewalling.

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.