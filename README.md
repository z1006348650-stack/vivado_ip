# AXI Multiboot Driver

> Xilinx Vivado IP - 通过 AXI 总线控制 SPI Flash 进行 Multiboot 启动

## 功能概述

本 IP 提供通过 AXI-Lite 接口读写 SPI Flash 的功能，支持：

- 🔄 **Multiboot 切换**：通过 ICAP 端口动态切换启动镜像
- 📦 **Flash 读写**：通过 AXI 总线直接读写外部 SPI Flash
- ⚡ **高速传输**：支持 AXI Stream 数据路径，最大 256 字节突发
- 🔌 **多 Flash 支持**：支持主流 NOR Flash 型号

## 支持的 Flash 型号

| 厂商 | 型号 | 容量 |
|------|------|------|
| Micron | MT25QL128 | 128Mb |
| Micron | MT25QL256 | 256Mb |
| Cypress | S25FL256S | 256Mb |
| Macronix | N25Q128 | 128Mb |

## 目录结构

```
axi_multiboot_driver_1.0/
├── hdl/                    # RTL 源码
│   ├── axi_multiboot_driver_v1_0.v
│   └── axi_multiboot_driver_v1_0_S00_AXI.v
├── src/                    # Flash 驱动和 IP 核
│   ├── flash_ctrl.v        # Flash 控制器
│   ├── flash_driver.v      # Flash 驱动层
│   ├── flash_top.v        # 顶层封装
│   ├── icap_jump.v        # ICAP Multiboot 跳转
│   └── axis_data_fifo_*/  # AXI Stream FIFO IP
├── sim/                    # 仿真文件
├── doc/                    # 文档和规格书
├── xgui/                   # Vivado GUI 配置
├── bd/                     # Block Design TCL
├── drivers/                # 软件驱动
├── example_designs/       # 示例工程
└── component.xml          # IP 定义文件
```

## 寄存器说明

| 地址 | 名称 | 描述 |
|------|------|------|
| 0x00 | CTRL | 控制寄存器 |
| 0x04 | STATUS | 状态寄存器 |
| 0x08 | ADDR_L | 地址低 32 位 |
| 0x0C | ADDR_H | 地址高 32 位 |
| 0x10 | DATA | 数据寄存器 |
| 0x14 | LEN | 传输长度 |

详细寄存器定义见 `doc/parameter_definition_detailed.md`

## 使用方法

### 1. 添加 IP 到工程

1. 在 Vivado 中打开 IP Catalog
2. 选择 `axi_multiboot_driver_v1_0`
3. 配置参数并生成 IP

### 2. 典型连接

```
                    ┌─────────────────────┐
                    │  axi_multiboot_driver│
                    │                     │
  S_AXI     ───────▶│ S00_AXI             │
  SPI_CLK   ◀───────│ clk                 │
  SPI_MOSI  ◀───────│ mosi                │
  SPI_MISO  ───────▶│ miso                │
  SPI_CS    ◀───────│ cs_n                │
  ICAP_CLK  ◀───────│ icap_clk            │
  ICAP     ◀───────▶│ icap                │
                    └─────────────────────┘
```

## 仿真

运行仿真测试：

```powershell
cd sim
vivado -mode batch -source run_regression.ps1
```

## 版本历史

- v1.0 - 初始版本，支持基本 Flash 读写和 Multiboot

## 参考文档

- [详细参数定义](./doc/parameter_definition_detailed.md)
- [寄存器状态映射](./doc/parameter_register_state_mapping.md)
- [Xilinx 7 Series Configuration Guide](doc/ug470_7Series_Config.pdf)