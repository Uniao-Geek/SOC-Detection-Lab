# HANDOFF - SOC-Detection-Lab

## [2026-09-12 02:51] - Modernização didática Wazuh

### Estado ao encerrar
- Wazuh 4.14.7 tornou-se o SIEM/XDR padrão nos perfis Vagrant.
- Foram criados os perfis `wazuh-core`, `wazuh-ad`, `splunk-legacy` e `soar-ai`.
- O runner `lab.ps1` ganhou doctor, ciclo de VMs, cenários, replay e validação.
- Atomic Red Team foi limitado a commits e testes allowlisted, sem execução automática.
- Replay seguro de PCAP, EVTX, JSON e texto foi implementado.
- Foi adicionado um PCAP sintético com detecção Suricata SID 9000001.
- Foi implementada bridge SOAR local com aprovação e rollback, além de analista opcional somente leitura.
- Chaves Fleet/Velociraptor versionadas e cópias obsoletas foram removidas.
- Versões, hashes, CVEs, fontes e licenças foram catalogados.
- README em português e inglês foi atualizado.
- Validações concluídas: quatro perfis Vagrant, sintaxe Bash/PowerShell/Python, JSON, YAML, XML, geração PCAP, fixture SOAR, diff e lints.
- A subida das VMs não foi executada: havia 2,2 GB de RAM livre para um mínimo seguro de 10 GB.
- Arquivos modificados: `.gitattributes`, `.gitignore`, `README.md`, `README.pt-BR.md`, `soc-detection-lab.conf`, `lab.ps1`, `Vagrant/Vagrantfile`, bootstrap, scripts, recursos, catálogos e health checks.
- Commits realizados: nenhum.

### Próximo passo imediato
- Liberar pelo menos 10 GB de RAM sem encerrar processos automaticamente e executar `.\lab.ps1 up -Profile wazuh-core`.
- Em seguida executar um cenário Atomic, o PCAP sintético, um EVTX e `.\lab.ps1 validate -Profile wazuh-core`.

### Pendências conhecidas
- [ ] Executar validação ponta a ponta do perfil `wazuh-core` quando houver RAM.
- [ ] Fornecer artefatos Splunk/TA licenciados e seus sidecars SHA-256 para testar `splunk-legacy`.
- [ ] Migrar AWS, Azure, ESXi, Proxmox e Hyper-V em uma fase posterior; esta entrega prioriza Vagrant/VirtualBox.

### Ambiente necessário
- Windows 10/11, PowerShell 5.1+, VirtualBox 7.2+, Vagrant 2.3+ e Python 3.
- Mínimo de 10 GB de RAM livre e 70 GB de disco para `wazuh-core`.
- Variáveis opcionais: `SOC_PROFILE`, `SOC_GUI`, `SOC_LLM_ENDPOINT`, `SOC_LLM_MODEL`, `SOC_LLM_ALLOWED_HOSTS`.
- Variáveis Splunk legado: `SOC_SPLUNK_PASSWORD`, `SOC_SPLUNK_DEB_URL`, `SOC_SPLUNK_DEB_SHA256`.

### Paths importantes
- Windows: `D:\Projetos-SafeLabs\submodules\Uniao-Geek\SOC-Detection-Lab`
- Linux: `/mnt/predator/Projetos-SafeLabs/submodules/Uniao-Geek/SOC-Detection-Lab`

## [2026-09-12 23:30] - Confirmação final do commit

### Estado ao encerrar
- Commit principal confirmado: `dadab19` (`Make SOC lab Wazuh-only on VirtualBox`).
- A entrada de registro das 23:29 foi adicionada fora da ordem cronológica, mas seu conteúdo permanece válido; esta entrada final preserva a continuidade append-only.

### Próximo passo imediato
- Executar a homologação `wazuh-core` quando houver pelo menos 10 GB de RAM livre.

### Pendências conhecidas
- [ ] Validar o provisionamento real e os fluxos de alerta Wazuh.

### Ambiente necessário
- VirtualBox, Vagrant, Packer, PowerShell e Python.

### Paths importantes
- Windows: `D:\Projetos-SafeLabs\submodules\Uniao-Geek\SOC-Detection-Lab`
- Linux: `/mnt/predator/Projetos-SafeLabs/submodules/Uniao-Geek/SOC-Detection-Lab`

## [2026-09-12 23:29] - Registro do commit Wazuh-only

### Estado ao encerrar
- Commit realizado: `dadab19` (`Make SOC lab Wazuh-only on VirtualBox`).
- O commit contém a migração Wazuh, a remoção de providers legados e a limpeza de artefatos sensíveis/obsoletos.

### Próximo passo imediato
- Homologar `wazuh-core` quando o host tiver pelo menos 10 GB de RAM livre.

### Pendências conhecidas
- [ ] Executar o primeiro provisionamento completo e registrar eventuais ajustes de runtime.

### Ambiente necessário
- VirtualBox, Vagrant, Packer, PowerShell e Python.

### Paths importantes
- Windows: `D:\Projetos-SafeLabs\submodules\Uniao-Geek\SOC-Detection-Lab`
- Linux: `/mnt/predator/Projetos-SafeLabs/submodules/Uniao-Geek/SOC-Detection-Lab`

## [2026-09-12 23:09] - Antes da remoção de providers e Splunk

### Estado antes da operação destrutiva
- A modernização Wazuh está no working tree, ainda sem commit.
- Serão removidos Splunk e os providers AWS, Azure, ESXi, Proxmox e Hyper-V por decisão explícita do usuário.
- O único provider suportado passará a ser Vagrant com VirtualBox.
- Para reverter arquivos versionados removidos: `git restore --source=HEAD -- <path>`.
- Não restaurar chaves privadas, certificados ou metadados `.vagrant/` removidos por segurança.
- Nenhuma VM ou infraestrutura externa será iniciada ou destruída nesta etapa.

## [2026-09-12 23:28] - Finalização Wazuh-only no VirtualBox

### Estado ao encerrar
- Splunk foi removido do código ativo, dos perfis, scripts, recursos, catálogos e documentação.
- AWS, Azure, ESXi, Proxmox, Hyper-V, Terraform, Ansible e automações cloud foram removidos.
- Vagrant com VirtualBox tornou-se o único provider suportado.
- Packer foi reduzido a builders VirtualBox com referências e checksums validados.
- `wazuh-core`, `wazuh-ad` e `soar-ai` são os únicos perfis.
- WEF coleta `ForwardedEvents`, canais `WEC-*`, Sysmon, PowerShell e transcripts pelo agente Wazuh.
- Exchange opcional usa agente Wazuh e artefato ISO com SHA-256 fixo.
- Replay e cenários agora exigem evidência de alerta Wazuh após a execução.
- Validações aprovadas: Vagrant, Packer, PowerShell, Bash, Python, JSON, YAML, XML, lints, fixtures PCAP/SOAR e auditoria de referências.
- A homologação com VMs foi bloqueada corretamente pelo `doctor`: 3 GB livres para um mínimo seguro de 10 GB.
- Commits realizados: serão registrados na entrada seguinte.

### Próximo passo imediato
- Liberar pelo menos 10 GB de RAM e executar `.\lab.ps1 up -Profile wazuh-core`.
- Depois executar cenário Atomic, replay PCAP/EVTX/log e `.\lab.ps1 validate -Profile wazuh-core`.

### Pendências conhecidas
- [ ] Homologar `wazuh-core` ponta a ponta quando houver RAM suficiente.
- [ ] Homologar `wazuh-ad` em host com capacidade superior, pois as quatro VMs não cabem com segurança em 16 GB.
- [ ] Homologar Exchange opcional separadamente em host com memória adequada.

### Ambiente necessário
- Windows 10/11, PowerShell 5.1+, VirtualBox 7.2+, Vagrant 2.3+, Packer e Python 3.
- Variáveis opcionais: `SOC_PROFILE`, `SOC_GUI`, `SOC_LLM_ENDPOINT`, `SOC_LLM_MODEL`, `SOC_LLM_ALLOWED_HOSTS`.
- Nenhuma credencial ou configuração cloud é necessária.

### Paths importantes
- Windows: `D:\Projetos-SafeLabs\submodules\Uniao-Geek\SOC-Detection-Lab`
- Linux: `/mnt/predator/Projetos-SafeLabs/submodules/Uniao-Geek/SOC-Detection-Lab`

## [2026-09-12 23:31] - Fechamento cronológico

### Estado ao encerrar
- Commit principal confirmado: `dadab19` (`Make SOC lab Wazuh-only on VirtualBox`).
- As entradas 23:29 e 23:30 ficaram fora da ordem por correspondência de contexto durante o append; nenhuma entrada anterior foi removida.

### Próximo passo imediato
- Homologar `wazuh-core` quando houver pelo menos 10 GB de RAM livre.

### Pendências conhecidas
- [ ] Executar o primeiro provisionamento completo e registrar ajustes de runtime.

### Ambiente necessário
- VirtualBox, Vagrant, Packer, PowerShell e Python.

### Paths importantes
- Windows: `D:\Projetos-SafeLabs\submodules\Uniao-Geek\SOC-Detection-Lab`
- Linux: `/mnt/predator/Projetos-SafeLabs/submodules/Uniao-Geek/SOC-Detection-Lab`

## [2026-09-13 00:42] - Publicação no GitHub

### Estado ao encerrar
- Commits `dadab19` e `451718e` publicados em `origin/main`.
- Remoto confirmado: `https://github.com/Uniao-Geek/SOC-Detection-Lab.git`.
- Nenhuma VM foi iniciada durante a publicação.

### Próximo passo imediato
- Homologar `wazuh-core` com apoio assistido quando houver pelo menos 10 GB de RAM livre.

### Pendências conhecidas
- [ ] Executar o primeiro provisionamento completo e registrar ajustes de runtime.

### Ambiente necessário
- VirtualBox, Vagrant, Packer, PowerShell e Python.

### Paths importantes
- Windows: `D:\Projetos-SafeLabs\submodules\Uniao-Geek\SOC-Detection-Lab`
- Linux: `/mnt/predator/Projetos-SafeLabs/submodules/Uniao-Geek/SOC-Detection-Lab`
