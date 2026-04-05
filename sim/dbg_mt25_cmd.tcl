run 2140 ns
puts "T=2140ns cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] cmd_valid=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_valid] cmd_shift=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_shift] cmd_latched=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_latched]"
run 10 ns
puts "T=2150ns cs=[get_value /tb_flash_driver_mt25/u_core/O_cs] cmd_valid=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_valid] cmd_shift=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_shift] cmd_latched=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_cmd_latched] last=[get_value /tb_flash_driver_mt25/u_core/W_last_cmd]"
quit
