# SOC Detection Laboratory

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Maintenance](https://img.shields.io/badge/maintained%3F-yes-green.svg)](https://github.com/Uniao-Geek/SOC-Detection-Lab/graphs/commit-activity)
[![GitHub last commit](https://img.shields.io/github/last-commit/Uniao-Geek/SOC-Detection-Lab.svg)](https://github.com/Uniao-Geek/SOC-Detection-Lab/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/Uniao-Geek/SOC-Detection-Lab.svg)](https://github.com/Uniao-Geek/SOC-Detection-Lab/issues)

> **Um laboratório moderno de detecção de segurança cibernética para caça a ameaças, simulação de adversários e treinamento SOC**

## 🎯 Visão Geral

O **SOC Detection Laboratory** é um ambiente completo e moderno de laboratório de segurança cibernética projetado para:

- **🔍 Detecção de Ameaças** - Análise avançada de logs e monitoramento de eventos de segurança
- **🎯 Threat Hunting** - Investigação proativa de ameaças cibernéticas
- **⚔️ Simulação de Adversários** - Simulação de ataques para teste de detecção
- **🎓 Treinamento SOC** - Treinamento de analistas de Security Operations Center
- **🔴 Exercícios Red Team** - Exercícios de equipe vermelha e purple team

## 🏢 Organização

**Uniao-Geek** - Pesquisa e Desenvolvimento em Segurança Cibernética

### 👥 Contribuidores

- **mrhenrike** - Desenvolvedor Líder e Pesquisador de Segurança

## 🏗️ Arquitetura do Laboratório

### 🖥️ Máquinas Virtuais

| VM | Sistema Operacional | Endereço IP | Função Principal |
|---|---|---|---|
| **logger** | Ubuntu 22.04 LTS | 192.168.56.105 | SIEM, Logging Centralizado, Análise |
| **dc** | Windows Server 2016 | 192.168.56.102 | Domain Controller, Active Directory |
| **wef** | Windows Server 2016 | 192.168.56.103 | Windows Event Forwarder |
| **win10** | Windows 10 | 192.168.56.104 | Workstation de Teste |

### 🛠️ Ferramentas Instaladas

#### Logger VM (Ubuntu 22.04) - Centro de Análise
- **🔍 Splunk Enterprise** - SIEM principal e análise de logs
- **🌐 Zeek (Bro)** - Análise avançada de tráfego de rede
- **🛡️ Suricata** - Sistema de detecção de intrusão (IDS/IPS)
- **📊 Fleet (osquery)** - Monitoramento de endpoints
- **🔬 Velociraptor** - Forensics digitais e resposta a incidentes
- **🖥️ Apache Guacamole** - Gateway de desktop remoto
- **🔗 OpenVSwitch** - Virtual switching avançado

#### Windows VMs - Ambiente de Produção
- **📝 Windows Event Logging** - Logs de sistema e aplicações
- **👁️ Sysmon** - Monitoramento avançado de processos
- **📡 osquery** - Telemetria de endpoints
- **🔬 Velociraptor Client** - Cliente de forensics
- **⚔️ Red Team Tools** - Ferramentas de teste e simulação

## 🚀 Início Rápido

### 📋 Pré-requisitos

- **VirtualBox 7.2.0+** (recomendado) ou VMware Workstation
- **Vagrant 2.3+**
- **8GB+ RAM** (16GB recomendado)
- **50GB+ espaço em disco**
- **Windows 10/11** ou **Linux** como sistema host

### ⚡ Instalação Rápida

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/Uniao-Geek/SOC-Detection-Lab.git
   cd SOC-Detection-Lab/Vagrant
   ```

2. **Execute o script de rebuild limpo:**
   ```bash
   chmod +x rebuild-logger.sh
   ./rebuild-logger.sh
   ```

3. **Aguarde a instalação completa** (30-60 minutos)

4. **Acesse o Splunk:**
   - **URL:** https://192.168.56.105:8000
   - **Usuário:** admin
   - **Senha:** changeme

### ⚙️ Configurações Automáticas

O sistema é configurado automaticamente com:

- ✅ **GRUB timeout**: 5 segundos (boot rápido)
- ✅ **Hostname**: logger
- ✅ **IP estático**: 192.168.56.105
- ✅ **DNS**: 8.8.8.8, 8.8.4.4, 192.168.56.102
- ✅ **Timezone**: UTC
- ✅ **Network**: Configuração otimizada para lab

## 🔧 Scripts e Ferramentas

### 📜 Scripts de Configuração

- `scripts/initial-system-config.sh` - Configuração inicial do sistema
- `scripts/configure-grub.sh` - Configuração do GRUB bootloader
- `rebuild-logger.sh` - Rebuild limpo da VM logger

### 🚀 Scripts de Bootstrap

- `logger_bootstrap_enhanced.sh` - Instalação completa da VM logger

**Modos disponíveis:**
- `main` - Instalação completa (padrão)
- `splunk_only` - Apenas Splunk Enterprise
- `zeek_only` - Apenas Zeek Network Monitor
- `suricata_only` - Apenas Suricata IDS
- `fleet_only` - Apenas Fleet osquery
- `guacamole_only` - Apenas Apache Guacamole
- `velociraptor_only` - Apenas Velociraptor
- `fix_network_only` - Apenas correção de rede

## 🌐 Acessos e URLs

### 🔗 URLs Principais

| Serviço | URL | Credenciais |
|---|---|---|
| **Splunk Web** | https://192.168.56.105:8000 | admin/changeme |
| **Splunk Management API** | https://192.168.56.105:8089 | admin/changeme |
| **Fleet osquery** | https://192.168.56.105:8412 | admin@detectionlab.network/Fl33tpassword! |
| **Apache Guacamole** | http://192.168.56.105:8080/guacamole | vagrant/vagrant |

### 🔌 Portas Forwarded

| Porta Host | Porta Guest | Serviço |
|---|---|---|
| 5625 | 22 | SSH Logger |
| 8000 | 8000 | Splunk Web UI |
| 8089 | 8089 | Splunk Management API |

## 📊 Monitoramento e Logs

### 📝 Logs Importantes

- `/var/log/logger_provision_report.log` - Relatório completo de provisionamento
- `/var/log/soc-detection-lab-initial-config.log` - Configuração inicial do sistema
- `/opt/splunk/var/log/splunk/` - Logs do Splunk Enterprise
- `/opt/zeek/logs/` - Logs do Zeek Network Monitor
- `/var/log/suricata/` - Logs do Suricata IDS

### 💻 Comandos Úteis

```bash
# Status dos serviços principais
systemctl status splunkd zeek suricata fleet

# Verificar conectividade entre VMs
ping -c 1 192.168.56.102  # DC
ping -c 1 192.168.56.103  # WEF
ping -c 1 192.168.56.104  # Win10

# Verificar configurações do sistema
hostname
ip addr show eth1
grep GRUB_TIMEOUT /etc/default/grub

# Monitorar logs em tempo real
tail -f /var/log/logger_provision_report.log
journalctl -f
```

## 🛠️ Troubleshooting

### ❗ Problemas Comuns

1. **VM não inicia:**
   - Verificar se VirtualBox está funcionando corretamente
   - Executar `vagrant destroy -f` e `vagrant up` novamente
   - Verificar logs do VirtualBox

2. **Problemas de rede:**
   - Verificar se o IP 192.168.56.105 está livre na rede
   - Executar `./rebuild-logger.sh` para rebuild limpo
   - Verificar configurações de firewall

3. **Splunk não acessível:**
   - Aguardar 5-10 minutos após o boot completo
   - Verificar logs: `journalctl -u splunkd`
   - Verificar se o serviço está rodando: `systemctl status splunkd`

4. **Timeout no GRUB:**
   - Executar `scripts/configure-grub.sh` manualmente
   - Verificar configuração: `cat /etc/default/grub`

### 🔍 Logs de Debug

```bash
# Logs do Vagrant em tempo real
vagrant ssh logger -c "tail -f /var/log/logger_provision_report.log"

# Logs do sistema
journalctl -f

# Status de todos os serviços
systemctl list-units --failed

# Verificar espaço em disco
df -h

# Verificar uso de memória
free -h
```

## 🚀 Plataformas de Deployment

### Desenvolvimento Local
- **Vagrant** com VirtualBox/VMware
- **Setup rápido** para testes e desenvolvimento

### Plataformas Cloud
- **AWS** - Deploy com Terraform
- **Azure** - Terraform + Ansible
- **ESXi** - Terraform + Ansible
- **Proxmox** - Terraform + Ansible

### Enterprise
- **HyperV** - Ambientes Windows Server
- **Custom** - Templates Packer para builds customizados

## 🤝 Contribuição

Contribuições são bem-vindas! Por favor, siga estes passos:

1. **Fork** o projeto
2. **Crie** uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. **Push** para a branch (`git push origin feature/AmazingFeature`)
5. **Abra** um Pull Request

### 📋 Guidelines de Contribuição

- Use commits descritivos
- Teste suas mudanças antes de submeter
- Mantenha a documentação atualizada
- Siga as convenções de código existentes

## 📄 Licença

Este projeto está licenciado sob a **Licença MIT** - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🙏 Agradecimentos

Este projeto é baseado no original [DetectionLab](https://github.com/clong/DetectionLab) por Chris Long, com significativas melhorias e modificações para operações SOC modernas.

### 🏆 Agradecimentos Especiais

- **Chris Long** - Criador original do DetectionLab
- **Palantir** - Configurações de Windows Event Forwarding
- **Splunk** - Plataforma SIEM enterprise
- **osquery** - Visibilidade cross-platform de endpoints
- **Suricata** - Sistema de detecção de intrusão
- **Zeek** - Framework de análise de rede
- **Velociraptor** - Plataforma de forensics digitais

## 📞 Suporte e Contato

Para suporte e dúvidas:

- **🐛 Issues**: [GitHub Issues](https://github.com/Uniao-Geek/SOC-Detection-Lab/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/Uniao-Geek/SOC-Detection-Lab/discussions)
- **📚 Wiki**: [Documentação Completa](https://github.com/Uniao-Geek/SOC-Detection-Lab/wiki)

---

**SOC Detection Laboratory** - Construindo o futuro da detecção de ameaças cibernéticas 🛡️

*Desenvolvido com ❤️ pela Uniao-Geek*
