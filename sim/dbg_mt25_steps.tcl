run 2500 ns
puts "T=2500ns LAST_CMD=[get_value /tb_flash_driver_mt25/u_core/W_last_cmd] WEL=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_wel] STATE=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state]"
run 1000 ns
puts "T=3500ns LAST_CMD=[get_value /tb_flash_driver_mt25/u_core/W_last_cmd] WEL=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_wel] STATE=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state]"
run 1000 ns
puts "T=4500ns LAST_CMD=[get_value /tb_flash_driver_mt25/u_core/W_last_cmd] WEL=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_wel] STATE=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state]"
run 2000 ns
puts "T=6500ns LAST_CMD=[get_value /tb_flash_driver_mt25/u_core/W_last_cmd] WEL=[get_value /tb_flash_driver_mt25/u_core/u_flash_model/R_wel] STATE=[get_value /tb_flash_driver_mt25/u_core/dut/cur_state]"
quit
