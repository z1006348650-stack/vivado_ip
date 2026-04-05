$ErrorActionPreference = 'Stop'
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rtl_dir = Join-Path $script_dir '..\rtl'
$out_file = Join-Path $script_dir 'tb_uart_axi_bridge.out'
$files = @(
    (Join-Path $rtl_dir 'reset_sync.v'),
    (Join-Path $rtl_dir 'uart_rx.v'),
    (Join-Path $rtl_dir 'uart_tx.v'),
    (Join-Path $rtl_dir 'frame_parser.v'),
    (Join-Path $rtl_dir 'frame_builder.v'),
    (Join-Path $rtl_dir 'axi_lite_master.v'),
    (Join-Path $rtl_dir 'axi_full_master.v'),
    (Join-Path $rtl_dir 'bridge_ctrl.v'),
    (Join-Path $rtl_dir 'uart_axi_bridge.v'),
    (Join-Path $script_dir 'axi_lite_slave_model.v'),
    (Join-Path $script_dir 'axi_full_slave_model.v'),
    (Join-Path $script_dir 'tb_uart_axi_bridge.v')
)
Push-Location $script_dir
try {
    & 'D:\software_work\iverilog\iverilog\bin\iverilog.exe' -g2005 -o $out_file @files
    & 'D:\software_work\iverilog\iverilog\bin\vvp.exe' $out_file
}
finally {
    Pop-Location
}
