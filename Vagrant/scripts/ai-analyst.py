#!/usr/bin/env python3
"""Produce a read-only analyst report for one training incident."""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

INCIDENT_ID = re.compile(r"^[a-f0-9]{24}$")
MAX_INCIDENT_BYTES = 262_144
MAX_RESPONSE_BYTES = 1_048_576


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(
        self,
        req: urllib.request.Request,
        fp: Any,
        code: int,
        msg: str,
        headers: Any,
        newurl: str,
    ) -> None:
        return None


def validate_endpoint(value: str) -> str:
    parsed = urllib.parse.urlparse(value)
    if parsed.username or parsed.password or not parsed.hostname:
        raise ValueError("LLM endpoint must not contain credentials.")

    if parsed.scheme == "http":
        try:
            address = ipaddress.ip_address(parsed.hostname)
        except ValueError as error:
            raise ValueError("Plain HTTP is restricted to loopback addresses.") from error
        if not address.is_loopback:
            raise ValueError("Plain HTTP is restricted to loopback addresses.")
    elif parsed.scheme == "https":
        allowed = {
            host.strip().lower()
            for host in os.environ.get("SOC_LLM_ALLOWED_HOSTS", "").split(",")
            if host.strip()
        }
        if parsed.hostname.lower() not in allowed:
            raise ValueError("HTTPS LLM host is not allowlisted.")
    else:
        raise ValueError("LLM endpoint must use HTTP loopback or allowlisted HTTPS.")

    return value


def build_prompt(incident: dict[str, Any]) -> str:
    return (
        "You are a read-only SOC training analyst. Analyze the incident JSON below. "
        "Return concise sections: summary, evidence, ATT&CK mapping, false-positive "
        "considerations, investigation steps, and reversible response recommendation. "
        "Do not claim to have executed actions and do not include commands.\n\n"
        f"{json.dumps(incident, sort_keys=True)}"
    )


def query_ollama(endpoint: str, model: str, prompt: str) -> str:
    payload = json.dumps(
        {"model": model, "prompt": prompt, "stream": False},
        separators=(",", ":"),
    ).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    opener = urllib.request.build_opener(NoRedirect)
    with opener.open(request, timeout=45) as response:
        length = response.headers.get("Content-Length")
        if length and int(length) > MAX_RESPONSE_BYTES:
            raise ValueError("LLM response is too large.")
        raw = response.read(MAX_RESPONSE_BYTES + 1)
    if len(raw) > MAX_RESPONSE_BYTES:
        raise ValueError("LLM response is too large.")
    result = json.loads(raw)
    text = result.get("response")
    if not isinstance(text, str) or not text.strip():
        raise ValueError("LLM response does not contain a report.")
    return text.strip()


def fallback_report(incident: dict[str, Any]) -> str:
    rule = incident.get("rule", {})
    return (
        "Summary: training alert awaiting analyst review.\n"
        f"Evidence: rule {rule.get('id', 'unknown')}, "
        f"agent {incident.get('agent', 'unknown')}, "
        f"source {incident.get('source_ip', 'not present')}.\n"
        "Investigation: validate source telemetry and scenario cleanup.\n"
        f"Proposed response: {incident.get('response_proposal', 'acknowledge')} "
        "after explicit operator approval."
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("incident_id")
    arguments = parser.parse_args()
    if not INCIDENT_ID.fullmatch(arguments.incident_id):
        raise ValueError("Incident ID is invalid.")

    root = Path("/var/lib/soc-detection-lab/soar/incidents").resolve()
    incident_path = (root / f"{arguments.incident_id}.json").resolve()
    if root not in incident_path.parents or not incident_path.is_file():
        raise FileNotFoundError("Incident not found.")
    if incident_path.stat().st_size > MAX_INCIDENT_BYTES:
        raise ValueError("Incident file is too large.")

    incident = json.loads(incident_path.read_text(encoding="utf-8"))
    endpoint_value = os.environ.get("SOC_LLM_ENDPOINT")
    provider = "deterministic-fallback"
    report = fallback_report(incident)
    if endpoint_value:
        endpoint = validate_endpoint(endpoint_value)
        model = os.environ.get("SOC_LLM_MODEL", "qwen3:0.6b")
        if not re.fullmatch(r"[A-Za-z0-9_.:/-]{1,128}", model):
            raise ValueError("LLM model name is invalid.")
        try:
            report = query_ollama(endpoint, model, build_prompt(incident))
            provider = f"ollama:{model}"
        except (OSError, urllib.error.URLError, ValueError, json.JSONDecodeError):
            provider = "deterministic-fallback"

    output = {
        "schema_version": 1,
        "incident_id": arguments.incident_id,
        "provider": provider,
        "read_only": True,
        "report": report,
    }
    output_path = incident_path.with_suffix(".analysis.json")
    temporary = output_path.with_suffix(".tmp")
    temporary.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    os.chmod(temporary, 0o600)
    temporary.replace(output_path)
    print(output_path)


if __name__ == "__main__":
    main()
