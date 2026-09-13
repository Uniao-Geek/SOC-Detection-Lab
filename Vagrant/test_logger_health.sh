#!/usr/bin/env bash
set -euo pipefail

PROFILE="${SOC_PROFILE:-wazuh-core}"
export VAGRANT_DEFAULT_PROVIDER="virtualbox"
FAILURES=0

case "$PROFILE" in
    wazuh-core|wazuh-ad|soar-ai) ;;
    *)
        echo "Unsupported SOC_PROFILE: $PROFILE" >&2
        exit 2
        ;;
esac

check_port() {
    local name="$1"
    local port="$2"
    if nc -z -w 5 127.0.0.1 "$port"; then
        echo "[OK] $name port $port"
    else
        echo "[FAIL] $name port $port" >&2
        ((FAILURES += 1))
    fi
}

check_service() {
    local name="$1"
    if vagrant ssh logger -c "sudo systemctl is-active --quiet '$name'"; then
        echo "[OK] $name"
    else
        echo "[FAIL] $name" >&2
        ((FAILURES += 1))
    fi
}

if ! vagrant status logger --machine-readable | grep -q ',state,running'; then
    echo "[FAIL] logger VM is not running" >&2
    exit 1
fi

check_port "Wazuh dashboard" 8443
for service in wazuh-indexer wazuh-manager wazuh-dashboard suricata zeek velociraptor_server; do
    check_service "$service"
done
if [[ "$PROFILE" == "soar-ai" ]]; then
    check_service "soc-lab-soar"
fi

if vagrant ssh logger -c "sudo ss -ltn | grep -q ':9997 '"; then
    echo "[FAIL] Removed SIEM forwarding port 9997 is listening" >&2
    ((FAILURES += 1))
fi

if (( FAILURES > 0 )); then
    echo "$FAILURES health check(s) failed." >&2
    exit 1
fi

echo "All logger checks passed for $PROFILE."
