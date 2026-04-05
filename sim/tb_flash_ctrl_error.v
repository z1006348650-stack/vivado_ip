`timescale 1ns / 1ps

module tb_flash_ctrl_error_core #(
    parameter integer FLASH_MODEL     = 0,
    parameter integer S25_TBPARM_TOP = 0
);

    localparam integer FLASH_MODEL_S25FL256S = 0;
    localparam integer FLASH_MODEL_MT25QL    = 1;
    localparam integer FLASH_MODEL_N25Q128A  = 2;

    localparam integer RD_DATA_MAX_LEN  = 256;
    localparam integer WR_DATA_MAX_LEN  = 256;
    localparam integer FLASH_ADDR_WIDTH = 32;
    localparam integer RD_DATA_W        = RD_DATA_MAX_LEN * 8;
    localparam integer WR_DATA_W        = WR_DATA_MAX_LEN * 8;
    localparam integer MEM_BYTES        = 2097152;
    localparam integer MAX_BEATS        = 40;
    localparam integer MAX_WAIT_CYCLES  = 200000;
    localparam [7:0] STATUS_CMD_EXPECT  = (FLASH_MODEL == FLASH_MODEL_S25FL256S) ? 8'h05 : 8'h70;

    localparam [4:0] FAIL_STAGE_ERASE_ADDR_INVALID = 5'd1;
    localparam [4:0] FAIL_STAGE_ERASE_TIMEOUT_4K   = 5'd3;
    localparam [4:0] FAIL_STAGE_ERASE_STATUS_ERROR = 5'd4;
    localparam [4:0] FAIL_STAGE_ERASE_VERIFY_ERROR = 5'd6;
    localparam [4:0] FAIL_STAGE_WRITE_STATUS_ERROR = 5'd7;
    localparam [4:0] FAIL_STAGE_WRITE_VERIFY_ERROR = 5'd8;
    localparam [4:0] FAIL_STAGE_ERASE_BUSY_NOT_SEEN = 5'd10;

    localparam [4:0] STATE_ERASE_CHECK_RD = 5'd7;
    localparam [4:0] STATE_WRITE_CHECK_RD = 5'd13;

    reg                             I_clk_in;
    reg                             I_rst_n;
    reg                             I_opt_begin;
    reg                             I_mode;
    reg  [FLASH_ADDR_WIDTH-1:0]     I_update_addr;
    reg  [31:0]                     I_bin_size;
    reg                             I_opt_busy;
    reg                             I_flash_opt_done;
    reg  [RD_DATA_W-1:0]            I_rd_data;
    reg  [7:0]                      I_rd_cmd_data;
    reg                             I_axis_tvalid;
    reg  [WR_DATA_W-1:0]            I_axis_tdata;
    reg                             I_almost_empty;

    wire [WR_DATA_W-1:0]            O_wr_data;
    wire                            O_opt_en;
    wire [3:0]                      O_opt_mode;
    wire [FLASH_ADDR_WIDTH-1:0]     O_wr_addr;
    wire [FLASH_ADDR_WIDTH-1:0]     O_rd_addr;
    wire [FLASH_ADDR_WIDTH-1:0]     O_era_addr;
    wire [7:0]                      O_rd_cmd;
    wire                            O_axis_tready;
    wire                            O_drv_opt_busy;
    wire                            O_drv_opt_ok;
    wire                            O_err;
    wire                            O_timeout_err;
    wire [4:0]                      O_last_fail_stage;

    reg  [WR_DATA_W-1:0]            R_src_data [0:MAX_BEATS-1];
    reg  [7:0]                      R_mem [0:MEM_BYTES-1];

    reg                             R_run_src;
    reg  [31:0]                     R_case_beats;
    reg  [31:0]                     R_src_idx;
    reg  [31:0]                     R_write_issue_cnt;
    reg                             R_seen_ok;
    reg                             R_seen_err;
    reg                             R_pending_valid;
    reg  [3:0]                      R_pending_mode;
    reg  [FLASH_ADDR_WIDTH-1:0]     R_pending_addr;
    reg  [7:0]                      R_pending_delay;
    reg  [7:0]                      R_erase_busy_reads;
    reg  [7:0]                      R_write_busy_reads;
    reg  [1:0]                      R_last_op_type;
    reg                             R_erase_error_latched;
    reg                             R_write_error_latched;
    reg                             R_opt_en_d;
    reg  [31:0]                     R_clear_status_count;

    reg                             R_inj_timeout_erase;
    reg                             R_inj_erase_status_error;
    reg                             R_inj_erase_busy_not_seen;
    reg                             R_inj_write_status_error;
    reg                             R_inj_erase_verify_error;
    reg                             R_inj_write_verify_error;

    wire                            W_opt_en_pos;

    reg  [4:0]                      R_cap_fail_stage;
    reg                             R_cap_timeout_err;
    reg  [31:0]                     R_cap_write_issue_cnt;
    reg                             R_cap_clear_status;
    reg                             R_cap_seen_ok;
    reg                             R_cap_seen_err;

    integer                         R_error_cnt;
    integer                         R_case_pass_cnt;
    integer                         R_error_cnt_keep;
    integer                         R_case_pass_keep;
    integer                         i;

    assign W_opt_en_pos = O_opt_en & (~R_opt_en_d);

    function [WR_DATA_W-1:0] F_build_beat;
        input [31:0] I_seed;
        integer b;
        reg [7:0] R_byte_v;
        begin
            F_build_beat = {WR_DATA_W{1'b0}};
            for (b = 0; b < WR_DATA_MAX_LEN; b = b + 1) begin
                R_byte_v = (I_seed + b) & 8'hFF;
                F_build_beat[b*8 +: 8] = R_byte_v;
            end
        end
    endfunction

    function [RD_DATA_W-1:0] F_mem_rd_block;
        input [FLASH_ADDR_WIDTH-1:0] I_addr;
        integer b;
        begin
            F_mem_rd_block = {RD_DATA_W{1'b1}};
            for (b = 0; b < RD_DATA_MAX_LEN; b = b + 1) begin
                if ((I_addr + b) < MEM_BYTES)
                    F_mem_rd_block[b*8 +: 8] = R_mem[I_addr + b];
                else
                    F_mem_rd_block[b*8 +: 8] = 8'hFF;
            end
        end
    endfunction

    function [7:0] F_status_byte;
        input I_dummy;
        reg [7:0] R_status;
        begin
            R_status = 8'h00;
            if (FLASH_MODEL == FLASH_MODEL_S25FL256S) begin
                if ((R_erase_busy_reads != 0) || (R_write_busy_reads != 0) || R_inj_timeout_erase)
                    R_status[0] = 1'b1;
                if (R_erase_error_latched)
                    R_status[5] = 1'b1;
                if (R_write_error_latched)
                    R_status[6] = 1'b1;
            end
            else begin
                R_status = 8'h80;
                if ((R_erase_busy_reads != 0) || (R_write_busy_reads != 0) || R_inj_timeout_erase)
                    R_status[7] = 1'b0;
                if (R_erase_error_latched) begin
                    R_status[5] = 1'b1;
                    R_status[1] = 1'b1;
                end
                if (R_write_error_latched) begin
                    R_status[4] = 1'b1;
                    R_status[1] = 1'b1;
                end
            end
            F_status_byte = R_status;
        end
    endfunction

    function [7:0] F_cmd_delay;
        input [3:0] I_mode_v;
        begin
            case (I_mode_v)
                4'd4: F_cmd_delay = 8'd2;
                4'd5: F_cmd_delay = 8'd3;
                4'd1: F_cmd_delay = 8'd2;
                4'd8: F_cmd_delay = 8'd1;
                4'd3: F_cmd_delay = 8'd1;
                4'd9: F_cmd_delay = 8'd1;
                default: F_cmd_delay = 8'd1;
            endcase
        end
    endfunction

    task T_mark_error;
        input [255:0] I_msg;
        begin
            R_error_cnt = R_error_cnt + 1;
            $display("[%0t] [TB][ERROR] %0s", $time, I_msg);
        end
    endtask

    task T_prepare_src_data;
        input [31:0] I_beats;
        integer k;
        begin
            for (k = 0; k < MAX_BEATS; k = k + 1)
                R_src_data[k] = {WR_DATA_W{1'b0}};
            for (k = 0; k < I_beats; k = k + 1)
                R_src_data[k] = F_build_beat(k);
        end
    endtask

    task T_mem_fill;
        input [FLASH_ADDR_WIDTH-1:0] I_addr;
        input [31:0]                 I_size;
        input [7:0]                  I_value;
        integer k;
        begin
            for (k = 0; k < I_size; k = k + 1) begin
                if ((I_addr + k) < MEM_BYTES)
                    R_mem[I_addr + k] = I_value;
            end
        end
    endtask

    task T_mem_write_beat;
        input [FLASH_ADDR_WIDTH-1:0] I_addr;
        input [WR_DATA_W-1:0]        I_data_v;
        integer b;
        begin
            for (b = 0; b < WR_DATA_MAX_LEN; b = b + 1) begin
                if ((I_addr + b) < MEM_BYTES)
                    R_mem[I_addr + b] = I_data_v[b*8 +: 8];
            end
        end
    endtask

    task T_erase_4k;
        input [FLASH_ADDR_WIDTH-1:0] I_addr;
        integer b;
        reg [FLASH_ADDR_WIDTH-1:0] R_base;
        begin
            R_base = {I_addr[31:12], 12'h000};
            for (b = 0; b < 4096; b = b + 1) begin
                if ((R_base + b) < MEM_BYTES)
                    R_mem[R_base + b] = 8'hFF;
            end
        end
    endtask

    task T_erase_64k;
        input [FLASH_ADDR_WIDTH-1:0] I_addr;
        integer b;
        reg [FLASH_ADDR_WIDTH-1:0] R_base;
        begin
            R_base = {I_addr[31:16], 16'h0000};
            for (b = 0; b < 65536; b = b + 1) begin
                if ((R_base + b) < MEM_BYTES)
                    R_mem[R_base + b] = 8'hFF;
            end
        end
    endtask

    task T_reset_dut;
        begin
            I_rst_n              = 1'b0;
            I_opt_begin          = 1'b0;
            I_mode               = 1'b0;
            I_update_addr        = {FLASH_ADDR_WIDTH{1'b0}};
            I_bin_size           = 32'd0;
            I_opt_busy           = 1'b0;
            I_flash_opt_done     = 1'b0;
            I_rd_data            = {RD_DATA_W{1'b1}};
            I_rd_cmd_data        = 8'h00;
            I_axis_tvalid        = 1'b0;
            I_axis_tdata         = {WR_DATA_W{1'b0}};
            I_almost_empty       = 1'b1;
            R_run_src            = 1'b0;
            R_case_beats         = 32'd0;
            R_src_idx            = 32'd0;
            R_write_issue_cnt    = 32'd0;
            R_seen_ok            = 1'b0;
            R_seen_err           = 1'b0;
            R_pending_valid      = 1'b0;
            R_pending_mode       = 4'd0;
            R_pending_addr       = {FLASH_ADDR_WIDTH{1'b0}};
            R_pending_delay      = 8'd0;
            R_erase_busy_reads   = 8'd0;
            R_write_busy_reads   = 8'd0;
            R_last_op_type       = 2'd0;
            R_erase_error_latched= 1'b0;
            R_write_error_latched= 1'b0;
            R_opt_en_d           = 1'b0;
            R_clear_status_count = 32'd0;
            R_inj_timeout_erase  = 1'b0;
            R_inj_erase_status_error = 1'b0;
            R_inj_erase_busy_not_seen = 1'b0;
            R_inj_write_status_error = 1'b0;
            R_inj_erase_verify_error = 1'b0;
            R_inj_write_verify_error = 1'b0;
            R_error_cnt          = 0;
            R_case_pass_cnt      = 0;
            for (i = 0; i < MEM_BYTES; i = i + 1)
                R_mem[i] = 8'hFF;
            repeat (20) @(posedge I_clk_in);
            I_rst_n = 1'b1;
            repeat (20) @(posedge I_clk_in);
        end
    endtask

    task T_reset_keep_counts;
        begin
            R_error_cnt_keep = R_error_cnt;
            R_case_pass_keep = R_case_pass_cnt;
            T_reset_dut();
            R_error_cnt = R_error_cnt_keep;
            R_case_pass_cnt = R_case_pass_keep;
        end
    endtask

    task T_start_case;
        input [FLASH_ADDR_WIDTH-1:0] I_update_addr_v;
        input [31:0]                 I_bin_size_v;
        input                        I_mode_verify_v;
        begin
            R_case_beats       = (I_bin_size_v / WR_DATA_MAX_LEN);
            if (R_case_beats > MAX_BEATS)
                T_mark_error("case beats exceed MAX_BEATS");
            T_prepare_src_data(R_case_beats);
            R_src_idx          = 32'd0;
            R_write_issue_cnt  = 32'd0;
            R_seen_ok          = 1'b0;
            R_seen_err         = 1'b0;
            R_clear_status_count = 32'd0;
            I_update_addr      = I_update_addr_v;
            I_bin_size         = I_bin_size_v;
            I_mode             = I_mode_verify_v;
            R_run_src          = 1'b1;
            @(posedge I_clk_in);
            I_opt_begin        = 1'b1;
            @(posedge I_clk_in);
            I_opt_begin        = 1'b0;
        end
    endtask

    task T_wait_expect_error;
        input [4:0]  I_expect_stage;
        input        I_expect_timeout;
        input [31:0] I_expect_write_issue_cnt;
        input        I_expect_clear_status;
        integer R_wait_cnt;
        begin
            R_wait_cnt = 0;
            while ((!R_seen_err) && (!R_seen_ok) && (R_wait_cnt < MAX_WAIT_CYCLES)) begin
                @(posedge I_clk_in);
                R_wait_cnt = R_wait_cnt + 1;
            end

            R_cap_fail_stage      = O_last_fail_stage;
            R_cap_timeout_err      = O_timeout_err;
            R_cap_write_issue_cnt  = R_write_issue_cnt;
            R_cap_clear_status     = (R_clear_status_count != 0);
            R_cap_seen_ok          = R_seen_ok;
            R_cap_seen_err         = R_seen_err;

            R_run_src     = 1'b0;
            I_axis_tvalid = 1'b0;
            repeat (8) @(posedge I_clk_in);

            if (R_wait_cnt >= MAX_WAIT_CYCLES)
                T_mark_error("error case timeout");
            if (!R_cap_seen_err)
                T_mark_error("expected O_err not seen");
            if (R_cap_seen_ok)
                T_mark_error("unexpected O_drv_opt_ok in error case");
            if (R_cap_fail_stage != I_expect_stage)
                T_mark_error("last fail stage mismatch");
            if (R_cap_timeout_err != I_expect_timeout)
                T_mark_error("timeout flag mismatch");
            if (R_cap_write_issue_cnt != I_expect_write_issue_cnt)
                T_mark_error("write issue count mismatch");
            if (I_expect_clear_status) begin
                if (!R_cap_clear_status)
                    T_mark_error("expected clear status before error path");
            end
            else begin
                if (R_cap_clear_status)
                    T_mark_error("unexpected clear status in error path");
            end

            R_case_pass_cnt = R_case_pass_cnt + 1;
            $display("[%0t] [TB][PASS] error case pass, model=%0d, stage=%0d", $time, FLASH_MODEL, I_expect_stage);
        end
    endtask

    flash_ctrl #(
        .RD_DATA_MAX_LEN          (RD_DATA_MAX_LEN),
        .WR_DATA_MAX_LEN          (WR_DATA_MAX_LEN),
        .FLASH_ADDR_WIDTH         (FLASH_ADDR_WIDTH),
        .FLASH_MODEL              (FLASH_MODEL),
        .S25_TBPARM_TOP           (S25_TBPARM_TOP),
        .ERASE_TIMEOUT_4K_CYCLES  (80),
        .ERASE_TIMEOUT_64K_CYCLES (80)
    ) dut (
        .I_clk_in                 (I_clk_in),
        .I_rst_n                  (I_rst_n),
        .I_opt_begin              (I_opt_begin),
        .I_mode                   (I_mode),
        .I_update_addr            (I_update_addr),
        .I_bin_size               (I_bin_size),
        .I_opt_busy               (I_opt_busy),
        .I_flash_opt_done         (I_flash_opt_done),
        .I_rd_data                (I_rd_data),
        .O_wr_data                (O_wr_data),
        .O_opt_en                 (O_opt_en),
        .O_opt_mode               (O_opt_mode),
        .O_wr_addr                (O_wr_addr),
        .O_rd_addr                (O_rd_addr),
        .O_era_addr               (O_era_addr),
        .I_rd_cmd_data            (I_rd_cmd_data),
        .O_rd_cmd                 (O_rd_cmd),
        .I_axis_tvalid            (I_axis_tvalid),
        .O_axis_tready            (O_axis_tready),
        .I_axis_tdata             (I_axis_tdata),
        .I_almost_empty           (I_almost_empty),
        .O_drv_opt_busy           (O_drv_opt_busy),
        .O_drv_opt_ok             (O_drv_opt_ok),
        .O_err                    (O_err),
        .O_timeout_err            (O_timeout_err),
        .O_last_fail_stage        (O_last_fail_stage)
    );

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_opt_en_d <= 1'b0;
            I_flash_opt_done <= 1'b0;
            I_rd_cmd_data <= 8'h00;
            I_rd_data <= {RD_DATA_W{1'b1}};
            R_pending_valid <= 1'b0;
            R_pending_mode  <= 4'd0;
            R_pending_addr  <= {FLASH_ADDR_WIDTH{1'b0}};
            R_pending_delay <= 8'd0;
            R_erase_busy_reads <= 8'd0;
            R_write_busy_reads <= 8'd0;
            R_last_op_type <= 2'd0;
            R_erase_error_latched <= 1'b0;
            R_write_error_latched <= 1'b0;
            R_clear_status_count <= 32'd0;
        end
        else begin
            R_opt_en_d <= O_opt_en;
            I_flash_opt_done <= 1'b0;
            if (W_opt_en_pos) begin
                R_pending_valid <= 1'b1;
                R_pending_mode  <= O_opt_mode;
                if ((O_opt_mode == 4'd4) || (O_opt_mode == 4'd5))
                    R_pending_addr <= O_era_addr;
                else if (O_opt_mode == 4'd1)
                    R_pending_addr <= O_wr_addr;
                else if (O_opt_mode == 4'd3)
                    R_pending_addr <= O_rd_addr;
                else
                    R_pending_addr <= {FLASH_ADDR_WIDTH{1'b0}};
                R_pending_delay <= F_cmd_delay(O_opt_mode);
                if (O_opt_mode == 4'd1)
                    R_write_issue_cnt <= R_write_issue_cnt + 1'b1;
            end
            else if (R_pending_valid) begin
                if (R_pending_delay != 0)
                    R_pending_delay <= R_pending_delay - 1'b1;
                else begin
                    case (R_pending_mode)
                        4'd9: begin
                            R_clear_status_count <= R_clear_status_count + 1'b1;
                            R_erase_error_latched <= 1'b0;
                            R_write_error_latched <= 1'b0;
                        end
                        4'd4: begin
                            if (!R_inj_erase_busy_not_seen)
                                T_erase_4k(R_pending_addr);
                            if (R_inj_erase_status_error)
                                R_erase_error_latched <= 1'b1;
                            R_last_op_type <= 2'd1;
                            if ((!R_inj_timeout_erase) && (!R_inj_erase_busy_not_seen))
                                R_erase_busy_reads <= 8'd2;
                        end
                        4'd5: begin
                            if (!R_inj_erase_busy_not_seen)
                                T_erase_64k(R_pending_addr);
                            if (R_inj_erase_status_error)
                                R_erase_error_latched <= 1'b1;
                            R_last_op_type <= 2'd1;
                            if ((!R_inj_timeout_erase) && (!R_inj_erase_busy_not_seen))
                                R_erase_busy_reads <= 8'd2;
                        end
                        4'd1: begin
                            T_mem_write_beat(R_pending_addr, O_wr_data);
                            if (R_inj_write_status_error)
                                R_write_error_latched <= 1'b1;
                            R_last_op_type <= 2'd2;
                            R_write_busy_reads <= 8'd1;
                        end
                        4'd3: begin
                            if ((dut.cur_state == STATE_ERASE_CHECK_RD) && R_inj_erase_verify_error)
                                I_rd_data <= {RD_DATA_W{1'b0}};
                            else if ((dut.cur_state == STATE_WRITE_CHECK_RD) && R_inj_write_verify_error)
                                I_rd_data <= {RD_DATA_W{1'b0}};
                            else
                                I_rd_data <= F_mem_rd_block(R_pending_addr);
                        end
                        4'd8: begin
                            if (O_rd_cmd != STATUS_CMD_EXPECT)
                                T_mark_error("status command mismatch");
                            I_rd_cmd_data <= F_status_byte(1'b0);
                            if (!R_inj_timeout_erase) begin
                                if (R_erase_busy_reads != 0)
                                    R_erase_busy_reads <= R_erase_busy_reads - 1'b1;
                                else if (R_write_busy_reads != 0)
                                    R_write_busy_reads <= R_write_busy_reads - 1'b1;
                            end
                        end
                        default: begin
                        end
                    endcase
                    I_flash_opt_done <= 1'b1;
                    R_pending_valid <= 1'b0;
                end
            end
        end
    end

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            I_axis_tvalid <= 1'b0;
            I_axis_tdata  <= {WR_DATA_W{1'b0}};
            I_almost_empty<= 1'b1;
            R_src_idx     <= 32'd0;
        end
        else begin
            if (R_run_src && (R_src_idx < R_case_beats)) begin
                I_axis_tvalid <= 1'b1;
                I_axis_tdata  <= R_src_data[R_src_idx];
                I_almost_empty<= ((R_case_beats - R_src_idx) <= 1);
                if (I_axis_tvalid && O_axis_tready)
                    R_src_idx <= R_src_idx + 1'b1;
            end
            else begin
                I_axis_tvalid <= 1'b0;
                I_almost_empty<= 1'b1;
            end
        end
    end

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_seen_ok  <= 1'b0;
            R_seen_err <= 1'b0;
        end
        else begin
            if (O_drv_opt_ok)
                R_seen_ok <= 1'b1;
            if (O_err)
                R_seen_err <= 1'b1;
        end
    end

    initial begin
        I_clk_in = 1'b0;
        T_reset_dut();

        T_start_case(32'h0000_0004, 32'd4096, 1'b0);
        T_wait_expect_error(FAIL_STAGE_ERASE_ADDR_INVALID, 1'b0, 32'd0, 1'b0);
        T_reset_keep_counts();

        R_inj_timeout_erase = 1'b1;
        T_start_case(32'h0000_1000, 32'd4096, 1'b0);
        T_wait_expect_error(FAIL_STAGE_ERASE_TIMEOUT_4K, 1'b1, 32'd0, (FLASH_MODEL != FLASH_MODEL_S25FL256S));
        R_inj_timeout_erase = 1'b0;
        T_reset_keep_counts();

        R_inj_erase_status_error = 1'b1;
        T_start_case(32'h0000_1000, 32'd4096, 1'b0);
        T_wait_expect_error(FAIL_STAGE_ERASE_STATUS_ERROR, 1'b0, 32'd0, (FLASH_MODEL != FLASH_MODEL_S25FL256S));
        R_inj_erase_status_error = 1'b0;
        T_reset_keep_counts();

        R_inj_erase_busy_not_seen = 1'b1;
        T_mem_fill(32'h0000_1000, 32'd4096, 8'h00);
        T_start_case(32'h0000_1000, 32'd4096, 1'b0);
        T_wait_expect_error(FAIL_STAGE_ERASE_BUSY_NOT_SEEN, 1'b0, 32'd0, (FLASH_MODEL != FLASH_MODEL_S25FL256S));
        R_inj_erase_busy_not_seen = 1'b0;
        T_reset_keep_counts();

        R_inj_write_status_error = 1'b1;
        T_mem_fill(32'h0000_1000, 32'd4096, 8'h00);
        T_start_case(32'h0000_1000, 32'd256, 1'b0);
        T_wait_expect_error(FAIL_STAGE_WRITE_STATUS_ERROR, 1'b0, 32'd1, (FLASH_MODEL != FLASH_MODEL_S25FL256S));
        R_inj_write_status_error = 1'b0;
        T_reset_keep_counts();

        R_inj_erase_verify_error = 1'b1;
        T_mem_fill(32'h0000_1000, 32'd4096, 8'h00);
        T_start_case(32'h0000_1000, 32'd4096, 1'b1);
        T_wait_expect_error(FAIL_STAGE_ERASE_VERIFY_ERROR, 1'b0, 32'd0, (FLASH_MODEL != FLASH_MODEL_S25FL256S));
        R_inj_erase_verify_error = 1'b0;
        T_reset_keep_counts();

        R_inj_write_verify_error = 1'b1;
        T_mem_fill(32'h0000_1000, 32'd4096, 8'h00);
        T_start_case(32'h0000_1000, 32'd256, 1'b1);
        T_wait_expect_error(FAIL_STAGE_WRITE_VERIFY_ERROR, 1'b0, 32'd1, (FLASH_MODEL != FLASH_MODEL_S25FL256S));
        R_inj_write_verify_error = 1'b0;

        if (R_error_cnt == 0) begin
            $display("=====================================================");
            $display("[TB][PASS] tb_flash_ctrl_error_core pass (FLASH_MODEL=%0d), case_pass=%0d", FLASH_MODEL, R_case_pass_cnt);
            $display("=====================================================");
        end
        else begin
            $display("=====================================================");
            $display("[TB][FAIL] tb_flash_ctrl_error_core fail, error_cnt=%0d, case_pass=%0d", R_error_cnt, R_case_pass_cnt);
            $display("=====================================================");
        end

        #100;
        $finish;
    end

    always #5 I_clk_in = ~I_clk_in;

endmodule

module tb_flash_ctrl_error_s25;
    tb_flash_ctrl_error_core #(
        .FLASH_MODEL     (0),
        .S25_TBPARM_TOP  (0)
    ) u_core ();
endmodule

module tb_flash_ctrl_error_mt25;
    tb_flash_ctrl_error_core #(
        .FLASH_MODEL     (1),
        .S25_TBPARM_TOP  (0)
    ) u_core ();
endmodule

module tb_flash_ctrl_error_n25q128a;
    tb_flash_ctrl_error_core #(
        .FLASH_MODEL     (2),
        .S25_TBPARM_TOP  (0)
    ) u_core ();
endmodule
