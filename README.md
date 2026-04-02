# CyberRange SOC Lab

A comprehensive security operations center (SOC) lab environment for cybersecurity training and practice. This lab includes vulnerable applications, SIEM tools, and automation scripts for easy deployment and management.

### 📥 [Click Here to Download `Cyberrange.ovf`](cyberrange%20_docs/Cyberrange.ovf)

## 📋 Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Screenshots](#screenshots)
- [System Components](#system-components)
- [Download & Installation](#download--installation)  
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🔍 Overview

CyberRange is a Docker-based SOC lab environment designed for hands-on cybersecurity training. It provides an isolated network where users can practice offensive and defensive security techniques using real-world tools and vulnerable applications.

## ✨ Features

- **Vulnerable Applications**: DVWA and OWASP Juice Shop for practicing web application security
- **SIEM Integration**: Splunk Enterprise for log monitoring and analysis
- **Automated Deployment**: One-click startup/shutdown scripts
- **Dynamic IP Detection**: Automatically detects and configures lab access based on your network
- **Aesthetic Dashboard**: Beautiful, informative web interface showing all available services
- **Persistent Storage**: Configurable disk expansion capabilities
- **Educational Focus**: Designed for learning and skill development in controlled environments

## 🖼️ Screenshots

Below are screenshots showcasing the CyberRange SOC Lab interface and components:

![Lab Dashboard](cyberrange%20_docs/Screenshot%202026-03-26%20235835.png)
*CyberRange SOC Lab Dashboard - Main interface showing all services*

![Service Cards](cyberrange%20_docs/Screenshot%202026-03-26%20235902.png)
*Service cards displaying DVWA, Juice Shop, and Splunk with credentials*

![Lab Services](cyberrange%20_docs/Screenshot%202026-03-26%20235919.png)
*Detailed view of running lab services and network configuration*

![Dashboard Details](cyberrange%20_docs/Screenshot%202026-03-26%20235939.png)
*Additional dashboard elements and styling*

![Mobile View](cyberrange%20_docs/Screenshot%202026-03-27%20000036.png)
*Responsive dashboard view on mobile devices*

![Service Status](cyberrange%20_docs/Screenshot%202026-03-27%20000056.png)
*Service status indicators and connection details*

## 🧩 System Components

CyberRange consists of the following key components:

### Offensive Security Targets (Red Team)
- **DVWA (Damn Vulnerable Web Application)** - PHP/MySQL web app with intentional vulnerabilities
  - URL: `http://[YOUR_IP]:8081`
  - Credentials: `admin` / `password`
  - Vulnerabilities: SQL Injection, XSS, Command Injection, File Upload, etc.

- **OWASP Juice Shop** - Modern Node.js/Angular application with diverse security challenges
  - URL: `http://[YOUR_IP]:3000`
  - Note: Registration required within the application

### Defensive Security Tools (Blue Team)
- **Splunk Enterprise** - Industry-leading SIEM for log collection, analysis, and visualization
  - URL: `http://[YOUR_IP]:8000`
  - Credentials: `admin` / `CyberRange@123`

### Infrastructure & Automation
- **Docker Compose** - Orchestrates all lab containers
- **Custom Dashboard** - Dynamic HTML interface showing service status and access links
- **Management Scripts** - Start, stop, reset, and disk expansion utilities
- **OVF Template** - Exportable virtual appliance for easy distribution

## 💾 Download & Installation  

**IMPORTANT**: The CyberRange SOC Lab is designed to be run as a pre-built virtual appliance. **Do not attempt to run it by cloning the repository alone** - you must download and use the OVF file for proper functionality.

### 📥 Primary Method: Download the OVF File (Recommended)

The easiest and most reliable way to run CyberRange is to download the pre-configured OVF (Open Virtualization Format) file:

1. **Download the OVF file**: [Cyberrange.ovf](cyberrange%20_docs/Cyberrange.ovf)
2. **Import into your virtualization software**:
   - VirtualBox: File → Import Appliance → Select the OVF file
   - VMware: File → Open → Select the OVF file
   - Hyper-V: Use the Convert-VM command or import through the UI
3. **Start the virtual machine**
4. **Access the lab environment**:
   - The virtual machine will boot up and configure its network settings
   - Once running, access the lab dashboard via your web browser at: `http://192.168.1.11:1337/Cyberrange`
   - **Note**: The IP address (192.168.1.11) may vary based on your network configuration. The lab startup script will display the correct IP when it runs.
5. **Login to the virtual machine** (if required for terminal access):
   - Username: `cyberrange`
   - Password: `cyberrange`
6. **Navigate to the lab directory** (files are located here after VM import):
   - After logging into the VM, the CyberRange files are located in the home directory or at `/home/cyberrange/192.168.1.11:1337/CyberRange`
   - Alternatively, if using Docker directly, navigate to the `Cyberrange_Programfiles` directory
7. **Launch the lab** (requires sudo):
   ```bash
   
   cd /home/cyberrange/192.168.1.11:1337/CyberRange/Cyberrange_Programfiles  # Adjust path if needed
   sudo ./lab-start.sh
   ```

### 🔧 Alternative Method: Cloning the Repository (For Developers Only)

If you wish to examine, modify, or contribute to the CyberRange codebase, you may clone the repository. **However, you will still need the OVF file or Docker environment to actually run the lab**:

```bash
git clone <repository-url>
cd CyberRange
```

> ⚠️ **Note**: Cloning only gives you the source code and scripts. To run the lab, you must either:
> 1. Use the OVF file method above (recommended for end users), OR
> 2. Install Docker and Docker Compose, then navigate to `Cyberrange_Programfiles` and run `sudo ./lab-start.sh`

### File Locations After VM Import

After importing and starting the OVF virtual machine:
- **Lab Dashboard**: Accessible at `http://[VM_IP]:1337/Cyberrange` (typically `http://192.168.1.11:1337/Cyberrange`)
- **Lab Filesystem Location**: The CyberRange application files are located within the VM at:
  - `/home/cyberrange/CyberRange/` (main directory)
  - `/home/cyberrange/CyberRange/Cyberrange_Programfiles/` (contains scripts and docker-compose)
- **Access Methods**:
  - Web Dashboard: `http://[VM_IP]:1337/Cyberrange` (shows service status and links)
  - Terminal/SSH: Login as `cyberrange`/`cyberrange` then navigate to the directories above
  - Services: Access individual tools via the dashboard links or directly at their ports

### Default Credentials (for lab access where applicable)
- **VM Login**: 
  - Username: `cyberrange`
  - Password: `cyberrange`
- **Note**: Individual services have their own credentials (see System Components section)
- **Always run lab commands with `sudo`** inside the virtual machine

## 🚀 Usage

### Starting the Lab (from within the virtual machine)
```bash
# After logging into the VM as cyberrange:cyberrange
cd /home/cyberrange/CyberRange/Cyberrange_Programfiles  # Path may vary
sudo ./lab-start.sh
```

### Stopping the Lab
```bash
cd /home/cyberrange/CyberRange/Cyberrange_Programfiles
sudo ./lab-stop.sh
```

### Resetting the Lab (WARNING: Destroys all data)
```bash
cd /home/cyberrange/CyberRange/Cyberrange_Programfiles
sudo ./lab-reset.sh
```
> ⚠️ This will destroy all containers, wipe logs/data, and perform a fresh start. Confirmation is required.

### Expanding Disk Space
```bash
cd /home/cyberrange/CyberRange/Cyberrange_Programfiles
sudo ./expand_disk.sh
```
Use this if you need more storage for logs, databases, or additional tools.

## 🔧 Troubleshooting

If you encounter issues, please refer to the following troubleshooting steps:

### Common Issues & Solutions

1. **OVF Import Problems**
   - Ensure your virtualization software is up to date
   - Try importing the OVA version if available (some platforms prefer OVA)
   - Check that virtualization is enabled in your BIOS/UEFI settings

2. **VM Not Getting IP Address**
   - Ensure the VM has network adapter configured (NAT or Bridged mode)
   - Check virtual network settings in your virtualization software
   - The lab-start.sh script includes multiple IP detection methods

3. **Docker not found or permission denied** (if using Docker method)
   - Ensure Docker is installed and running
   - Add your user to the docker group: `sudo usermod -aG docker $USER`
   - Log out and back in, or use `sudo` with the scripts

4. **Port conflicts (services not starting)**
   - Check if ports 8081, 3000, 8000, or 9000 are already in use
   - Stop conflicting services or modify the docker-compose.yml file
   - Use `sudo netstat -tulpn` to check port usage

5. **Dashboard not accessible at http://192.168.1.11:1337/Cyberrange**
   - Verify the lab-start.sh script completed successfully inside the VM
   - Check if the Python HTTP server is running on port 1337 (for dashboard) and 9000 (for internal dashboard)
   - Ensure your firewall allows traffic on the required ports
   - The actual IP may differ - check the VM's network settings or look for IP display in lab startup output

6. **IP detection issues**
   - The lab-start.sh script includes multiple IP detection methods
   - If automatic detection fails, you can manually set the LAN_IP variable in lab-start.sh
   - Alternatively, access services directly using known ports (e.g., `http://localhost:8081` for DVWA from within the VM)

7. **Container startup failures**
   - Check Docker logs: `docker compose logs`
   - Ensure sufficient system resources (RAM, CPU, disk space) allocated to the VM
   - Try resetting Docker daemon: `sudo systemctl restart docker`

### Advanced Troubleshooting
For persistent issues, examine the following files in the `Cyberrange_Programfiles` directory inside the VM:
- `lab-start.sh` - Main startup script with detailed logging
- `docker-compose.yml` - Container configuration
- Individual service logs (accessible via `docker compose logs [service-name]`)
- The `.claude` directory may contain additional configuration insights

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request to:
- Fix bugs
- Add new vulnerable applications or security tools
- Improve the dashboard or documentation
- Enhance the automation scripts
- Add troubleshooting guides

Please ensure your contributions align with the educational purpose of this lab.

## ⚠️ Disclaimer

**CYBER RANGE &nbsp;Â·&nbsp; EDUCATIONAL USE ONLY &nbsp;Â·&nbsp; ISOLATED LAB ENVIRONMENT**

This lab is intended for educational and training purposes only. All vulnerable applications should be run in isolated environments. The creators are not responsible for any misuse of this software.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*Last updated: April 2, 2026*