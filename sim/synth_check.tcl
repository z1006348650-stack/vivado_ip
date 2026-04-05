set script_dir [file normalize [file dirname [info script]]]
set repo_dir   [file normalize [file dirname $script_dir]]
set src_dir    [file join $repo_dir src]
set hdl_dir    [file join $repo_dir hdl]
set inc_dir    [file join $src_dir axis_data_fifo_4bytes hdl]

create_project synth_check $script_dir -part xc7k325tffg676-2 -in_memory
set_property XPM_LIBRARIES [list XPM_CDC XPM_FIFO XPM_MEMORY] [current_project]

add_files [list \
    [file join $hdl_dir axi_multiboot_driver_v1_0_S00_AXI.v] \
    [file join $hdl_dir axi_multiboot_driver_v1_0.v] \
    [file join $src_dir cmd_decoder.v] \
    [file join $src_dir flash_ctrl.v] \
    [file join $src_dir flash_driver.v] \
    [file join $src_dir flash_top.v] \
    [file join $src_dir icap_jump.v] \
    [file join $src_dir startup_bridge.v] \
    [file join $src_dir axis_data_fifo_4bytes hdl axis_infrastructure_v1_1_vl_rfs.v] \
    [file join $src_dir axis_data_fifo_4bytes hdl axis_data_fifo_v2_0_vl_rfs.v] \
    [file join $src_dir axis_data_fifo_4bytes synth axis_data_fifo_4bytes.v] \
]

set_property include_dirs [list $inc_dir] [current_fileset]
set_property top axi_multiboot_driver_v1_0 [current_fileset]
update_compile_order -fileset sources_1

synth_design -top axi_multiboot_driver_v1_0 -part xc7k325tffg676-2 -mode out_of_context
report_utilization -file [file join $script_dir synth_utilization.rpt]
report_timing_summary -file [file join $script_dir synth_timing.rpt]
