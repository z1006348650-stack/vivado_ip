from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Optional

SOF = 0xAA
EOF = 0x55
ADDR_WIDTH_BITS = 40
ADDR_WIDTH_BYTES = 5
LEN_FIELD_BYTES = 2
MAX_ADDR = (1 << ADDR_WIDTH_BITS) - 1
MAX_LEN_FIELD = (1 << (LEN_FIELD_BYTES * 8)) - 1
MAX_FULL_DATA_BYTES = 1024

CMD_LITE_WRITE = 0x01
CMD_LITE_READ = 0x02
CMD_FULL_WRITE = 0x03
CMD_FULL_READ = 0x04

STATUS_SUCCESS = 0x00
STATUS_ALIGN_ERR = 0x01
STATUS_AXI_ERR = 0x02
STATUS_LEN_ERR = 0x03
STATUS_CMD_ERR = 0x04

STATUS_NAMES = {
    STATUS_SUCCESS: "SUCCESS",
    STATUS_ALIGN_ERR: "ALIGN_ERR",
    STATUS_AXI_ERR: "AXI_ERR",
    STATUS_LEN_ERR: "LEN_ERR",
    STATUS_CMD_ERR: "CMD_ERR",
}


class BridgeError(Exception):
    pass


class ProtocolError(BridgeError):
    pass


class FrameFormatError(ProtocolError):
    pass


class ChecksumError(ProtocolError):
    pass


class ResponseMismatchError(ProtocolError):
    pass


class SerialTimeoutError(BridgeError):
    pass


class StatusError(BridgeError):
    def __init__(self, status: int, response: "ResponseFrame") -> None:
        self.status = status
        self.response = response
        message = STATUS_NAMES.get(status, f"UNKNOWN_STATUS_0x{status:02X}")
        super().__init__(f"Device returned status {message} (0x{status:02X})")


@dataclass(frozen=True)
class ResponseFrame:
    len_field: int
    cmd: int
    addr: int
    status: int
    data: bytes
    raw_frame: bytes

    @property
    def status_name(self) -> str:
        return STATUS_NAMES.get(self.status, f"0x{self.status:02X}")


def status_name(status: int) -> str:
    return STATUS_NAMES.get(status, f"0x{status:02X}")


def calc_chk(byte_values: Iterable[int]) -> int:
    chk = 0
    for value in byte_values:
        chk ^= value & 0xFF
    return chk


def validate_len_field(len_field: int) -> None:
    if not 0 <= len_field <= MAX_LEN_FIELD:
        raise ValueError(f"LEN field must be in range 0..{MAX_LEN_FIELD}")


def pack_addr(addr: int) -> bytes:
    if not 0 <= addr <= MAX_ADDR:
        raise ValueError(f"ADDR out of range: 0x{addr:X}")
    return addr.to_bytes(ADDR_WIDTH_BYTES, byteorder="big", signed=False)


def unpack_addr(raw_addr: bytes) -> int:
    if len(raw_addr) != ADDR_WIDTH_BYTES:
        raise ValueError("ADDR must be exactly 5 bytes")
    return int.from_bytes(raw_addr, byteorder="big", signed=False)


def get_request_data_len(cmd: int, len_field: int) -> int:
    validate_len_field(len_field)
    if cmd == CMD_LITE_WRITE:
        return len_field
    if cmd == CMD_LITE_READ:
        return 0
    if cmd == CMD_FULL_WRITE:
        return len_field
    if cmd == CMD_FULL_READ:
        return 0
    return 0


def get_response_data_len(cmd: int, len_field: int, status: int) -> int:
    validate_len_field(len_field)
    if status != STATUS_SUCCESS:
        return 0
    if cmd == CMD_LITE_READ:
        return len_field
    if cmd == CMD_FULL_READ:
        return len_field
    return 0


def build_request_frame(cmd: int, addr: int, len_field: int, data: bytes = b"") -> bytes:
    validate_len_field(len_field)
    expected_len = get_request_data_len(cmd, len_field)
    if len(data) != expected_len:
        raise ValueError(
            f"Request data length mismatch for cmd 0x{cmd:02X}: "
            f"expected {expected_len}, got {len(data)}"
        )

    frame_wo_chk = (
        bytes([SOF])
        + len_field.to_bytes(LEN_FIELD_BYTES, byteorder="big", signed=False)
        + bytes([cmd])
        + pack_addr(addr)
        + data
    )
    chk = calc_chk(frame_wo_chk)
    return frame_wo_chk + bytes([chk, EOF])


def build_lite_write_frame(addr: int, value: int) -> bytes:
    if not 0 <= value <= 0xFFFF_FFFF:
        raise ValueError("LITE write value must fit in 32 bits")
    data = value.to_bytes(4, byteorder="little", signed=False)
    return build_request_frame(CMD_LITE_WRITE, addr, 4, data)


def build_lite_read_frame(addr: int) -> bytes:
    return build_request_frame(CMD_LITE_READ, addr, 4, b"")


def build_full_write_frame(addr: int, data: bytes) -> bytes:
    if len(data) < 4:
        raise ValueError("FULL write data must be at least 4 bytes")
    if len(data) % 4 != 0:
        raise ValueError("FULL write data length must be a multiple of 4 bytes")
    if len(data) > MAX_FULL_DATA_BYTES:
        raise ValueError(f"FULL write data must not exceed {MAX_FULL_DATA_BYTES} bytes")
    return build_request_frame(CMD_FULL_WRITE, addr, len(data), data)


def build_full_read_frame(addr: int, size: int) -> bytes:
    if not 1 <= size <= MAX_FULL_DATA_BYTES:
        raise ValueError(f"FULL read size must be in range 1..{MAX_FULL_DATA_BYTES}")
    return build_request_frame(CMD_FULL_READ, addr, size, b"")


def parse_response_frame(
    frame: bytes,
    expected_cmd: Optional[int] = None,
    expected_addr: Optional[int] = None,
) -> ResponseFrame:
    if len(frame) < 12:
        raise FrameFormatError("Response frame too short")
    if frame[0] != SOF:
        raise FrameFormatError(f"Invalid SOF: 0x{frame[0]:02X}")
    if frame[-1] != EOF:
        raise FrameFormatError(f"Invalid EOF: 0x{frame[-1]:02X}")

    len_field = int.from_bytes(frame[1:3], byteorder="big", signed=False)
    cmd = frame[3]
    addr = unpack_addr(frame[4:9])
    status = frame[9]
    data_len = get_response_data_len(cmd, len_field, status)
    expected_frame_len = 12 + data_len
    if len(frame) != expected_frame_len:
        raise FrameFormatError(
            f"Response length mismatch: expected {expected_frame_len}, got {len(frame)}"
        )

    data = frame[10:10 + data_len]
    chk = frame[-2]
    expected_chk = calc_chk(frame[:-2])
    if chk != expected_chk:
        raise ChecksumError(
            f"Response CHK mismatch: expected 0x{expected_chk:02X}, got 0x{chk:02X}"
        )

    if expected_cmd is not None and cmd != expected_cmd:
        raise ResponseMismatchError(
            f"Response CMD mismatch: expected 0x{expected_cmd:02X}, got 0x{cmd:02X}"
        )

    if expected_addr is not None and addr != expected_addr:
        raise ResponseMismatchError(
            f"Response ADDR mismatch: expected 0x{expected_addr:010X}, got 0x{addr:010X}"
        )

    return ResponseFrame(
        len_field=len_field,
        cmd=cmd,
        addr=addr,
        status=status,
        data=data,
        raw_frame=frame,
    )
