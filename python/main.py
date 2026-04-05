from __future__ import annotations

import argparse
import sys
from pathlib import Path

from bin_sender import download_bin_via_axif
from bridge_client import UartAxiBridgeClient
from bridge_protocol import BridgeError
from uart_transport import UartTransport


def parse_int(text: str) -> int:
    return int(text, 0)


def parse_hex_bytes(text: str) -> bytes:
    normalized = text.strip().replace(" ", "").replace("_", "").replace(",", "")
    if normalized.startswith("0x") or normalized.startswith("0X"):
        normalized = normalized[2:]
    if len(normalized) == 0:
        return b""
    if len(normalized) % 2 != 0:
        raise argparse.ArgumentTypeError("hex byte string must contain an even number of hex digits")
    try:
        return bytes.fromhex(normalized)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc


def add_download_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("file", help="Path to .bin file")
    parser.add_argument("base_addr", type=parse_int, help="Start AXI address")
    parser.add_argument("--chunk-size", type=int, default=1024, help="Bytes per FULL_WRITE frame, default 1024")
    parser.add_argument("--pad-byte", type=parse_int, default=0xFF, help="Pad byte for the last partial word, default 0xFF")
    parser.add_argument("--verify", action="store_true", help="Read back each chunk through FULL_READ and compare")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="UART-AXI Bridge CLI")
    parser.add_argument("--port", required=True, help="Serial port, for example COM3")
    parser.add_argument("--baudrate", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=1.0, help="Transaction timeout in seconds")
    parser.add_argument("--write-timeout", type=float, default=1.0)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--retry-delay", type=float, default=0.05)

    subparsers = parser.add_subparsers(dest="command", required=True)

    lite_read = subparsers.add_parser("lite-read", help="Read one 32-bit AXI-Lite register")
    lite_read.add_argument("addr", type=parse_int)

    lite_write = subparsers.add_parser("lite-write", help="Write one 32-bit AXI-Lite register")
    lite_write.add_argument("addr", type=parse_int)
    lite_write.add_argument("value", type=parse_int)

    full_read = subparsers.add_parser("full-read", help="Read bytes through AXI-Full")
    full_read.add_argument("addr", type=parse_int)
    full_read.add_argument("size", type=int)
    full_read.add_argument("--out", help="Optional output file path")

    full_write = subparsers.add_parser("full-write", help="Write bytes through AXI-Full")
    full_write.add_argument("addr", type=parse_int)
    group = full_write.add_mutually_exclusive_group(required=True)
    group.add_argument("--hex", dest="hex_data", type=parse_hex_bytes)
    group.add_argument("--file", dest="file_path")

    send_bin = subparsers.add_parser(
        "send-bin",
        help="Download a Xilinx .bin file through AXI-Full FULL_WRITE frames",
    )
    add_download_args(send_bin)

    download_bin = subparsers.add_parser(
        "download-bin",
        help="Alias of send-bin, dedicated AXI-Full bin download command",
    )
    add_download_args(download_bin)

    return parser


def print_download_report(report) -> None:
    rate_kib = (report.bytes_sent_on_wire / 1024.0) / report.elapsed_seconds if report.elapsed_seconds > 0 else 0.0
    print(
        "DOWNLOAD_BIN OK: "
        f"file_size={report.file_size} bytes, "
        f"wire_bytes={report.bytes_sent_on_wire}, "
        f"pad_bytes={report.padded_bytes}, "
        f"chunks={report.chunk_count}, "
        f"addr_range=0x{report.base_addr:010X}-0x{report.end_addr_exclusive:010X}, "
        f"verify={'on' if report.verify_enabled else 'off'}, "
        f"elapsed={report.elapsed_seconds:.3f}s, "
        f"rate={rate_kib:.2f} KiB/s"
    )


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    transport = UartTransport(
        port=args.port,
        baudrate=args.baudrate,
        timeout=args.timeout,
        write_timeout=args.write_timeout,
    )

    try:
        with transport:
            client = UartAxiBridgeClient(
                transport=transport,
                retries=args.retries,
                retry_delay=args.retry_delay,
                transaction_timeout=args.timeout,
            )

            if args.command == "lite-read":
                value = client.lite_read(args.addr)
                print(f"0x{value:08X}")
                return 0

            if args.command == "lite-write":
                client.lite_write(args.addr, args.value)
                print(f"LITE_WRITE OK: addr=0x{args.addr:010X} value=0x{args.value:08X}")
                return 0

            if args.command == "full-read":
                data = client.full_read(args.addr, args.size)
                if args.out:
                    Path(args.out).write_bytes(data)
                    print(f"FULL_READ OK: {len(data)} bytes saved to {args.out}")
                else:
                    print(data.hex())
                return 0

            if args.command == "full-write":
                if args.hex_data is not None:
                    data = args.hex_data
                else:
                    data = Path(args.file_path).read_bytes()
                client.full_write(args.addr, data)
                print(f"FULL_WRITE OK: addr=0x{args.addr:010X} bytes={len(data)}")
                return 0

            if args.command in {"send-bin", "download-bin"}:
                report = download_bin_via_axif(
                    client=client,
                    bin_path=args.file,
                    base_addr=args.base_addr,
                    chunk_size=args.chunk_size,
                    pad_byte=args.pad_byte,
                    verify=args.verify,
                )
                print_download_report(report)
                return 0

            parser.error(f"Unknown command: {args.command}")
            return 2

    except BridgeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"OS ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
