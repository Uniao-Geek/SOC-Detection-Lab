# SOC Detection Laboratory

Laboratório didático para demonstrar o ciclo básico de um SOC: gerar atividade,
coletar telemetria, detectar, alertar, investigar, responder, conter e validar a
recuperação.

Autor: André Henrique (@mrhenrike) | União Geek | https://uniaogeek.com.br/

## Arquitetura

O perfil padrão usa:

- Wazuh como SIEM/XDR e inventário de endpoints
- Sysmon, osquery e agente Wazuh no Windows
- Suricata e Zeek para visibilidade de rede
- Velociraptor para DFIR
- Atomic Red Team com allowlist para validação de detecções
- replay offline de PCAP, EVTX, JSON e logs de texto
- bridge SOAR local com aprovação humana
- analista IA opcional e somente leitura

O único caminho de execução suportado é Vagrant com VirtualBox.

## Perfis

- `wazuh-core`: logger e Win10, recomendado para hosts com 16 GB
- `wazuh-ad`: adiciona DC e WEF, recomendado para hosts com mais memória
- `soar-ai`: adiciona bridge SOAR e adaptador de analista IA ao `wazuh-core`

O runner impede o início quando a RAM ou o disco livres são insuficientes. Ele
não encerra processos do host.

## Início rápido no Windows

Pré-requisitos:

- Windows 10/11
- VirtualBox 7.2+
- Vagrant 2.3+
- PowerShell 5.1+
- 70 GB livres
- pelo menos 10 GB de RAM livre para `wazuh-core`

```powershell
.\lab.ps1 doctor -Profile wazuh-core
.\lab.ps1 up -Profile wazuh-core
.\lab.ps1 status -Profile wazuh-core
.\lab.ps1 validate -Profile wazuh-core
```

Acesse o dashboard Wazuh em `https://127.0.0.1:8443`. As credenciais são geradas
durante o provisionamento e ficam somente na VM logger, sob
`/var/lib/soc-detection-lab/secrets/`, com acesso restrito.

Para encerrar:

```powershell
.\lab.ps1 down -Profile wazuh-core
```

`reset` destrói as VMs do perfil e sempre solicita confirmação, salvo uso
explícito de `-Force`.

## Cenários de ataque e detecção

Os cenários são manifestos versionados em
`Vagrant/resources/scenarios/`. O runner só aceita IDs existentes e o executor
mantém uma segunda allowlist interna.

```powershell
.\lab.ps1 scenario -Profile wazuh-core -ScenarioId powershell-obfuscated
.\lab.ps1 scenario -Profile wazuh-core -ScenarioId registry-run-key
.\lab.ps1 scenario -Profile wazuh-core -ScenarioId credential-enumeration
.\lab.ps1 scenario -Profile wazuh-ad -ScenarioId lateral-smb-probe
.\lab.ps1 scenario -Profile wazuh-core -ScenarioId patch-compliance
.\lab.ps1 scenario -Profile soar-ai -ScenarioId response-containment
```

Cada manifesto informa técnica ATT&CK, risco, timeout, telemetria esperada,
alerta esperado e cleanup. O instalador do Atomic Red Team baixa commits fixos,
não executa testes durante o provisionamento e não instala Mimikatz,
PowerSploit, PurpleSharp ou BadBlood por padrão.

## Replay de PCAP

Gere o PCAP sintético e não roteável:

```powershell
python .\Vagrant\scripts\generate-training-pcap.py .\.tmp\training.pcap
.\lab.ps1 replay -Profile wazuh-core -ReplayType pcap -Path .\.tmp\training.pcap
```

O replay padrão é offline. Suricata e Zeek processam a captura e enviam JSON ao
Wazuh. O tráfego contém o marcador `SOC-LAB-C2-Beacon`, detectado pelo SID
Suricata `9000001`.

Replay ao vivo é bloqueado por padrão. Quando habilitado manualmente dentro da
VM, ele usa somente `eth1`, limita a taxa e recusa execução se essa interface
tiver rota para a Internet.

## Replay de EVTX e logs

```powershell
.\lab.ps1 replay -Profile wazuh-core -ReplayType evtx -Path .\dados\amostra.evtx
.\lab.ps1 replay -Profile wazuh-core -ReplayType log -Path .\dados\eventos.jsonl
```

Entradas são validadas por extensão, tamanho, localização e formato. EVTX
preserva o timestamp original em um campo separado e limita a importação a
5.000 eventos. Hayabusa pode ser usado opcionalmente quando o binário e seu
SHA-256 sidecar forem fornecidos pelo operador.

## SOAR e resposta

No perfil `soar-ai`, alertas didáticos Wazuh viram incidentes em:

```text
/var/lib/soc-detection-lab/soar/incidents/
/var/lib/soc-detection-lab/soar/pending/
```

Nenhuma contenção é automática. Para aprovar uma ação proposta:

```bash
sudo soc-lab-approve-response INCIDENT_ID
```

O único bloqueio de rede permitido aceita endereços da rede host-only
`192.168.56.0/24`, protege gateway e logger e agenda rollback em cinco minutos.
O blueprint de Shuffle está em
`Vagrant/resources/soar/shuffle-wazuh-training.blueprint.json` e deve ser
configurado na interface do Shuffle, pois IDs de apps variam por instalação.

## Analista IA

O adaptador gera relatório, nunca executa ações. Sem modelo configurado, produz
um resumo determinístico. Para usar Ollama na própria VM:

```bash
export SOC_LLM_ENDPOINT=http://127.0.0.1:11434/api/generate
export SOC_LLM_MODEL=qwen3:0.6b
soc-lab-ai-analyst INCIDENT_ID
```

HTTP é aceito somente em loopback. Endpoints HTTPS externos precisam estar em
`SOC_LLM_ALLOWED_HOSTS`. Redirecionamentos, credenciais na URL e respostas
maiores que 1 MB são recusados.

## Proveniência e CVEs

- fontes, commits, licenças e política: `Vagrant/resources/catalog/sources.yaml`
- CVEs e advisories priorizados: `Vagrant/resources/catalog/cves.yaml`
- versões e hashes: `soc-detection-lab.conf`

O catálogo cobre Windows KEV de 2026, Velociraptor 0.77.2, Suricata 8.0.6 e osquery 5.23.1. PoCs públicos não são
executados nem incorporados automaticamente.

## Segurança

- use somente em rede isolada e sistemas autorizados
- não reutilize credenciais ou certificados do laboratório
- snapshots devem preceder cenários de risco médio
- conteúdo externo precisa de commit, versão e hash ou assinatura
- ações ofensivas e contenções autônomas por agentes IA são proibidas
- este projeto não é adequado para produção

## Créditos e licença

Baseado no DetectionLab de Chris Long, com componentes de Wazuh, Red Canary,
SigmaHQ, OISF, Zeek, Velociraptor, osquery e Olaf Hartong. Preserve as
licenças e atribuições de cada fonte descrita no catálogo.

O código deste repositório usa a licença MIT. Conteúdo obtido de terceiros
permanece sob a licença de sua origem.
