from __future__ import annotations

import argparse
import sys

from bin_sender import download_bin_via_axif
from bridge_client import UartAxiBridgeClient
from bridge_protocol import BridgeError
from uart_transport import UartTransport


def parse_int(text: str) -> int:
    return int(text, 0)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Dedicated AXI-Full Xilinx .bin downloader for the UART-AXI bridge"
    )
    parser.add_argument("--port", required=True, help="Serial port, for example COM3")
    parser.add_argument("--baudrate", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument("--write-timeout", type=float, default=1.0)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--retry-delay", type=float, default=0.05)
    parser.add_argument("file", help="Path to Xilinx .bin file")
    parser.add_argument("base_addr", type=parse_int, help="Start AXI address")
    parser.add_argument("--chunk-size", type=int, default=1024, help="Bytes per FULL_WRITE frame")
    parser.add_argument("--pad-byte", type=parse_int, default=0xFF, help="Pad byte for the last partial word")
    parser.add_argument("--verify", action="store_true", help="Verify each written chunk through FULL_READ")
    return parser


def main() -> int:
    args = build_parser().parse_args()

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
            report = download_bin_via_axif(
                client=client,
                bin_path=args.file,
                base_addr=args.base_addr,
                chunk_size=args.chunk_size,
                pad_byte=args.pad_byte,
                verify=args.verify,
            )
            rate_kib = (report.bytes_sent_on_wire / 1024.0) / report.elapsed_seconds if report.elapsed_seconds > 0 else 0.0
            print(
                "AXIF_BIN_DOWNLOAD OK: "
                f"file_size={report.file_size} bytes, "
                f"wire_bytes={report.bytes_sent_on_wire}, "
                f"pad_bytes={report.padded_bytes}, "
                f"chunks={report.chunk_count}, "
                f"addr_range=0x{report.base_addr:010X}-0x{report.end_addr_exclusive:010X}, "
                f"verify={'on' if report.verify_enabled else 'off'}, "
                f"elapsed={report.elapsed_seconds:.3f}s, "
                f"rate={rate_kib:.2f} KiB/s"
            )
            return 0
    except BridgeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"OS ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
