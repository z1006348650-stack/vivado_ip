proc snap {tag} {
    puts "$tag stage=[get_value /tb_flash_ctrl_error_mt25/u_core/O_last_fail_stage] timeout=[get_value /tb_flash_ctrl_error_mt25/u_core/O_timeout_err] write_issue=[get_value /tb_flash_ctrl_error_mt25/u_core/R_write_issue_cnt] clear_status=[get_value /tb_flash_ctrl_error_mt25/u_core/R_clear_status_count] seen_ok=[get_value /tb_flash_ctrl_error_mt25/u_core/R_seen_ok] seen_err=[get_value /tb_flash_ctrl_error_mt25/u_core/R_seen_err] state=[get_value /tb_flash_ctrl_error_mt25/u_core/dut/cur_state]"
}
run 530 ns
snap CASE1
run 100 ns
snap CASE2
run 320 ns
snap CASE3
run 100 ns
snap CASE4
run 380 ns
snap CASE5
run 100 ns
snap CASE6
quit
