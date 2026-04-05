run 1700 ns
puts "T=1700ns wr_cmd_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_wr_cmd_bit_cnt] wr_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_wr_bit_cnt] era_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_era_bit_cnt] state=[get_value /tb_flash_driver_s25/u_core/dut/cur_state]"
run 50 ns
puts "T=1750ns wr_cmd_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_wr_cmd_bit_cnt] wr_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_wr_bit_cnt] era_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_era_bit_cnt] state=[get_value /tb_flash_driver_s25/u_core/dut/cur_state]"
run 50 ns
puts "T=1800ns wr_cmd_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_wr_cmd_bit_cnt] wr_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_wr_bit_cnt] era_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_era_bit_cnt] state=[get_value /tb_flash_driver_s25/u_core/dut/cur_state]"
run 50 ns
puts "T=1850ns wr_cmd_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_wr_cmd_bit_cnt] wr_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_wr_bit_cnt] era_cnt=[get_value /tb_flash_driver_s25/u_core/dut/R_era_bit_cnt] state=[get_value /tb_flash_driver_s25/u_core/dut/cur_state]"
quit
