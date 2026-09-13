#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${SOC_CONFIG_FILE:-/tmp/soc-detection-lab.conf}"
DESTINATION_ROOT="/opt/soc-detection-lab/content"

if [[ -n "${1:-}" ]]; then
    echo "Usage: $0" >&2
    exit 2
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$CONFIG_FILE"
set +a

sync_repository() {
    local remote="$1"
    local commit="$2"
    local destination="$3"

    if [[ ! "$remote" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.git$ ]] \
        || [[ ! "$commit" =~ ^[a-f0-9]{40}$ ]]; then
        echo "Rejected repository metadata." >&2
        return 1
    fi

    mkdir -p "$destination"
    if [[ ! -d "$destination/.git" ]]; then
        git -C "$destination" init --quiet
        git -C "$destination" remote add origin "$remote"
    fi
    git -C "$destination" fetch --quiet --depth 1 origin "$commit"
    git -C "$destination" checkout --quiet --detach "$commit"
    [[ "$(git -C "$destination" rev-parse HEAD)" == "$commit" ]]
}

mkdir -p "$DESTINATION_ROOT"
sync_repository \
    "https://github.com/SigmaHQ/sigma.git" \
    "$SIGMA_COMMIT" \
    "$DESTINATION_ROOT/sigma"

find "$DESTINATION_ROOT" -type d -name .git -prune -o -type f -exec chmod a-w {} +
echo "Detection content synchronized at pinned commits."
