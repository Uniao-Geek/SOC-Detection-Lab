#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run this installer as root." >&2
    exit 1
fi

available_mb="$(awk '/MemAvailable/ {print int($2 / 1024)}' /proc/meminfo)"
if (( available_mb < 1024 )); then
    echo "At least 1 GB of free guest memory is required." >&2
    exit 1
fi

install -d -m 0755 /usr/local/lib/soc-detection-lab
install -d -m 0750 /var/lib/soc-detection-lab/soar
install -m 0755 /vagrant/scripts/soar-bridge.py /usr/local/lib/soc-detection-lab/soar-bridge.py
install -m 0755 /vagrant/scripts/ai-analyst.py /usr/local/bin/soc-lab-ai-analyst
install -m 0755 /vagrant/scripts/approve-response.sh /usr/local/bin/soc-lab-approve-response
install -m 0644 /vagrant/resources/soar/soc-lab-soar.service /etc/systemd/system/soc-lab-soar.service

python3 -m py_compile \
    /usr/local/lib/soc-detection-lab/soar-bridge.py \
    /usr/local/bin/soc-lab-ai-analyst

systemctl daemon-reload
systemctl enable --now soc-lab-soar.service
systemctl is-active --quiet soc-lab-soar.service

echo "Local approval-gated SOAR bridge installed."
echo "Shuffle remains external and optional. Import the blueprint from:"
echo "  /vagrant/resources/soar/shuffle-wazuh-training.blueprint.json"
echo "AI reports are read-only and use a loopback Ollama endpoint only when SOC_LLM_ENDPOINT is set."
