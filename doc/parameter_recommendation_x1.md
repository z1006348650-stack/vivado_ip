# axi_multiboot_driver x1/x4 参数推荐表

> 适用范围：当前版本支持 `SPI_BUS_WIDTH=1` 和 `SPI_BUS_WIDTH=4`。
>
> 目标：同时兼容 Xilinx 7 系列/UltraScale 与 S25FL256SAIF00、MT25QL256、N25Q128A。

## 1. 顶层参数推荐值（x1/x4）

| 场景 | FPGA_FAMILY | USE_STARTUP_FLASH_IO | SPI_BUS_WIDTH | FLASH_MODEL | S25_TBPARM_TOP | MULTIBOOT_ADDR_SHIFT | ERASE_TIMEOUT_4K_CYCLES | ERASE_TIMEOUT_64K_CYCLES | 说明 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 7 系列 + S25FL256SAIF00 | 0 | 0 | 1/4 | 0 | 0 | 0 | 200000000 | 300000000 | SAIF00 默认底部参数区（Hybrid） |
| 7 系列 + MT25QL256 | 0 | 0 | 1/4 | 1 | 0 | 0 | 200000000 | 300000000 | MT25 Uniform 4KB，满足对齐时自动优先 64KB |
| 7 系列 + N25Q128A | 0 | 0 | 1/4 | 2 | 0 | 0 | 200000000 | 300000000 | N25Q 使用 24-bit 地址命令 |
| UltraScale + S25FL256SAIF00（专用脚） | 1 | 1 | 1/4 | 0 | 0 | 0 | 200000000 | 300000000 | 通过 STARTUPE3 使用配置专用引脚 |
| UltraScale + MT25QL256（专用脚） | 1 | 1 | 1/4 | 1 | 0 | 0 | 200000000 | 300000000 | 通过 STARTUPE3 使用配置专用引脚 |
| UltraScale + 普通 I/O SPI/QSPI | 1 | 0 | 1/4 | 0/1/2 | 0 | 0 | 200000000 | 300000000 | 不走配置专用引脚 |

## 2. 参数含义补充

- `SPI_BUS_WIDTH`
  - `1`：标准 SPI，命令、地址、状态、读写数据均为 x1。
  - `4`：命令、地址、状态仍为 x1，Flash 读写数据相位为 x4。
  - x4 模式需要外部完成 QE bit 配置，或保证 Flash 上电后已启用 Quad。

- `USE_STARTUP_FLASH_IO`
  - `0`：MISO 来自顶层 `I_data`；x4 时 DQ 输入来自 `I_dq[3:0]`，输出为 `O_dq[3:0]`，方向为 `O_dq_oe[3:0]`。
  - `1`：仅在 `FPGA_FAMILY=1` 生效，DQ 来自 STARTUPE3 `DI/DO/DTS`，CS/MOSI/SCK 走专用配置引脚。

- `FLASH_MODEL`
  - `0`：S25FL256S。
  - `1`：MT25QL256/512。
  - `2`：N25Q128A。

- `S25_TBPARM_TOP`
  - 仅 `FLASH_MODEL=0` 有效。
  - `0`：4KB 参数区在底部（S25FL256SAIF00 默认）。
  - `1`：4KB 参数区在顶部（仅当器件配置确认为 TBPARM=1 时使用）。

## 3. 擦除超时参数换算（非 100MHz 时）

当前默认值对应 100MHz 系统时钟：

- `ERASE_TIMEOUT_4K_CYCLES = 2.0s * 100MHz = 200000000`
- `ERASE_TIMEOUT_64K_CYCLES = 3.0s * 100MHz = 300000000`

若系统时钟为 `SYS_CLK_FREQ`，建议按下式换算：

- `ERASE_TIMEOUT_4K_CYCLES = ceil(2.0 * SYS_CLK_FREQ)`
- `ERASE_TIMEOUT_64K_CYCLES = ceil(3.0 * SYS_CLK_FREQ)`

## 4. 地址规划约束（与控制器逻辑一致）

- 起始擦除地址需至少 4KB 对齐。
- 对 S25 非参数区（64KB 区）擦除时，地址必须 64KB 对齐且剩余长度不少于 64KB。
- MT25/N25Q 场景下控制器会在“64KB 对齐且长度足够”时走 64KB 擦除，其余段落走 4KB 擦除。