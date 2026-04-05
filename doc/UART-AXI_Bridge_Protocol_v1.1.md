# UART-AXI Bridge 协议规范 v2.0

## 1. 协议概览

- 交互模式：PC 发请求帧，FPGA 返回响应帧，一问一答，按顺序处理
- 物理链路：UART，默认 `115200-8N1`
- 地址宽度：`40 bit`
- 字节序：
  - `LEN`：`2 Byte`，大端
  - `ADDR`：`5 Byte`，大端
  - `DATA`：按 AXI 访问字节流原样传输；当前实现的 32 位字内部仍按低字节先传
- 坏帧处理：`SOF/EOF/CHK` 错误时直接丢帧，不返回响应
- 并发模型：单事务串行处理，上一帧响应完成后再接收下一帧

本版本为协议不兼容升级：

- `LEN` 从 `1 Byte` 扩展到 `2 Byte`
- `FULL_*` 命令的 `LEN` 改为“实际字节数”，不再使用旧版本的 `LEN+1` 编码
- 当前 RTL 实现保持“单个 UART 帧对应单个 AXI Burst”，因此 `FULL_WRITE` / `FULL_READ` 的单帧最大值为 `1024 Byte`

## 2. 帧格式

### 2.1 请求帧（PC -> FPGA）

```text
SOF | LEN[15:8] | LEN[7:0] | CMD | ADDR[5B] | DATA | CHK | EOF
 1B |    1B     |    1B    | 1B  |   5B     | 变长 | 1B  | 1B
```

### 2.2 响应帧（FPGA -> PC）

```text
SOF | LEN[15:8] | LEN[7:0] | CMD | ADDR[5B] | STATUS | DATA | CHK | EOF
 1B |    1B     |    1B    | 1B  |   5B     |   1B   | 变长 | 1B  | 1B
```

说明：

- `STATUS` 只存在于响应帧
- `LEN` 只描述 `DATA` 的字节数，不包含 `STATUS`
- 写成功、写失败、读失败响应都使用 `LEN=0`

## 3. 字段定义

| 字段 | 宽度 | 说明 |
|------|------|------|
| `SOF` | 1B | 固定 `0xAA` |
| `LEN` | 2B | `DATA` 的实际字节数，大端 |
| `CMD` | 1B | 命令码，响应帧原样回传 |
| `ADDR` | 5B | `40 bit` 地址，大端 |
| `STATUS` | 1B | 仅响应帧存在，表示执行结果 |
| `DATA` | 变长 | 写数据或读回数据 |
| `CHK` | 1B | 从 `SOF` 到 `DATA` 末字节的逐字节 XOR |
| `EOF` | 1B | 固定 `0x55` |

## 4. 命令定义

| CMD | 名称 | 请求 `LEN` | 请求 `DATA` | 响应 `LEN` | AXI 类型 |
|-----|------|------------|-------------|------------|----------|
| `0x01` | `LITE_WRITE` | 固定 `4` | 4B | 固定 `0` | AXI-Lite 单次写 |
| `0x02` | `LITE_READ` | 固定 `4` | 无 | 成功时固定 `4`，失败时 `0` | AXI-Lite 单次读 |
| `0x03` | `FULL_WRITE` | `4..1024`，且为 `4` 的倍数 | `LEN` 字节 | 固定 `0` | AXI-Full Burst 写 |
| `0x04` | `FULL_READ` | `1..1024` | 无 | 成功时等于请求 `LEN`，失败时 `0` | AXI-Full Burst 读 |

补充：

- `LITE_*` 命令保留固定 `32 bit` 访问语义，因此请求 `LEN` 固定为 `4`
- `FULL_READ` 允许非 `4` 字节对齐的读长度，FPGA 内部会按 `ceil(LEN/4)` 发起 AXI Burst，再裁掉多余字节

## 5. STATUS 定义

| 值 | 名称 | 含义 |
|----|------|------|
| `0x00` | `SUCCESS` | 操作成功 |
| `0x01` | `ALIGN_ERR` | 地址未按 `4 Byte` 对齐 |
| `0x02` | `AXI_ERR` | AXI 从机返回错误或 AXI 访问超时 |
| `0x03` | `LEN_ERR` | `LEN` 不合法 |
| `0x04` | `CMD_ERR` | 未知命令 |

## 6. 合法性检查

| CMD | 地址检查 | 长度检查 |
|-----|----------|----------|
| `LITE_WRITE` | `ADDR[1:0] == 0` | `LEN == 4` |
| `LITE_READ` | `ADDR[1:0] == 0` | `LEN == 4` |
| `FULL_WRITE` | `ADDR[1:0] == 0` | `4 <= LEN <= 1024` 且 `LEN % 4 == 0` |
| `FULL_READ` | `ADDR[1:0] == 0` | `1 <= LEN <= 1024` |

错误优先级：

```text
CMD_ERR > ALIGN_ERR > LEN_ERR
```

## 7. FULL 命令与 AXI Burst 映射

- `FULL_WRITE`：`beats = LEN / 4`
- `FULL_READ`：`beats = ceil(LEN / 4)`
- 当前实现约束：
  - AXI 数据宽度固定 `32 bit`
  - 单次 AXI Burst 最大 `256 beats`
  - 因此单帧 `FULL_WRITE` / `FULL_READ` 最大都是 `1024 Byte`

## 8. CHK 计算

- 请求帧：

```text
CHK = SOF ^ LEN_H ^ LEN_L ^ CMD ^ ADDR[0] ^ ADDR[1] ^ ADDR[2] ^ ADDR[3] ^ ADDR[4] ^ DATA[...]
```

- 响应帧：

```text
CHK = SOF ^ LEN_H ^ LEN_L ^ CMD ^ ADDR[0] ^ ADDR[1] ^ ADDR[2] ^ ADDR[3] ^ ADDR[4] ^ STATUS ^ DATA[...]
```

## 9. 典型帧示例

### 9.1 LITE_WRITE，向 `0xA0` 写入 `0x12345678`

请求：

```text
AA 00 04 01 00 00 00 00 A0 78 56 34 12 07 55
```

响应：

```text
AA 00 00 01 00 00 00 00 A0 00 0B 55
```

### 9.2 LITE_READ，读取 `0xA0`

请求：

```text
AA 00 04 02 00 00 00 00 A0 0C 55
```

响应：

```text
AA 00 04 02 00 00 00 00 A0 00 78 56 34 12 04 55
```

### 9.3 FULL_WRITE，向 `0x100` 写入 `16B`

请求：

```text
AA 00 10 03 00 00 00 01 00 A3 A2 A1 A0 B3 B2 B1 B0 C3 C2 C1 C0 D3 D2 D1 D0 B8 55
```

响应：

```text
AA 00 00 03 00 00 00 01 00 00 A8 55
```

### 9.4 FULL_READ，从 `0x100` 读取 `8B`

请求：

```text
AA 00 08 04 00 00 00 01 00 A7 55
```

响应：

```text
AA 00 08 04 00 00 00 01 00 00 A3 A2 A1 A0 B3 B2 B1 B0 A7 55
```

### 9.5 FULL_READ，从 `0x200` 读取 `5B`

请求：

```text
AA 00 05 04 00 00 00 02 00 A9 55
```

响应：

```text
AA 00 05 04 00 00 00 02 00 00 EF BE AD DE 78 F3 55
```

### 9.6 FULL_READ，读取 `1024B`

- 请求 `LEN = 0x0400`
- AXI Burst `beats = 256`
- 成功响应时，响应头中的 `LEN` 也为 `0x0400`

请求头如下：

```text
AA 04 00 04 00 00 00 03 00 A9 55
```

## 10. 实现约束建议

- 时钟统一使用系统主时钟，不在逻辑中派生新时钟
- 复位采用异步输入、同步释放
- AXI-Lite 固定为单次 `32 bit` 访问
- AXI-Full 固定 `32 bit` 数据宽度，`BURST=INCR`
- 建议保留 AXI 超时计数器，并统一映射为 `STATUS_AXI_ERR`

版本：`v2.0`

最后更新：`2026-04-04`
