from __future__ import annotations

import time
from typing import Optional

from bridge_protocol import (
    CMD_FULL_READ,
    CMD_FULL_WRITE,
    CMD_LITE_READ,
    CMD_LITE_WRITE,
    STATUS_SUCCESS,
    BridgeError,
    ProtocolError,
    ResponseFrame,
    SerialTimeoutError,
    StatusError,
    build_full_read_frame,
    build_full_write_frame,
    build_lite_read_frame,
    build_lite_write_frame,
)
from uart_transport import UartTransport


class UartAxiBridgeClient:
    def __init__(
        self,
        transport: UartTransport,
        retries: int = 3,
        retry_delay: float = 0.05,
        transaction_timeout: Optional[float] = None,
    ) -> None:
        self.transport = transport
        self.retries = retries
        self.retry_delay = retry_delay
        self.transaction_timeout = transaction_timeout

    def lite_write(self, addr: int, value: int) -> ResponseFrame:
        frame = build_lite_write_frame(addr, value)
        return self.transact(frame, expected_cmd=CMD_LITE_WRITE, expected_addr=addr)

    def lite_read(self, addr: int) -> int:
        frame = build_lite_read_frame(addr)
        response = self.transact(frame, expected_cmd=CMD_LITE_READ, expected_addr=addr)
        if len(response.data) != 4:
            raise ProtocolError(f"LITE_READ response must contain 4 bytes, got {len(response.data)}")
        return int.from_bytes(response.data, byteorder="little", signed=False)

    def full_write(self, addr: int, data: bytes) -> ResponseFrame:
        frame = build_full_write_frame(addr, data)
        return self.transact(frame, expected_cmd=CMD_FULL_WRITE, expected_addr=addr)

    def full_read(self, addr: int, size: int) -> bytes:
        frame = build_full_read_frame(addr, size)
        response = self.transact(frame, expected_cmd=CMD_FULL_READ, expected_addr=addr)
        if len(response.data) != size:
            raise ProtocolError(
                f"FULL_READ response length mismatch: expected {size}, got {len(response.data)}"
            )
        return response.data

    def transact(self, frame: bytes, expected_cmd: int, expected_addr: int) -> ResponseFrame:
        last_error: Optional[BridgeError] = None
        attempts = self.retries + 1

        for attempt in range(attempts):
            self.transport.flush_input()
            self.transport.write(frame)
            try:
                response = self.transport.read_response_frame(
                    expected_cmd=expected_cmd,
                    expected_addr=expected_addr,
                    timeout=self.transaction_timeout,
                )
            except (SerialTimeoutError, ProtocolError) as exc:
                last_error = exc
                if attempt == attempts - 1:
                    break
                time.sleep(self.retry_delay)
                continue

            if response.status != STATUS_SUCCESS:
                raise StatusError(response.status, response)
            return response

        if last_error is None:
            raise RuntimeError("Transaction failed without a captured error")
        raise last_error