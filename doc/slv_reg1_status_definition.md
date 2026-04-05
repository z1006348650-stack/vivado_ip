# `slv_reg1` 状态寄存器说明（`0x04`）

> 适用模块：`axi_multiboot_driver_v1_0`  
> 读地址偏移：`0x04`（AXI-Lite）  
> 信号来源：`cmd_decoder.O_fb_data`

## 1. 位图定义（32bit）

| 位段 | 名称 | 含义 |
|---|---|---|
| `[7:0]` | `status_code` | 命令结果码：`8'h5A`=默认/进行中，`8'h55`=成功，`8'hAA`=失败 |
| `[8]` | `flash_err` | Flash 流程失败标志（擦写/校验相关） |
| `[9]` | `icap_err` | ICAP 跳转失败标志 |
| `[10]` | `timeout_err` | 超时失败标志（Flash 擦除超时或 ICAP 等待超时） |
| `[15:11]` | `last_fail_stage` | 最近一次失败阶段编码（见下表） |
| `[31:16]` | `reserved` | 保留，当前为 `0` |

寄存器打包格式：

```verilog
O_fb_data = {16'd0, last_fail_stage[4:0], timeout_err, icap_err, flash_err, status_code[7:0]};
```

## 2. `last_fail_stage` 编码表

| 编码 | 宏名 | 触发来源 | 说明 |
|---:|---|---|---|
| `0` | `FAIL_STAGE_NONE` | `flash_ctrl/cmd_decoder` | 无失败 |
| `1` | `FAIL_STAGE_ERASE_ADDR_INVALID` | `flash_ctrl` | 擦除起始地址非法（对齐/区域约束不满足） |
| `2` | `FAIL_STAGE_ERASE_TIMEOUT_64K` | `flash_ctrl` | 64KB 擦除状态轮询超时 |
| `3` | `FAIL_STAGE_ERASE_TIMEOUT_4K` | `flash_ctrl` | 4KB 擦除状态轮询超时 |
| `4` | `FAIL_STAGE_ERASE_STATUS_ERROR` | `flash_ctrl` | 擦除后状态寄存器报错 |
| `5` | `FAIL_STAGE_ERASE_NEXT_INVALID` | `flash_ctrl` | 擦除推进到下一段地址时非法 |
| `6` | `FAIL_STAGE_ERASE_VERIFY_ERROR` | `flash_ctrl` | 擦除读回校验失败（非全 `1`） |
| `7` | `FAIL_STAGE_WRITE_STATUS_ERROR` | `flash_ctrl` | 写后状态寄存器报错 |
| `8` | `FAIL_STAGE_WRITE_VERIFY_ERROR` | `flash_ctrl` | 写后读回校验不一致 |
| `9` | `FAIL_STAGE_WRITE_OVERFLOW` | `flash_ctrl` | 写计数越界（多写保护触发） |
| `10` | `FAIL_STAGE_ERASE_BUSY_NOT_SEEN` | `flash_ctrl` | 擦除命令后始终未观察到 Busy 置位 |
| `16` | `FAIL_STAGE_ICAP_TIMEOUT` | `cmd_decoder` | ICAP 等待完成超时 |
| 其他 | - | - | 预留 |

## 3. 软件判定建议

1. 先读 `status_code`：`0x55` 成功，`0xAA` 失败。  
2. 若失败，再看 `flash_err/icap_err/timeout_err` 三个位快速分类。  
3. 最后根据 `last_fail_stage` 精确定位到失败阶段。  

示例：
- `status_code=0xAA, flash_err=1, timeout_err=1, last_fail_stage=2`：64KB 擦除超时。
- `status_code=0xAA, icap_err=1, timeout_err=1, last_fail_stage=16`：ICAP 跳转等待超时。
