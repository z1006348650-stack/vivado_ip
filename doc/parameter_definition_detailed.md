# axi_multiboot_driver 参数说明（详细版，x1/x4）

> 适用代码版本：`axi_multiboot_driver_v1_0.v`
>
> 重点场景：7 Series / UltraScale + `S25FL256S` / `MT25QL256` / `N25Q128A`，支持 `SPI_BUS_WIDTH=1/4`。

## 1. 顶层参数总览

| 参数名 | 默认值 | 单位/类型 | 作用 | 主要影响模块 |
|---|---:|---|---|---|
| `C_S00_AXI_DATA_WIDTH` | `32` | bit | AXI-Lite 数据位宽 | `axi_multiboot_driver_v1_0_S00_AXI` |
| `C_S00_AXI_ADDR_WIDTH` | `5` | bit | AXI-Lite 地址位宽 | `axi_multiboot_driver_v1_0_S00_AXI` |
| `SYS_CLK_FREQ` | `100000000` | Hz | 系统主时钟频率 | `flash_driver` 分频计数 |
| `FLASH_CLK_FREQ` | `10000000` | Hz | SPI SCK 目标频率 | `flash_driver` |
| `RD_DATA_MAX_LEN` | `4` | Byte/拍 | 单次读传输数据宽度 | `flash_ctrl/flash_driver` |
| `WR_DATA_MAX_LEN` | `4` | Byte/拍 | 单次写传输数据宽度 | `flash_ctrl/flash_driver`、AXIS FIFO 规格 |
| `FLASH_ADDR_WIDTH` | `32` | bit | Flash 地址总线宽度 | `flash_top/flash_ctrl/flash_driver/icap_jump` |
| `UPDATE_BASE_ADDR` | `0x00500000` | 地址 | 驱动寄存器默认升级地址 | `axi_multiboot_driver_v1_0_S00_AXI` |
| `DEVICE_ID` | `0x03651093` | 32-bit | ICAP 原语 DEVICE_ID | `icap_jump` |
| `FPGA_FAMILY` | `0` | 枚举 | 选择 7 系列或 UltraScale 原语 | `icap_jump/startup_bridge` |
| `MULTIBOOT_ADDR_SHIFT` | `0` | bit数 | `I_update_addr` 写入 WBSTAR 前右移位数 | `icap_jump` |
| `USE_STARTUP_FLASH_IO` | `0` | 0/1 | UltraScale 下是否通过 STARTUPE3 走配置专用引脚访问 Flash | `startup_bridge` + 顶层 MISO 选择 |
| `FLASH_MODEL` | `0` | 枚举 | 选择 S25 / MT25 / N25Q 的命令集、地址宽度和状态位策略 | `flash_ctrl/flash_driver` |
| `SPI_BUS_WIDTH` | `1` | 枚举 | 选择 Flash 数据相位按 x1 还是 x4 传输 | `flash_top/flash_ctrl/flash_driver` |
| `S25_TBPARM_TOP` | `0` | 0/1 | S25 Hybrid 参数区位置（底部/顶部） | `flash_ctrl` |
| `ERASE_TIMEOUT_4K_CYCLES` | `200000000` | clk cycles | 4KB 擦除轮询超时阈值 | `flash_ctrl` |
| `ERASE_TIMEOUT_64K_CYCLES` | `300000000` | clk cycles | 64KB 擦除轮询超时阈值 | `flash_ctrl` |
| `POST_ERASE_STATUS_GUARD_CYCLES` | `10` | clk cycles | 擦除状态读回后的保护等待拍数 | `flash_ctrl` |

## 2. 枚举参数取值定义

- `FPGA_FAMILY`
  - `0`: 7 Series（`ICAPE2` + `STARTUPE2`）
  - `1`: UltraScale/UltraScale+（`ICAPE3` + `STARTUPE3`）

- `FLASH_MODEL`
  - `0`: `S25FL256S` 系列（含 `S25FL256SAIF00`）
  - `1`: `MT25QL256`
  - `2`: `N25Q128A`

- `SPI_BUS_WIDTH`
  - `1`: 标准 SPI，命令/地址/状态/读写数据全部走 x1。
  - `4`: 命令/地址/状态仍走 x1，读写数据相位走 x4（`DQ[3:0]` 并行传输）。
  - 这属于真实 QSPI x4 数据模式，不是“名义 x4、实际仍按 x1 发数据”。
  - 这也不是 QPI；当前设计没有把命令和地址阶段切成 4-bit。

- `S25_TBPARM_TOP`（仅 `FLASH_MODEL=0` 有效）
  - `0`: 参数区在底部（`0x00000000 ~ 0x0001FFFF`，32 x 4KB）
  - `1`: 参数区在顶部（`0x01FE0000 ~ 0x01FFFFFF`，32 x 4KB）

## 3. `SPI_BUS_WIDTH=4` 的实际含义（真 x4，不是 QPI）

- 当前 RTL 在 `SPI_BUS_WIDTH=4` 时，会切换到 Quad Read/Quad Program 命令：
  - `S25FL256S` / `MT25QL`：`4QOR=0x6C`，`4QPP=0x34`
  - `N25Q128A`：`4READ=0x6B`，`4PP=0x32`
- 数据相位通过 `DQ[3:0]` 并行收发，方向控制由 `O_dq_oe[3:0]` 给出。
- 状态寄存器读、普通命令字节和地址字节仍按 x1 发出。
- 因此当前实现的准确表述是：
  - 真正的 QSPI x4 数据模式
  - 不是“假 x4”
  - 也不是全阶段都切成 4-bit 的 QPI

## 4. UltraScale 下 I/O 口行为

`FPGA_FAMILY=1` 时：

- 若 `USE_STARTUP_FLASH_IO=1`
  - `flash_ctrl -> flash_driver` 产生的 SPI 控制信号进入 `startup_bridge`。
  - `CS/MOSI/SCK` 通过 `STARTUPE3` 走配置专用引脚。
  - `MISO` 从 `STARTUPE3.DI[1]` 回读；x4 时 `DQ[3:0]` 通过 `DI/DO/DTS` 交互。
  - 顶层 `O_cs/O_data` 仍保留为内部信号镜像，便于兼容旧设计和调试观察。

- 若 `USE_STARTUP_FLASH_IO=0`
  - 仍按普通 FPGA I/O 方式工作：`I_data/O_cs/O_data/IO_dq` 直接用于 SPI/QSPI。

## 5. `MULTIBOOT_ADDR_SHIFT` 的实际用途

在 `icap_jump` 里：

- `W_wbstar_addr = I_update_addr >> MULTIBOOT_ADDR_SHIFT`
- 作用：把“上层传入地址单位”映射成 WBSTAR 期望编码。
- 当前默认建议：`0`（保持与现有软件地址语义一致）。
- 只有在联调确认 WBSTAR 地址语义不一致时再调整。

## 6. 两个擦除超时参数具体用在哪个阶段

- `ERASE_TIMEOUT_64K_CYCLES`
  - 用于状态机 `RD_ERA_64K_STATUS_CHECK`。
  - 逻辑：64KB 擦除命令下发后，不断读状态寄存器；若一直 Busy 且计数超过该阈值，进入错误态。

- `ERASE_TIMEOUT_4K_CYCLES`
  - 用于状态机 `RD_ERA_4K_STATUS_CHECK`。
  - 逻辑：4KB 擦除命令下发后，同样做 Busy 轮询超时保护。

这两个参数替代了“同地址重复擦除 N 次”的策略，属于更稳定的“状态轮询 + 超时保护”方案。

## 7. 默认值建议（100MHz 系统时钟）

- `ERASE_TIMEOUT_4K_CYCLES = 200000000`（约 2.0s）
- `ERASE_TIMEOUT_64K_CYCLES = 300000000`（约 3.0s）

换算公式（任意 `SYS_CLK_FREQ`）：

- `ERASE_TIMEOUT_4K_CYCLES = ceil(2.0 * SYS_CLK_FREQ)`
- `ERASE_TIMEOUT_64K_CYCLES = ceil(3.0 * SYS_CLK_FREQ)`

## 8. 推荐组合（x1/x4）

### 8.1 7 系列 + S25FL256SAIF00

- `FPGA_FAMILY=0`
- `USE_STARTUP_FLASH_IO=0`
- `FLASH_MODEL=0`
- `SPI_BUS_WIDTH=1/4`
- `S25_TBPARM_TOP=0`（默认底部参数区）
- `MULTIBOOT_ADDR_SHIFT=0`

### 8.2 7 系列 + MT25QL256

- `FPGA_FAMILY=0`
- `USE_STARTUP_FLASH_IO=0`
- `FLASH_MODEL=1`
- `SPI_BUS_WIDTH=1/4`
- `S25_TBPARM_TOP` 忽略
- `MULTIBOOT_ADDR_SHIFT=0`

### 8.3 7 系列 + N25Q128A

- `FPGA_FAMILY=0`
- `USE_STARTUP_FLASH_IO=0`
- `FLASH_MODEL=2`
- `SPI_BUS_WIDTH=1/4`
- `S25_TBPARM_TOP` 忽略
- `MULTIBOOT_ADDR_SHIFT=0`

### 8.4 UltraScale + 板载配置 Flash 专用脚（推荐）

- `FPGA_FAMILY=1`
- `USE_STARTUP_FLASH_IO=1`
- `FLASH_MODEL` 按器件选择（`0`/`1`/`2`）
- `SPI_BUS_WIDTH=1/4`
- `MULTIBOOT_ADDR_SHIFT=0` 起步

### 8.5 UltraScale + 普通 I/O SPI（非专用配置脚）

- `FPGA_FAMILY=1`
- `USE_STARTUP_FLASH_IO=0`
- 其余同上

## 9. 当前验证结论

- `S25FL256S` 的 `SPI_BUS_WIDTH=4` 已完成实板验证，`mode=0` 和 `mode=1` 都已跑通。
- `S25FL256S` 的实板 x4 通过条件，当前依赖上位机参数 `--reverse-each-stream-word`。
- `MT25QL` 和 `N25Q128A` 的 x4 已完成 `flash_driver` 级仿真回归。
- 详细验证记录见 [x4_validation_status.md](./x4_validation_status.md)。

## 10. 地址规划约束（保持不丢字节/不多字节的前提）

- 擦除起始地址至少 4KB 对齐。
- 对 S25 非参数区，必须按 64KB 对齐擦除。
- 写入路径按 `WR_DATA_MAX_LEN` 为一拍，不握手不取数，避免多写/丢写。
