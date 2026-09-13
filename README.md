# SOC Detection Laboratory

An educational lab for the core SOC cycle: generate activity, collect telemetry,
detect, alert, investigate, respond, contain, and validate recovery.

Author: André Henrique (@mrhenrike) | União Geek | https://uniaogeek.com.br/

Portuguese documentation: [README.pt-BR.md](README.pt-BR.md)

## Default stack

- Wazuh SIEM/XDR
- Sysmon, osquery, and Wazuh Windows agents
- Suricata and Zeek network telemetry
- Velociraptor DFIR
- allowlisted Atomic Red Team scenarios
- offline PCAP, EVTX, JSON, and text log replay
- approval-gated local SOAR bridge
- optional read-only AI analyst

The only supported deployment path is Vagrant with VirtualBox.

## Profiles

- `wazuh-core`: logger and Windows 10, suitable for a 16 GB host
- `wazuh-ad`: adds the domain controller and WEF
- `soar-ai`: adds the SOAR bridge and AI analyst adapter

## Quick start

Requirements: Windows 10/11, VirtualBox 7.2+, Vagrant 2.3+, PowerShell 5.1+,
70 GB free disk, and at least 10 GB free memory for `wazuh-core`.

```powershell
.\lab.ps1 doctor -Profile wazuh-core
.\lab.ps1 up -Profile wazuh-core
.\lab.ps1 validate -Profile wazuh-core
```

Open the Wazuh dashboard at `https://127.0.0.1:8443`. Credentials are generated
inside the logger VM and stored under `/var/lib/soc-detection-lab/secrets/`.

```powershell
.\lab.ps1 down -Profile wazuh-core
```

## Detection validation

```powershell
.\lab.ps1 scenario -Profile wazuh-core -ScenarioId powershell-obfuscated
.\lab.ps1 scenario -Profile wazuh-core -ScenarioId registry-run-key
.\lab.ps1 scenario -Profile wazuh-core -ScenarioId credential-enumeration
.\lab.ps1 scenario -Profile wazuh-ad -ScenarioId lateral-smb-probe
.\lab.ps1 scenario -Profile wazuh-core -ScenarioId patch-compliance
.\lab.ps1 scenario -Profile soar-ai -ScenarioId response-containment
```

Scenario manifests define ATT&CK mapping, risk, timeout, expected telemetry,
expected detection, and cleanup. Atomic content is fetched at pinned commits
and is never executed during provisioning.

## PCAP, EVTX, and log replay

```powershell
python .\Vagrant\scripts\generate-training-pcap.py .\.tmp\training.pcap
.\lab.ps1 replay -Profile wazuh-core -ReplayType pcap -Path .\.tmp\training.pcap
.\lab.ps1 replay -Profile wazuh-core -ReplayType evtx -Path .\data\sample.evtx
.\lab.ps1 replay -Profile wazuh-core -ReplayType log -Path .\data\events.jsonl
```

PCAP processing is offline by default. The generated capture uses non-routable
training traffic and triggers Suricata SID `9000001`. Live replay is disabled
unless explicitly enabled inside the isolated VM.

Replay inputs are constrained by path, extension, size, record count, and line
length. Hayabusa is supported as an optional operator-supplied tool with a
matching SHA-256 sidecar.

## SOAR and AI

The `soar-ai` profile creates incidents and pending actions under
`/var/lib/soc-detection-lab/soar/`. Responses require explicit approval:

```bash
sudo soc-lab-approve-response INCIDENT_ID
```

Network blocks are limited to the host-only lab subnet and automatically roll
back after five minutes. The Shuffle blueprint is stored at
`Vagrant/resources/soar/shuffle-wazuh-training.blueprint.json`.

The AI adapter only writes analyst reports:

```bash
export SOC_LLM_ENDPOINT=http://127.0.0.1:11434/api/generate
export SOC_LLM_MODEL=qwen3:0.6b
soc-lab-ai-analyst INCIDENT_ID
```

Plain HTTP is limited to loopback. External HTTPS hosts require an explicit
allowlist. The adapter cannot invoke offensive or response actions.

## Provenance and security

- component versions and hashes: `soc-detection-lab.conf`
- source commits and licenses: `Vagrant/resources/catalog/sources.yaml`
- prioritized advisories: `Vagrant/resources/catalog/cves.yaml`
- scenarios: `Vagrant/resources/scenarios/`

Use only on isolated systems you are authorized to test. Do not reuse lab
credentials or certificates. Third-party content requires an immutable
reference plus a checksum or trusted signature. Public PoCs and unverified
binaries are not executed automatically.

## Credits and license

Based on Chris Long's DetectionLab and projects maintained by Wazuh, Red Canary,
SigmaHQ, OISF, Zeek, Velociraptor, osquery, and Olaf Hartong.

Repository code is MIT licensed. Downloaded third-party content retains its
upstream license.
