# axi_multiboot_driver 参数-寄存器-状态机阶段对照表（x1）

> 适用范围：`axi_multiboot_driver_v1_0`，SPI x1。
>
> 目标：把“参数配置 -> AXI寄存器 -> 各状态机阶段”关系一次性对齐，便于软硬件联调。

## 1. AXI-Lite 寄存器映射（软件可见）

| 地址偏移 | 名称 | 方向 | 关键位/字段 | 作用 |
|---|---|---|---|---|
| `0x00` | `slv_reg0` | W | bit0 | 命令触发位（上升沿触发） |
| `0x00` | `slv_reg0` | W | bit13 | 软复位流程触发（`cmd_decoder` 的 `GET_RST_INFO`） |
| `0x00` | `slv_reg0` | W | bit14 | Flash 升级流程触发（`GET_DRV_INFO`） |
| `0x00` | `slv_reg0` | W | bit15 | ICAP 跳转流程触发（`GET_ICAP_INFO`） |
| `0x04` | `slv_reg1`/`W_fb_data` | R | bit7:0 | 反馈状态：`0x5A`忙中/默认，`0x55`成功，`0xAA`失败 |
| `0x08` | `slv_reg2` | W | [31:0] | 更新起始地址（Flash 读写擦地址；ICAP 场景下为 update_base） |
| `0x0C` | `slv_reg3` | W | [31:0] | 升级 bin 大小（字节） |
| `0x10` | `slv_reg4` | W | bit0 | 驱动模式（`flash_ctrl.I_mode`，0=不做读回校验，1=读回校验） |
| `0x14`~`0x1C` | `slv_reg5~7` | RW | - | 预留 |

## 2. 顶层参数到模块的落点

| 参数 | 主要落点 | 影响阶段 |
|---|---|---|
| `SYS_CLK_FREQ` | `flash_driver` | SPI 时钟分频与位传输节拍 |
| `FLASH_CLK_FREQ` | `flash_driver` | SPI SCK 实际速率 |
| `RD_DATA_MAX_LEN` | `flash_ctrl/flash_driver` | 读阶段每拍字节数、计数边界 |
| `WR_DATA_MAX_LEN` | `flash_ctrl/flash_driver` | 写阶段每拍字节数、AXIS 写拍计数 |
| `FLASH_ADDR_WIDTH` | `flash_ctrl/flash_driver/icap_jump` | 地址位宽与移位边界 |
| `FLASH_TYPE` | `flash_ctrl` | 状态寄存器命令与 Busy/Error 位定义 |
| `S25_TBPARM_TOP` | `flash_ctrl` | S25 4KB 参数区在顶部/底部判断 |
| `ERASE_TIMEOUT_4K_CYCLES` | `flash_ctrl` | `RD_ERA_4K_STATUS_CHECK` 超时判错 |
| `ERASE_TIMEOUT_64K_CYCLES` | `flash_ctrl` | `RD_ERA_64K_STATUS_CHECK` 超时判错 |
| `FPGA_FAMILY` | `icap_jump/startup_bridge` | 7系列/UltraScale 原语选择 |
| `USE_STARTUP_FLASH_IO` | `startup_bridge` + 顶层 MISO 选择 | UltraScale 专用配置引脚路径使能 |
| `MULTIBOOT_ADDR_SHIFT` | `icap_jump` | `WBSTAR` 写入地址右移换算 |
| `DEVICE_ID` | `icap_jump` | ICAP 原语参数 |
| `UPDATE_BASE_ADDR` | `cmd_decoder/S00_AXI` | 上电默认更新地址 |

## 3. `cmd_decoder` 状态机阶段与寄存器关系

| 状态 | 入口条件 | 关键动作 | 出口 |
|---|---|---|---|
| `IDLE` | 等待 `slv_reg0[0]` 上升沿 | 空闲保持 | -> `GET_OPT_MODE` |
| `GET_OPT_MODE` | 收到触发 | 解析 `slv_reg0[13/14/15]` | -> `GET_RST_INFO`/`GET_DRV_INFO`/`GET_ICAP_INFO` |
| `GET_RST_INFO` | bit13=1 | 拉低 `O_aux_rst_n` 10 个周期 | -> `OPT_END` |
| `GET_DRV_INFO` | bit14=1 | 读取 `slv_reg2/3/4`，置 `O_opt_begin` | `I_drv_opt_busy` 拉高后 -> `OPT_END` |
| `GET_ICAP_INFO` | bit15=1 | `O_icap_en=1`，更新 `O_update_base_addr` | -> `OPT_END` |
| `OPT_END` | 各流程收尾 | 清触发脉冲 | -> `IDLE` |

## 4. `flash_ctrl` 阶段图（逻辑层）

### 4.1 擦除阶段

| 逻辑阶段 | 状态名 | 下发给 `flash_driver` 的 `O_opt_mode` |
|---|---|---|
| 64KB 擦除命令 | `ERASE_64K` | `4'd5` |
| 64KB 状态读取 | `RD_ERA_64K_STATUS` | `4'd8` |
| 64KB 状态判定 | `RD_ERA_64K_STATUS_CHECK` | 无新命令（解析 `I_rd_cmd_data`） |
| 4KB 擦除命令 | `ERASE_4K` | `4'd4` |
| 4KB 状态读取 | `RD_ERA_4K_STATUS` | `4'd8` |
| 4KB 状态判定 | `RD_ERA_4K_STATUS_CHECK` | 无新命令 |

### 4.2 校验与写入阶段

| 逻辑阶段 | 状态名 | 下发命令 |
|---|---|---|
| 擦除读回 | `ERASE_CHECK_RD` | `4'd3`（多字节读） |
| 擦除比较 | `ERASE_CHECK_CMPR` | 比较 `&I_rd_data`（全1通过） |
| 写命令 | `WRITE` | `4'd1`（页写，多字节） |
| 写状态读取 | `RD_WRITE_STATUS` | `4'd8` |
| 写状态判定 | `RD_WRITE_STATUE_CHECK` | 解析 Busy/Error，并做写拍上限保护 |
| 写后读回 | `WRITE_CHECK_RD` | `4'd3` |
| 写后比较 | `WRITE_CHECK_CMPR` | 比较 `I_rd_data == R_wr_data` |

### 4.3 结束/错误阶段

| 状态名 | 含义 |
|---|---|
| `FINISH` | 正常完成，`O_drv_opt_ok` 置位 |
| `ERA_CHECK_ERROR` | 擦除链路错误（超时/状态错误/地址非法/擦除检查失败） |
| `WRITE_CHECK_ERR` | 写链路错误（状态错误/读回不一致/计数越界） |

## 5. `flash_driver` 的 `I_mode` 编码对照

| `I_mode` | SPI 操作 |
|---:|---|
| `0` | 写单字节 |
| `1` | 写多字节（当前主流程使用） |
| `2` | 读单字节 |
| `3` | 读多字节（校验流程使用） |
| `4` | 4KB 擦除 |
| `5` | 64KB 擦除 |
| `6` | 全片擦除 |
| `7` | 写寄存器命令 |
| `8` | 读状态寄存器命令 |

## 6. Flash 类型相关状态位解释（`flash_ctrl` 解析）

| Flash | 轮询命令 | Busy 判断 | 擦除错误判断 | 写错误判断 |
|---|---|---|---|---|
| S25 (`FLASH_TYPE=0`) | `0x05` | `I_rd_cmd_data[0]==1` 为忙 | `bit5` | `bit6` |
| MT25 (`FLASH_TYPE=1`) | `0x70` | `I_rd_cmd_data[7]==0` 为忙 | `bit5 or bit1` | `bit4 or bit1` |

## 7. 两个擦除超时参数对应的精确阶段

| 参数 | 生效状态 | 判错条件 |
|---|---|---|
| `ERASE_TIMEOUT_4K_CYCLES` | `RD_ERA_4K_STATUS_CHECK` | Busy 持续且计数达到阈值 -> `ERA_CHECK_ERROR` |
| `ERASE_TIMEOUT_64K_CYCLES` | `RD_ERA_64K_STATUS_CHECK` | Busy 持续且计数达到阈值 -> `ERA_CHECK_ERROR` |

## 8. 一次完整升级流程（mode=0）

1. 软件写 `0x08/0x0C/0x10` 配置地址、大小、模式。
2. 软件写 `0x00 = 0x0000_4001`（bit14 + bit0）触发 flash_ctrl。
3. `cmd_decoder.GET_DRV_INFO` 拉起 `O_opt_begin`。
4. `flash_ctrl` 进入擦除链路（按地址/flash类型自动选择 4KB/64KB）。
5. 擦除完成后进入写入链路，AXIS 按握手逐拍下发数据。
6. 全部写完，`flash_ctrl.FINISH`，`W_fb_data` 变为 `0x55`。

## 9. 排障建议（和这份对照表配套）

- `0x04` 读回 `0xAA`：先看 `flash_ctrl` 是否停在 `ERA_CHECK_ERROR` 或 `WRITE_CHECK_ERR`。
- 一直不结束：优先检查状态轮询命令/Busy 位定义是否匹配 `FLASH_TYPE`。
- 地址相关错误：检查起始地址 4KB 对齐，以及 S25 非参数区 64KB 对齐约束。
- UltraScale 配置专用脚场景：确认 `FPGA_FAMILY=1` 且 `USE_STARTUP_FLASH_IO=1`。

