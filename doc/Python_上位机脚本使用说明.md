# Python 上位机脚本使用说明

## 1. 说明

本目录下的 Python 脚本用于通过 UART 与 FPGA 侧 `uart_axi_bridge` 通信，完成以下功能：

- AXI-Lite 单次读写
- AXI-Full 连续读写
- 将 Xilinx `.bin` 文件按协议分帧下载到指定 AXI 地址
- 可选读回校验

脚本位于 `uart_axi_bridge\python` 目录，主要文件如下：

- `main.py`：统一命令行入口
- `download_bin_axif.py`：专用 `.bin` 下载脚本
- `bridge_protocol.py`：协议编解码
- `uart_transport.py`：串口收发
- `bridge_client.py`：高层读写接口
- `bin_sender.py`：`.bin` 分块下载逻辑
- `requirements.txt`：Python 依赖

## 2. 协议版本

当前脚本对应 FPGA 侧协议 `v2.0`：

- `LEN` 为 `2 Byte`，大端
- `FULL_WRITE` / `FULL_READ` 的 `LEN` 直接表示实际字节数
- 单帧 `FULL_WRITE` 最大 `1024 Byte`
- 单帧 `FULL_READ` 最大 `1024 Byte`

如果 FPGA 仍在使用旧版 `1 Byte LEN` / `LEN+1` 协议，这套脚本不能直接混用。

## 3. 环境要求

- Windows
- Python 3.9 及以上
- 串口可正常连接 FPGA 开发板
- FPGA 侧协议与当前脚本版本一致

当前脚本默认串口参数：

- 波特率：`115200`
- 数据位：`8`
- 停止位：`1`
- 校验位：`None`

## 4. 安装依赖

先进入脚本目录：

```powershell
cd <你的工程目录>\uart_axi_bridge\python
```

查看 Python 版本：

```powershell
python --version
```

安装依赖：

```powershell
python -m pip install -r requirements.txt
```

## 5. 串口号确认方法

将 FPGA 板卡连接到电脑后，在 Windows 设备管理器中查看：

- `端口 (COM 和 LPT)`

记下串口号，例如：

- `COM3`
- `COM5`

## 6. main.py 的基本用法

### 6.1 查看帮助

```powershell
python main.py --help
python main.py lite-read --help
python main.py lite-write --help
python main.py full-read --help
python main.py full-write --help
python main.py download-bin --help
```

### 6.2 Lite 读寄存器

```powershell
python main.py --port COM3 lite-read 0xA0
```

### 6.3 Lite 写寄存器

```powershell
python main.py --port COM3 lite-write 0xA0 0x12345678
```

### 6.4 Full 读数据

从 AXI-Full 地址空间读取指定字节数：

```powershell
python main.py --port COM3 full-read 0x100 16
```

保存到文件：

```powershell
python main.py --port COM3 full-read 0x100 256 --out readback.bin
```

### 6.5 Full 写数据

直接写十六进制字符串：

```powershell
python main.py --port COM3 full-write 0x100 --hex A3A2A1A0B3B2B1B0
```

从文件写入：

```powershell
python main.py --port COM3 full-write 0x100 --file payload.bin
```

长度约束：

- `full-write`：`4..1024 Byte`，且必须是 `4 Byte` 的整数倍
- `full-read`：`1..1024 Byte`

## 7. 使用 main.py 下载 .bin

统一入口支持以下两种命令，功能等价：

```powershell
python main.py --port COM3 download-bin <bin文件路径> <AXI起始地址>
python main.py --port COM3 send-bin <bin文件路径> <AXI起始地址>
```

示例：

```powershell
python main.py --port COM3 download-bin .\design.bin 0x0000000000
```

开启读回校验：

```powershell
python main.py --port COM3 download-bin .\design.bin 0x0000000000 --verify
```

## 8. 使用 download_bin_axif.py 下载 .bin

这是专用下载脚本，更适合现场直接使用。

基本命令：

```powershell
python download_bin_axif.py --port COM3 <bin文件路径> <AXI起始地址>
```

示例：

```powershell
python download_bin_axif.py --port COM3 .\design.bin 0x0000000000
```

开启读回校验：

```powershell
python download_bin_axif.py --port COM3 .\design.bin 0x0000000000 --verify
```

## 9. .bin 下载行为说明

`.bin` 下载流程固定走 `AXI-FULL` / `FULL_WRITE`。

脚本行为如下：

- 按块分包发送，默认按 `1024 Byte` 分块
- 每发送一块后，下载地址自动递增
- 最后一块如果不足 `4 Byte`，会自动补 `0xFF`
- 打开 `--verify` 后，会对每个分块执行 `FULL_READ` 读回校验

说明：

- 地址递增按“实际发送长度”计算
- 如果最后一块补了 `0xFF`，校验时比较的是补齐后的数据
- 可通过 `--chunk-size` 指定更小分块，范围为 `4..1024`，且必须是 `4` 的倍数

## 10. 推荐使用方式

- 如果只是调寄存器：用 `main.py`
- 如果是整包下载 `.bin`：优先用 `download_bin_axif.py`

## 11. 常见问题

### 11.1 提示找不到串口

检查：

- 串口线是否连接正常
- 设备管理器中是否能看到对应 `COM` 口
- 命令中的串口号是否填写正确

### 11.2 提示超时

检查：

- FPGA 是否已经上电
- FPGA 端 UART 波特率是否为 `115200`
- FPGA 端协议版本是否与当前脚本一致
- 起始地址是否正确

### 11.3 下载最后一块长度不是 4 的整数倍

这是允许的。脚本会自动在尾部补 `0xFF`，然后再发送。

### 11.4 是否默认读回校验

默认不校验。

如需校验，手动增加：

```powershell
--verify
```

## 12. 一个完整示例

假设：

- 工程目录：`<你的工程目录>`
- 串口号：`COM5`
- 文件路径：`.\design.bin`
- AXI 起始地址：`0x0000000000`

执行：

```powershell
cd <你的工程目录>\uart_axi_bridge\python
python -m pip install -r requirements.txt
python download_bin_axif.py --port COM5 .\design.bin 0x0000000000
```

边写边校验：

```powershell
python download_bin_axif.py --port COM5 .\design.bin 0x0000000000 --verify
```
