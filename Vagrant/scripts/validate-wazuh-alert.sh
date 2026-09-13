#!/usr/bin/env bash
set -euo pipefail

ALERTS="${SOC_WAZUH_ALERTS_FILE:-/var/ossec/logs/alerts/alerts.json}"
SINCE=""
SCENARIO=""
TIMEOUT=90

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since)
            SINCE="${2:-}"
            shift 2
            ;;
        --scenario)
            SCENARIO="${2:-}"
            shift 2
            ;;
        --timeout)
            TIMEOUT="${2:-}"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if [[ ! "$SINCE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
    [[ -n "$SCENARIO" && ! "$SCENARIO" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] ||
    [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]] ||
    (( TIMEOUT < 10 || TIMEOUT > 300 )); then
    echo "Usage: $0 --since UTC_TIMESTAMP [--scenario ID] [--timeout 10..300]" >&2
    exit 2
fi
SINCE_COMPARE="${SINCE%Z}"

for ((elapsed = 0; elapsed < TIMEOUT; elapsed += 3)); do
    if [[ -s "$ALERTS" ]] && tail -n 2000 "$ALERTS" | jq -e \
        --arg since "$SINCE_COMPARE" \
        --arg scenario "$SCENARIO" \
        'select(
            .timestamp >= $since
            and (.rule.id == "110001" or .rule.id == "110010")
            and (
                $scenario == ""
                or .data.soc_lab.scenario_id == $scenario
                or .data.scenario_id == $scenario
            )
        )' "$ALERTS" >/dev/null; then
        echo "Wazuh detection evidence found."
        exit 0
    fi
    sleep 3
done

echo "No matching Wazuh detection was found within ${TIMEOUT}s." >&2
exit 1
