run 1600 ns
for {set i 0} {$i < 30} {incr i} {
    puts "T=[current_time] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck] mosi=[get_value /tb_flash_driver_mt25/u_core/O_data] bits=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_bit_cnt] shift=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_shift] state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] last=[get_value /tb_flash_driver_mt25/u_core/W_last_cmd]"
    run 10 ns
}
quit
