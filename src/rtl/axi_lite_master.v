`timescale 1ns / 1ps
`default_nettype none

module axi_lite_master #(
    parameter integer AXI_ADDR_WIDTH  = 40,
    parameter integer AXI_TIMEOUT_CYCLES = 1024
) (
    input  wire                        i_clk,
    input  wire                        i_rst,
    input  wire                        i_cmd_valid,
    output wire                        o_cmd_ready,
    input  wire                        i_cmd_write,
    input  wire [AXI_ADDR_WIDTH-1:0]   i_cmd_addr,
    input  wire [31:0]                 i_cmd_wdata,
    output reg                         o_cmd_done,
    output reg                         o_cmd_error,
    output reg                         o_cmd_timeout,
    output reg [31:0]                  o_cmd_rdata,
    output reg [AXI_ADDR_WIDTH-1:0]    o_m_axil_awaddr,
    output reg [2:0]                   o_m_axil_awprot,
    output reg                         o_m_axil_awvalid,
    input  wire                        i_m_axil_awready,
    output reg [31:0]                  o_m_axil_wdata,
    output reg [3:0]                   o_m_axil_wstrb,
    output reg                         o_m_axil_wvalid,
    input  wire                        i_m_axil_wready,
    input  wire [1:0]                  i_m_axil_bresp,
    input  wire                        i_m_axil_bvalid,
    output reg                         o_m_axil_bready,
    output reg [AXI_ADDR_WIDTH-1:0]    o_m_axil_araddr,
    output reg [2:0]                   o_m_axil_arprot,
    output reg                         o_m_axil_arvalid,
    input  wire                        i_m_axil_arready,
    input  wire [31:0]                 i_m_axil_rdata,
    input  wire [1:0]                  i_m_axil_rresp,
    input  wire                        i_m_axil_rvalid,
    output reg                         o_m_axil_rready
);

localparam [2:0] ST_IDLE  = 3'd0;
localparam [2:0] ST_WR_AW = 3'd1;
localparam [2:0] ST_WR_W  = 3'd2;
localparam [2:0] ST_WR_B  = 3'd3;
localparam [2:0] ST_RD_AR = 3'd4;
localparam [2:0] ST_RD_R  = 3'd5;

reg [2:0] r_state;
reg [31:0] r_timeout_cnt;

assign o_cmd_ready = (r_state == ST_IDLE);

always @(posedge i_clk) begin
    if (i_rst) begin
        r_state            <= ST_IDLE;
        r_timeout_cnt      <= 32'd0;
        o_cmd_done       <= 1'b0;
        o_cmd_error      <= 1'b0;
        o_cmd_timeout    <= 1'b0;
        o_cmd_rdata      <= 32'd0;
        o_m_axil_awaddr  <= {AXI_ADDR_WIDTH{1'b0}};
        o_m_axil_awprot  <= 3'b000;
        o_m_axil_awvalid <= 1'b0;
        o_m_axil_wdata   <= 32'd0;
        o_m_axil_wstrb   <= 4'hF;
        o_m_axil_wvalid  <= 1'b0;
        o_m_axil_bready  <= 1'b0;
        o_m_axil_araddr  <= {AXI_ADDR_WIDTH{1'b0}};
        o_m_axil_arprot  <= 3'b000;
        o_m_axil_arvalid <= 1'b0;
        o_m_axil_rready  <= 1'b0;
    end
    else begin
        o_cmd_done    <= 1'b0;
        o_cmd_error   <= 1'b0;
        o_cmd_timeout <= 1'b0;

        case (r_state)
            ST_IDLE: begin
                r_timeout_cnt <= 32'd0;

                if (i_cmd_valid) begin
                    if (i_cmd_write) begin
                        o_m_axil_awaddr  <= i_cmd_addr;
                        o_m_axil_awprot  <= 3'b000;
                        o_m_axil_awvalid <= 1'b1;
                        o_m_axil_wdata   <= i_cmd_wdata;
                        o_m_axil_wstrb   <= 4'hF;
                        r_state            <= ST_WR_AW;
                    end
                    else begin
                        o_m_axil_araddr  <= i_cmd_addr;
                        o_m_axil_arprot  <= 3'b000;
                        o_m_axil_arvalid <= 1'b1;
                        r_state            <= ST_RD_AR;
                    end
                end
            end

            ST_WR_AW: begin
                if (o_m_axil_awvalid && i_m_axil_awready) begin
                    o_m_axil_awvalid <= 1'b0;
                    o_m_axil_wvalid  <= 1'b1;
                    r_timeout_cnt       <= 32'd0;
                    r_state             <= ST_WR_W;
                end
                else if (r_timeout_cnt >= (AXI_TIMEOUT_CYCLES - 1)) begin
                    o_m_axil_awvalid <= 1'b0;
                    o_cmd_done       <= 1'b1;
                    o_cmd_error      <= 1'b1;
                    o_cmd_timeout    <= 1'b1;
                    r_timeout_cnt      <= 32'd0;
                    r_state            <= ST_IDLE;
                end
                else begin
                    r_timeout_cnt <= r_timeout_cnt + 32'd1;
                end
            end

            ST_WR_W: begin
                if (o_m_axil_wvalid && i_m_axil_wready) begin
                    o_m_axil_wvalid <= 1'b0;
                    o_m_axil_bready <= 1'b1;
                    r_timeout_cnt      <= 32'd0;
                    r_state            <= ST_WR_B;
                end
                else if (r_timeout_cnt >= (AXI_TIMEOUT_CYCLES - 1)) begin
                    o_m_axil_wvalid <= 1'b0;
                    o_cmd_done      <= 1'b1;
                    o_cmd_error     <= 1'b1;
                    o_cmd_timeout   <= 1'b1;
                    r_timeout_cnt     <= 32'd0;
                    r_state           <= ST_IDLE;
                end
                else begin
                    r_timeout_cnt <= r_timeout_cnt + 32'd1;
                end
            end

            ST_WR_B: begin
                if (i_m_axil_bvalid && o_m_axil_bready) begin
                    o_m_axil_bready <= 1'b0;
                    o_cmd_done      <= 1'b1;
                    o_cmd_error     <= (i_m_axil_bresp != 2'b00);
                    r_timeout_cnt     <= 32'd0;
                    r_state           <= ST_IDLE;
                end
                else if (r_timeout_cnt >= (AXI_TIMEOUT_CYCLES - 1)) begin
                    o_m_axil_bready <= 1'b0;
                    o_cmd_done      <= 1'b1;
                    o_cmd_error     <= 1'b1;
                    o_cmd_timeout   <= 1'b1;
                    r_timeout_cnt     <= 32'd0;
                    r_state           <= ST_IDLE;
                end
                else begin
                    r_timeout_cnt <= r_timeout_cnt + 32'd1;
                end
            end

            ST_RD_AR: begin
                if (o_m_axil_arvalid && i_m_axil_arready) begin
                    o_m_axil_arvalid <= 1'b0;
                    o_m_axil_rready  <= 1'b1;
                    r_timeout_cnt      <= 32'd0;
                    r_state            <= ST_RD_R;
                end
                else if (r_timeout_cnt >= (AXI_TIMEOUT_CYCLES - 1)) begin
                    o_m_axil_arvalid <= 1'b0;
                    o_cmd_done       <= 1'b1;
                    o_cmd_error      <= 1'b1;
                    o_cmd_timeout    <= 1'b1;
                    r_timeout_cnt      <= 32'd0;
                    r_state            <= ST_IDLE;
                end
                else begin
                    r_timeout_cnt <= r_timeout_cnt + 32'd1;
                end
            end

            ST_RD_R: begin
                if (i_m_axil_rvalid && o_m_axil_rready) begin
                    o_m_axil_rready <= 1'b0;
                    o_cmd_rdata     <= i_m_axil_rdata;
                    o_cmd_done      <= 1'b1;
                    o_cmd_error     <= (i_m_axil_rresp != 2'b00);
                    r_timeout_cnt     <= 32'd0;
                    r_state           <= ST_IDLE;
                end
                else if (r_timeout_cnt >= (AXI_TIMEOUT_CYCLES - 1)) begin
                    o_m_axil_rready <= 1'b0;
                    o_cmd_done      <= 1'b1;
                    o_cmd_error     <= 1'b1;
                    o_cmd_timeout   <= 1'b1;
                    r_timeout_cnt     <= 32'd0;
                    r_state           <= ST_IDLE;
                end
                else begin
                    r_timeout_cnt <= r_timeout_cnt + 32'd1;
                end
            end

            default: begin
                r_state <= ST_IDLE;
            end
        endcase
    end
end

endmodule

`default_nettype wire