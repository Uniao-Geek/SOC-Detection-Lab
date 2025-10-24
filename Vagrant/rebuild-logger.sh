#!/bin/bash
# Script para destruir e reconstruir a VM logger do zero
# SOC Detection Laboratory - Clean Rebuild

set -e

echo "==========================================================================="
echo " [*] SOC Detection Laboratory - Clean VM Rebuild"
echo "==========================================================================="

# Função de logging
log_stage() {
    echo -e "$1"
}

# Verificar se estamos no diretório correto
if [ ! -f "Vagrantfile" ]; then
    log_stage "[X] Error: Vagrantfile not found. Please run this script from the Vagrant directory."
    exit 1
fi

log_stage "[+] Starting clean rebuild process..."

# 1. Parar todas as VMs
log_stage "[+] Step 1: Stopping all VMs..."
vagrant halt 2>/dev/null || true

# 2. Destruir VM logger especificamente
log_stage "[+] Step 2: Destroying logger VM..."
vagrant destroy logger -f 2>/dev/null || true

# 3. Limpar cache do Vagrant
log_stage "[+] Step 3: Cleaning Vagrant cache..."
vagrant global-status --prune 2>/dev/null || true

# 4. Limpar cache do VirtualBox (se aplicável)
log_stage "[+] Step 4: Cleaning VirtualBox cache..."
if command -v VBoxManage >/dev/null 2>&1; then
    # Listar VMs órfãs e removê-las
    VBoxManage list vms | grep -E "(logger|detectionlab)" | while read -r line; do
        vm_name=$(echo "$line" | cut -d'"' -f2)
        log_stage "[+] Removing orphaned VM: $vm_name"
        VBoxManage unregistervm "$vm_name" --delete 2>/dev/null || true
    done
fi

# 5. Verificar espaço em disco
log_stage "[+] Step 5: Checking disk space..."
df -h . | head -2

# 6. Limpar arquivos temporários locais
log_stage "[+] Step 6: Cleaning local temporary files..."
rm -rf .vagrant/machines/logger/ 2>/dev/null || true
rm -rf .vagrant/tmp/ 2>/dev/null || true

# 7. Verificar conectividade de rede
log_stage "[+] Step 7: Checking network connectivity..."
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    log_stage "[+] Network connectivity confirmed"
else
    log_stage "[!] Warning: Network connectivity issues detected"
fi

# 8. Verificar se os scripts necessários existem
log_stage "[+] Step 8: Verifying required scripts..."
REQUIRED_SCRIPTS=(
    "scripts/initial-system-config.sh"
    "scripts/configure-grub.sh"
    "logger_bootstrap_enhanced.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        log_stage "[+] Found: $script"
        chmod +x "$script"
    else
        log_stage "[X] Missing: $script"
        exit 1
    fi
done

# 9. Verificar Vagrantfile
log_stage "[+] Step 9: Verifying Vagrantfile configuration..."
if grep -q "initial-system-config.sh" Vagrantfile; then
    log_stage "[+] Vagrantfile configured for initial system config"
else
    log_stage "[!] Warning: Vagrantfile may not be properly configured"
fi

# 10. Iniciar rebuild
log_stage "[+] Step 10: Starting VM rebuild..."
log_stage "[!] This will take several minutes. Please be patient..."

# Mostrar informações do sistema antes de começar
echo ""
echo "System Information:"
echo "  - Host OS: $(uname -s)"
echo "  - Available Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  - Available Disk Space: $(df -h . | tail -1 | awk '{print $4}')"
echo "  - VirtualBox Version: $(VBoxManage --version 2>/dev/null || echo 'Not available')"
echo ""

# Confirmar antes de prosseguir
read -p "Do you want to proceed with the rebuild? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_stage "[*] Rebuild cancelled by user"
    exit 0
fi

# Executar vagrant up
log_stage "[+] Executing: vagrant up logger"
vagrant up logger

# Verificar status final
log_stage "[+] Step 11: Verifying final status..."
vagrant status logger

echo ""
echo "==========================================================================="
echo " [*] Clean Rebuild Process Completed!"
echo "==========================================================================="
echo ""
echo "Next Steps:"
echo "  1. Check VM status: vagrant status"
echo "  2. Connect to VM: vagrant ssh logger"
echo "  3. Verify configurations:"
echo "     - Hostname: hostname"
echo "     - IP Address: ip addr show eth1"
echo "     - GRUB Timeout: grep GRUB_TIMEOUT /etc/default/grub"
echo "     - DNS: dig @8.8.8.8 github.com"
echo ""
echo "Access URLs:"
echo "  - Splunk Web UI: https://192.168.56.105:8000"
echo "  - Splunk Management API: https://192.168.56.105:8089"
echo ""
echo "==========================================================================="
