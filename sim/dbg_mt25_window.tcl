run 2000 ns
puts "T2000 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] modelbits=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_bit_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt] cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck]"
run 50 ns
puts "T2050 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] modelbits=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_bit_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt] cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck]"
run 50 ns
puts "T2100 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] modelbits=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_bit_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt] cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck]"
run 50 ns
puts "T2150 state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] modelbits=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_bit_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt] cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck]"
quit
