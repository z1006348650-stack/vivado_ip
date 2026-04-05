run 2200 ns
puts "T=2200ns wr_cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_cmd_bit_cnt] wr_bit=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt] era_bit=[get_value /tb_flash_driver_mt25/u_core/dut/R_era_bit_cnt] state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state]"
run 200 ns
puts "T=2400ns wr_cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_cmd_bit_cnt] wr_bit=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt] era_bit=[get_value /tb_flash_driver_mt25/u_core/dut/R_era_bit_cnt] state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state]"
run 200 ns
puts "T=2600ns wr_cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_cmd_bit_cnt] wr_bit=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt] era_bit=[get_value /tb_flash_driver_mt25/u_core/dut/R_era_bit_cnt] state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state]"
quit
