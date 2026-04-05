# axi_multiboot_driver 参数说明（详细版，x1）

> 适用代码版本：`axi_multiboot_driver_v1_0.v`
>
> 重点场景：7 Series / UltraScale + `S25FL256SAIF00` / `MT25QL256`，仅 SPI x1。

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
| `FLASH_TYPE` | `0` | 枚举 | 选择 S25 或 MT25 的擦除/状态位策略 | `flash_ctrl` |
| `S25_TBPARM_TOP` | `0` | 0/1 | S25 Hybrid 参数区位置（底部/顶部） | `flash_ctrl` |
| `ERASE_TIMEOUT_4K_CYCLES` | `200000000` | clk cycles | 4KB 擦除轮询超时阈值 | `flash_ctrl` |
| `ERASE_TIMEOUT_64K_CYCLES` | `300000000` | clk cycles | 64KB 擦除轮询超时阈值 | `flash_ctrl` |

## 2. 枚举参数取值定义

- `FPGA_FAMILY`
  - `0`: 7 Series（`ICAPE2` + `STARTUPE2`）
  - `1`: UltraScale/UltraScale+（`ICAPE3` + `STARTUPE3`）

- `FLASH_TYPE`
  - `0`: `S25FL256S` 系列（含 `S25FL256SAIF00`）
  - `1`: `MT25QL256`

- `S25_TBPARM_TOP`（仅 `FLASH_TYPE=0` 有效）
  - `0`: 参数区在底部（`0x00000000 ~ 0x0001FFFF`，32 x 4KB）
  - `1`: 参数区在顶部（`0x01FE0000 ~ 0x01FFFFFF`，32 x 4KB）

## 3. UltraScale 下 I/O 口行为（你现在最关心的）

`FPGA_FAMILY=1` 时：

- 若 `USE_STARTUP_FLASH_IO=1`
  - `flash_ctrl -> flash_driver` 产生的 SPI 控制信号进入 `startup_bridge`。
  - `CS/MOSI/SCK` 通过 `STARTUPE3` 走配置专用引脚。
  - `MISO` 从 `STARTUPE3.DI[1]` 回读（顶层 `I_data` 不再作为有效数据来源）。
  - 顶层 `O_cs/O_data` 仍保留为内部信号镜像，便于兼容旧设计/调试观察。

- 若 `USE_STARTUP_FLASH_IO=0`
  - 仍按普通 FPGA I/O 方式工作：`I_data/O_cs/O_data` 直接用于 SPI。

## 4. `MULTIBOOT_ADDR_SHIFT` 的实际用途

在 `icap_jump` 里：

- `W_wbstar_addr = I_update_addr >> MULTIBOOT_ADDR_SHIFT`
- 作用：把“上层传入地址单位”映射成 WBSTAR 期望编码。
- 当前默认建议：`0`（保持与现有软件地址语义一致）。
- 只有在联调确认 WBSTAR 地址语义不一致时再调整。

## 5. 两个擦除超时参数具体用在哪个阶段

- `ERASE_TIMEOUT_64K_CYCLES`
  - 用于状态机 `RD_ERA_64K_STATUS_CHECK`。
  - 逻辑：64KB 擦除命令下发后，不断读状态寄存器；若一直 Busy 且计数超过该阈值，进入错误态。

- `ERASE_TIMEOUT_4K_CYCLES`
  - 用于状态机 `RD_ERA_4K_STATUS_CHECK`。
  - 逻辑：4KB 擦除命令下发后，同样做 Busy 轮询超时保护。

这两个参数替代了“同地址重复擦除 N 次”的策略，属于更稳定的“状态轮询 + 超时保护”方案。

## 6. 默认值建议（100MHz 系统时钟）

- `ERASE_TIMEOUT_4K_CYCLES = 200000000`（约 2.0s）
- `ERASE_TIMEOUT_64K_CYCLES = 300000000`（约 3.0s）

换算公式（任意 `SYS_CLK_FREQ`）：

- `ERASE_TIMEOUT_4K_CYCLES = ceil(2.0 * SYS_CLK_FREQ)`
- `ERASE_TIMEOUT_64K_CYCLES = ceil(3.0 * SYS_CLK_FREQ)`

## 7. 推荐组合（x1）

### 7.1 7 系列 + S25FL256SAIF00

- `FPGA_FAMILY=0`
- `USE_STARTUP_FLASH_IO=0`
- `FLASH_TYPE=0`
- `S25_TBPARM_TOP=0`（默认底部参数区）
- `MULTIBOOT_ADDR_SHIFT=0`

### 7.2 7 系列 + MT25QL256

- `FPGA_FAMILY=0`
- `USE_STARTUP_FLASH_IO=0`
- `FLASH_TYPE=1`
- `S25_TBPARM_TOP` 忽略
- `MULTIBOOT_ADDR_SHIFT=0`

### 7.3 UltraScale + 板载配置 Flash 专用脚（推荐）

- `FPGA_FAMILY=1`
- `USE_STARTUP_FLASH_IO=1`
- `FLASH_TYPE` 按器件选择（`0`/`1`）
- `MULTIBOOT_ADDR_SHIFT=0` 起步

### 7.4 UltraScale + 普通 I/O SPI（非专用配置脚）

- `FPGA_FAMILY=1`
- `USE_STARTUP_FLASH_IO=0`
- 其余同上

## 8. 地址规划约束（保持不丢字节/不多字节的前提）

- 擦除起始地址至少 4KB 对齐。
- 对 S25 非参数区，必须按 64KB 对齐擦除。
- 写入路径按 `WR_DATA_MAX_LEN` 为一拍，不握手不取数，避免多写/丢写。

