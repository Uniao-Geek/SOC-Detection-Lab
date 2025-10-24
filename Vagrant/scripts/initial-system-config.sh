#!/bin/bash
# Script para configurações iniciais do sistema
# SOC Detection Laboratory - Logger VM Initial Configuration

set -e

echo "==========================================================================="
echo " [*] SOC Detection Laboratory - Initial System Configuration"
echo "==========================================================================="

# Função de logging
log_stage() {
    echo -e "$1"
}

# 1. Configurar GRUB
log_stage "[+] Step 1: Configuring GRUB boot timeout..."
if [ -f /vagrant/scripts/configure-grub.sh ]; then
    chmod +x /vagrant/scripts/configure-grub.sh
    /vagrant/scripts/configure-grub.sh
else
    log_stage "[!] GRUB configuration script not found, configuring manually..."
    # Configuração manual do GRUB
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub
    update-grub
fi

# 2. Configurar hostname
log_stage "[+] Step 2: Setting hostname to 'logger'..."
hostnamectl set-hostname logger
echo "logger" > /etc/hostname

# 3. Configurar /etc/hosts
log_stage "[+] Step 3: Configuring /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1 localhost
127.0.1.1 logger
192.168.56.105 logger logger.windomain.local
192.168.56.102 dc.windomain.local dc
192.168.56.103 wef.windomain.local wef
192.168.56.104 win10.windomain.local win10
EOF

# 4. Configurar rede estática
log_stage "[+] Step 4: Configuring static network..."
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
    eth1:
      dhcp4: false
      addresses:
        - 192.168.56.105/24
      gateway4: 192.168.56.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4, 192.168.56.102]
EOF

# 5. Aplicar configuração de rede
log_stage "[+] Step 5: Applying network configuration..."
netplan apply

# 6. Configurar DNS
log_stage "[+] Step 6: Configuring DNS resolvers..."
systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 192.168.56.102
EOF

# Tornar resolv.conf imutável
chattr +i /etc/resolv.conf 2>/dev/null || true

# 7. Configurar timezone (opcional)
log_stage "[+] Step 7: Setting timezone to UTC..."
timedatectl set-timezone UTC

# 8. Atualizar sistema básico
log_stage "[+] Step 8: Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# 9. Instalar pacotes essenciais
log_stage "[+] Step 9: Installing essential packages..."
apt-get install -y curl wget git htop net-tools dnsutils

# 10. Verificar configurações
log_stage "[+] Step 10: Verifying configurations..."

# Verificar hostname
CURRENT_HOSTNAME=$(hostname)
if [ "$CURRENT_HOSTNAME" = "logger" ]; then
    log_stage "[+] Hostname correctly set to 'logger'"
else
    log_stage "[!] Hostname issue: Current '$CURRENT_HOSTNAME', Expected 'logger'"
fi

# Verificar IP
ETH1_IP=$(ip -4 addr show eth1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
if [ "$ETH1_IP" = "192.168.56.105" ]; then
    log_stage "[+] eth1 IP correctly set to 192.168.56.105"
else
    log_stage "[!] IP issue: Current '$ETH1_IP', Expected '192.168.56.105'"
fi

# Verificar DNS
if dig +short @8.8.8.8 github.com >/dev/null 2>&1; then
    log_stage "[+] DNS resolution working correctly"
else
    log_stage "[!] DNS resolution issues detected"
fi

# 11. Criar arquivo de status
log_stage "[+] Step 11: Creating system status file..."
cat > /var/log/soc-detection-lab-initial-config.log << EOF
SOC Detection Laboratory - Initial Configuration
===============================================
Timestamp: $(date)
Hostname: $(hostname)
IP eth1: $(ip -4 addr show eth1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
GRUB Timeout: $(grep GRUB_TIMEOUT /etc/default/grub | cut -d= -f2)
Timezone: $(timedatectl show --property=Timezone --value)
Kernel: $(uname -r)
Ubuntu Version: $(lsb_release -rs)
===============================================
EOF

echo ""
echo "==========================================================================="
echo " [*] Initial System Configuration Completed Successfully!"
echo "==========================================================================="
echo ""
echo "System Information:"
echo "  - Hostname: $(hostname)"
echo "  - IP Address: $(ip -4 addr show eth1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)"
echo "  - GRUB Timeout: 5 seconds"
echo "  - Timezone: UTC"
echo "  - Status Log: /var/log/soc-detection-lab-initial-config.log"
echo ""
echo "Next Steps:"
echo "  - Run main provisioning script"
echo "  - Install SOC tools and applications"
echo "  - Configure Splunk, Zeek, Fleet, etc."
echo ""
echo "==========================================================================="
