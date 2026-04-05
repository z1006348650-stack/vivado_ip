`timescale 1ns / 1ps
`default_nettype none

module uart_axi_bridge #(
    parameter integer SYS_CLK_FREQ_HZ      = 50000000,
    parameter integer UART_BAUD_RATE       = 115200,
    parameter integer AXI_ADDR_WIDTH       = 40,
    parameter integer AXI_TIMEOUT_CYCLES   = 1024,
    parameter integer MAX_FRAME_DATA_BYTES = 1024,
    parameter [3:0]   AXI_FULL_AWCACHE     = 4'b0011,
    parameter [3:0]   AXI_FULL_ARCACHE     = 4'b0011,
    parameter [2:0]   AXI_FULL_AWPROT      = 3'b000,
    parameter [2:0]   AXI_FULL_ARPROT      = 3'b000,
    parameter [3:0]   AXI_FULL_AWQOS       = 4'd0,
    parameter [3:0]   AXI_FULL_ARQOS       = 4'd0
) (
    input  wire                      i_clk,
    input  wire                      i_rst_n,
    input  wire                      i_uart_rx,
    output wire                      o_uart_tx,
    output wire [AXI_ADDR_WIDTH-1:0] o_m_axil_awaddr,
    output wire [2:0]                o_m_axil_awprot,
    output wire                      o_m_axil_awvalid,
    input  wire                      i_m_axil_awready,
    output wire [31:0]               o_m_axil_wdata,
    output wire [3:0]                o_m_axil_wstrb,
    output wire                      o_m_axil_wvalid,
    input  wire                      i_m_axil_wready,
    input  wire [1:0]                i_m_axil_bresp,
    input  wire                      i_m_axil_bvalid,
    output wire                      o_m_axil_bready,
    output wire [AXI_ADDR_WIDTH-1:0] o_m_axil_araddr,
    output wire [2:0]                o_m_axil_arprot,
    output wire                      o_m_axil_arvalid,
    input  wire                      i_m_axil_arready,
    input  wire [31:0]               i_m_axil_rdata,
    input  wire [1:0]                i_m_axil_rresp,
    input  wire                      i_m_axil_rvalid,
    output wire                      o_m_axil_rready,
    output wire [AXI_ADDR_WIDTH-1:0] o_m_axi_awaddr,
    output wire [7:0]                o_m_axi_awlen,
    output wire [2:0]                o_m_axi_awsize,
    output wire [1:0]                o_m_axi_awburst,
    output wire                      o_m_axi_awlock,
    output wire [3:0]                o_m_axi_awcache,
    output wire [2:0]                o_m_axi_awprot,
    output wire [3:0]                o_m_axi_awqos,
    output wire                      o_m_axi_awvalid,
    input  wire                      i_m_axi_awready,
    output wire [31:0]               o_m_axi_wdata,
    output wire [3:0]                o_m_axi_wstrb,
    output wire                      o_m_axi_wlast,
    output wire                      o_m_axi_wvalid,
    input  wire                      i_m_axi_wready,
    input  wire [1:0]                i_m_axi_bresp,
    input  wire                      i_m_axi_bvalid,
    output wire                      o_m_axi_bready,
    output wire [AXI_ADDR_WIDTH-1:0] o_m_axi_araddr,
    output wire [7:0]                o_m_axi_arlen,
    output wire [2:0]                o_m_axi_arsize,
    output wire [1:0]                o_m_axi_arburst,
    output wire                      o_m_axi_arlock,
    output wire [3:0]                o_m_axi_arcache,
    output wire [2:0]                o_m_axi_arprot,
    output wire [3:0]                o_m_axi_arqos,
    output wire                      o_m_axi_arvalid,
    input  wire                      i_m_axi_arready,
    input  wire [31:0]               i_m_axi_rdata,
    input  wire [1:0]                i_m_axi_rresp,
    input  wire                      i_m_axi_rlast,
    input  wire                      i_m_axi_rvalid,
    output wire                      o_m_axi_rready
);

localparam integer LP_UART_CLKS_PER_BIT_RAW = (SYS_CLK_FREQ_HZ + (UART_BAUD_RATE / 2)) / UART_BAUD_RATE;
localparam integer LP_UART_CLKS_PER_BIT     = (LP_UART_CLKS_PER_BIT_RAW < 1) ? 1 : LP_UART_CLKS_PER_BIT_RAW;
localparam integer LP_MAX_FRAME_DATA_BYTES  = (MAX_FRAME_DATA_BYTES < 4) ? 4 : ((MAX_FRAME_DATA_BYTES > 1024) ? 1024 : MAX_FRAME_DATA_BYTES);

wire w_rst;
wire w_uart_rx_dv;
wire [7:0] w_uart_rx_byte;
wire w_parser_req_valid;
wire w_parser_req_ready;
wire [15:0] w_parser_req_len;
wire [7:0] w_parser_req_cmd;
wire [39:0] w_parser_req_addr;
wire w_parser_req_data_wr_en;
wire [9:0] w_parser_req_data_wr_addr;
wire [7:0] w_parser_req_data_wr_byte;
wire w_parser_frame_drop_pulse;
wire w_builder_resp_ready;
wire w_builder_tx_valid;
wire [7:0] w_builder_tx_byte;
wire w_uart_tx_ready;
wire w_bridge_busy;
wire w_axil_cmd_valid;
wire w_axil_cmd_ready;
wire w_axil_cmd_write;
wire [AXI_ADDR_WIDTH-1:0] w_axil_cmd_addr;
wire [31:0] w_axil_cmd_wdata;
wire w_axil_cmd_done;
wire w_axil_cmd_error;
wire w_axil_cmd_timeout;
wire [31:0] w_axil_cmd_rdata;
wire w_axif_cmd_valid;
wire w_axif_cmd_ready;
wire w_axif_cmd_write;
wire [AXI_ADDR_WIDTH-1:0] w_axif_cmd_addr;
wire [8:0] w_axif_cmd_beats;
wire w_axif_cmd_done;
wire w_axif_cmd_error;
wire w_axif_cmd_timeout;
wire [31:0] w_axif_wr_data;
wire w_axif_wr_valid;
wire w_axif_wr_ready;
wire [31:0] w_axif_rd_data;
wire w_axif_rd_valid;
wire w_axif_rd_ready;
wire w_resp_valid;
wire [15:0] w_resp_len_field;
wire [10:0] w_resp_data_count;
wire [7:0] w_resp_cmd;
wire [39:0] w_resp_addr;
wire [7:0] w_resp_status;
wire w_resp_data_wr_en;
wire [9:0] w_resp_data_wr_addr;
wire [7:0] w_resp_data_wr_byte;

reset_sync u_reset_sync (
    .i_clk   (i_clk),
    .i_rst_n (i_rst_n),
    .o_rst   (w_rst)
);

uart_rx #(
    .CLKS_PER_BIT (LP_UART_CLKS_PER_BIT)
) u_uart_rx (
    .i_clk      (i_clk),
    .i_rst      (w_rst),
    .i_rx_serial(i_uart_rx),
    .o_rx_dv    (w_uart_rx_dv),
    .o_rx_byte  (w_uart_rx_byte)
);

frame_parser #(
    .MAX_FRAME_DATA_BYTES (LP_MAX_FRAME_DATA_BYTES)
) u_frame_parser (
    .i_clk             (i_clk),
    .i_rst             (w_rst),
    .i_rx_dv           (w_uart_rx_dv & ~w_bridge_busy),
    .i_rx_byte         (w_uart_rx_byte),
    .o_req_valid       (w_parser_req_valid),
    .i_req_ready       (w_parser_req_ready),
    .o_req_len         (w_parser_req_len),
    .o_req_cmd         (w_parser_req_cmd),
    .o_req_addr        (w_parser_req_addr),
    .o_req_data_wr_en  (w_parser_req_data_wr_en),
    .o_req_data_wr_addr(w_parser_req_data_wr_addr),
    .o_req_data_wr_byte(w_parser_req_data_wr_byte),
    .o_frame_drop_pulse(w_parser_frame_drop_pulse)
);

bridge_ctrl #(
    .AXI_ADDR_WIDTH       (AXI_ADDR_WIDTH),
    .MAX_FRAME_DATA_BYTES (LP_MAX_FRAME_DATA_BYTES)
) u_bridge_ctrl (
    .i_clk             (i_clk),
    .i_rst             (w_rst),
    .i_req_valid       (w_parser_req_valid),
    .o_req_ready       (w_parser_req_ready),
    .i_req_len         (w_parser_req_len),
    .i_req_cmd         (w_parser_req_cmd),
    .i_req_addr        (w_parser_req_addr),
    .i_req_data_wr_en  (w_parser_req_data_wr_en),
    .i_req_data_wr_addr(w_parser_req_data_wr_addr),
    .i_req_data_wr_byte(w_parser_req_data_wr_byte),
    .o_resp_valid      (w_resp_valid),
    .i_resp_ready      (w_builder_resp_ready),
    .o_resp_len_field  (w_resp_len_field),
    .o_resp_data_count (w_resp_data_count),
    .o_resp_cmd        (w_resp_cmd),
    .o_resp_addr       (w_resp_addr),
    .o_resp_status     (w_resp_status),
    .o_resp_data_wr_en (w_resp_data_wr_en),
    .o_resp_data_wr_addr(w_resp_data_wr_addr),
    .o_resp_data_wr_byte(w_resp_data_wr_byte),
    .o_axil_cmd_valid  (w_axil_cmd_valid),
    .i_axil_cmd_ready  (w_axil_cmd_ready),
    .o_axil_cmd_write  (w_axil_cmd_write),
    .o_axil_cmd_addr   (w_axil_cmd_addr),
    .o_axil_cmd_wdata  (w_axil_cmd_wdata),
    .i_axil_cmd_done   (w_axil_cmd_done),
    .i_axil_cmd_error  (w_axil_cmd_error),
    .i_axil_cmd_timeout(w_axil_cmd_timeout),
    .i_axil_cmd_rdata  (w_axil_cmd_rdata),
    .o_axif_cmd_valid  (w_axif_cmd_valid),
    .i_axif_cmd_ready  (w_axif_cmd_ready),
    .o_axif_cmd_write  (w_axif_cmd_write),
    .o_axif_cmd_addr   (w_axif_cmd_addr),
    .o_axif_cmd_beats  (w_axif_cmd_beats),
    .i_axif_cmd_done   (w_axif_cmd_done),
    .i_axif_cmd_error  (w_axif_cmd_error),
    .i_axif_cmd_timeout(w_axif_cmd_timeout),
    .o_axif_wr_data    (w_axif_wr_data),
    .o_axif_wr_valid   (w_axif_wr_valid),
    .i_axif_wr_ready   (w_axif_wr_ready),
    .i_axif_rd_data    (w_axif_rd_data),
    .i_axif_rd_valid   (w_axif_rd_valid),
    .o_axif_rd_ready   (w_axif_rd_ready),
    .o_busy            (w_bridge_busy)
);

frame_builder #(
    .MAX_FRAME_DATA_BYTES (LP_MAX_FRAME_DATA_BYTES)
) u_frame_builder (
    .i_clk             (i_clk),
    .i_rst             (w_rst),
    .i_resp_valid      (w_resp_valid),
    .o_resp_ready      (w_builder_resp_ready),
    .i_resp_len_field  (w_resp_len_field),
    .i_resp_data_count (w_resp_data_count),
    .i_resp_cmd        (w_resp_cmd),
    .i_resp_addr       (w_resp_addr),
    .i_resp_status     (w_resp_status),
    .i_resp_data_wr_en (w_resp_data_wr_en),
    .i_resp_data_wr_addr(w_resp_data_wr_addr),
    .i_resp_data_wr_byte(w_resp_data_wr_byte),
    .o_tx_valid        (w_builder_tx_valid),
    .i_tx_ready        (w_uart_tx_ready),
    .o_tx_byte         (w_builder_tx_byte),
    .o_busy            ()
);

uart_tx #(
    .CLKS_PER_BIT (LP_UART_CLKS_PER_BIT)
) u_uart_tx (
    .i_clk      (i_clk),
    .i_rst      (w_rst),
    .i_tx_valid (w_builder_tx_valid),
    .i_tx_byte  (w_builder_tx_byte),
    .o_tx_ready (w_uart_tx_ready),
    .o_tx_serial(o_uart_tx),
    .o_tx_active()
);

axi_lite_master #(
    .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH),
    .AXI_TIMEOUT_CYCLES (AXI_TIMEOUT_CYCLES)
) u_axi_lite_master (
    .i_clk           (i_clk),
    .i_rst           (w_rst),
    .i_cmd_valid     (w_axil_cmd_valid),
    .o_cmd_ready     (w_axil_cmd_ready),
    .i_cmd_write     (w_axil_cmd_write),
    .i_cmd_addr      (w_axil_cmd_addr),
    .i_cmd_wdata     (w_axil_cmd_wdata),
    .o_cmd_done      (w_axil_cmd_done),
    .o_cmd_error     (w_axil_cmd_error),
    .o_cmd_timeout   (w_axil_cmd_timeout),
    .o_cmd_rdata     (w_axil_cmd_rdata),
    .o_m_axil_awaddr (o_m_axil_awaddr),
    .o_m_axil_awprot (o_m_axil_awprot),
    .o_m_axil_awvalid(o_m_axil_awvalid),
    .i_m_axil_awready(i_m_axil_awready),
    .o_m_axil_wdata  (o_m_axil_wdata),
    .o_m_axil_wstrb  (o_m_axil_wstrb),
    .o_m_axil_wvalid (o_m_axil_wvalid),
    .i_m_axil_wready (i_m_axil_wready),
    .i_m_axil_bresp  (i_m_axil_bresp),
    .i_m_axil_bvalid (i_m_axil_bvalid),
    .o_m_axil_bready (o_m_axil_bready),
    .o_m_axil_araddr (o_m_axil_araddr),
    .o_m_axil_arprot (o_m_axil_arprot),
    .o_m_axil_arvalid(o_m_axil_arvalid),
    .i_m_axil_arready(i_m_axil_arready),
    .i_m_axil_rdata  (i_m_axil_rdata),
    .i_m_axil_rresp  (i_m_axil_rresp),
    .i_m_axil_rvalid (i_m_axil_rvalid),
    .o_m_axil_rready (o_m_axil_rready)
);

axi_full_master #(
    .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH),
    .AXI_TIMEOUT_CYCLES (AXI_TIMEOUT_CYCLES),
    .AXI_AWCACHE        (AXI_FULL_AWCACHE),
    .AXI_ARCACHE        (AXI_FULL_ARCACHE),
    .AXI_AWPROT         (AXI_FULL_AWPROT),
    .AXI_ARPROT         (AXI_FULL_ARPROT),
    .AXI_AWQOS          (AXI_FULL_AWQOS),
    .AXI_ARQOS          (AXI_FULL_ARQOS)
) u_axi_full_master (
    .i_clk          (i_clk),
    .i_rst          (w_rst),
    .i_cmd_valid    (w_axif_cmd_valid),
    .o_cmd_ready    (w_axif_cmd_ready),
    .i_cmd_write    (w_axif_cmd_write),
    .i_cmd_addr     (w_axif_cmd_addr),
    .i_cmd_beats    (w_axif_cmd_beats),
    .o_cmd_done     (w_axif_cmd_done),
    .o_cmd_error    (w_axif_cmd_error),
    .o_cmd_timeout  (w_axif_cmd_timeout),
    .i_wr_data      (w_axif_wr_data),
    .i_wr_valid     (w_axif_wr_valid),
    .o_wr_ready     (w_axif_wr_ready),
    .o_rd_data      (w_axif_rd_data),
    .o_rd_valid     (w_axif_rd_valid),
    .i_rd_ready     (w_axif_rd_ready),
    .o_m_axi_awaddr (o_m_axi_awaddr),
    .o_m_axi_awlen  (o_m_axi_awlen),
    .o_m_axi_awsize (o_m_axi_awsize),
    .o_m_axi_awburst(o_m_axi_awburst),
    .o_m_axi_awlock (o_m_axi_awlock),
    .o_m_axi_awcache(o_m_axi_awcache),
    .o_m_axi_awprot (o_m_axi_awprot),
    .o_m_axi_awqos  (o_m_axi_awqos),
    .o_m_axi_awvalid(o_m_axi_awvalid),
    .i_m_axi_awready(i_m_axi_awready),
    .o_m_axi_wdata  (o_m_axi_wdata),
    .o_m_axi_wstrb  (o_m_axi_wstrb),
    .o_m_axi_wlast  (o_m_axi_wlast),
    .o_m_axi_wvalid (o_m_axi_wvalid),
    .i_m_axi_wready (i_m_axi_wready),
    .i_m_axi_bresp  (i_m_axi_bresp),
    .i_m_axi_bvalid (i_m_axi_bvalid),
    .o_m_axi_bready (o_m_axi_bready),
    .o_m_axi_araddr (o_m_axi_araddr),
    .o_m_axi_arlen  (o_m_axi_arlen),
    .o_m_axi_arsize (o_m_axi_arsize),
    .o_m_axi_arburst(o_m_axi_arburst),
    .o_m_axi_arlock (o_m_axi_arlock),
    .o_m_axi_arcache(o_m_axi_arcache),
    .o_m_axi_arprot (o_m_axi_arprot),
    .o_m_axi_arqos  (o_m_axi_arqos),
    .o_m_axi_arvalid(o_m_axi_arvalid),
    .i_m_axi_arready(i_m_axi_arready),
    .i_m_axi_rdata  (i_m_axi_rdata),
    .i_m_axi_rresp  (i_m_axi_rresp),
    .i_m_axi_rlast  (i_m_axi_rlast),
    .i_m_axi_rvalid (i_m_axi_rvalid),
    .o_m_axi_rready (o_m_axi_rready)
);

endmodule

`default_nettype wire
