`timescale 1ns / 1ps

module tb_flash_ctrl_noloss_core #(
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
    localparam integer MAX_BEATS        = 320;
    localparam integer MAX_WAIT_CYCLES  = 1200000;
    localparam [7:0] STATUS_CMD_EXPECT  = (FLASH_MODEL == FLASH_MODEL_S25FL256S) ? 8'h05 : 8'h70;

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

    reg  [WR_DATA_W-1:0]            R_exp_data [0:MAX_BEATS-1];
    reg  [7:0]                      R_mem [0:MEM_BYTES-1];

    reg                             R_run_src;
    reg  [31:0]                     R_case_beats;
    reg  [31:0]                     R_src_idx;
    reg  [31:0]                     R_axis_fire_cnt;
    reg                             R_seen_ok;
    reg                             R_seen_err;
    reg  [31:0]                     R_wr_cnt_at_done;
    reg  [31:0]                     R_wr_chk_cnt_at_done;
    reg                             R_done_snapshot_valid;
    reg                             R_first_opt_mode_valid;
    reg  [3:0]                      R_first_opt_mode;
    reg  [31:0]                     R_clear_status_count;
    reg  [31:0]                     R_clear_status_count_start;
    reg  [31:0]                     R_erase_4k_count;
    reg  [31:0]                     R_erase_64k_count;
    reg  [31:0]                     R_erase_4k_count_start;
    reg  [31:0]                     R_erase_64k_count_start;

    reg                             R_pending_valid;
    reg  [3:0]                      R_pending_mode;
    reg  [FLASH_ADDR_WIDTH-1:0]     R_pending_addr;
    reg  [7:0]                      R_pending_delay;
    reg  [7:0]                      R_erase_busy_reads;
    reg  [7:0]                      R_write_busy_reads;
    reg                             R_erase_error_latched;
    reg                             R_write_error_latched;

    reg                             R_opt_en_d;
    wire                            W_opt_en_pos;

    integer                         R_error_cnt;
    integer                         R_case_pass_cnt;
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
                if (R_erase_busy_reads != 0 || R_write_busy_reads != 0)
                    R_status[0] = 1'b1;
                if (R_erase_error_latched)
                    R_status[5] = 1'b1;
                if (R_write_error_latched)
                    R_status[6] = 1'b1;
            end
            else begin
                R_status = 8'h80;
                if (R_erase_busy_reads != 0 || R_write_busy_reads != 0)
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

    task T_prepare_case_data;
        input [31:0] I_beats;
        input [31:0] I_seed;
        integer k;
        begin
            for (k = 0; k < MAX_BEATS; k = k + 1)
                R_exp_data[k] = {WR_DATA_W{1'b0}};
            for (k = 0; k < I_beats; k = k + 1)
                R_exp_data[k] = F_build_beat(I_seed + k);
        end
    endtask

    task T_check_payload;
        input [FLASH_ADDR_WIDTH-1:0] I_base_addr;
        input [31:0]                 I_beats;
        integer beat_idx;
        integer byte_idx;
        reg [7:0] R_expect_byte;
        begin
            for (beat_idx = 0; beat_idx < I_beats; beat_idx = beat_idx + 1) begin
                for (byte_idx = 0; byte_idx < WR_DATA_MAX_LEN; byte_idx = byte_idx + 1) begin
                    R_expect_byte = R_exp_data[beat_idx][byte_idx*8 +: 8];
                    if (R_mem[I_base_addr + beat_idx*WR_DATA_MAX_LEN + byte_idx] != R_expect_byte)
                        T_mark_error("payload memory mismatch");
                end
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
            R_axis_fire_cnt      = 32'd0;
            R_seen_ok            = 1'b0;
            R_seen_err           = 1'b0;
            R_wr_cnt_at_done     = 32'd0;
            R_wr_chk_cnt_at_done = 32'd0;
            R_done_snapshot_valid= 1'b0;
            R_first_opt_mode_valid = 1'b0;
            R_first_opt_mode     = 4'd0;
            R_clear_status_count = 32'd0;
            R_clear_status_count_start = 32'd0;
            R_erase_4k_count     = 32'd0;
            R_erase_64k_count    = 32'd0;
            R_erase_4k_count_start = 32'd0;
            R_erase_64k_count_start = 32'd0;
            R_pending_valid      = 1'b0;
            R_pending_mode       = 4'd0;
            R_pending_addr       = {FLASH_ADDR_WIDTH{1'b0}};
            R_pending_delay      = 8'd0;
            R_erase_busy_reads   = 8'd0;
            R_write_busy_reads   = 8'd0;
            R_erase_error_latched= 1'b0;
            R_write_error_latched= 1'b0;
            R_opt_en_d           = 1'b0;
            R_error_cnt          = 0;
            R_case_pass_cnt      = 0;
            for (i = 0; i < MEM_BYTES; i = i + 1)
                R_mem[i] = 8'hFF;
            repeat (20) @(posedge I_clk_in);
            I_rst_n = 1'b1;
            repeat (20) @(posedge I_clk_in);
        end
    endtask

    task T_run_one_case;
        input [FLASH_ADDR_WIDTH-1:0] I_update_addr_v;
        input [31:0]                 I_bin_size_v;
        input [31:0]                 I_seed_v;
        input                        I_mode_verify_v;
        input [31:0]                 I_expect_erase4k_delta;
        input [31:0]                 I_expect_erase64k_delta;
        integer R_wait_cnt;
        begin
            if ((I_bin_size_v % WR_DATA_MAX_LEN) != 0)
                T_mark_error("bin size is not multiple of WR_DATA_MAX_LEN");

            R_case_beats          = (I_bin_size_v / WR_DATA_MAX_LEN);
            R_src_idx             = 32'd0;
            R_axis_fire_cnt       = 32'd0;
            R_seen_ok             = 1'b0;
            R_seen_err            = 1'b0;
            R_done_snapshot_valid = 1'b0;
            R_first_opt_mode_valid = 1'b0;
            R_first_opt_mode      = 4'd0;
            R_clear_status_count_start = R_clear_status_count;
            R_erase_4k_count_start = R_erase_4k_count;
            R_erase_64k_count_start = R_erase_64k_count;
            T_prepare_case_data(R_case_beats, I_seed_v);
            T_mem_fill(I_update_addr_v, I_bin_size_v + 32'd256, 8'h00);

            I_update_addr = I_update_addr_v;
            I_bin_size    = I_bin_size_v;
            I_mode        = I_mode_verify_v;
            R_run_src     = 1'b1;
            @(posedge I_clk_in);
            I_opt_begin   = 1'b1;
            @(posedge I_clk_in);
            I_opt_begin   = 1'b0;

            R_wait_cnt = 0;
            while ((!R_seen_ok) && (!R_seen_err) && (R_wait_cnt < MAX_WAIT_CYCLES)) begin
                @(posedge I_clk_in);
                R_wait_cnt = R_wait_cnt + 1;
            end

            R_run_src      = 1'b0;
            I_axis_tvalid  = 1'b0;
            repeat (10) @(posedge I_clk_in);

            if (R_wait_cnt >= MAX_WAIT_CYCLES)
                T_mark_error("case timeout");
            if (R_seen_err)
                T_mark_error("unexpected O_err in noloss case");
            if (!R_seen_ok)
                T_mark_error("O_drv_opt_ok not seen");
            if (O_timeout_err)
                T_mark_error("unexpected timeout flag");
            if (O_last_fail_stage != 5'd0)
                T_mark_error("unexpected last fail stage");
            if (R_axis_fire_cnt != R_case_beats)
                T_mark_error("axis fire count mismatch");
            if (!R_done_snapshot_valid)
                T_mark_error("done snapshot missing");
            else begin
                if (R_wr_cnt_at_done != R_case_beats)
                    T_mark_error("write count mismatch");
                if (I_mode_verify_v) begin
                    if (R_wr_chk_cnt_at_done != R_case_beats)
                        T_mark_error("write check count mismatch");
                end
                else begin
                    if (R_wr_chk_cnt_at_done != 0)
                        T_mark_error("write check count should stay zero");
                end
            end

            if (FLASH_MODEL == FLASH_MODEL_S25FL256S) begin
                if (R_clear_status_count != R_clear_status_count_start)
                    T_mark_error("S25 should not issue clear status");
                if (R_first_opt_mode == 4'd9)
                    T_mark_error("S25 first mode should not be clear status");
            end
            else begin
                if (R_clear_status_count != (R_clear_status_count_start + 1'b1))
                    T_mark_error("Micron path clear status count mismatch");
                if ((!R_first_opt_mode_valid) || (R_first_opt_mode != 4'd9))
                    T_mark_error("Micron path first mode should be clear status");
            end

            if ((R_erase_4k_count - R_erase_4k_count_start) != I_expect_erase4k_delta)
                T_mark_error("erase 4k count delta mismatch");
            if ((R_erase_64k_count - R_erase_64k_count_start) != I_expect_erase64k_delta)
                T_mark_error("erase 64k count delta mismatch");

            T_check_payload(I_update_addr_v, R_case_beats);
            R_case_pass_cnt = R_case_pass_cnt + 1;
            $display("[%0t] [TB][PASS] noloss case pass, model=%0d, addr=0x%08h, size=%0d, verify=%0d", $time, FLASH_MODEL, I_update_addr_v, I_bin_size_v, I_mode_verify_v);
        end
    endtask

    flash_ctrl #(
        .RD_DATA_MAX_LEN          (RD_DATA_MAX_LEN),
        .WR_DATA_MAX_LEN          (WR_DATA_MAX_LEN),
        .FLASH_ADDR_WIDTH         (FLASH_ADDR_WIDTH),
        .FLASH_MODEL              (FLASH_MODEL),
        .S25_TBPARM_TOP           (S25_TBPARM_TOP),
        .ERASE_TIMEOUT_4K_CYCLES  (200000),
        .ERASE_TIMEOUT_64K_CYCLES (300000)
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
            R_erase_error_latched <= 1'b0;
            R_write_error_latched <= 1'b0;
        end
        else begin
            R_opt_en_d <= O_opt_en;
            I_flash_opt_done <= 1'b0;
            if (W_opt_en_pos) begin
                R_pending_valid <= 1'b1;
                R_pending_mode  <= O_opt_mode;
                if (O_opt_mode == 4'd4)
                    R_pending_addr <= O_era_addr;
                else if (O_opt_mode == 4'd5)
                    R_pending_addr <= O_era_addr;
                else if (O_opt_mode == 4'd1)
                    R_pending_addr <= O_wr_addr;
                else if (O_opt_mode == 4'd3)
                    R_pending_addr <= O_rd_addr;
                else
                    R_pending_addr <= {FLASH_ADDR_WIDTH{1'b0}};
                R_pending_delay <= F_cmd_delay(O_opt_mode);

                if (!R_first_opt_mode_valid) begin
                    R_first_opt_mode_valid <= 1'b1;
                    R_first_opt_mode <= O_opt_mode;
                end
                if (O_opt_mode == 4'd4)
                    R_erase_4k_count <= R_erase_4k_count + 1'b1;
                else if (O_opt_mode == 4'd5)
                    R_erase_64k_count <= R_erase_64k_count + 1'b1;
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
                            T_erase_4k(R_pending_addr);
                            R_erase_busy_reads <= 8'd2;
                        end
                        4'd5: begin
                            T_erase_64k(R_pending_addr);
                            R_erase_busy_reads <= 8'd3;
                        end
                        4'd1: begin
                            T_mem_write_beat(R_pending_addr, O_wr_data);
                            R_write_busy_reads <= 8'd2;
                        end
                        4'd3: begin
                            I_rd_data <= F_mem_rd_block(R_pending_addr);
                        end
                        4'd8: begin
                            if (O_rd_cmd != STATUS_CMD_EXPECT)
                                T_mark_error("status command mismatch");
                            I_rd_cmd_data <= F_status_byte(1'b0);
                            if (R_erase_busy_reads != 0)
                                R_erase_busy_reads <= R_erase_busy_reads - 1'b1;
                            else if (R_write_busy_reads != 0)
                                R_write_busy_reads <= R_write_busy_reads - 1'b1;
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
            R_axis_fire_cnt <= 32'd0;
        end
        else begin
            if (R_run_src && (R_src_idx < R_case_beats)) begin
                I_axis_tvalid <= 1'b1;
                I_axis_tdata  <= R_exp_data[R_src_idx];
                I_almost_empty<= ((R_case_beats - R_src_idx) <= 1);
                if (I_axis_tvalid && O_axis_tready) begin
                    R_src_idx <= R_src_idx + 1'b1;
                    R_axis_fire_cnt <= R_axis_fire_cnt + 1'b1;
                end
            end
            else begin
                I_axis_tvalid <= 1'b0;
                I_almost_empty<= 1'b1;
            end
        end
    end

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_seen_ok <= 1'b0;
            R_seen_err <= 1'b0;
            R_wr_cnt_at_done <= 32'd0;
            R_wr_chk_cnt_at_done <= 32'd0;
            R_done_snapshot_valid <= 1'b0;
        end
        else begin
            if (O_drv_opt_ok) begin
                R_seen_ok <= 1'b1;
                R_wr_cnt_at_done <= dut.R_wr_cnt;
                R_wr_chk_cnt_at_done <= dut.R_wr_chk_cnt;
                R_done_snapshot_valid <= 1'b1;
            end
            if (O_err)
                R_seen_err <= 1'b1;
        end
    end

    initial begin
        I_clk_in = 1'b0;
        T_reset_dut();

        T_run_one_case(32'h0000_1000, 32'd4096, 32'h11, 1'b0, 32'd1, 32'd0);
        T_run_one_case(32'h0002_0000, 32'd65536, 32'h33, 1'b1, 32'd0, 32'd1);

        if (FLASH_MODEL == FLASH_MODEL_S25FL256S)
            T_run_one_case(32'h0001_F000, 32'd8192, 32'h55, 1'b1, 32'd1, 32'd1);
        else
            T_run_one_case(32'h0000_F000, 32'd69632, 32'h77, 1'b1, 32'd1, 32'd1);

        if (R_error_cnt == 0) begin
            $display("=====================================================");
            $display("[TB][PASS] tb_flash_ctrl_noloss_core pass (FLASH_MODEL=%0d), case_pass=%0d", FLASH_MODEL, R_case_pass_cnt);
            $display("=====================================================");
        end
        else begin
            $display("=====================================================");
            $display("[TB][FAIL] tb_flash_ctrl_noloss_core fail, error_cnt=%0d, case_pass=%0d", R_error_cnt, R_case_pass_cnt);
            $display("=====================================================");
        end

        #100;
        $finish;
    end

    always #5 I_clk_in = ~I_clk_in;

endmodule

module tb_flash_ctrl_noloss_s25;
    tb_flash_ctrl_noloss_core #(
        .FLASH_MODEL     (0),
        .S25_TBPARM_TOP  (0)
    ) u_core ();
endmodule

module tb_flash_ctrl_noloss_mt25;
    tb_flash_ctrl_noloss_core #(
        .FLASH_MODEL     (1),
        .S25_TBPARM_TOP  (0)
    ) u_core ();
endmodule

module tb_flash_ctrl_noloss_n25q128a;
    tb_flash_ctrl_noloss_core #(
        .FLASH_MODEL     (2),
        .S25_TBPARM_TOP  (0)
    ) u_core ();
endmodule
