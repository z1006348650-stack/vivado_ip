run 2095 ns
puts "T=2095 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck]"
run 50 ns
puts "T=2145 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck] last=[get_value /tb_flash_driver_mt25/u_core/W_last_cmd]"
quit
