run 1800 ns
puts "T=1800 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck] clkcnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs]"
run 100 ns
puts "T=1900 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck] clkcnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs]"
quit
