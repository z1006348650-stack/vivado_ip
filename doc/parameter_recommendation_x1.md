# axi_multiboot_driver x1 参数推荐表

> 适用范围：当前版本仅 SPI x1。
>
> 目标：同时兼容 Xilinx 7 系列/UltraScale 与 S25FL256SAIF00、MT25QL256。

## 1. 顶层参数推荐值（x1）

| 场景 | FPGA_FAMILY | USE_STARTUP_FLASH_IO | FLASH_TYPE | S25_TBPARM_TOP | MULTIBOOT_ADDR_SHIFT | ERASE_TIMEOUT_4K_CYCLES | ERASE_TIMEOUT_64K_CYCLES | 说明 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| 7 系列 + S25FL256SAIF00 | 0 | 0 | 0 | 0 | 0 | 200000000 | 300000000 | SAIF00 默认底部参数区（Hybrid） |
| 7 系列 + MT25QL256 | 0 | 0 | 1 | 0 | 0 | 200000000 | 300000000 | MT25 Uniform 4KB，满足对齐时自动优先 64KB |
| UltraScale + S25FL256SAIF00（专用脚） | 1 | 1 | 0 | 0 | 0 | 200000000 | 300000000 | 通过 STARTUPE3 使用配置专用引脚 |
| UltraScale + MT25QL256（专用脚） | 1 | 1 | 1 | 0 | 0 | 200000000 | 300000000 | 通过 STARTUPE3 使用配置专用引脚 |
| UltraScale + 普通 I/O SPI | 1 | 0 | 0/1 | 0 | 0 | 200000000 | 300000000 | 不走配置专用引脚 |

## 2. 参数含义补充

- `USE_STARTUP_FLASH_IO`
  - `0`：MISO 来自顶层 `I_data`，`O_cs/O_data` 走普通 IO。
  - `1`：仅在 `FPGA_FAMILY=1` 生效，MISO 来自 STARTUPE3 `DI[1]`，CS/MOSI/SCK 走专用配置引脚。

- `S25_TBPARM_TOP`
  - 仅 `FLASH_TYPE=0` 有效。
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
- MT25 场景下控制器会在“64KB 对齐且长度足够”时走 64KB 擦除，其余段落走 4KB 擦除。

