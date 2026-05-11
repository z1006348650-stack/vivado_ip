`timescale 1ns / 1ps

module tb_flash_driver_core #(
    parameter integer FLASH_MODEL = 0,
    parameter integer SPI_BUS_WIDTH = 1
);

    localparam integer FLASH_MODEL_S25FL256S = 0;
    localparam integer FLASH_MODEL_MT25QL    = 1;
    localparam integer FLASH_MODEL_N25Q128A  = 2;

    localparam integer SYS_CLK_FREQ     = 100000000;
    localparam integer FLASH_CLK_FREQ   = 10000000;
    localparam integer SYS_CLK_PERIOD_NS = 1000000000 / SYS_CLK_FREQ;
    localparam integer CLK_DIV          = SYS_CLK_FREQ / FLASH_CLK_FREQ;
    localparam integer EXPECT_SCK_HIGH_NS = (CLK_DIV - (CLK_DIV >> 1) - 1) * SYS_CLK_PERIOD_NS;
    localparam integer FLASH_ADDR_WIDTH = 32;
    localparam integer RD_DATA_MAX_LEN  = 4;
    localparam integer WR_DATA_MAX_LEN  = 4;
    localparam integer RD_DATA_W        = RD_DATA_MAX_LEN * 8;
    localparam integer WR_DATA_W        = WR_DATA_MAX_LEN * 8;
    localparam integer MAX_WAIT_CYCLES  = 200000;

    localparam integer USE_X4             = (SPI_BUS_WIDTH == 4);
    localparam [7:0] EXPECT_PP_CMD        = USE_X4 ? ((FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h32 : 8'h34) :
                                                     ((FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h02 : 8'h12);
    localparam [7:0] EXPECT_READ_CMD      = USE_X4 ? ((FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h6B : 8'h6C) :
                                                     ((FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h03 : 8'h13);
    localparam [7:0] EXPECT_ERASE_4K_CMD  = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h20 : 8'h21;
    localparam [7:0] EXPECT_ERASE_64K_CMD = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'hD8 : 8'hDC;
    localparam [2:0] EXPECT_ADDR_BYTES    = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 3'd3 : 3'd4;

    reg                           I_clk_in;
    reg                           I_rst_n;
    reg  [3:0]                    I_mode;
    reg                           I_opt_en;
    reg  [FLASH_ADDR_WIDTH-1:0]   I_wr_base_addr;
    reg  [FLASH_ADDR_WIDTH-1:0]   I_rd_base_addr;
    reg  [FLASH_ADDR_WIDTH-1:0]   I_era_base_addr;
    reg  [WR_DATA_W-1:0]          I_wr_data;
    reg  [7:0]                    I_wr_cmd;
    reg  [7:0]                    I_wr_cmd_data;
    reg  [7:0]                    I_rd_cmd;

    wire [RD_DATA_W-1:0]          O_rd_data;
    wire                          O_cs;
    wire                          O_sck;
    wire                          O_data;
    wire [3:0]                    O_dq;
    wire [3:0]                    O_dq_oe;
    wire [7:0]                    O_rd_cmd_data;
    wire                          O_opt_done;
    wire                          O_opt_busy;

    wire                          W_spi_miso;
    wire [3:0]                    W_spi_flash_dq;
    wire [7:0]                    W_last_cmd;
    wire [31:0]                   W_last_addr;
    wire [2:0]                    W_last_addr_bytes;
    wire [31:0]                   W_clear_status_count;
    wire [31:0]                   W_pp_count;
    wire [31:0]                   W_erase_4k_count;
    wire [31:0]                   W_erase_64k_count;

    integer R_error_cnt;
    integer i;

    task T_mark_error;
        input [255:0] I_msg;
        begin
            R_error_cnt = R_error_cnt + 1;
            $display("[%0t] [TB][ERROR] %0s", $time, I_msg);
        end
    endtask

    task T_wait_done;
        input [255:0] I_tag;
        integer R_wait_cnt;
        begin
            R_wait_cnt = 0;
            while ((!O_opt_done) && (R_wait_cnt < MAX_WAIT_CYCLES)) begin
                @(posedge I_clk_in);
                R_wait_cnt = R_wait_cnt + 1;
            end
            if (R_wait_cnt >= MAX_WAIT_CYCLES)
                T_mark_error(I_tag);
            repeat (10) @(posedge I_clk_in);
        end
    endtask

    task T_pulse_opt;
        input [3:0] I_mode_v;
        begin
            @(posedge I_clk_in);
            I_mode   <= I_mode_v;
            I_opt_en <= 1'b1;
            @(posedge I_clk_in);
            I_opt_en <= 1'b0;
        end
    endtask

    task T_check_next_transaction_sck_edges;
        input integer I_expect_edges;
        input [255:0] I_tag;
        integer R_edge_cnt;
        begin
            R_edge_cnt = 0;
            wait (O_cs == 1'b0);
            while (O_cs == 1'b0) begin
                @(posedge O_sck or posedge O_cs);
                if (!O_cs)
                    R_edge_cnt = R_edge_cnt + 1;
            end
            if (R_edge_cnt != I_expect_edges) begin
                $display("[%0t] [TB][INFO] %0s: sck_rise_cnt=%0d expect=%0d", $time, I_tag, R_edge_cnt, I_expect_edges);
                T_mark_error("transaction sck edge count mismatch");
            end
        end
    endtask

    task T_check_next_transaction_sck_high_width;
        input integer I_expect_edges;
        input time I_expect_high_ns;
        input [255:0] I_tag;
        integer R_edge_cnt;
        time R_rise_time;
        time R_high_width;
        begin
            R_edge_cnt = 0;
            wait (O_cs == 1'b0);
            begin : MONITOR_HIGH_WIDTH
                while (O_cs == 1'b0) begin
                    @(posedge O_sck or posedge O_cs);
                    if (O_cs)
                        disable MONITOR_HIGH_WIDTH;
                    R_edge_cnt = R_edge_cnt + 1;
                    R_rise_time = $time;
                    @(negedge O_sck or posedge O_cs);
                    if (O_cs)
                        disable MONITOR_HIGH_WIDTH;
                    R_high_width = $time - R_rise_time;
                    if (R_high_width != I_expect_high_ns) begin
                        $display("[%0t] [TB][INFO] %0s: pulse=%0d high_width=%0t expect=%0t", $time, I_tag, R_edge_cnt, R_high_width, I_expect_high_ns);
                        T_mark_error("transaction sck high width mismatch");
                    end
                end
            end
            if (R_edge_cnt != I_expect_edges) begin
                $display("[%0t] [TB][INFO] %0s: sck_rise_cnt=%0d expect=%0d", $time, I_tag, R_edge_cnt, I_expect_edges);
                T_mark_error("transaction sck edge count mismatch");
            end
        end
    endtask

    initial begin
        I_clk_in       = 1'b0;
        I_rst_n        = 1'b0;
        I_mode         = 4'd0;
        I_opt_en       = 1'b0;
        I_wr_base_addr = 32'd0;
        I_rd_base_addr = 32'd0;
        I_era_base_addr= 32'd0;
        I_wr_data      = {WR_DATA_W{1'b0}};
        I_wr_cmd       = 8'h00;
        I_wr_cmd_data  = 8'h00;
        I_rd_cmd       = (FLASH_MODEL == FLASH_MODEL_S25FL256S) ? 8'h05 : 8'h70;
        R_error_cnt    = 0;

        repeat (20) @(posedge I_clk_in);
        I_rst_n = 1'b1;
        repeat (20) @(posedge I_clk_in);

        if (FLASH_MODEL != FLASH_MODEL_S25FL256S) begin
            T_pulse_opt(4'd9);
            T_wait_done("clear status timeout");
            $display("[TB][INFO] clear-status last_cmd=0x%02x clear_cnt=%0d", W_last_cmd, W_clear_status_count);
            if (W_last_cmd != 8'h50)
                T_mark_error("clear status command mismatch");
            if (W_clear_status_count != 32'd1)
                T_mark_error("clear status count mismatch");
        end

        for (i = 0; i < 32; i = i + 1)
            u_flash_model.R_mem[32'h0000_1000 + i] = 8'h00;
        I_era_base_addr = 32'h0000_1000;
        fork
            T_check_next_transaction_sck_edges(8, "erase4k_wren_edges");
            T_check_next_transaction_sck_high_width(8, EXPECT_SCK_HIGH_NS, "erase4k_wren_high_width");
            T_pulse_opt(4'd4);
        join
        T_wait_done("erase 4k timeout");
        if (W_last_cmd != EXPECT_ERASE_4K_CMD)
            T_mark_error("erase 4k command mismatch");
        if (W_last_addr != 32'h0000_1000)
            T_mark_error("erase 4k address mismatch");
        if (W_last_addr_bytes != EXPECT_ADDR_BYTES)
            T_mark_error("erase 4k address width mismatch");
        if (W_erase_4k_count != 32'd1)
            T_mark_error("erase 4k count mismatch");
        for (i = 0; i < 32; i = i + 1) begin
            if (u_flash_model.R_mem[32'h0000_1000 + i] != 8'hFF)
                T_mark_error("erase 4k memory mismatch");
        end

        for (i = 0; i < 32; i = i + 1)
            u_flash_model.R_mem[32'h0001_0000 + i] = 8'h00;
        I_era_base_addr = 32'h0001_0000;
        fork
            T_check_next_transaction_sck_edges(8, "erase64k_wren_edges");
            T_check_next_transaction_sck_high_width(8, EXPECT_SCK_HIGH_NS, "erase64k_wren_high_width");
            T_pulse_opt(4'd5);
        join
        T_wait_done("erase 64k timeout");
        if (W_last_cmd != EXPECT_ERASE_64K_CMD)
            T_mark_error("erase 64k command mismatch");
        if (W_last_addr != 32'h0001_0000)
            T_mark_error("erase 64k address mismatch");
        if (W_last_addr_bytes != EXPECT_ADDR_BYTES)
            T_mark_error("erase 64k address width mismatch");
        if (W_erase_64k_count != 32'd1)
            T_mark_error("erase 64k count mismatch");
        for (i = 0; i < 32; i = i + 1) begin
            if (u_flash_model.R_mem[32'h0001_0000 + i] != 8'hFF)
                T_mark_error("erase 64k memory mismatch");
        end

        I_wr_base_addr = 32'h0000_1020;
        I_wr_data      = 32'h11223344;
        fork
            T_check_next_transaction_sck_edges(8, "program_wren_edges");
            T_check_next_transaction_sck_high_width(8, EXPECT_SCK_HIGH_NS, "program_wren_high_width");
            T_pulse_opt(4'd1);
        join
        T_wait_done("write multi timeout");
        if (W_last_cmd != EXPECT_PP_CMD)
            T_mark_error("program command mismatch");
        if (W_last_addr != 32'h0000_1020)
            T_mark_error("program address mismatch");
        if (W_last_addr_bytes != EXPECT_ADDR_BYTES)
            T_mark_error("program address width mismatch");
        if (W_pp_count != 32'd1)
            T_mark_error("program count mismatch");
        if (u_flash_model.R_mem[32'h0000_1020] != 8'h11)
            T_mark_error("program byte0 mismatch");
        if (u_flash_model.R_mem[32'h0000_1021] != 8'h22)
            T_mark_error("program byte1 mismatch");
        if (u_flash_model.R_mem[32'h0000_1022] != 8'h33)
            T_mark_error("program byte2 mismatch");
        if (u_flash_model.R_mem[32'h0000_1023] != 8'h44)
            T_mark_error("program byte3 mismatch");

        u_flash_model.R_mem[32'h0000_1040] = 8'hA1;
        u_flash_model.R_mem[32'h0000_1041] = 8'hB2;
        u_flash_model.R_mem[32'h0000_1042] = 8'hC3;
        u_flash_model.R_mem[32'h0000_1043] = 8'hD4;
        I_rd_base_addr = 32'h0000_1040;
        T_pulse_opt(4'd3);
        T_wait_done("read multi timeout");
        if (W_last_cmd != EXPECT_READ_CMD)
            T_mark_error("read command mismatch");
        if (W_last_addr != 32'h0000_1040)
            T_mark_error("read address mismatch");
        if (W_last_addr_bytes != EXPECT_ADDR_BYTES)
            T_mark_error("read address width mismatch");
        if (O_rd_data != 32'hA1B2C3D4)
            T_mark_error("read data mismatch");

        if (R_error_cnt == 0) begin
            $display("=====================================================");
            $display("[TB][PASS] tb_flash_driver_core pass (FLASH_MODEL=%0d)", FLASH_MODEL);
            $display("=====================================================");
        end
        else begin
            $display("=====================================================");
            $display("[TB][FAIL] tb_flash_driver_core fail, error_cnt=%0d", R_error_cnt);
            $display("=====================================================");
        end

        #100;
        $finish;
    end

    always #5 I_clk_in = ~I_clk_in;

    flash_driver #(
        .SYS_CLK_FREQ     (SYS_CLK_FREQ),
        .FLASH_CLK_FREQ   (FLASH_CLK_FREQ),
        .RD_DATA_MAX_LEN  (RD_DATA_MAX_LEN),
        .WR_DATA_MAX_LEN  (WR_DATA_MAX_LEN),
        .FLASH_ADDR_WIDTH (FLASH_ADDR_WIDTH),
        .FLASH_MODEL      (FLASH_MODEL),
        .SPI_BUS_WIDTH    (SPI_BUS_WIDTH)
    ) dut (
        .I_clk_in         (I_clk_in),
        .I_rst_n          (I_rst_n),
        .I_mode           (I_mode),
        .I_opt_en         (I_opt_en),
        .I_wr_base_addr   (I_wr_base_addr),
        .I_rd_base_addr   (I_rd_base_addr),
        .I_era_base_addr  (I_era_base_addr),
        .I_wr_data        (I_wr_data),
        .I_wr_cmd         (I_wr_cmd),
        .I_wr_cmd_data    (I_wr_cmd_data),
        .O_rd_data        (O_rd_data),
        .I_data           (W_spi_miso),
        .I_dq             (W_spi_flash_dq),
        .I_rd_cmd         (I_rd_cmd),
        .O_rd_cmd_data    (O_rd_cmd_data),
        .O_cs             (O_cs),
        .O_sck            (O_sck),
        .O_data           (O_data),
        .O_dq             (O_dq),
        .O_dq_oe          (O_dq_oe),
        .O_opt_done       (O_opt_done),
        .O_opt_busy       (O_opt_busy)
    );

    tb_spi_flash_model #(
        .FLASH_MODEL            (FLASH_MODEL),
        .SPI_BUS_WIDTH          (SPI_BUS_WIDTH),
        .MEM_BYTES              (262144),
        .P_BUSY_POLLS_PP        (1),
        .P_BUSY_POLLS_ERASE_4K  (1),
        .P_BUSY_POLLS_ERASE_64K (1)
    ) u_flash_model (
        .I_rst_n                (I_rst_n),
        .I_cs_n                 (O_cs),
        .I_sck                  (O_sck),
        .I_mosi                 (O_data),
        .I_dq                   (O_dq),
        .O_miso                 (W_spi_miso),
        .O_dq                   (W_spi_flash_dq),
        .O_last_cmd             (W_last_cmd),
        .O_last_addr            (W_last_addr),
        .O_last_addr_bytes      (W_last_addr_bytes),
        .O_clear_status_count   (W_clear_status_count),
        .O_pp_count             (W_pp_count),
        .O_erase_4k_count       (W_erase_4k_count),
        .O_erase_64k_count      (W_erase_64k_count)
    );

endmodule

module tb_flash_driver_s25;
    tb_flash_driver_core #(
        .FLASH_MODEL (0)
    ) u_core ();
endmodule

module tb_flash_driver_mt25;
    tb_flash_driver_core #(
        .FLASH_MODEL (1)
    ) u_core ();
endmodule

module tb_flash_driver_n25q128a;
    tb_flash_driver_core #(
        .FLASH_MODEL (2)
    ) u_core ();
endmodule

module tb_flash_driver_s25_x4;
    tb_flash_driver_core #(
        .FLASH_MODEL   (0),
        .SPI_BUS_WIDTH (4)
    ) u_core ();
endmodule

module tb_flash_driver_mt25_x4;
    tb_flash_driver_core #(
        .FLASH_MODEL   (1),
        .SPI_BUS_WIDTH (4)
    ) u_core ();
endmodule

module tb_flash_driver_n25q128a_x4;
    tb_flash_driver_core #(
        .FLASH_MODEL   (2),
        .SPI_BUS_WIDTH (4)
    ) u_core ();
endmodule
