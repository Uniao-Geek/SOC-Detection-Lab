"""Generate a deterministic, non-routable HTTP PCAP for detection training."""

from __future__ import annotations

import argparse
import ipaddress
import struct
import time
from pathlib import Path


def checksum(data: bytes) -> int:
    if len(data) % 2:
        data += b"\x00"
    total = sum(struct.unpack(f"!{len(data) // 2}H", data))
    total = (total >> 16) + (total & 0xFFFF)
    total += total >> 16
    return (~total) & 0xFFFF


def build_packet(
    source_ip: str,
    destination_ip: str,
    source_port: int,
    destination_port: int,
    sequence: int,
    acknowledgement: int,
    flags: int,
    payload: bytes = b"",
) -> bytes:
    source = ipaddress.ip_address(source_ip).packed
    destination = ipaddress.ip_address(destination_ip).packed
    ethernet = bytes.fromhex("0200000000020200000000010800")

    tcp_without_checksum = struct.pack(
        "!HHLLBBHHH",
        source_port,
        destination_port,
        sequence,
        acknowledgement,
        5 << 4,
        flags,
        64240,
        0,
        0,
    )
    pseudo_header = source + destination + struct.pack("!BBH", 0, 6, len(tcp_without_checksum) + len(payload))
    tcp_checksum = checksum(pseudo_header + tcp_without_checksum + payload)
    tcp = struct.pack(
        "!HHLLBBH",
        source_port,
        destination_port,
        sequence,
        acknowledgement,
        5 << 4,
        flags,
        64240,
    ) + struct.pack("!HH", tcp_checksum, 0)

    total_length = 20 + len(tcp) + len(payload)
    ip_without_checksum = struct.pack(
        "!BBHHHBBH4s4s",
        0x45,
        0,
        total_length,
        0x534F,
        0x4000,
        64,
        6,
        0,
        source,
        destination,
    )
    ip_header = ip_without_checksum[:10] + struct.pack("!H", checksum(ip_without_checksum)) + ip_without_checksum[12:]
    return ethernet + ip_header + tcp + payload


def write_pcap(path: Path) -> None:
    client_ip = "192.168.56.104"
    server_ip = "192.168.56.200"
    source_port = 49152
    destination_port = 80
    request = (
        b"GET /training/beacon HTTP/1.1\r\n"
        b"Host: training.invalid\r\n"
        b"User-Agent: SOC-LAB-C2-Beacon\r\n"
        b"Connection: close\r\n\r\n"
    )
    response = b"HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n"

    packets = [
        build_packet(client_ip, server_ip, source_port, destination_port, 1000, 0, 0x02),
        build_packet(server_ip, client_ip, destination_port, source_port, 5000, 1001, 0x12),
        build_packet(client_ip, server_ip, source_port, destination_port, 1001, 5001, 0x10),
        build_packet(client_ip, server_ip, source_port, destination_port, 1001, 5001, 0x18, request),
        build_packet(server_ip, client_ip, destination_port, source_port, 5001, 1001 + len(request), 0x18, response),
    ]

    path.parent.mkdir(parents=True, exist_ok=True)
    now = int(time.time())
    with path.open("wb") as output:
        output.write(struct.pack("<IHHIIII", 0xA1B2C3D4, 2, 4, 0, 0, 65535, 1))
        for offset, packet in enumerate(packets):
            output.write(struct.pack("<IIII", now + offset, 0, len(packet), len(packet)))
            output.write(packet)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    if arguments.output.suffix.lower() != ".pcap":
        raise ValueError("Output must use the .pcap extension.")
    write_pcap(arguments.output.resolve())


if __name__ == "__main__":
    main()
