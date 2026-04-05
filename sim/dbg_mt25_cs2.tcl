run 2200 ns
puts "T2200 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt]"
run 100 ns
puts "T2300 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt]"
run 100 ns
puts "T2400 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt] last=[get_value /tb_flash_driver_mt25/u_core/W_last_cmd] modelbits=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_bit_cnt] shift=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_shift]"
quit
