from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

from bridge_client import UartAxiBridgeClient


@dataclass(frozen=True)
class BinChunk:
    offset: int
    raw_length: int
    write_data: bytes


@dataclass(frozen=True)
class TransferReport:
    file_path: str
    file_size: int
    bytes_written: int
    bytes_sent_on_wire: int
    padded_bytes: int
    chunk_count: int
    elapsed_seconds: float
    base_addr: int
    end_addr_exclusive: int
    verify_enabled: bool


def pad_to_word_boundary(data: bytes, pad_byte: int = 0xFF) -> bytes:
    if not 0 <= pad_byte <= 0xFF:
        raise ValueError("pad_byte must be in range 0..255")
    remainder = len(data) % 4
    if remainder == 0:
        return data
    return data + bytes([pad_byte]) * (4 - remainder)


def iter_bin_chunks(payload: bytes, chunk_size: int = 1024, pad_byte: int = 0xFF) -> Iterator[BinChunk]:
    if len(payload) == 0:
        raise ValueError("BIN file is empty")
    if not 4 <= chunk_size <= 1024:
        raise ValueError("chunk_size must be in range 4..1024")
    if chunk_size % 4 != 0:
        raise ValueError("chunk_size must be a multiple of 4")

    for offset in range(0, len(payload), chunk_size):
        raw_chunk = payload[offset:offset + chunk_size]
        yield BinChunk(
            offset=offset,
            raw_length=len(raw_chunk),
            write_data=pad_to_word_boundary(raw_chunk, pad_byte=pad_byte),
        )


def verify_chunk(client: UartAxiBridgeClient, addr: int, expected_data: bytes) -> None:
    readback = client.full_read(addr, len(expected_data))
    if readback != expected_data:
        raise RuntimeError(
            f"Verify failed at addr 0x{addr:010X}: "
            f"expected {expected_data.hex()}, got {readback.hex()}"
        )


def download_bin_via_axif(
    client: UartAxiBridgeClient,
    bin_path: str,
    base_addr: int,
    chunk_size: int = 1024,
    pad_byte: int = 0xFF,
    verify: bool = False,
) -> TransferReport:
    payload = Path(bin_path).read_bytes()
    started_at = time.monotonic()
    bytes_written = 0
    bytes_sent_on_wire = 0
    chunk_count = 0
    current_addr = base_addr

    for chunk in iter_bin_chunks(payload, chunk_size=chunk_size, pad_byte=pad_byte):
        client.full_write(current_addr, chunk.write_data)
        if verify:
            verify_chunk(client, current_addr, chunk.write_data)

        bytes_written += chunk.raw_length
        bytes_sent_on_wire += len(chunk.write_data)
        chunk_count += 1
        percent = bytes_written * 100.0 / len(payload)
        verify_text = " verify=on" if verify else ""
        print(
            f"[{chunk_count:04d}] addr=0x{current_addr:010X} "
            f"raw={chunk.raw_length:3d} send={len(chunk.write_data):3d} "
            f"done={bytes_written}/{len(payload)} ({percent:6.2f}%){verify_text}"
        )
        current_addr += len(chunk.write_data)

    elapsed = time.monotonic() - started_at
    return TransferReport(
        file_path=str(Path(bin_path)),
        file_size=len(payload),
        bytes_written=bytes_written,
        bytes_sent_on_wire=bytes_sent_on_wire,
        padded_bytes=bytes_sent_on_wire - len(payload),
        chunk_count=chunk_count,
        elapsed_seconds=elapsed,
        base_addr=base_addr,
        end_addr_exclusive=current_addr,
        verify_enabled=verify,
    )


def send_bin_file(
    client: UartAxiBridgeClient,
    bin_path: str,
    base_addr: int,
    chunk_size: int = 1024,
    pad_byte: int = 0xFF,
    verify: bool = False,
) -> TransferReport:
    return download_bin_via_axif(
        client=client,
        bin_path=bin_path,
        base_addr=base_addr,
        chunk_size=chunk_size,
        pad_byte=pad_byte,
        verify=verify,
    )
