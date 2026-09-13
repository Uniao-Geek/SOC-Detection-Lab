#!/usr/bin/env bash
set -euo pipefail

INCIDENT_ID="${1:-}"
STATE_ROOT="/var/lib/soc-detection-lab/soar"
PENDING="$STATE_ROOT/pending/$INCIDENT_ID.json"
AUDIT="$STATE_ROOT/audit.jsonl"

if [[ ! "$INCIDENT_ID" =~ ^[a-f0-9]{24}$ ]] || [[ ! -f "$PENDING" ]]; then
    echo "Usage: $0 INCIDENT_ID" >&2
    exit 2
fi

action="$(jq -er '.action' "$PENDING")"
recorded_id="$(jq -er '.incident_id' "$PENDING")"
if [[ "$recorded_id" != "$INCIDENT_ID" ]]; then
    echo "Incident identity mismatch." >&2
    exit 1
fi

case "$action" in
    acknowledge)
        result="acknowledged"
        ;;
    block-lab-ip)
        source_ip="$(jq -er '.source_ip' "$PENDING")"
        python3 - "$source_ip" <<'PY'
import ipaddress
import sys

address = ipaddress.ip_address(sys.argv[1])
network = ipaddress.ip_network("192.168.56.0/24")
if address not in network or address in {
    ipaddress.ip_address("192.168.56.1"),
    ipaddress.ip_address("192.168.56.105"),
}:
    raise SystemExit("Address is outside the response allowlist.")
PY
        iptables -C INPUT -s "$source_ip" -m comment --comment "soc-lab-$INCIDENT_ID" -j DROP 2>/dev/null ||
            iptables -I INPUT 1 -s "$source_ip" -m comment --comment "soc-lab-$INCIDENT_ID" -j DROP
        systemd-run --quiet --unit="soc-lab-rollback-$INCIDENT_ID" --on-active=5m \
            /bin/sh -c "iptables -D INPUT -s '$source_ip' -m comment --comment 'soc-lab-$INCIDENT_ID' -j DROP || true"
        result="blocked_for_300_seconds"
        ;;
    *)
        echo "Response action is not allowlisted." >&2
        exit 1
        ;;
esac

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -nc \
    --arg timestamp "$timestamp" \
    --arg incident_id "$INCIDENT_ID" \
    --arg action "$action" \
    --arg result "$result" \
    '{timestamp:$timestamp,incident_id:$incident_id,action:$action,result:$result,approved_by:"local-operator"}' \
    >>"$AUDIT"
chmod 600 "$AUDIT"
rm -f "$PENDING"
echo "Response approved: $result"
