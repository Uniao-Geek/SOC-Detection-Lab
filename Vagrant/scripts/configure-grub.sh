#!/bin/bash
# Script para configurar GRUB com timeout reduzido
# SOC Detection Laboratory - Logger VM Configuration

set -e

echo "==========================================================================="
echo " [*] Configuring GRUB boot timeout..."
echo "==========================================================================="

# Backup do arquivo GRUB original
if [ ! -f /etc/default/grub.backup ]; then
    cp /etc/default/grub /etc/default/grub.backup
    echo "[+] GRUB configuration backed up to /etc/default/grub.backup"
fi

# Configurar timeout do GRUB para 5 segundos
echo "[+] Setting GRUB timeout to 5 seconds..."
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub

# Configurar timeout do GRUB_STYLE para 5 segundos (se existir)
if grep -q "GRUB_TIMEOUT_STYLE" /etc/default/grub; then
    sed -i 's/GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
else
    echo "GRUB_TIMEOUT_STYLE=menu" >> /etc/default/grub
fi

# Configurar para não mostrar splash screen (opcional)
if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
    # Remove "quiet splash" se existir
    sed -i 's/quiet splash//g' /etc/default/grub
    # Adiciona "quiet" apenas se não existir
    if ! grep -q "quiet" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 quiet"/' /etc/default/grub
    fi
fi

# Aplicar configurações do GRUB
echo "[+] Updating GRUB configuration..."
update-grub

echo "[+] GRUB configuration completed successfully!"
echo "    - Boot timeout: 5 seconds"
echo "    - Configuration backed up to /etc/default/grub.backup"

# Verificar se a configuração foi aplicada
if grep -q "GRUB_TIMEOUT=5" /etc/default/grub; then
    echo "[+] GRUB timeout successfully set to 5 seconds"
else
    echo "[!] Warning: GRUB timeout may not have been set correctly"
fi

echo "==========================================================================="
