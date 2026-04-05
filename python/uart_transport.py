from __future__ import annotations

import time
from typing import Optional

import serial

from bridge_protocol import (
    SOF,
    ResponseFrame,
    SerialTimeoutError,
    get_response_data_len,
    parse_response_frame,
    unpack_addr,
)


class UartTransport:
    def __init__(
        self,
        port: str,
        baudrate: int = 115200,
        timeout: float = 1.0,
        write_timeout: float = 1.0,
    ) -> None:
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.write_timeout = write_timeout
        self._serial: Optional[serial.Serial] = None

    def open(self) -> None:
        if self._serial is not None and self._serial.is_open:
            return
        self._serial = serial.Serial(
            port=self.port,
            baudrate=self.baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=self.timeout,
            write_timeout=self.write_timeout,
        )

    def close(self) -> None:
        if self._serial is not None:
            self._serial.close()
            self._serial = None

    def __enter__(self) -> "UartTransport":
        self.open()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.close()

    def flush_input(self) -> None:
        self._require_open().reset_input_buffer()

    def flush_output(self) -> None:
        self._require_open().reset_output_buffer()

    def write(self, data: bytes) -> None:
        ser = self._require_open()
        ser.write(data)
        ser.flush()

    def read_response_frame(
        self,
        expected_cmd: Optional[int] = None,
        expected_addr: Optional[int] = None,
        timeout: Optional[float] = None,
    ) -> ResponseFrame:
        deadline = time.monotonic() + (timeout if timeout is not None else self.timeout)
        self._read_until_sof(deadline)
        header = self._read_exact(9, deadline)
        len_field = int.from_bytes(header[0:2], byteorder="big", signed=False)
        cmd = header[2]
        addr = unpack_addr(header[3:8])
        status = header[8]
        data_len = get_response_data_len(cmd, len_field, status)
        tail = self._read_exact(data_len + 2, deadline)
        frame = bytes([SOF]) + header + tail
        return parse_response_frame(frame, expected_cmd=expected_cmd, expected_addr=expected_addr)

    def _read_until_sof(self, deadline: float) -> None:
        while True:
            chunk = self._read_with_deadline(1, deadline)
            if chunk[0] == SOF:
                return

    def _read_exact(self, size: int, deadline: float) -> bytes:
        data = bytearray()
        while len(data) < size:
            data.extend(self._read_with_deadline(size - len(data), deadline))
        return bytes(data)

    def _read_with_deadline(self, size: int, deadline: float) -> bytes:
        time_left = deadline - time.monotonic()
        if time_left <= 0:
            raise SerialTimeoutError("Timed out waiting for UART response")

        ser = self._require_open()
        old_timeout = ser.timeout
        ser.timeout = min(old_timeout if old_timeout is not None else time_left, time_left)
        try:
            chunk = ser.read(size)
        finally:
            ser.timeout = old_timeout

        if len(chunk) == 0:
            raise SerialTimeoutError("Timed out waiting for UART response")
        return chunk

    def _require_open(self) -> serial.Serial:
        if self._serial is None or not self._serial.is_open:
            raise RuntimeError("Serial port is not open")
        return self._serial
