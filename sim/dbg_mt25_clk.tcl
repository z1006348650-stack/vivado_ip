run 2000 ns
puts "T=2000ns cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt]"
run 10 ns
puts "T=2010ns cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt]"
run 40 ns
puts "T=2050ns cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt]"
run 50 ns
puts "T=2100ns cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt]"
run 50 ns
puts "T=2150ns cnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] state=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt]"
quit
