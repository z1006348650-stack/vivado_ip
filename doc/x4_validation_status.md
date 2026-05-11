# axi_multiboot_driver x4 验证状态

> 更新日期：`2026-05-11`
>
> 范围：`axi_multiboot_driver_1.0`

## 1. 结论先说

- 当前 `SPI_BUS_WIDTH=4` 是真的 QSPI x4 数据模式，不是假 x4。
- 更准确地说：
  - 命令、地址、状态寄存器读仍然走 x1
  - Flash 数据读写相位走 x4（`DQ[3:0]` 并行）
  - 因此它不是 QPI
- `S25FL256S` 的 x4 已完成实板验证并跑通。
- `MT25QL` 和 `N25Q128A` 的 x4 已完成 `flash_driver` 级仿真验证。

## 2. 为什么说这是真 x4

当前 RTL 在 `SPI_BUS_WIDTH=4` 时，不是简单复用 x1 数据线跑完整流程，而是明确切换到 Quad 数据命令和 `DQ[3:0]` 收发：

- `S25FL256S` / `MT25QL`
  - `READ_CMD_X4 = 0x6C`
  - `WRITE_CMD_X4 = 0x34`
- `N25Q128A`
  - `READ_CMD_X4 = 0x6B`
  - `WRITE_CMD_X4 = 0x32`

同时：

- 数据输入来自 `I_dq[3:0]`
- 数据输出走 `O_dq[3:0]`
- 方向控制走 `O_dq_oe[3:0]`

所以当前实现属于真实的 Quad SPI x4 data phase。

## 3. 实板验证状态

### 3.1 S25FL256S

- 状态：通过
- 验证方式：实板 + Python 上位机 + 完整镜像下载、更新、跳转
- 当前成功结论：
  - `mode=0` 通过
  - `mode=1` 通过
  - `jump` 已成功实测触发
  - `final multiboot status = 0x00000055`
  - `final dma status = 0x00001002`

### 3.2 已确认通过的实板参数

- Flash 地址 `0x00500000`
  - 完整 `1.bin`
  - `mode=0` 通过
  - `mode=1` 通过
- Flash 地址 `0x00600000`
  - 完整 `x4.bin`
  - `mode=0 + --jump` 通过
  - 跳转后 UART bridge 立即掉线，属于重配置启动后的预期现象

### 3.3 当前实板通过时使用的上位机参数

- `--reverse-each-stream-word`
- `--chunk-size 256`
- `--verify-bram-bytes 32`

说明：

- `--reverse-each-stream-word` 是上位机对每个 `stream_word_bytes` 数据块做反序补偿。
- 当前 `prj_325t` 默认 `stream_word_bytes=32`，因此现象上会表现为每个 `32B` 数据块反序补偿。
- 这不是“整文件反序”。

## 4. 仿真验证状态

### 4.1 `flash_driver` 级 x4 仿真

已完成以下三个顶层的 x4 仿真回归，结果均通过：

- `tb_flash_driver_s25_x4`
- `tb_flash_driver_mt25_x4`
- `tb_flash_driver_n25q128a_x4`

验证目标：

- x4 命令选择正确
- `DQ[3:0]` 数据相位收发正确
- 不同器件型号的 x4 opcode 选择正确

### 4.2 `flash_driver` 级 x1 仿真

对应的 x1 `flash_driver` 回归也已经通过：

- `tb_flash_driver_s25`
- `tb_flash_driver_mt25`
- `tb_flash_driver_n25q128a`

## 5. 本次和 x4 相关的关键修正

### 5.1 S25 清状态命令修正

- `S25FL256S` 的清状态命令修正为 `0x30`
- `MT25QL` / `N25Q128A` 仍保持 `0x50`

原因：

- `S25FL256S` 的 `CLSR` 是 `0x30`
- `MT25QL` / `N25Q128A` 的 `Clear Flag Status Register` 使用 `0x50`

### 5.2 QE 准备流程修正

针对 `S25FL256S + x4`，修正了 QE 使能过程里的状态寄存器回写策略：

- 不再把异常读到的 `SR1=0xFF` 原样写回
- QE 准备时固定写 `SR1=0x00`
- `CR1` 只置 `QE` 位

该修正用于避免错误地把保护位一并写高，导致后续擦除卡死。

## 6. 当前边界

- 当前可以确认：
  - `S25FL256S` x4：实板通过
  - `MT25QL` x4：`flash_driver` 级仿真通过
  - `N25Q128A` x4：`flash_driver` 级仿真通过
- 当前还不在本记录里承诺的内容：
  - `MT25QL` / `N25Q128A` 的实板 x4 已通过
  - 命令/地址阶段也按 x4 发送

## 7. 关于镜像生成的注意事项

- 当前上位机/IP 链路已经证明可以把数据按 x4 写入 Flash。
- 但如果目标是“FPGA 从 Flash 以 x4 方式真正启动配置”，镜像本身也应按 x4 启动方式生成。
- 否则即使烧录成功，重配置启动阶段仍可能按 x1 方式取数，或者启动失败。

## 8. 推荐表述

后续文档、汇报或评审里，建议这样描述当前状态：

- `SPI_BUS_WIDTH=4` 已实现真实 QSPI x4 数据模式
- `S25FL256S` 已完成实板验证，并已完成 `jump` 跳转验证
- `MT25QL` 和 `N25Q128A` 已完成 x4 驱动级仿真验证
- 当前实现不是 QPI，命令/地址/状态阶段仍为 x1
