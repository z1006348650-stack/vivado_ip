read_verilog G:/016-codex/0-xianyu/2-uart_fpga_update/uart_axi_bridge/src/rtl/reset_sync.v
read_verilog G:/016-codex/0-xianyu/2-uart_fpga_update/uart_axi_bridge/src/rtl/uart_rx.v
read_verilog G:/016-codex/0-xianyu/2-uart_fpga_update/uart_axi_bridge/src/rtl/uart_tx.v
read_verilog G:/016-codex/0-xianyu/2-uart_fpga_update/uart_axi_bridge/src/rtl/frame_parser.v
read_verilog G:/016-codex/0-xianyu/2-uart_fpga_update/uart_axi_bridge/src/rtl/frame_builder.v
read_verilog G:/016-codex/0-xianyu/2-uart_fpga_update/uart_axi_bridge/src/rtl/axi_lite_master.v
read_verilog G:/016-codex/0-xianyu/2-uart_fpga_update/uart_axi_bridge/src/rtl/axi_full_master.v
read_verilog G:/016-codex/0-xianyu/2-uart_fpga_update/uart_axi_bridge/src/rtl/bridge_ctrl.v
read_verilog G:/016-codex/0-xianyu/2-uart_fpga_update/uart_axi_bridge/src/rtl/uart_axi_bridge.v
synth_design -top uart_axi_bridge -part xc7a35tcsg324-1
report_utilization -file vivado_synth_utilization.rpt
report_timing_summary -file vivado_synth_timing.rpt
exit