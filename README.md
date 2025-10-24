<<<<<<< HEAD
# SOC Detection Laboratory

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Maintenance](https://img.shields.io/badge/maintained%3F-yes-green.svg)](https://github.com/Uniao-Geek/SOC-Detection-Lab/graphs/commit-activity)
[![GitHub last commit](https://img.shields.io/github/last-commit/Uniao-Geek/SOC-Detection-Lab.svg)](https://github.com/Uniao-Geek/SOC-Detection-Lab/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/Uniao-Geek/SOC-Detection-Lab.svg)](https://github.com/Uniao-Geek/SOC-Detection-Lab/issues)

> **A modern cybersecurity detection laboratory for threat hunting, adversary simulation, and SOC training**

## 🎯 Overview

The **SOC Detection Laboratory** is a comprehensive, modern cybersecurity lab environment designed for:

- **🔍 Threat Detection** - Advanced log analysis and security event monitoring
- **🎯 Threat Hunting** - Proactive cybersecurity threat investigation
- **⚔️ Adversary Simulation** - Attack simulation for detection testing
- **🎓 SOC Training** - Security Operations Center analyst training
- **🔴 Red Team Exercises** - Red team and purple team exercises

## 🏢 Organization

**Uniao-Geek** - Cybersecurity Research & Development

### 👥 Contributors

- **mrhenrike** - Lead Developer & Security Researcher

## 🏗️ Lab Architecture

### 🖥️ Virtual Machines

| VM | Operating System | IP Address | Primary Function |
|---|---|---|---|
| **logger** | Ubuntu 22.04 LTS | 192.168.56.105 | SIEM, Centralized Logging, Analysis |
| **dc** | Windows Server 2016 | 192.168.56.102 | Domain Controller, Active Directory |
| **wef** | Windows Server 2016 | 192.168.56.103 | Windows Event Forwarder |
| **win10** | Windows 10 | 192.168.56.104 | Test Workstation |

### 🛠️ Installed Tools

#### Logger VM (Ubuntu 22.04) - Analysis Center
- **🔍 Splunk Enterprise** - Primary SIEM and log analysis
- **🌐 Zeek (Bro)** - Advanced network traffic analysis
- **🛡️ Suricata** - Intrusion detection system (IDS/IPS)
- **📊 Fleet (osquery)** - Endpoint monitoring
- **🔬 Velociraptor** - Digital forensics and incident response
- **🖥️ Apache Guacamole** - Remote desktop gateway
- **🔗 OpenVSwitch** - Advanced virtual switching

#### Windows VMs - Production Environment
- **📝 Windows Event Logging** - System and application logs
- **👁️ Sysmon** - Advanced process monitoring
- **📡 osquery** - Endpoint telemetry
- **🔬 Velociraptor Client** - Forensics client
- **⚔️ Red Team Tools** - Testing and simulation tools

## 🚀 Quick Start

### 📋 Prerequisites

- **VirtualBox 7.2.0+** (recommended) or VMware Workstation
- **Vagrant 2.3+**
- **8GB+ RAM** (16GB recommended)
- **50GB+ disk space**
- **Windows 10/11** or **Linux** as host system

### ⚡ Quick Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Uniao-Geek/SOC-Detection-Lab.git
   cd SOC-Detection-Lab/Vagrant
   ```

2. **Run the clean rebuild script:**
   ```bash
   chmod +x rebuild-logger.sh
   ./rebuild-logger.sh
   ```

3. **Wait for complete installation** (30-60 minutes)

4. **Access Splunk:**
   - **URL:** https://192.168.56.105:8000
   - **Username:** admin
   - **Password:** changeme

### ⚙️ Automatic Configurations

The system is automatically configured with:

- ✅ **GRUB timeout**: 5 seconds (fast boot)
- ✅ **Hostname**: logger
- ✅ **Static IP**: 192.168.56.105
- ✅ **DNS**: 8.8.8.8, 8.8.4.4, 192.168.56.102
- ✅ **Timezone**: UTC
- ✅ **Network**: Optimized lab configuration

## 🔧 Scripts and Tools

### 📜 Configuration Scripts

- `scripts/initial-system-config.sh` - Initial system configuration
- `scripts/configure-grub.sh` - GRUB bootloader configuration
- `rebuild-logger.sh` - Clean logger VM rebuild

### 🚀 Bootstrap Scripts

- `logger_bootstrap_enhanced.sh` - Complete logger VM installation

**Available modes:**
- `main` - Complete installation (default)
- `splunk_only` - Splunk Enterprise only
- `zeek_only` - Zeek Network Monitor only
- `suricata_only` - Suricata IDS only
- `fleet_only` - Fleet osquery only
- `guacamole_only` - Apache Guacamole only
- `velociraptor_only` - Velociraptor only
- `fix_network_only` - Network fix only

## 🌐 Access and URLs

### 🔗 Main URLs

| Service | URL | Credentials |
|---|---|---|
| **Splunk Web** | https://192.168.56.105:8000 | admin/changeme |
| **Splunk Management API** | https://192.168.56.105:8089 | admin/changeme |
| **Fleet osquery** | https://192.168.56.105:8412 | admin@detectionlab.network/Fl33tpassword! |
| **Apache Guacamole** | http://192.168.56.105:8080/guacamole | vagrant/vagrant |

### 🔌 Forwarded Ports

| Host Port | Guest Port | Service |
|---|---|---|
| 5625 | 22 | SSH Logger |
| 8000 | 8000 | Splunk Web UI |
| 8089 | 8089 | Splunk Management API |

## 📊 Monitoring and Logs

### 📝 Important Logs

- `/var/log/logger_provision_report.log` - Complete provisioning report
- `/var/log/soc-detection-lab-initial-config.log` - Initial system configuration
- `/opt/splunk/var/log/splunk/` - Splunk Enterprise logs
- `/opt/zeek/logs/` - Zeek Network Monitor logs
- `/var/log/suricata/` - Suricata IDS logs

### 💻 Useful Commands

```bash
# Status of main services
systemctl status splunkd zeek suricata fleet

# Check connectivity between VMs
ping -c 1 192.168.56.102  # DC
ping -c 1 192.168.56.103  # WEF
ping -c 1 192.168.56.104  # Win10

# Check system configurations
hostname
ip addr show eth1
grep GRUB_TIMEOUT /etc/default/grub

# Monitor logs in real-time
tail -f /var/log/logger_provision_report.log
journalctl -f
```

## 🛠️ Troubleshooting

### ❗ Common Issues

1. **VM won't start:**
   - Check if VirtualBox is working correctly
   - Run `vagrant destroy -f` and `vagrant up` again
   - Check VirtualBox logs

2. **Network issues:**
   - Verify IP 192.168.56.105 is free on the network
   - Run `./rebuild-logger.sh` for clean rebuild
   - Check firewall settings

3. **Splunk not accessible:**
   - Wait 5-10 minutes after complete boot
   - Check logs: `journalctl -u splunkd`
   - Verify service is running: `systemctl status splunkd`

4. **GRUB timeout:**
   - Run `scripts/configure-grub.sh` manually
   - Check configuration: `cat /etc/default/grub`

### 🔍 Debug Logs

```bash
# Vagrant logs in real-time
vagrant ssh logger -c "tail -f /var/log/logger_provision_report.log"

# System logs
journalctl -f

# Status of all services
systemctl list-units --failed

# Check disk space
df -h

# Check memory usage
free -h
```

## 🚀 Deployment Platforms

### Local Development
- **Vagrant** with VirtualBox/VMware
- **Quick setup** for testing and development

### Cloud Platforms
- **AWS** - Terraform deployment
- **Azure** - Terraform + Ansible
- **ESXi** - Terraform + Ansible
- **Proxmox** - Terraform + Ansible

### Enterprise
- **HyperV** - Windows Server environments
- **Custom** - Packer templates for custom builds

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. **Fork** the project
2. **Create** a feature branch (`git checkout -b feature/AmazingFeature`)
3. **Commit** your changes (`git commit -m 'Add some AmazingFeature'`)
4. **Push** to the branch (`git push origin feature/AmazingFeature`)
5. **Open** a Pull Request

### 📋 Contribution Guidelines

- Use descriptive commits
- Test your changes before submitting
- Keep documentation updated
- Follow existing code conventions

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

This project is based on the original [DetectionLab](https://github.com/clong/DetectionLab) by Chris Long, with significant improvements and modifications for modern SOC operations.

### 🏆 Special Acknowledgments

- **Chris Long** - Original DetectionLab creator
- **Palantir** - Windows Event Forwarding configurations
- **Splunk** - Enterprise SIEM platform
- **osquery** - Cross-platform endpoint visibility
- **Suricata** - Intrusion detection system
- **Zeek** - Network analysis framework
- **Velociraptor** - Digital forensics platform

## 📞 Support and Contact

For support and questions:

- **🐛 Issues**: [GitHub Issues](https://github.com/Uniao-Geek/SOC-Detection-Lab/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/Uniao-Geek/SOC-Detection-Lab/discussions)
- **📚 Wiki**: [Complete Documentation](https://github.com/Uniao-Geek/SOC-Detection-Lab/wiki)

---

**SOC Detection Laboratory** - Building the future of cybersecurity threat detection 🛡️

*Developed with ❤️ by Uniao-Geek*
=======
# SOC-Detection-Lab
A modern cybersecurity detection laboratory for threat hunting, adversary simulation, and SOC training
>>>>>>> 94da3a75c6eca092ad10da402c3addaf4d92ef85
