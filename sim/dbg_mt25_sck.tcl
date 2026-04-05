run 2080 ns
puts "T=2080 cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck] clkcnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] model_bits=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_bit_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt]"
run 10 ns
puts "T=2090 cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck] clkcnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] model_bits=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_bit_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt]"
run 10 ns
puts "T=2100 cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] sck=[get_value /tb_flash_driver_mt25/u_core/O_sck] clkcnt=[get_value /tb_flash_driver_mt25/u_core/dut/R_clk_cnt] model_bits=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_bit_cnt] wr=[get_value /tb_flash_driver_mt25/u_core/dut/R_wr_bit_cnt]"
quit
