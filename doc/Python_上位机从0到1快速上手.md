# Python 上位机从 0 到 1 快速上手

这份文档只讲怎么最快跑起来。

如果你第一次接触这个项目，先记住下面两条：

- 调寄存器，用 `main.py`
- 下载 `.bin`，用 `download_bin_axif.py`

## 1. 第一步：打开 PowerShell

在 Windows 中打开 `PowerShell`。

## 2. 第二步：进入脚本目录

```powershell
cd <你的工程目录>\uart_axi_bridge\python
```

## 3. 第三步：安装依赖

```powershell
python --version
python -m pip install -r requirements.txt
```

## 4. 第四步：确认串口号

把 FPGA 板卡连接到电脑，在设备管理器中查看：

- `端口 (COM 和 LPT)`

例如你看到的是 `COM5`，后面命令里的串口号就写 `COM5`。

## 5. 第五步：直接下载 .bin

```powershell
python download_bin_axif.py --port COM5 .\design.bin 0x0000000000
```

这条命令的含义是：

- `download_bin_axif.py`：专用下载脚本
- `--port COM5`：使用 `COM5` 串口
- `.\design.bin`：要下载的 `.bin` 文件
- `0x0000000000`：写入 FPGA 的 AXI 起始地址

## 6. 下载时脚本会自动做什么

你不需要手工分包，脚本会自动完成：

- 按协议把 `.bin` 切成多个分块
- 每块调用一次 `AXI-FULL` 的 `FULL_WRITE`
- 默认按 `1024 Byte` 分块
- 每发送一块，地址自动递增
- 最后一块不足 `4 Byte` 时，自动补 `0xFF`

## 7. 如果你想写完后读回校验

加上 `--verify`：

```powershell
python download_bin_axif.py --port COM5 .\design.bin 0x0000000000 --verify
```

说明：

- 默认不校验
- 加上 `--verify` 后会更慢，但更稳

## 8. 如果你想读寄存器

```powershell
python main.py --port COM5 lite-read 0xA0
```

## 9. 如果你想写寄存器

```powershell
python main.py --port COM5 lite-write 0xA0 0x12345678
```

## 10. 如果你想读 AXI-Full 数据

例如读取 `16` 字节：

```powershell
python main.py --port COM5 full-read 0x100 16
```

## 11. 如果你想写一小段 AXI-Full 数据

例如直接写十六进制数据：

```powershell
python main.py --port COM5 full-write 0x100 --hex A3A2A1A0B3B2B1B0
```

当前限制：

- `full-write` 最大 `1024 Byte`
- `full-read` 最大 `1024 Byte`
- `full-write` 长度必须是 `4 Byte` 的整数倍

## 12. 如果你不确定命令怎么写

```powershell
python main.py --help
python download_bin_axif.py --help
```

## 13. 建议你照着抄的完整流程

假设：

- 串口号是 `COM5`
- `.bin` 文件名是 `design.bin`
- 文件就在当前目录
- 目标地址是 `0x0000000000`

那就直接执行：

```powershell
cd <你的工程目录>\uart_axi_bridge\python
python -m pip install -r requirements.txt
python download_bin_axif.py --port COM5 .\design.bin 0x0000000000
```

## 14. 如果失败，先检查这 4 项

- 串口号是否正确
- FPGA 是否已经上电
- UART 波特率是否为 `115200`
- AXI 起始地址是否正确

## 15. 你通常只需要改的 3 个地方

- `COM5` 改成你的串口号
- `.\design.bin` 改成你的 `.bin` 文件路径
- `0x0000000000` 改成你的 AXI 起始地址
