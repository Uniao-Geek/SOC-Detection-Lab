#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

CONFIG_FILE="${SOC_CONFIG_FILE:-/tmp/soc-detection-lab.conf}"
REPORT_FILE="/var/log/soc-detection-lab-provision.jsonl"
SECRET_ROOT="/var/lib/soc-detection-lab/secrets"
CACHE_ROOT="/opt/soc-detection-lab/cache"
FAILED_MODULES=()

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Provisioning must run as root." >&2
    exit 1
fi
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$CONFIG_FILE"
set +a

mkdir -p "$SECRET_ROOT" "$CACHE_ROOT"
chmod 700 "$SECRET_ROOT"

log() {
    printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

record_status() {
    local module="$1"
    local status="$2"
    jq -nc \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg module "$module" \
        --arg status "$status" \
        '{timestamp:$timestamp,module:$module,status:$status}' \
        >>"$REPORT_FILE"
}

download_verified() {
    local url="$1"
    local destination="$2"
    local expected_sha256="$3"

    if [[ ! "$url" =~ ^https:// ]] || [[ ! "$expected_sha256" =~ ^[a-fA-F0-9]{64}$ ]]; then
        log "Rejected download metadata for $url"
        return 1
    fi

    curl --fail --location --proto '=https' --tlsv1.2 \
        --retry 3 --connect-timeout 15 --max-time 900 \
        --output "$destination" "$url"
    echo "${expected_sha256,,}  $destination" | sha256sum --check --status || {
        rm -f "$destination"
        log "SHA-256 validation failed for $url"
        return 1
    }
}

wait_for_service() {
    local service="$1"
    local attempts="${2:-60}"

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if systemctl is-active --quiet "$service"; then
            return 0
        fi
        sleep 2
    done
    systemctl status "$service" --no-pager || true
    return 1
}

install_base_dependencies() {
    apt-get update
    apt-get install --no-install-recommends -y \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        dnsutils \
        ethtool \
        flex \
        bison \
        git \
        gnupg \
        jq \
        libcurl4-openssl-dev \
        libjemalloc-dev \
        liblzma-dev \
        libmagic-dev \
        libmaxminddb-dev \
        libpcap-dev \
        libreadline-dev \
        libssl-dev \
        make \
        net-tools \
        python3 \
        python3-pip \
        software-properties-common \
        tcpdump \
        unzip
}

configure_host() {
    hostnamectl set-hostname logger
    grep -qE '(^|[[:space:]])logger($|[[:space:]])' /etc/hosts ||
        printf '127.0.1.1 logger\n' >>/etc/hosts

    if ! ip -4 address show eth1 | grep -q '192\.168\.56\.105/'; then
        log "eth1 does not have the expected lab address."
        return 1
    fi
}

configure_wazuh_inputs() {
    install -m 0640 -o root -g wazuh \
        /vagrant/resources/wazuh/soc_lab_rules.xml \
        /var/ossec/etc/rules/soc_lab_rules.xml

    python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET

path = Path("/var/ossec/etc/ossec.conf")
tree = ET.parse(path)
root = tree.getroot()
entries = (
    ("json", "/var/log/suricata/eve.json"),
    ("json", "/opt/zeek/logs/current/*.log"),
    ("json", "/var/lib/soc-detection-lab/replay/*.jsonl"),
)
existing = {node.findtext("location") for node in root.findall("localfile")}
for log_format, location in entries:
    if location in existing:
        continue
    localfile = ET.SubElement(root, "localfile")
    ET.SubElement(localfile, "log_format").text = log_format
    ET.SubElement(localfile, "location").text = location
ET.indent(tree, space="  ")
tree.write(path, encoding="unicode")
PY

    /var/ossec/bin/wazuh-analysisd -t
    systemctl restart wazuh-manager
    wait_for_service wazuh-manager
}

install_wazuh() {
    local installer="$CACHE_ROOT/wazuh-install-${WAZUH_VERSION}.sh"
    local installed_version=""

    if dpkg-query -W wazuh-manager >/dev/null 2>&1; then
        installed_version="$(dpkg-query -W -f='${Version}' wazuh-manager | cut -d- -f1)"
    fi

    if [[ "$installed_version" != "$WAZUH_VERSION" ]]; then
        download_verified "$WAZUH_INSTALLER_URL" "$installer" "$WAZUH_INSTALLER_SHA256"
        chmod 700 "$installer"
        (
            cd "$CACHE_ROOT"
            bash "$installer" -a
        ) >"/var/log/wazuh-install.log" 2>&1
        chmod 600 /var/log/wazuh-install.log

        if [[ -f "$CACHE_ROOT/wazuh-install-files.tar" ]]; then
            mv "$CACHE_ROOT/wazuh-install-files.tar" "$SECRET_ROOT/"
            chmod 600 "$SECRET_ROOT/wazuh-install-files.tar"
        fi
    fi

    installed_version="$(dpkg-query -W -f='${Version}' wazuh-manager 2>/dev/null | cut -d- -f1)"
    if [[ "$installed_version" != "$WAZUH_VERSION" ]]; then
        log "Expected Wazuh $WAZUH_VERSION, installed ${installed_version:-unknown}."
        return 1
    fi

    mkdir -p /var/lib/soc-detection-lab/replay
    chmod 750 /var/lib/soc-detection-lab/replay
    configure_wazuh_inputs

    for service in wazuh-indexer wazuh-manager wazuh-dashboard; do
        systemctl enable "$service"
        wait_for_service "$service" 90
    done

    if [[ -f /etc/apt/sources.list.d/wazuh.list ]]; then
        sed -i 's/^deb /# deb /' /etc/apt/sources.list.d/wazuh.list
    fi
}

install_suricata() {
    add-apt-repository -y ppa:oisf/suricata-stable
    apt-get update
    apt-get install -y suricata suricata-update

    if ! suricata --build-info | grep -q "Suricata version ${SURICATA_VERSION}"; then
        log "Installed Suricata does not match $SURICATA_VERSION."
        return 1
    fi
    if ! suricata-update --version | grep -q "$SURICATA_UPDATE_VERSION"; then
        log "Installed suricata-update does not match $SURICATA_UPDATE_VERSION."
        return 1
    fi

    install -m 0644 /vagrant/resources/suricata/suricata.yaml /etc/suricata/suricata.yaml
    sed -i -E 's/^(IFACE|iface)=.*/IFACE=eth1/' /etc/default/suricata
    suricata-update update-sources
    suricata-update enable-source et/open
    suricata-update
    if ! grep -q 'sid:9000001;' /var/lib/suricata/rules/suricata.rules; then
        cat /vagrant/resources/suricata/soc-lab.rules >>/var/lib/suricata/rules/suricata.rules
    fi
    suricata -T -c /etc/suricata/suricata.yaml
    systemctl enable --now suricata
    wait_for_service suricata
}

install_zeek() {
    local archive="$CACHE_ROOT/zeek-${ZEEK_VERSION}.tar.gz"
    local source_dir="/opt/zeek-${ZEEK_VERSION}"

    if [[ ! -x /opt/zeek/bin/zeek ]] ||
        ! /opt/zeek/bin/zeek --version 2>&1 | grep -q "$ZEEK_VERSION"; then
        download_verified \
            "https://download.zeek.org/zeek-${ZEEK_VERSION}.tar.gz" \
            "$archive" \
            "$ZEEK_SOURCE_SHA256"
        rm -rf "$source_dir"
        tar -xzf "$archive" -C /opt
        (
            cd "$source_dir"
            ./configure --prefix=/opt/zeek
            make -j2
            make install
        )
    fi

    cat >/opt/zeek/etc/node.cfg <<'EOF'
[zeek]
type=standalone
host=localhost
interface=eth1
EOF
    cat >/opt/zeek/share/zeek/site/local.zeek <<'EOF'
@load tuning/json-logs
@load policy/frameworks/files/hash-all-files
@load policy/protocols/conn/mac-logging
@load policy/protocols/conn/vlan-logging
redef ignore_checksums = T;
EOF

    install -m 0644 /vagrant/resources/zeek/zeek.service /etc/systemd/system/zeek.service
    systemctl daemon-reload
    systemctl enable --now zeek
    wait_for_service zeek
}

install_velociraptor() {
    local install_dir="/opt/velociraptor"
    local binary="$install_dir/velociraptor"
    local server_config="$SECRET_ROOT/velociraptor-server.yaml"
    local shared_secret_dir="/vagrant/.secrets/velociraptor"
    local url="https://github.com/Velocidex/velociraptor/releases/download/v${VELOCIRAPTOR_VERSION}/velociraptor-v${VELOCIRAPTOR_VERSION}-linux-amd64"
    local merge

    mkdir -p "$install_dir" "$shared_secret_dir"
    chmod 700 "$shared_secret_dir" 2>/dev/null || true
    download_verified "$url" "$binary" "$VELOCIRAPTOR_LINUX_SHA256"
    chmod 755 "$binary"

    merge="$(jq -nc \
        --arg client_url "https://logger:${VELOCIRAPTOR_FRONTEND_PORT}/" \
        --argjson frontend_port "$VELOCIRAPTOR_FRONTEND_PORT" \
        --argjson gui_port "$VELOCIRAPTOR_GUI_PORT" \
        '{Client:{server_urls:[$client_url]},Frontend:{hostname:"logger",bind_address:"0.0.0.0",bind_port:$frontend_port},GUI:{bind_address:"0.0.0.0",bind_port:$gui_port}}')"

    if [[ ! -s "$server_config" ]]; then
        "$binary" config generate --merge "$merge" >"$server_config"
        chmod 600 "$server_config"
    fi

    "$binary" --config "$server_config" config client \
        >"$shared_secret_dir/client.config.yaml"
    chmod 600 "$shared_secret_dir/client.config.yaml" 2>/dev/null || true

    if ! dpkg-query -W velociraptor-server >/dev/null 2>&1; then
        (
            cd "$install_dir"
            "$binary" --config "$server_config" debian server
            package="$(ls -1 velociraptor_*_server.deb | head -n 1)"
            dpkg -i "$package"
        )
    fi
    systemctl enable velociraptor_server
    wait_for_service velociraptor_server
}

sync_detection_content() {
    chmod +x /vagrant/scripts/sync-detection-content.sh
    SOC_CONFIG_FILE="$CONFIG_FILE" /vagrant/scripts/sync-detection-content.sh
}

run_module() {
    local module="$1"
    log "Starting $module"
    if "$module"; then
        record_status "$module" "success"
    else
        record_status "$module" "failed"
        FAILED_MODULES+=("$module")
    fi
}

final_healthcheck() {
    local failed=0
    for service in wazuh-indexer wazuh-manager wazuh-dashboard suricata zeek velociraptor_server; do
        if ! systemctl is-active --quiet "$service"; then
            log "Service is not active: $service"
            failed=1
        fi
    done
    if (( ${#FAILED_MODULES[@]} > 0 )); then
        log "Failed modules: ${FAILED_MODULES[*]}"
        failed=1
    fi
    return "$failed"
}

wazuh_stack() {
    local lock_file="/run/lock/soc-detection-lab-provision.lock"
    exec 9>"$lock_file"
    flock -n 9 || {
        log "Provisioning is already running."
        return 1
    }

    run_module install_base_dependencies
    run_module configure_host
    run_module install_wazuh
    run_module install_suricata
    run_module install_zeek
    run_module install_velociraptor
    run_module sync_detection_content
    final_healthcheck
}

main() {
    local mode="${1:-wazuh_stack}"
    case "$mode" in
        main|wazuh_stack)
            wazuh_stack
            ;;
        wazuh_only)
            install_base_dependencies
            install_wazuh
            ;;
        suricata_only)
            install_base_dependencies
            install_suricata
            ;;
        zeek_only)
            install_base_dependencies
            install_zeek
            ;;
        velociraptor_only)
            install_base_dependencies
            install_velociraptor
            ;;
        *)
            log "Unsupported mode: $mode"
            return 2
            ;;
    esac
}

main "$@"
