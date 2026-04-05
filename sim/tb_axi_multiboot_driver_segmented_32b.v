`timescale 1ns / 1ps

module tb_axi_multiboot_driver_segmented_32b_core #(
    parameter integer FLASH_MODEL             = 0,
    parameter integer FPGA_FAMILY            = 0,
    parameter integer MULTIBOOT_ADDR_SHIFT   = 0,
    parameter integer TB_FLASH_MEM_BYTES     = 6291456,
    parameter integer TB_BUSY_POLLS_PP       = 2,
    parameter integer TB_BUSY_POLLS_ERASE_4K = 4,
    parameter integer TB_BUSY_POLLS_ERASE_64K= 8
);

    localparam integer FLASH_MODEL_S25FL256S = 0;
    localparam integer C_S00_AXI_DATA_WIDTH  = 32;
    localparam integer C_S00_AXI_ADDR_WIDTH  = 5;
    localparam integer SYS_CLK_FREQ          = 100000000;
    localparam integer FLASH_CLK_FREQ        = 10000000;
    localparam integer RD_DATA_MAX_LEN       = 32;
    localparam integer WR_DATA_MAX_LEN       = 32;
    localparam integer FLASH_ADDR_WIDTH      = 32;
    localparam [31:0] UPDATE_BASE_ADDR       = 32'h0050_0000;
    localparam [31:0] DEVICE_ID              = 32'h0363_1093;
    localparam integer WR_DATA_W             = WR_DATA_MAX_LEN * 8;
    localparam integer MAX_WAIT_CYCLES       = 500000;
    localparam [31:0] FIRST_SEG_ADDR         = 32'h0050_0000;
    localparam [31:0] SECOND_SEG_ADDR        = 32'h0054_0000;
    localparam [31:0] FIRST_SEG_BEATS        = 32'd4;
    localparam [31:0] SECOND_SEG_BEATS       = 32'd3;
    localparam [31:0] SECOND_SEG_RAW_BYTES   = 32'd81;

    reg                         s_axis_tvalid;
    wire                        s_axis_tready;
    reg  [WR_DATA_W-1:0]        s_axis_tdata;
    wire                        I_data;
    reg                         I_icap_en;
    wire                        O_cs;
    wire                        O_data;

    reg                         s00_axi_aclk;
    reg                         s00_axi_aresetn;
    reg  [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_awaddr;
    reg  [2:0]                  s00_axi_awprot;
    reg                         s00_axi_awvalid;
    wire                        s00_axi_awready;
    reg  [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_wdata;
    reg  [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb;
    reg                         s00_axi_wvalid;
    wire                        s00_axi_wready;
    wire [1:0]                  s00_axi_bresp;
    wire                        s00_axi_bvalid;
    reg                         s00_axi_bready;
    reg  [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_araddr;
    reg  [2:0]                  s00_axi_arprot;
    reg                         s00_axi_arvalid;
    wire                        s00_axi_arready;
    wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_rdata;
    wire [1:0]                  s00_axi_rresp;
    wire                        s00_axi_rvalid;
    reg                         s00_axi_rready;

    reg                         R_run_stream;
    reg  [31:0]                 R_total_beats;
    reg  [31:0]                 R_sent_beats;
    reg  [31:0]                 R_stream_seed;
    integer                     R_error_cnt;
    reg  [31:0]                 R_read_data;
    reg                         R_seen_icap_done;
    reg  [31:0]                 R_wr_cnt_at_done;
    reg                         R_wr_cnt_done_valid;
    reg  [31:0]                 R_wr_chk_cnt_at_done;
    reg                         R_wr_chk_cnt_done_valid;
    reg  [31:0]                 R_clear_status_start;

    wire [7:0]                  W_last_cmd;
    wire [31:0]                 W_last_addr;
    wire [2:0]                  W_last_addr_bytes;
    wire [31:0]                 W_clear_status_count;
    wire [31:0]                 W_pp_count;
    wire [31:0]                 W_erase_4k_count;
    wire [31:0]                 W_erase_64k_count;

    function [WR_DATA_W-1:0] F_axis_data;
        input [31:0] I_idx;
        integer byte_idx;
        reg [WR_DATA_W-1:0] R_temp_data;
        reg [7:0] R_temp_byte;
        begin
            R_temp_data = {WR_DATA_W{1'b0}};
            for (byte_idx = 0; byte_idx < WR_DATA_MAX_LEN; byte_idx = byte_idx + 1) begin
                R_temp_byte = (I_idx + byte_idx) & 8'hFF;
                R_temp_data[((WR_DATA_MAX_LEN - byte_idx) * 8) - 1 -: 8] = R_temp_byte;
            end
            F_axis_data = R_temp_data;
        end
    endfunction

    task T_mark_error;
        input [255:0] I_msg;
        begin
            R_error_cnt = R_error_cnt + 1;
            $display("[%0t] [TB][ERROR] %0s", $time, I_msg);
        end
    endtask

    task T_axi_write;
        input [31:0] I_addr;
        input [31:0] I_data_v;
        begin
            @(posedge s00_axi_aclk);
            s00_axi_awaddr  <= I_addr[C_S00_AXI_ADDR_WIDTH-1:0];
            s00_axi_wdata   <= I_data_v;
            s00_axi_awvalid <= 1'b1;
            s00_axi_wvalid  <= 1'b1;
            s00_axi_bready  <= 1'b1;
            while (!(s00_axi_awready && s00_axi_wready))
                @(posedge s00_axi_aclk);
            @(posedge s00_axi_aclk);
            s00_axi_awvalid <= 1'b0;
            s00_axi_wvalid  <= 1'b0;
            while (!s00_axi_bvalid)
                @(posedge s00_axi_aclk);
            @(posedge s00_axi_aclk);
            s00_axi_bready  <= 1'b0;
        end
    endtask

    task T_axi_read;
        input  [31:0] I_addr;
        output [31:0] O_data_v;
        begin
            @(posedge s00_axi_aclk);
            s00_axi_araddr  <= I_addr[C_S00_AXI_ADDR_WIDTH-1:0];
            s00_axi_arvalid <= 1'b1;
            s00_axi_rready  <= 1'b1;
            while (!s00_axi_arready)
                @(posedge s00_axi_aclk);
            @(posedge s00_axi_aclk);
            s00_axi_arvalid <= 1'b0;
            while (!s00_axi_rvalid)
                @(posedge s00_axi_aclk);
            O_data_v = s00_axi_rdata;
            @(posedge s00_axi_aclk);
            s00_axi_rready <= 1'b0;
        end
    endtask

    task T_issue_icap_jump;
        input [31:0] I_update_addr_v;
        begin
            T_axi_write(32'h0000_0008, I_update_addr_v);
            T_axi_write(32'h0000_0000, 32'h0000_0000);
            T_axi_write(32'h0000_0000, 32'h0000_8001);
        end
    endtask

    task T_issue_flash_ctrl;
        input [31:0] I_update_addr_v;
        input [31:0] I_bin_size_v;
        input        I_mode_verify_v;
        begin
            T_axi_write(32'h0000_0008, I_update_addr_v);
            T_axi_write(32'h0000_000C, I_bin_size_v);
            T_axi_write(32'h0000_0010, {31'd0, I_mode_verify_v});
            T_axi_write(32'h0000_0000, 32'h0000_0000);
            T_axi_write(32'h0000_0000, 32'h0000_4001);
        end
    endtask

    task T_issue_flash_reset;
        begin
            T_axi_write(32'h0000_0000, 32'h0000_0000);
            T_axi_write(32'h0000_0000, 32'h0000_2001);
        end
    endtask

    task T_check_flash_bytes;
        input [31:0] I_base_addr;
        input [31:0] I_beats;
        input [31:0] I_seed;
        integer beat_idx;
        integer byte_idx;
        integer mismatch_cnt;
        reg [7:0] R_expect_byte;
        reg [7:0] R_actual_byte;
        begin
            mismatch_cnt = 0;
            for (beat_idx = 0; beat_idx < I_beats; beat_idx = beat_idx + 1) begin
                for (byte_idx = 0; byte_idx < WR_DATA_MAX_LEN; byte_idx = byte_idx + 1) begin
                    R_expect_byte = (I_seed + beat_idx + byte_idx) & 8'hFF;
                    R_actual_byte = u_spi_flash_model.R_mem[I_base_addr + beat_idx*WR_DATA_MAX_LEN + byte_idx];
                    if (R_actual_byte != R_expect_byte) begin
                        if (mismatch_cnt < 8) begin
                            $display("[%0t] [TB][INFO] payload mismatch addr=0x%08h beat=%0d byte=%0d expect=0x%02h actual=0x%02h", $time, (I_base_addr + beat_idx*WR_DATA_MAX_LEN + byte_idx), beat_idx, byte_idx, R_expect_byte, R_actual_byte);
                        end
                        mismatch_cnt = mismatch_cnt + 1;
                        T_mark_error("flash memory payload mismatch");
                    end
                end
            end
        end
    endtask

    task T_wait_flash_done_and_check;
        input [31:0] I_expect_beats;
        input        I_mode_verify_v;
        input [31:0] I_update_addr_v;
        input [31:0] I_seed_v;
        reg [31:0] R_wait_cnt;
        begin
            R_wait_cnt = 32'd0;
            while ((!dut.W_drv_opt_ok) && (!dut.W_err) && (R_wait_cnt < MAX_WAIT_CYCLES)) begin
                @(posedge s00_axi_aclk);
                R_wait_cnt = R_wait_cnt + 1'b1;
            end

            if (R_wait_cnt >= MAX_WAIT_CYCLES)
                T_mark_error("flash ctrl timeout");
            if (dut.W_err)
                T_mark_error("flash ctrl error flag asserted");
            if (!dut.W_drv_opt_ok)
                T_mark_error("flash ctrl done flag not seen");

            T_axi_read(32'h0000_0004, R_read_data);
            if (R_read_data[7:0] != 8'h55)
                T_mark_error("feedback register != 0x55");
            if (R_read_data[10:8] != 3'b000)
                T_mark_error("feedback register error bits should be zero");
            if (R_read_data[15:11] != 5'd0)
                T_mark_error("feedback register last_fail_stage should be zero");
            if (!R_wr_cnt_done_valid)
                T_mark_error("R_wr_cnt snapshot missing");
            else if (R_wr_cnt_at_done != I_expect_beats)
                T_mark_error("R_wr_cnt mismatch");
            if (!R_wr_chk_cnt_done_valid)
                T_mark_error("R_wr_chk_cnt snapshot missing");
            else if (I_mode_verify_v && (R_wr_chk_cnt_at_done != I_expect_beats))
                T_mark_error("R_wr_chk_cnt mismatch in verify mode");
            else if ((!I_mode_verify_v) && (R_wr_chk_cnt_at_done != 0))
                T_mark_error("R_wr_chk_cnt should be zero in no-verify mode");
            if (R_sent_beats != I_expect_beats)
                T_mark_error("AXIS sent beat count mismatch");

            if (FLASH_MODEL == FLASH_MODEL_S25FL256S) begin
                if (W_clear_status_count != R_clear_status_start)
                    T_mark_error("S25 path should not issue clear status");
            end
            else begin
                if (W_clear_status_count != (R_clear_status_start + 1'b1))
                    T_mark_error("Micron path clear status count mismatch");
            end

            T_check_flash_bytes(I_update_addr_v, I_expect_beats, I_seed_v);
        end
    endtask

    tb_spi_flash_model #(
        .FLASH_MODEL             (FLASH_MODEL),
        .MEM_BYTES               (TB_FLASH_MEM_BYTES),
        .P_BUSY_POLLS_PP         (TB_BUSY_POLLS_PP),
        .P_BUSY_POLLS_ERASE_4K   (TB_BUSY_POLLS_ERASE_4K),
        .P_BUSY_POLLS_ERASE_64K  (TB_BUSY_POLLS_ERASE_64K)
    ) u_spi_flash_model (
        .I_rst_n                 (s00_axi_aresetn),
        .I_cs_n                  (O_cs),
        .I_sck                   (dut.W_sck),
        .I_mosi                  (O_data),
        .O_miso                  (I_data),
        .O_last_cmd              (W_last_cmd),
        .O_last_addr             (W_last_addr),
        .O_last_addr_bytes       (W_last_addr_bytes),
        .O_clear_status_count    (W_clear_status_count),
        .O_pp_count              (W_pp_count),
        .O_erase_4k_count        (W_erase_4k_count),
        .O_erase_64k_count       (W_erase_64k_count)
    );

    axi_multiboot_driver_v1_0 #(
        .C_S00_AXI_DATA_WIDTH      (C_S00_AXI_DATA_WIDTH),
        .C_S00_AXI_ADDR_WIDTH      (C_S00_AXI_ADDR_WIDTH),
        .SYS_CLK_FREQ              (SYS_CLK_FREQ),
        .FLASH_CLK_FREQ            (FLASH_CLK_FREQ),
        .RD_DATA_MAX_LEN           (RD_DATA_MAX_LEN),
        .WR_DATA_MAX_LEN           (WR_DATA_MAX_LEN),
        .FLASH_ADDR_WIDTH          (FLASH_ADDR_WIDTH),
        .UPDATE_BASE_ADDR          (UPDATE_BASE_ADDR),
        .DEVICE_ID                 (DEVICE_ID),
        .FPGA_FAMILY               (FPGA_FAMILY),
        .MULTIBOOT_ADDR_SHIFT      (MULTIBOOT_ADDR_SHIFT),
        .FLASH_MODEL               (FLASH_MODEL),
        .S25_TBPARM_TOP            (0),
        .ERASE_TIMEOUT_4K_CYCLES   (200000),
        .ERASE_TIMEOUT_64K_CYCLES  (300000)
    ) dut (
        .s_axis_tvalid             (s_axis_tvalid),
        .s_axis_tready             (s_axis_tready),
        .s_axis_tdata              (s_axis_tdata),
        .I_data                    (I_data),
        .I_icap_en                 (I_icap_en),
        .O_cs                      (O_cs),
        .O_data                    (O_data),
        .s00_axi_aclk              (s00_axi_aclk),
        .s00_axi_aresetn           (s00_axi_aresetn),
        .s00_axi_awaddr            (s00_axi_awaddr),
        .s00_axi_awprot            (s00_axi_awprot),
        .s00_axi_awvalid           (s00_axi_awvalid),
        .s00_axi_awready           (s00_axi_awready),
        .s00_axi_wdata             (s00_axi_wdata),
        .s00_axi_wstrb             (s00_axi_wstrb),
        .s00_axi_wvalid            (s00_axi_wvalid),
        .s00_axi_wready            (s00_axi_wready),
        .s00_axi_bresp             (s00_axi_bresp),
        .s00_axi_bvalid            (s00_axi_bvalid),
        .s00_axi_bready            (s00_axi_bready),
        .s00_axi_araddr            (s00_axi_araddr),
        .s00_axi_arprot            (s00_axi_arprot),
        .s00_axi_arvalid           (s00_axi_arvalid),
        .s00_axi_arready           (s00_axi_arready),
        .s00_axi_rdata             (s00_axi_rdata),
        .s00_axi_rresp             (s00_axi_rresp),
        .s00_axi_rvalid            (s00_axi_rvalid),
        .s00_axi_rready            (s00_axi_rready)
    );

    always @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
        if (!s00_axi_aresetn) begin
            s_axis_tvalid <= 1'b0;
            s_axis_tdata  <= {WR_DATA_W{1'b0}};
            R_sent_beats  <= 32'd0;
        end
        else begin
            if (!R_run_stream) begin
                s_axis_tvalid <= 1'b0;
                s_axis_tdata  <= {WR_DATA_W{1'b0}};
            end
            else if (!s_axis_tvalid) begin
                if (R_sent_beats < R_total_beats) begin
                    s_axis_tvalid <= 1'b1;
                    s_axis_tdata  <= F_axis_data(R_stream_seed + R_sent_beats);
                end
                else begin
                    s_axis_tvalid <= 1'b0;
                end
            end
            else if (s_axis_tready) begin
                R_sent_beats <= R_sent_beats + 1'b1;
                if ((R_sent_beats + 1'b1) < R_total_beats) begin
                    s_axis_tvalid <= 1'b1;
                    s_axis_tdata  <= F_axis_data(R_stream_seed + R_sent_beats + 1'b1);
                end
                else begin
                    s_axis_tvalid <= 1'b0;
                    s_axis_tdata  <= {WR_DATA_W{1'b0}};
                end
            end
        end
    end

    always @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
        if (!s00_axi_aresetn)
            R_seen_icap_done <= 1'b0;
        else if (dut.W_opt_done)
            R_seen_icap_done <= 1'b1;
    end

    always @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
        if (!s00_axi_aresetn) begin
            R_wr_cnt_at_done <= 32'd0;
            R_wr_cnt_done_valid <= 1'b0;
            R_wr_chk_cnt_at_done <= 32'd0;
            R_wr_chk_cnt_done_valid <= 1'b0;
        end
        else if (dut.W_drv_opt_ok) begin
            R_wr_cnt_at_done <= dut.flash_top_inst.flash_ctrl_inst.R_wr_cnt;
            R_wr_cnt_done_valid <= 1'b1;
            R_wr_chk_cnt_at_done <= dut.flash_top_inst.flash_ctrl_inst.R_wr_chk_cnt;
            R_wr_chk_cnt_done_valid <= 1'b1;
        end
    end

    initial begin
        s_axis_tvalid    = 1'b0;
        s_axis_tdata     = {WR_DATA_W{1'b0}};
        I_icap_en        = 1'b0;
        s00_axi_aclk     = 1'b0;
        s00_axi_aresetn  = 1'b0;
        s00_axi_awaddr   = {C_S00_AXI_ADDR_WIDTH{1'b0}};
        s00_axi_awprot   = 3'b000;
        s00_axi_awvalid  = 1'b0;
        s00_axi_wdata    = {C_S00_AXI_DATA_WIDTH{1'b0}};
        s00_axi_wstrb    = {(C_S00_AXI_DATA_WIDTH/8){1'b1}};
        s00_axi_wvalid   = 1'b0;
        s00_axi_bready   = 1'b0;
        s00_axi_araddr   = {C_S00_AXI_ADDR_WIDTH{1'b0}};
        s00_axi_arprot   = 3'b000;
        s00_axi_arvalid  = 1'b0;
        s00_axi_rready   = 1'b0;
        R_run_stream     = 1'b0;
        R_total_beats    = 32'd0;
        R_sent_beats     = 32'd0;
        R_stream_seed    = 32'h10;
        R_error_cnt      = 0;
        R_read_data      = 32'd0;
        R_seen_icap_done = 1'b0;
        R_wr_cnt_at_done = 32'd0;
        R_wr_cnt_done_valid = 1'b0;
        R_wr_chk_cnt_at_done = 32'd0;
        R_wr_chk_cnt_done_valid = 1'b0;
        R_clear_status_start = 32'd0;

        $display("[TB][INFO] 32B segmented regression: first segment=%0d bytes, tail raw=%0d bytes, tail wire=%0d bytes", FIRST_SEG_BEATS * WR_DATA_MAX_LEN, SECOND_SEG_RAW_BYTES, SECOND_SEG_BEATS * WR_DATA_MAX_LEN);

        repeat (30) @(posedge s00_axi_aclk);
        s00_axi_aresetn = 1'b1;
        repeat (20) @(posedge s00_axi_aclk);

        T_issue_icap_jump(32'h00B0_0000);
        repeat (1000) @(posedge s00_axi_aclk);
        if (!R_seen_icap_done)
            T_mark_error("ICAP done pulse not seen");

        R_total_beats = FIRST_SEG_BEATS;
        R_sent_beats  = 32'd0;
        R_run_stream  = 1'b1;
        R_stream_seed = 32'h10;
        R_wr_cnt_done_valid = 1'b0;
        R_wr_chk_cnt_done_valid = 1'b0;
        R_clear_status_start = W_clear_status_count;
        T_issue_flash_ctrl(FIRST_SEG_ADDR, (R_total_beats * WR_DATA_MAX_LEN), 1'b0);
        T_wait_flash_done_and_check(R_total_beats, 1'b0, FIRST_SEG_ADDR, R_stream_seed);
        R_run_stream = 1'b0;
        repeat (30) @(posedge s00_axi_aclk);

        R_total_beats = SECOND_SEG_BEATS;
        R_sent_beats  = 32'd0;
        R_run_stream  = 1'b1;
        R_stream_seed = 32'h40;
        R_wr_cnt_done_valid = 1'b0;
        R_wr_chk_cnt_done_valid = 1'b0;
        R_clear_status_start = W_clear_status_count;
        T_issue_flash_ctrl(SECOND_SEG_ADDR, (R_total_beats * WR_DATA_MAX_LEN), 1'b1);
        T_wait_flash_done_and_check(R_total_beats, 1'b1, SECOND_SEG_ADDR, R_stream_seed);
        R_run_stream = 1'b0;
        repeat (30) @(posedge s00_axi_aclk);

        T_issue_flash_reset();
        repeat (100) @(posedge s00_axi_aclk);
        if (dut.W_err)
            T_mark_error("unexpected error after flash reset command");

        if (R_error_cnt == 0) begin
            $display("=====================================================");
            $display("[TB][PASS] tb_axi_multiboot_driver_segmented_32b_core pass (FLASH_MODEL=%0d)", FLASH_MODEL);
            $display("=====================================================");
        end
        else begin
            $display("=====================================================");
            $display("[TB][FAIL] tb_axi_multiboot_driver_segmented_32b_core fail, error_cnt=%0d", R_error_cnt);
            $display("=====================================================");
        end

        #100;
        $finish;
    end

    always #5 s00_axi_aclk = ~s00_axi_aclk;

endmodule

module tb_axi_multiboot_driver_segmented_32b_s25;
    tb_axi_multiboot_driver_segmented_32b_core #(
        .FLASH_MODEL          (0),
        .FPGA_FAMILY          (0),
        .MULTIBOOT_ADDR_SHIFT (0)
    ) u_core ();
endmodule

module tb_axi_multiboot_driver_segmented_32b_mt25;
    tb_axi_multiboot_driver_segmented_32b_core #(
        .FLASH_MODEL          (1),
        .FPGA_FAMILY          (0),
        .MULTIBOOT_ADDR_SHIFT (0)
    ) u_core ();
endmodule

module tb_axi_multiboot_driver_segmented_32b_n25q128a;
    tb_axi_multiboot_driver_segmented_32b_core #(
        .FLASH_MODEL          (2),
        .FPGA_FAMILY          (0),
        .MULTIBOOT_ADDR_SHIFT (0)
    ) u_core ();
endmodule
