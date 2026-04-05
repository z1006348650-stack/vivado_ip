# UART-AXI Bridge 实现说明

## 1. 当前版本

- 协议版本：`v2.0`
- 请求/响应 `LEN`：`16 bit`，大端
- `FULL_*` 的 `LEN`：直接表示实际字节数
- 当前单帧最大 `FULL` 载荷：`1024 Byte`

这一版和旧的 `1 Byte LEN` / `LEN+1` 编码不兼容，FPGA 和上位机必须同时升级。

## 2. 帧格式摘要

### 请求帧

```text
AA | LEN_H | LEN_L | CMD | ADDR[5B] | DATA | CHK | 55
```

### 响应帧

```text
AA | LEN_H | LEN_L | CMD | ADDR[5B] | STATUS | DATA | CHK | 55
```

约定：

- `STATUS` 不计入 `LEN`
- `CHK` 为从 `SOF` 到 `DATA` 末字节的逐字节 XOR

## 3. 命令行为

| CMD | 名称 | 请求 `LEN` | 响应 `LEN` |
|-----|------|------------|------------|
| `0x01` | `LITE_WRITE` | 固定 `4` | 固定 `0` |
| `0x02` | `LITE_READ` | 固定 `4` | 成功时固定 `4` |
| `0x03` | `FULL_WRITE` | `4..1024` 且 `4` 字节对齐 | 固定 `0` |
| `0x04` | `FULL_READ` | `1..1024` | 成功时等于请求 `LEN` |

## 4. RTL 约束

- AXI 数据宽度：`32 bit`
- `FULL_WRITE`：`beats = LEN / 4`
- `FULL_READ`：`beats = ceil(LEN / 4)`
- 单个 AXI Burst 最大 `256 beats`
- 因此单帧 `FULL` 最大 `1024 Byte`

## 5. 当前源码入口

- 顶层 RTL：`src/rtl/uart_axi_bridge.v`
- 协议解析：`src/rtl/frame_parser.v`
- 主控制：`src/rtl/bridge_ctrl.v`
- 响应封包：`src/rtl/frame_builder.v`
- AXI-Full 主机：`src/rtl/axi_full_master.v`
- Python 协议栈：`python/bridge_protocol.py`

## 6. 仿真覆盖

当前 testbench 已覆盖：

- `LITE_WRITE` / `LITE_READ`
- `FULL_WRITE` / `FULL_READ`
- `FULL_READ` 非 4 字节对齐长度
- `FULL_WRITE 256B`
- `FULL_READ 256B`
- `FULL_WRITE 1024B`
- `FULL_READ 1024B`
- 地址未对齐
- 非法长度
- `FULL_READ LEN=0`
- 未知命令
- 校验错帧丢弃
- AXI-Lite 超时
- AXI-Full 超时

## 7. IP 打包说明

- 源文件以 `src/rtl` 为准
- 重新打包 IP 请执行：`prj/package_ip.tcl`
- 打包脚本已将 `M_AXI` 元数据最大 Burst 长度更新为 `256`
