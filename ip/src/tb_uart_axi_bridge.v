`timescale 1ns / 1ps
`default_nettype none

module tb_uart_axi_bridge;

localparam integer CLK_PERIOD_NS         = 20;
localparam integer TB_SYS_CLK_FREQ_HZ   = 50000000;
localparam integer TB_UART_BAUD_RATE    = 6250000;
localparam integer TB_UART_CLKS_PER_BIT = (TB_SYS_CLK_FREQ_HZ + (TB_UART_BAUD_RATE / 2)) / TB_UART_BAUD_RATE;
localparam integer AXI_TIMEOUT_CYCLES   = 32;
localparam integer RX_TIMEOUT_CYCLES    = 40000;

reg r_clk;
reg r_rst_n;
reg r_uart_rx_line;
wire w_uart_tx_line;

wire [39:0] w_m_axil_awaddr;
wire [2:0]  w_m_axil_awprot;
wire        w_m_axil_awvalid;
wire        w_m_axil_awready;
wire [31:0] w_m_axil_wdata;
wire [3:0]  w_m_axil_wstrb;
wire        w_m_axil_wvalid;
wire        w_m_axil_wready;
wire [1:0]  w_m_axil_bresp;
wire        w_m_axil_bvalid;
wire        w_m_axil_bready;
wire [39:0] w_m_axil_araddr;
wire [2:0]  w_m_axil_arprot;
wire        w_m_axil_arvalid;
wire        w_m_axil_arready;
wire [31:0] w_m_axil_rdata;
wire [1:0]  w_m_axil_rresp;
wire        w_m_axil_rvalid;
wire        w_m_axil_rready;
wire [39:0] w_m_axi_awaddr;
wire [7:0]  w_m_axi_awlen;
wire [2:0]  w_m_axi_awsize;
wire [1:0]  w_m_axi_awburst;
wire        w_m_axi_awlock;
wire [3:0]  w_m_axi_awcache;
wire [2:0]  w_m_axi_awprot;
wire [3:0]  w_m_axi_awqos;
wire        w_m_axi_awvalid;
wire        w_m_axi_awready;
wire [31:0] w_m_axi_wdata;
wire [3:0]  w_m_axi_wstrb;
wire        w_m_axi_wlast;
wire        w_m_axi_wvalid;
wire        w_m_axi_wready;
wire [1:0]  w_m_axi_bresp;
wire        w_m_axi_bvalid;
wire        w_m_axi_bready;
wire [39:0] w_m_axi_araddr;
wire [7:0]  w_m_axi_arlen;
wire [2:0]  w_m_axi_arsize;
wire [1:0]  w_m_axi_arburst;
wire        w_m_axi_arlock;
wire [3:0]  w_m_axi_arcache;
wire [2:0]  w_m_axi_arprot;
wire [3:0]  w_m_axi_arqos;
wire        w_m_axi_arvalid;
wire        w_m_axi_arready;
wire [31:0] w_m_axi_rdata;
wire [1:0]  w_m_axi_rresp;
wire        w_m_axi_rlast;
wire        w_m_axi_rvalid;
wire        w_m_axi_rready;

reg [7:0] r_lite_aw_wait_cycles;
reg [7:0] r_lite_w_wait_cycles;
reg [7:0] r_lite_b_wait_cycles;
reg [7:0] r_lite_ar_wait_cycles;
reg [7:0] r_lite_r_wait_cycles;
reg       r_lite_block_aw;
reg       r_lite_block_w;
reg       r_lite_block_b;
reg       r_lite_block_ar;
reg       r_lite_block_r;
reg       r_lite_force_bresp_err;
reg       r_lite_force_rresp_err;
reg [7:0] r_full_aw_wait_cycles;
reg [7:0] r_full_w_wait_cycles;
reg [7:0] r_full_b_wait_cycles;
reg [7:0] r_full_ar_wait_cycles;
reg [7:0] r_full_r_wait_cycles;
reg       r_full_block_aw;
reg       r_full_block_w;
reg       r_full_block_b;
reg       r_full_block_ar;
reg       r_full_block_r;
reg       r_full_force_bresp_err;
reg       r_full_force_rresp_err;

wire       w_host_rx_dv;
wire [7:0] w_host_rx_byte;
reg [7:0] r_tx_buf [0:511];
reg [7:0] r_data_buf [0:255];
reg [7:0] r_exp_buf [0:511];
reg [7:0] r_rx_buf [0:511];
integer r_tx_count;
integer r_exp_count;
integer r_rx_count;
integer r_case_count;
integer r_fail_count;
integer r_idx;
reg r_full_mem_mismatch;

uart_axi_bridge #(
    .SYS_CLK_FREQ_HZ      (TB_SYS_CLK_FREQ_HZ),
    .UART_BAUD_RATE       (TB_UART_BAUD_RATE),
    .AXI_ADDR_WIDTH       (40),
    .AXI_TIMEOUT_CYCLES   (AXI_TIMEOUT_CYCLES),
    .MAX_FRAME_DATA_BYTES (256)
) dut (
    .i_clk      (r_clk),
    .i_rst_n        (r_rst_n),
    .i_uart_rx      (r_uart_rx_line),
    .o_uart_tx      (w_uart_tx_line),
    .o_m_axil_awaddr(w_m_axil_awaddr),
    .o_m_axil_awprot(w_m_axil_awprot),
    .o_m_axil_awvalid(w_m_axil_awvalid),
    .i_m_axil_awready(w_m_axil_awready),
    .o_m_axil_wdata (w_m_axil_wdata),
    .o_m_axil_wstrb (w_m_axil_wstrb),
    .o_m_axil_wvalid(w_m_axil_wvalid),
    .i_m_axil_wready(w_m_axil_wready),
    .i_m_axil_bresp (w_m_axil_bresp),
    .i_m_axil_bvalid(w_m_axil_bvalid),
    .o_m_axil_bready(w_m_axil_bready),
    .o_m_axil_araddr(w_m_axil_araddr),
    .o_m_axil_arprot(w_m_axil_arprot),
    .o_m_axil_arvalid(w_m_axil_arvalid),
    .i_m_axil_arready(w_m_axil_arready),
    .i_m_axil_rdata (w_m_axil_rdata),
    .i_m_axil_rresp (w_m_axil_rresp),
    .i_m_axil_rvalid(w_m_axil_rvalid),
    .o_m_axil_rready(w_m_axil_rready),
    .o_m_axi_awaddr (w_m_axi_awaddr),
    .o_m_axi_awlen  (w_m_axi_awlen),
    .o_m_axi_awsize (w_m_axi_awsize),
    .o_m_axi_awburst(w_m_axi_awburst),
    .o_m_axi_awlock (w_m_axi_awlock),
    .o_m_axi_awcache(w_m_axi_awcache),
    .o_m_axi_awprot (w_m_axi_awprot),
    .o_m_axi_awqos  (w_m_axi_awqos),
    .o_m_axi_awvalid(w_m_axi_awvalid),
    .i_m_axi_awready(w_m_axi_awready),
    .o_m_axi_wdata  (w_m_axi_wdata),
    .o_m_axi_wstrb  (w_m_axi_wstrb),
    .o_m_axi_wlast  (w_m_axi_wlast),
    .o_m_axi_wvalid (w_m_axi_wvalid),
    .i_m_axi_wready (w_m_axi_wready),
    .i_m_axi_bresp  (w_m_axi_bresp),
    .i_m_axi_bvalid (w_m_axi_bvalid),
    .o_m_axi_bready (w_m_axi_bready),
    .o_m_axi_araddr (w_m_axi_araddr),
    .o_m_axi_arlen  (w_m_axi_arlen),
    .o_m_axi_arsize (w_m_axi_arsize),
    .o_m_axi_arburst(w_m_axi_arburst),
    .o_m_axi_arlock (w_m_axi_arlock),
    .o_m_axi_arcache(w_m_axi_arcache),
    .o_m_axi_arprot (w_m_axi_arprot),
    .o_m_axi_arqos  (w_m_axi_arqos),
    .o_m_axi_arvalid(w_m_axi_arvalid),
    .i_m_axi_arready(w_m_axi_arready),
    .i_m_axi_rdata  (w_m_axi_rdata),
    .i_m_axi_rresp  (w_m_axi_rresp),
    .i_m_axi_rlast  (w_m_axi_rlast),
    .i_m_axi_rvalid (w_m_axi_rvalid),
    .o_m_axi_rready (w_m_axi_rready)
);

uart_rx #(
    .CLKS_PER_BIT (TB_UART_CLKS_PER_BIT)
) u_host_uart_rx (
    .i_clk      (r_clk),
    .i_rst      (!r_rst_n),
    .i_rx_serial(w_uart_tx_line),
    .o_rx_dv    (w_host_rx_dv),
    .o_rx_byte  (w_host_rx_byte)
);

axi_lite_slave_model #(
    .AXI_ADDR_WIDTH (40),
    .MEM_WORDS      (256)
) u_axil_slave (
    .i_clk             (r_clk),
    .i_rst             (!r_rst_n),
    .i_aw_wait_cycles  (r_lite_aw_wait_cycles),
    .i_w_wait_cycles   (r_lite_w_wait_cycles),
    .i_b_wait_cycles   (r_lite_b_wait_cycles),
    .i_ar_wait_cycles  (r_lite_ar_wait_cycles),
    .i_r_wait_cycles   (r_lite_r_wait_cycles),
    .i_block_aw        (r_lite_block_aw),
    .i_block_w         (r_lite_block_w),
    .i_block_b         (r_lite_block_b),
    .i_block_ar        (r_lite_block_ar),
    .i_block_r         (r_lite_block_r),
    .i_force_bresp_err (r_lite_force_bresp_err),
    .i_force_rresp_err (r_lite_force_rresp_err),
    .i_s_axil_awaddr   (w_m_axil_awaddr),
    .i_s_axil_awprot   (w_m_axil_awprot),
    .i_s_axil_awvalid  (w_m_axil_awvalid),
    .o_s_axil_awready  (w_m_axil_awready),
    .i_s_axil_wdata    (w_m_axil_wdata),
    .i_s_axil_wstrb    (w_m_axil_wstrb),
    .i_s_axil_wvalid   (w_m_axil_wvalid),
    .o_s_axil_wready   (w_m_axil_wready),
    .o_s_axil_bresp    (w_m_axil_bresp),
    .o_s_axil_bvalid   (w_m_axil_bvalid),
    .i_s_axil_bready   (w_m_axil_bready),
    .i_s_axil_araddr   (w_m_axil_araddr),
    .i_s_axil_arprot   (w_m_axil_arprot),
    .i_s_axil_arvalid  (w_m_axil_arvalid),
    .o_s_axil_arready  (w_m_axil_arready),
    .o_s_axil_rdata    (w_m_axil_rdata),
    .o_s_axil_rresp    (w_m_axil_rresp),
    .o_s_axil_rvalid   (w_m_axil_rvalid),
    .i_s_axil_rready   (w_m_axil_rready)
);

axi_full_slave_model #(
    .AXI_ADDR_WIDTH (40),
    .MEM_WORDS      (512)
) u_axi_slave (
    .i_clk            (r_clk),
    .i_rst            (!r_rst_n),
    .i_aw_wait_cycles (r_full_aw_wait_cycles),
    .i_w_wait_cycles  (r_full_w_wait_cycles),
    .i_b_wait_cycles  (r_full_b_wait_cycles),
    .i_ar_wait_cycles (r_full_ar_wait_cycles),
    .i_r_wait_cycles  (r_full_r_wait_cycles),
    .i_block_aw       (r_full_block_aw),
    .i_block_w        (r_full_block_w),
    .i_block_b        (r_full_block_b),
    .i_block_ar       (r_full_block_ar),
    .i_block_r        (r_full_block_r),
    .i_force_bresp_err(r_full_force_bresp_err),
    .i_force_rresp_err(r_full_force_rresp_err),
    .i_s_axi_awaddr   (w_m_axi_awaddr),
    .i_s_axi_awlen    (w_m_axi_awlen),
    .i_s_axi_awsize   (w_m_axi_awsize),
    .i_s_axi_awburst  (w_m_axi_awburst),
    .i_s_axi_awlock   (w_m_axi_awlock),
    .i_s_axi_awcache  (w_m_axi_awcache),
    .i_s_axi_awprot   (w_m_axi_awprot),
    .i_s_axi_awqos    (w_m_axi_awqos),
    .i_s_axi_awvalid  (w_m_axi_awvalid),
    .o_s_axi_awready  (w_m_axi_awready),
    .i_s_axi_wdata    (w_m_axi_wdata),
    .i_s_axi_wstrb    (w_m_axi_wstrb),
    .i_s_axi_wlast    (w_m_axi_wlast),
    .i_s_axi_wvalid   (w_m_axi_wvalid),
    .o_s_axi_wready   (w_m_axi_wready),
    .o_s_axi_bresp    (w_m_axi_bresp),
    .o_s_axi_bvalid   (w_m_axi_bvalid),
    .i_s_axi_bready   (w_m_axi_bready),
    .i_s_axi_araddr   (w_m_axi_araddr),
    .i_s_axi_arlen    (w_m_axi_arlen),
    .i_s_axi_arsize   (w_m_axi_arsize),
    .i_s_axi_arburst  (w_m_axi_arburst),
    .i_s_axi_arlock   (w_m_axi_arlock),
    .i_s_axi_arcache  (w_m_axi_arcache),
    .i_s_axi_arprot   (w_m_axi_arprot),
    .i_s_axi_arqos    (w_m_axi_arqos),
    .i_s_axi_arvalid  (w_m_axi_arvalid),
    .o_s_axi_arready  (w_m_axi_arready),
    .o_s_axi_rdata    (w_m_axi_rdata),
    .o_s_axi_rresp    (w_m_axi_rresp),
    .o_s_axi_rlast    (w_m_axi_rlast),
    .o_s_axi_rvalid   (w_m_axi_rvalid),
    .i_s_axi_rready   (w_m_axi_rready)
);

always #(CLK_PERIOD_NS / 2) r_clk = ~r_clk;

always @(posedge r_clk) begin
    if (!r_rst_n) begin
        r_rx_count <= 0;
    end
    else if (w_host_rx_dv) begin
        r_rx_buf[r_rx_count] <= w_host_rx_byte;
        r_rx_count <= r_rx_count + 1;
    end
end

task wait_clocks;
    input integer cycles;
    integer j;
    begin
        for (j = 0; j < cycles; j = j + 1) begin
            @(posedge r_clk);
        end
    end
endtask

task uart_send_byte;
    input [7:0] data_byte;
    integer bit_idx;
    begin
        r_uart_rx_line = 1'b0;
        wait_clocks(TB_UART_CLKS_PER_BIT);

        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            r_uart_rx_line = data_byte[bit_idx];
            wait_clocks(TB_UART_CLKS_PER_BIT);
        end

        r_uart_rx_line = 1'b1;
        wait_clocks(TB_UART_CLKS_PER_BIT);
    end
endtask

task send_tx_buffer;
    integer j;
    begin
        for (j = 0; j < r_tx_count; j = j + 1) begin
            uart_send_byte(r_tx_buf[j]);
        end

        wait_clocks(TB_UART_CLKS_PER_BIT * 2);
    end
endtask

task clear_rx_buffer;
    begin
        r_rx_count = 0;
    end
endtask

task clear_data_buf;
    integer j;
    begin
        for (j = 0; j < 256; j = j + 1) begin
            r_data_buf[j] = 8'd0;
        end
    end
endtask

task build_request;
    input [7:0] req_len;
    input [7:0] req_cmd;
    input [39:0] req_addr;
    integer j;
    integer payload_count;
    reg [7:0] r_chk;
    begin
        r_tx_count = 0;
        r_chk = 8'h00;
        payload_count = 0;

        case (req_cmd)
            8'h03: payload_count = req_len + 1;
            8'h01: payload_count = req_len;
            default: payload_count = 0;
        endcase

        r_tx_buf[r_tx_count] = 8'hAA;
        r_chk = r_chk ^ 8'hAA;
        r_tx_count = r_tx_count + 1;

        r_tx_buf[r_tx_count] = req_len;
        r_chk = r_chk ^ req_len;
        r_tx_count = r_tx_count + 1;

        r_tx_buf[r_tx_count] = req_cmd;
        r_chk = r_chk ^ req_cmd;
        r_tx_count = r_tx_count + 1;

        r_tx_buf[r_tx_count] = req_addr[39:32]; r_chk = r_chk ^ req_addr[39:32]; r_tx_count = r_tx_count + 1;
        r_tx_buf[r_tx_count] = req_addr[31:24]; r_chk = r_chk ^ req_addr[31:24]; r_tx_count = r_tx_count + 1;
        r_tx_buf[r_tx_count] = req_addr[23:16]; r_chk = r_chk ^ req_addr[23:16]; r_tx_count = r_tx_count + 1;
        r_tx_buf[r_tx_count] = req_addr[15:8];  r_chk = r_chk ^ req_addr[15:8];  r_tx_count = r_tx_count + 1;
        r_tx_buf[r_tx_count] = req_addr[7:0];   r_chk = r_chk ^ req_addr[7:0];   r_tx_count = r_tx_count + 1;

        for (j = 0; j < payload_count; j = j + 1) begin
            r_tx_buf[r_tx_count] = r_data_buf[j];
            r_chk = r_chk ^ r_data_buf[j];
            r_tx_count = r_tx_count + 1;
        end

        r_tx_buf[r_tx_count] = r_chk;
        r_tx_count = r_tx_count + 1;
        r_tx_buf[r_tx_count] = 8'h55;
        r_tx_count = r_tx_count + 1;
    end
endtask
task build_expected_response;
    input [7:0] resp_len_i;
    input [7:0] resp_cmd_i;
    input [39:0] resp_addr_i;
    input [7:0] resp_status_i;
    integer j;
    integer payload_count;
    reg [7:0] r_chk;
    begin
        r_exp_count = 0;
        r_chk = 8'h00;
        payload_count = 0;

        if (resp_status_i == 8'h00) begin
            case (resp_cmd_i)
                8'h02: payload_count = resp_len_i;
                8'h04: payload_count = resp_len_i + 1;
                default: payload_count = 0;
            endcase
        end

        r_exp_buf[r_exp_count] = 8'hAA;
        r_chk = r_chk ^ 8'hAA;
        r_exp_count = r_exp_count + 1;

        r_exp_buf[r_exp_count] = resp_len_i;
        r_chk = r_chk ^ resp_len_i;
        r_exp_count = r_exp_count + 1;

        r_exp_buf[r_exp_count] = resp_cmd_i;
        r_chk = r_chk ^ resp_cmd_i;
        r_exp_count = r_exp_count + 1;

        r_exp_buf[r_exp_count] = resp_addr_i[39:32]; r_chk = r_chk ^ resp_addr_i[39:32]; r_exp_count = r_exp_count + 1;
        r_exp_buf[r_exp_count] = resp_addr_i[31:24]; r_chk = r_chk ^ resp_addr_i[31:24]; r_exp_count = r_exp_count + 1;
        r_exp_buf[r_exp_count] = resp_addr_i[23:16]; r_chk = r_chk ^ resp_addr_i[23:16]; r_exp_count = r_exp_count + 1;
        r_exp_buf[r_exp_count] = resp_addr_i[15:8];  r_chk = r_chk ^ resp_addr_i[15:8];  r_exp_count = r_exp_count + 1;
        r_exp_buf[r_exp_count] = resp_addr_i[7:0];   r_chk = r_chk ^ resp_addr_i[7:0];   r_exp_count = r_exp_count + 1;

        r_exp_buf[r_exp_count] = resp_status_i;
        r_chk = r_chk ^ resp_status_i;
        r_exp_count = r_exp_count + 1;

        for (j = 0; j < payload_count; j = j + 1) begin
            r_exp_buf[r_exp_count] = r_data_buf[j];
            r_chk = r_chk ^ r_data_buf[j];
            r_exp_count = r_exp_count + 1;
        end

        r_exp_buf[r_exp_count] = r_chk;
        r_exp_count = r_exp_count + 1;
        r_exp_buf[r_exp_count] = 8'h55;
        r_exp_count = r_exp_count + 1;
    end
endtask
task wait_for_rx_bytes;
    input integer expected_count;
    input [8*32-1:0] case_name;
    integer cycles;
    begin
        cycles = 0;

        while ((r_rx_count < expected_count) && (cycles < RX_TIMEOUT_CYCLES)) begin
            @(posedge r_clk);
            cycles = cycles + 1;
        end

        if (r_rx_count < expected_count) begin
            $display("[FAIL] %0s: timeout waiting response, got %0d expected %0d", case_name, r_rx_count, expected_count);
            r_fail_count = r_fail_count + 1;
        end
    end
endtask

task compare_expected;
    input [8*32-1:0] case_name;
    integer j;
    reg r_mismatch;
    begin
        r_mismatch = 1'b0;

        if (r_rx_count != r_exp_count) begin
            r_mismatch = 1'b1;
        end
        else begin
            for (j = 0; j < r_exp_count; j = j + 1) begin
                if (r_rx_buf[j] !== r_exp_buf[j]) begin
                    r_mismatch = 1'b1;
                end
            end
        end

        if (r_mismatch) begin
            $display("[FAIL] %0s: response r_mismatch", case_name);
            $write("  expected:");
            for (j = 0; j < r_exp_count; j = j + 1) begin
                $write(" %02x", r_exp_buf[j]);
            end
            $write("\n  actual  :");
            for (j = 0; j < r_rx_count; j = j + 1) begin
                $write(" %02x", r_rx_buf[j]);
            end
            $write("\n");
            r_fail_count = r_fail_count + 1;
        end
        else begin
            $display("[PASS] %0s", case_name);
        end
    end
endtask

task expect_no_response;
    input [8*32-1:0] case_name;
    begin
        wait_clocks(RX_TIMEOUT_CYCLES / 4);

        if (r_rx_count != 0) begin
            $display("[FAIL] %0s: expected no response, got %0d bytes", case_name, r_rx_count);
            r_fail_count = r_fail_count + 1;
        end
        else begin
            $display("[PASS] %0s", case_name);
        end
    end
endtask

task set_default_slave_ctrl;
    begin
        r_lite_aw_wait_cycles  = 8'd0;
        r_lite_w_wait_cycles   = 8'd0;
        r_lite_b_wait_cycles   = 8'd0;
        r_lite_ar_wait_cycles  = 8'd0;
        r_lite_r_wait_cycles   = 8'd0;
        r_lite_block_aw        = 1'b0;
        r_lite_block_w         = 1'b0;
        r_lite_block_b         = 1'b0;
        r_lite_block_ar        = 1'b0;
        r_lite_block_r         = 1'b0;
        r_lite_force_bresp_err = 1'b0;
        r_lite_force_rresp_err = 1'b0;
        r_full_aw_wait_cycles  = 8'd0;
        r_full_w_wait_cycles   = 8'd0;
        r_full_b_wait_cycles   = 8'd0;
        r_full_ar_wait_cycles  = 8'd0;
        r_full_r_wait_cycles   = 8'd0;
        r_full_block_aw        = 1'b0;
        r_full_block_w         = 1'b0;
        r_full_block_b         = 1'b0;
        r_full_block_ar        = 1'b0;
        r_full_block_r         = 1'b0;
        r_full_force_bresp_err = 1'b0;
        r_full_force_rresp_err = 1'b0;
    end
endtask

task clear_model_memories;
    integer j;
    begin
        for (j = 0; j < 256; j = j + 1) begin
            u_axil_slave.r_mem_word[j] = 32'd0;
        end

        for (j = 0; j < 512; j = j + 1) begin
            u_axi_slave.r_mem_word[j] = 32'd0;
        end
    end
endtask

initial begin
    r_clk = 1'b0;
    r_rst_n = 1'b0;
    r_uart_rx_line = 1'b1;
    r_tx_count = 0;
    r_exp_count = 0;
    r_rx_count = 0;
    r_case_count = 0;
    r_fail_count = 0;

    set_default_slave_ctrl();
    clear_model_memories();
    clear_data_buf();

    wait_clocks(20);
    r_rst_n = 1'b1;
    wait_clocks(20);

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    r_lite_aw_wait_cycles = 8'd2;
    r_lite_w_wait_cycles  = 8'd1;
    r_lite_b_wait_cycles  = 8'd2;
    r_data_buf[0] = 8'h78;
    r_data_buf[1] = 8'h56;
    r_data_buf[2] = 8'h34;
    r_data_buf[3] = 8'h12;
    build_request(8'd4, 8'h01, 40'h0000_0000_A0);
    clear_data_buf();
    build_expected_response(8'd0, 8'h01, 40'h0000_0000_A0, 8'h00);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "lite_write_ok");
    compare_expected("lite_write_ok");
    if (u_axil_slave.r_mem_word[8'h28] !== 32'h1234_5678) begin
        $display("[FAIL] lite_write_ok: AXI-Lite memory content r_mismatch");
        r_fail_count = r_fail_count + 1;
    end

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    r_lite_ar_wait_cycles = 8'd2;
    r_lite_r_wait_cycles  = 8'd3;
    u_axil_slave.r_mem_word[8'h28] = 32'h1234_5678;
    build_request(8'd4, 8'h02, 40'h0000_0000_A0);
    r_data_buf[0] = 8'h78;
    r_data_buf[1] = 8'h56;
    r_data_buf[2] = 8'h34;
    r_data_buf[3] = 8'h12;
    build_expected_response(8'd4, 8'h02, 40'h0000_0000_A0, 8'h00);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "lite_read_ok");
    compare_expected("lite_read_ok");

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    r_full_aw_wait_cycles = 8'd1;
    r_full_w_wait_cycles  = 8'd1;
    r_full_b_wait_cycles  = 8'd1;
    r_data_buf[0]  = 8'hA3; r_data_buf[1]  = 8'hA2; r_data_buf[2]  = 8'hA1; r_data_buf[3]  = 8'hA0;
    r_data_buf[4]  = 8'hB3; r_data_buf[5]  = 8'hB2; r_data_buf[6]  = 8'hB1; r_data_buf[7]  = 8'hB0;
    r_data_buf[8]  = 8'hC3; r_data_buf[9]  = 8'hC2; r_data_buf[10] = 8'hC1; r_data_buf[11] = 8'hC0;
    r_data_buf[12] = 8'hD3; r_data_buf[13] = 8'hD2; r_data_buf[14] = 8'hD1; r_data_buf[15] = 8'hD0;
    build_request(8'd15, 8'h03, 40'h0000_0001_00);
    clear_data_buf();
    build_expected_response(8'd0, 8'h03, 40'h0000_0001_00, 8'h00);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "full_write_ok");
    compare_expected("full_write_ok");
    if ((u_axi_slave.r_mem_word[10'h040] !== 32'hA0A1_A2A3) ||
        (u_axi_slave.r_mem_word[10'h041] !== 32'hB0B1_B2B3) ||
        (u_axi_slave.r_mem_word[10'h042] !== 32'hC0C1_C2C3) ||
        (u_axi_slave.r_mem_word[10'h043] !== 32'hD0D1_D2D3)) begin
        $display("[FAIL] full_write_ok: AXI memory content r_mismatch");
        r_fail_count = r_fail_count + 1;
    end

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    r_full_ar_wait_cycles = 8'd2;
    r_full_r_wait_cycles  = 8'd1;
    u_axi_slave.r_mem_word[10'h040] = 32'hA0A1_A2A3;
    u_axi_slave.r_mem_word[10'h041] = 32'hB0B1_B2B3;
    build_request(8'd7, 8'h04, 40'h0000_0001_00);
    r_data_buf[0] = 8'hA3; r_data_buf[1] = 8'hA2; r_data_buf[2] = 8'hA1; r_data_buf[3] = 8'hA0;
    r_data_buf[4] = 8'hB3; r_data_buf[5] = 8'hB2; r_data_buf[6] = 8'hB1; r_data_buf[7] = 8'hB0;
    build_expected_response(8'd7, 8'h04, 40'h0000_0001_00, 8'h00);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "full_read_ok");
    compare_expected("full_read_ok");
    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    r_full_aw_wait_cycles = 8'd2;
    r_full_w_wait_cycles  = 8'd1;
    r_full_b_wait_cycles  = 8'd2;
    for (r_idx = 0; r_idx < 64; r_idx = r_idx + 1) begin
        r_data_buf[r_idx * 4] = r_idx[7:0];
        r_data_buf[r_idx * 4 + 1] = 8'h40 + r_idx[7:0];
        r_data_buf[r_idx * 4 + 2] = 8'h80 + r_idx[7:0];
        r_data_buf[r_idx * 4 + 3] = 8'hC0 + r_idx[7:0];
    end
    build_request(8'd255, 8'h03, 40'h0000_0005_00);
    build_expected_response(8'd0, 8'h03, 40'h0000_0005_00, 8'h00);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "full_write_256b");
    compare_expected("full_write_256b");
    r_full_mem_mismatch = 1'b0;
    for (r_idx = 0; r_idx < 64; r_idx = r_idx + 1) begin
        if (u_axi_slave.r_mem_word[10'h140 + r_idx] !== {8'hC0 + r_idx[7:0], 8'h80 + r_idx[7:0], 8'h40 + r_idx[7:0], r_idx[7:0]}) begin
            r_full_mem_mismatch = 1'b1;
        end
    end
    if (r_full_mem_mismatch) begin
        $display("[FAIL] full_write_256b: AXI memory content r_mismatch");
        r_fail_count = r_fail_count + 1;
    end

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    u_axi_slave.r_mem_word[10'h080] = 32'hDEAD_BEEF;
    u_axi_slave.r_mem_word[10'h081] = 32'h1234_5678;
    build_request(8'd4, 8'h04, 40'h0000_0002_00);
    r_data_buf[0] = 8'hEF; r_data_buf[1] = 8'hBE; r_data_buf[2] = 8'hAD; r_data_buf[3] = 8'hDE; r_data_buf[4] = 8'h78;
    build_expected_response(8'd4, 8'h04, 40'h0000_0002_00, 8'h00);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "full_read_partial_ok");
    compare_expected("full_read_partial_ok");
    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    for (r_idx = 0; r_idx < 64; r_idx = r_idx + 1) begin
        u_axi_slave.r_mem_word[10'h0C0 + r_idx] = {8'h30 + r_idx[7:0], 8'h20 + r_idx[7:0], 8'h10 + r_idx[7:0], r_idx[7:0]};
        r_data_buf[r_idx * 4] = r_idx[7:0];
        r_data_buf[r_idx * 4 + 1] = 8'h10 + r_idx[7:0];
        r_data_buf[r_idx * 4 + 2] = 8'h20 + r_idx[7:0];
        r_data_buf[r_idx * 4 + 3] = 8'h30 + r_idx[7:0];
    end
    build_request(8'd255, 8'h04, 40'h0000_0003_00);
    build_expected_response(8'd255, 8'h04, 40'h0000_0003_00, 8'h00);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "full_read_256b");
    compare_expected("full_read_256b");

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    r_data_buf[0] = 8'h78; r_data_buf[1] = 8'h56; r_data_buf[2] = 8'h34; r_data_buf[3] = 8'h12;
    build_request(8'd4, 8'h01, 40'h0000_0000_A3);
    clear_data_buf();
    build_expected_response(8'd0, 8'h01, 40'h0000_0000_A3, 8'h01);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "align_err");
    compare_expected("align_err");

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    r_data_buf[0] = 8'h01; r_data_buf[1] = 8'h02; r_data_buf[2] = 8'h03; r_data_buf[3] = 8'h04;
    r_data_buf[4] = 8'h05; r_data_buf[5] = 8'h06;
    build_request(8'd5, 8'h03, 40'h0000_0001_00);
    clear_data_buf();
    build_expected_response(8'd0, 8'h03, 40'h0000_0001_00, 8'h03);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "len_err");
    compare_expected("len_err");

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    build_request(8'd0, 8'h07, 40'h0000_0000_00);
    clear_data_buf();
    build_expected_response(8'd0, 8'h07, 40'h0000_0000_00, 8'h04);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "cmd_err");
    compare_expected("cmd_err");

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    r_data_buf[0] = 8'h78; r_data_buf[1] = 8'h56; r_data_buf[2] = 8'h34; r_data_buf[3] = 8'h12;
    build_request(8'd4, 8'h01, 40'h0000_0000_A0);
    r_tx_buf[r_tx_count - 2] = r_tx_buf[r_tx_count - 2] ^ 8'hFF;
    send_tx_buffer();
    expect_no_response("chk_drop");

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    r_lite_block_r = 1'b1;
    build_request(8'd4, 8'h02, 40'h0000_0000_A0);
    clear_data_buf();
    build_expected_response(8'd0, 8'h02, 40'h0000_0000_A0, 8'h02);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "axil_timeout");
    compare_expected("axil_timeout");

    r_case_count = r_case_count + 1;
    clear_rx_buffer();
    clear_data_buf();
    set_default_slave_ctrl();
    r_full_block_r = 1'b1;
    build_request(8'd3, 8'h04, 40'h0000_0001_00);
    clear_data_buf();
    build_expected_response(8'd0, 8'h04, 40'h0000_0001_00, 8'h02);
    send_tx_buffer();
    wait_for_rx_bytes(r_exp_count, "axif_timeout");
    compare_expected("axif_timeout");

    wait_clocks(100);
    $display("Cases: %0d, Failures: %0d", r_case_count, r_fail_count);

    if (r_fail_count == 0) begin
        $display("TB PASS");
    end
    else begin
        $fatal(1, "TB FAIL");
    end

    $finish;
end

endmodule

`default_nettype wire