#!/usr/bin/env bash
set -euo pipefail

REPLAY_ROOT="${SOC_REPLAY_ROOT:-/vagrant/.replay}"
OUTPUT_ROOT="${SOC_REPLAY_OUTPUT_ROOT:-/var/lib/soc-detection-lab/replay}"
TYPE=""
INPUT=""
LIVE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)
            TYPE="${2:-}"
            shift 2
            ;;
        --file)
            INPUT="${2:-}"
            shift 2
            ;;
        --live)
            LIVE=true
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if [[ "$TYPE" != "pcap" && "$TYPE" != "log" ]] || [[ -z "$INPUT" ]]; then
    echo "Usage: $0 --type pcap|log --file /vagrant/.replay/file [--live]" >&2
    exit 2
fi

resolved_root="$(realpath "$REPLAY_ROOT")"
resolved_input="$(realpath "$INPUT")"
if [[ "$resolved_input" != "$resolved_root/"* ]] || [[ ! -f "$resolved_input" ]]; then
    echo "Input must be a regular file staged under $REPLAY_ROOT." >&2
    exit 1
fi

size="$(stat -c %s "$resolved_input")"
if (( size <= 0 || size > 1073741824 )); then
    echo "Input size is outside the allowed range." >&2
    exit 1
fi

run_id="$(date -u +%Y%m%dT%H%M%SZ)-$(openssl rand -hex 6)"
work_dir="$OUTPUT_ROOT/work-$run_id"
output="$OUTPUT_ROOT/replay-$run_id.jsonl"
mkdir -p "$work_dir" "$OUTPUT_ROOT"
chmod 750 "$OUTPUT_ROOT" "$work_dir"
trap 'rm -rf "$work_dir"' EXIT

append_json() {
    local source="$1"
    local source_type="$2"
    jq -c \
        --arg id "$run_id" \
        --arg source_type "$source_type" \
        'if type == "object" then . + {soc_lab: {event_type: "telemetry", scenario_id: $id, title: "Offline telemetry replay", source_type: $source_type, expected_alert: true}} else error("Replay record must be an object") end' \
        "$source" >>"$output"
}

if [[ "$TYPE" == "pcap" ]]; then
    case "${resolved_input,,}" in
        *.pcap|*.pcapng) ;;
        *)
            echo "PCAP input must use .pcap or .pcapng." >&2
            exit 1
            ;;
    esac
    magic="$(od -An -tx1 -N4 "$resolved_input" | tr -d ' \n')"
    case "$magic" in
        d4c3b2a1|a1b2c3d4|4d3cb2a1|a1b23c4d|0a0d0d0a) ;;
        *)
            echo "PCAP magic bytes are invalid." >&2
            exit 1
            ;;
    esac

    if "$LIVE"; then
        if [[ "${SOC_ALLOW_LIVE_REPLAY:-false}" != "true" ]]; then
            echo "Live replay requires SOC_ALLOW_LIVE_REPLAY=true." >&2
            exit 1
        fi
        if ip route get 1.1.1.1 | grep -q 'dev eth1'; then
            echo "Refusing live replay because eth1 has an Internet route." >&2
            exit 1
        fi
        timeout 300 tcpreplay --intf1=eth1 --mbps=5 --loop=1 "$resolved_input"
    else
        mkdir -p "$work_dir/suricata"
        timeout 300 suricata -r "$resolved_input" -l "$work_dir/suricata" \
            -c /etc/suricata/suricata.yaml
        if [[ -s "$work_dir/suricata/eve.json" ]]; then
            append_json "$work_dir/suricata/eve.json" "suricata"
        fi

        (
            cd "$work_dir"
            timeout 300 zeek -Cr "$resolved_input" LogAscii::use_json=T
        )
        for zeek_log in "$work_dir"/*.log; do
            [[ -s "$zeek_log" ]] || continue
            append_json "$zeek_log" "zeek:$(basename "$zeek_log" .log)"
        done
    fi
else
    case "${resolved_input,,}" in
        *.json|*.jsonl)
            line_count=0
            while IFS= read -r line; do
                ((line_count += 1))
                (( line_count <= 100000 )) || {
                    echo "Log exceeds the 100000 line limit." >&2
                    exit 1
                }
                (( ${#line} <= 1048576 )) || {
                    echo "Log line exceeds the 1 MB limit." >&2
                    exit 1
                }
                printf '%s\n' "$line" | jq -e -c \
                    --arg id "$run_id" \
                    'if type == "object" then . + {soc_lab: {event_type: "telemetry", scenario_id: $id, title: "JSON log replay", source_type: "json", expected_alert: true}} else error("JSON record must be an object") end' \
                    >>"$output"
            done <"$resolved_input"
            ;;
        *.log)
            awk 'length($0) > 1048576 {exit 2} NR > 100000 {exit 3} {print}' "$resolved_input" |
                jq -R -c --arg id "$run_id" \
                    '{message: ., soc_lab: {event_type: "telemetry", scenario_id: $id, title: "Text log replay", source_type: "text", expected_alert: true}}' \
                    >"$output"
            ;;
        *)
            echo "Log input must use .json, .jsonl or .log." >&2
            exit 1
            ;;
    esac
fi

chmod 640 "$output" 2>/dev/null || true
rm -f "$resolved_input"
echo "Replay completed: $output"
