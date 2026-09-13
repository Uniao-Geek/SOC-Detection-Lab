#!/usr/bin/env python3
"""Create approval-gated training incidents from Wazuh JSON alerts."""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import logging
import os
import signal
import time
from pathlib import Path
from typing import Any

ALLOWED_RULE_IDS = {"110001", "110010"}
PROTECTED_ADDRESSES = {
    ipaddress.ip_address("192.168.56.1"),
    ipaddress.ip_address("192.168.56.105"),
}
MAX_LINE_BYTES = 1_048_576


class Bridge:
    def __init__(self, alerts_path: Path, state_root: Path) -> None:
        self.alerts_path = alerts_path
        self.state_root = state_root
        self.incidents = state_root / "incidents"
        self.pending = state_root / "pending"
        self.offset_path = state_root / "offset"
        self.running = True
        for directory in (state_root, self.incidents, self.pending):
            directory.mkdir(parents=True, exist_ok=True)
            directory.chmod(0o750)

    def stop(self, *_: object) -> None:
        self.running = False

    def read_offset(self) -> int:
        try:
            value = int(self.offset_path.read_text(encoding="ascii"))
            return max(value, 0)
        except (FileNotFoundError, ValueError):
            return 0

    def write_offset(self, value: int) -> None:
        temporary = self.offset_path.with_suffix(".tmp")
        temporary.write_text(str(value), encoding="ascii")
        os.chmod(temporary, 0o600)
        temporary.replace(self.offset_path)

    @staticmethod
    def extract_source_ip(alert: dict[str, Any]) -> str | None:
        data = alert.get("data")
        if not isinstance(data, dict):
            return None
        for key in ("srcip", "src_ip", "source_ip"):
            candidate = data.get(key)
            if not isinstance(candidate, str):
                continue
            try:
                address = ipaddress.ip_address(candidate)
            except ValueError:
                continue
            if (
                address.version == 4
                and address in ipaddress.ip_network("192.168.56.0/24")
                and address not in PROTECTED_ADDRESSES
            ):
                return str(address)
        return None

    def process_alert(self, alert: dict[str, Any]) -> None:
        rule = alert.get("rule")
        if not isinstance(rule, dict) or str(rule.get("id")) not in ALLOWED_RULE_IDS:
            return

        identity = json.dumps(
            {
                "id": rule.get("id"),
                "timestamp": alert.get("timestamp"),
                "agent": alert.get("agent"),
                "data": alert.get("data"),
            },
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        incident_id = hashlib.sha256(identity).hexdigest()[:24]
        source_ip = self.extract_source_ip(alert)
        action = {
            "schema_version": 1,
            "incident_id": incident_id,
            "status": "pending_approval",
            "action": "block-lab-ip" if source_ip else "acknowledge",
            "source_ip": source_ip,
            "expires_seconds": 300 if source_ip else 0,
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        incident = {
            "schema_version": 1,
            "id": incident_id,
            "status": "new",
            "rule": {
                "id": str(rule.get("id")),
                "level": rule.get("level"),
                "description": rule.get("description"),
            },
            "agent": alert.get("agent"),
            "timestamp": alert.get("timestamp"),
            "source_ip": source_ip,
            "response_proposal": action["action"],
        }
        self.write_json(self.incidents / f"{incident_id}.json", incident)
        self.write_json(self.pending / f"{incident_id}.json", action)
        logging.info("Created training incident %s", incident_id)

    @staticmethod
    def write_json(path: Path, value: dict[str, Any]) -> None:
        temporary = path.with_suffix(".tmp")
        temporary.write_text(
            json.dumps(value, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        os.chmod(temporary, 0o600)
        temporary.replace(path)

    def run_once(self) -> None:
        if not self.alerts_path.exists():
            return
        file_size = self.alerts_path.stat().st_size
        offset = self.read_offset()
        if offset > file_size:
            offset = 0
        with self.alerts_path.open("rb") as alerts:
            alerts.seek(offset)
            while line := alerts.readline(MAX_LINE_BYTES + 1):
                if len(line) > MAX_LINE_BYTES:
                    logging.warning("Skipped oversized Wazuh alert line")
                    continue
                try:
                    alert = json.loads(line)
                except (UnicodeDecodeError, json.JSONDecodeError):
                    logging.warning("Skipped malformed Wazuh alert")
                    continue
                if isinstance(alert, dict):
                    self.process_alert(alert)
            self.write_offset(alerts.tell())

    def run(self) -> None:
        while self.running:
            self.run_once()
            time.sleep(2)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    parser.add_argument(
        "--alerts",
        type=Path,
        default=Path("/var/ossec/logs/alerts/alerts.json"),
    )
    parser.add_argument(
        "--state-root",
        type=Path,
        default=Path("/var/lib/soc-detection-lab/soar"),
    )
    arguments = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    bridge = Bridge(arguments.alerts, arguments.state_root)
    signal.signal(signal.SIGTERM, bridge.stop)
    signal.signal(signal.SIGINT, bridge.stop)
    if arguments.once:
        bridge.run_once()
    else:
        bridge.run()


if __name__ == "__main__":
    main()
