`timescale 1ns / 1ps
`default_nettype none

module bridge_ctrl #(
    parameter integer AXI_ADDR_WIDTH       = 40,
    parameter integer MAX_FRAME_DATA_BYTES = 1024
) (
    input  wire                      i_clk,
    input  wire                      i_rst,
    input  wire                      i_req_valid,
    output reg                       o_req_ready,
    input  wire [15:0]               i_req_len,
    input  wire [7:0]                i_req_cmd,
    input  wire [39:0]               i_req_addr,
    input  wire                      i_req_data_wr_en,
    input  wire [9:0]                i_req_data_wr_addr,
    input  wire [7:0]                i_req_data_wr_byte,
    output reg                       o_resp_valid,
    input  wire                      i_resp_ready,
    output reg [15:0]                o_resp_len_field,
    output reg [10:0]                o_resp_data_count,
    output reg [7:0]                 o_resp_cmd,
    output reg [39:0]                o_resp_addr,
    output reg [7:0]                 o_resp_status,
    output reg                       o_resp_data_wr_en,
    output reg [9:0]                 o_resp_data_wr_addr,
    output reg [7:0]                 o_resp_data_wr_byte,
    output reg                       o_axil_cmd_valid,
    input  wire                      i_axil_cmd_ready,
    output reg                       o_axil_cmd_write,
    output reg [AXI_ADDR_WIDTH-1:0]  o_axil_cmd_addr,
    output reg [31:0]                o_axil_cmd_wdata,
    input  wire                      i_axil_cmd_done,
    input  wire                      i_axil_cmd_error,
    input  wire                      i_axil_cmd_timeout,
    input  wire [31:0]               i_axil_cmd_rdata,
    output reg                       o_axif_cmd_valid,
    input  wire                      i_axif_cmd_ready,
    output reg                       o_axif_cmd_write,
    output reg [AXI_ADDR_WIDTH-1:0]  o_axif_cmd_addr,
    output reg [8:0]                 o_axif_cmd_beats,
    input  wire                      i_axif_cmd_done,
    input  wire                      i_axif_cmd_error,
    input  wire                      i_axif_cmd_timeout,
    output wire [31:0]               o_axif_wr_data,
    output wire                      o_axif_wr_valid,
    input  wire                      i_axif_wr_ready,
    input  wire [31:0]               i_axif_rd_data,
    input  wire                      i_axif_rd_valid,
    output reg                       o_axif_rd_ready,
    output wire                      o_busy
);

localparam [3:0] ST_IDLE       = 4'd0;
localparam [3:0] ST_CHECK      = 4'd1;
localparam [3:0] ST_AXIL_START = 4'd2;
localparam [3:0] ST_AXIL_WAIT  = 4'd3;
localparam [3:0] ST_AXIF_START = 4'd4;
localparam [3:0] ST_AXIF_WRITE = 4'd5;
localparam [3:0] ST_AXIF_READ  = 4'd6;
localparam [3:0] ST_RESP_COPY  = 4'd7;
localparam [3:0] ST_RESP_SEND  = 4'd8;

localparam [7:0] CMD_LITE_WRITE = 8'h01;
localparam [7:0] CMD_LITE_READ  = 8'h02;
localparam [7:0] CMD_FULL_WRITE = 8'h03;
localparam [7:0] CMD_FULL_READ  = 8'h04;

localparam [7:0] STATUS_SUCCESS   = 8'h00;
localparam [7:0] STATUS_ALIGN_ERR = 8'h01;
localparam [7:0] STATUS_AXI_ERR   = 8'h02;
localparam [7:0] STATUS_LEN_ERR   = 8'h03;
localparam [7:0] STATUS_CMD_ERR   = 8'h04;

localparam integer LP_MAX_FRAME_DATA_BYTES = (MAX_FRAME_DATA_BYTES < 4) ? 4 : ((MAX_FRAME_DATA_BYTES > 1024) ? 1024 : MAX_FRAME_DATA_BYTES);

reg [3:0] r_state;
reg [7:0] r_req_data_mem [0:LP_MAX_FRAME_DATA_BYTES-1];
reg [7:0] r_resp_data_mem [0:LP_MAX_FRAME_DATA_BYTES-1];
reg [15:0] r_req_len_field_latched;
reg [7:0] r_req_cmd_latched;
reg [39:0] r_req_addr_latched;
reg [15:0] r_resp_len_field_latched;
reg [10:0] r_resp_data_count_latched;
reg [7:0] r_resp_status_latched;
reg [9:0] r_copy_idx;
reg [8:0] r_axif_wr_word_idx;
reg [10:0] r_axif_rd_byte_idx;
reg [8:0] r_axif_beats_latched;
wire [31:0] w_lite_req_word;
wire [9:0] w_axif_wr_base;
wire [31:0] w_full_req_word;
wire [15:0] w_full_req_byte_count;
wire [8:0] w_full_write_beats;
wire [8:0] w_full_read_beats;
wire [10:0] w_axif_rd_idx_p1;
wire [10:0] w_axif_rd_idx_p2;
wire [10:0] w_axif_rd_idx_p3;
wire w_req_addr_unaligned;

assign o_busy = (r_state != ST_IDLE);
assign w_lite_req_word = {r_req_data_mem[8'd3], r_req_data_mem[8'd2], r_req_data_mem[8'd1], r_req_data_mem[8'd0]};
assign w_axif_wr_base = {r_axif_wr_word_idx[7:0], 2'b00};
assign w_full_req_word = {
    r_req_data_mem[w_axif_wr_base + 10'd3],
    r_req_data_mem[w_axif_wr_base + 10'd2],
    r_req_data_mem[w_axif_wr_base + 10'd1],
    r_req_data_mem[w_axif_wr_base + 10'd0]
};
assign w_full_req_byte_count = r_req_len_field_latched;
assign w_full_write_beats = w_full_req_byte_count[10:2];
assign w_full_read_beats = w_full_req_byte_count[10:2] + ((w_full_req_byte_count[1:0] != 2'b00) ? 9'd1 : 9'd0);
assign w_axif_rd_idx_p1 = r_axif_rd_byte_idx + 11'd1;
assign w_axif_rd_idx_p2 = r_axif_rd_byte_idx + 11'd2;
assign w_axif_rd_idx_p3 = r_axif_rd_byte_idx + 11'd3;
assign w_req_addr_unaligned = (r_req_addr_latched[1:0] != 2'b00);
assign o_axif_wr_valid = (r_state == ST_AXIF_WRITE) && (r_axif_wr_word_idx < r_axif_beats_latched);
assign o_axif_wr_data  = w_full_req_word;

integer r_idx;

always @(posedge i_clk) begin
    if (i_rst) begin
        r_state                   <= ST_IDLE;
        r_req_len_field_latched   <= 16'd0;
        r_req_cmd_latched         <= 8'd0;
        r_req_addr_latched        <= 40'd0;
        r_resp_len_field_latched  <= 16'd0;
        r_resp_data_count_latched <= 11'd0;
        r_resp_status_latched     <= 8'd0;
        r_copy_idx                <= 10'd0;
        r_axif_wr_word_idx        <= 9'd0;
        r_axif_rd_byte_idx        <= 11'd0;
        r_axif_beats_latched      <= 9'd0;
        o_req_ready               <= 1'b0;
        o_resp_valid              <= 1'b0;
        o_resp_len_field          <= 16'd0;
        o_resp_data_count         <= 11'd0;
        o_resp_cmd                <= 8'd0;
        o_resp_addr               <= 40'd0;
        o_resp_status             <= 8'd0;
        o_resp_data_wr_en         <= 1'b0;
        o_resp_data_wr_addr       <= 10'd0;
        o_resp_data_wr_byte       <= 8'd0;
        o_axil_cmd_valid          <= 1'b0;
        o_axil_cmd_write          <= 1'b0;
        o_axil_cmd_addr           <= {AXI_ADDR_WIDTH{1'b0}};
        o_axil_cmd_wdata          <= 32'd0;
        o_axif_cmd_valid          <= 1'b0;
        o_axif_cmd_write          <= 1'b0;
        o_axif_cmd_addr           <= {AXI_ADDR_WIDTH{1'b0}};
        o_axif_cmd_beats          <= 9'd0;
        o_axif_rd_ready           <= 1'b0;
        for (r_idx = 0; r_idx < LP_MAX_FRAME_DATA_BYTES; r_idx = r_idx + 1) begin
            r_req_data_mem[r_idx]  <= 8'd0;
            r_resp_data_mem[r_idx] <= 8'd0;
        end
    end
    else begin
        o_req_ready       <= 1'b0;
        o_resp_valid      <= 1'b0;
        o_resp_data_wr_en <= 1'b0;
        o_axil_cmd_valid  <= 1'b0;
        o_axif_cmd_valid  <= 1'b0;
        o_axif_rd_ready   <= 1'b0;

        if (i_req_data_wr_en && (i_req_data_wr_addr < LP_MAX_FRAME_DATA_BYTES)) begin
            r_req_data_mem[i_req_data_wr_addr] <= i_req_data_wr_byte;
        end

        if ((r_state == ST_AXIF_READ) && i_axif_rd_valid) begin
            if (r_axif_rd_byte_idx < w_full_req_byte_count[10:0]) begin
                r_resp_data_mem[r_axif_rd_byte_idx[9:0]] <= i_axif_rd_data[7:0];
            end
            if (w_axif_rd_idx_p1 < w_full_req_byte_count[10:0]) begin
                r_resp_data_mem[w_axif_rd_idx_p1[9:0]] <= i_axif_rd_data[15:8];
            end
            if (w_axif_rd_idx_p2 < w_full_req_byte_count[10:0]) begin
                r_resp_data_mem[w_axif_rd_idx_p2[9:0]] <= i_axif_rd_data[23:16];
            end
            if (w_axif_rd_idx_p3 < w_full_req_byte_count[10:0]) begin
                r_resp_data_mem[w_axif_rd_idx_p3[9:0]] <= i_axif_rd_data[31:24];
            end
        end

        case (r_state)
            ST_IDLE: begin
                if (i_req_valid && i_resp_ready && i_axil_cmd_ready && i_axif_cmd_ready) begin
                    o_req_ready             <= 1'b1;
                    r_req_len_field_latched <= i_req_len;
                    r_req_cmd_latched       <= i_req_cmd;
                    r_req_addr_latched      <= i_req_addr;
                    r_state                 <= ST_CHECK;
                end
            end
            ST_CHECK: begin
                o_resp_cmd  <= r_req_cmd_latched;
                o_resp_addr <= r_req_addr_latched;
                if ((r_req_cmd_latched != CMD_LITE_WRITE) &&
                    (r_req_cmd_latched != CMD_LITE_READ)  &&
                    (r_req_cmd_latched != CMD_FULL_WRITE) &&
                    (r_req_cmd_latched != CMD_FULL_READ)) begin
                    r_resp_len_field_latched  <= 16'd0;
                    r_resp_data_count_latched <= 11'd0;
                    r_resp_status_latched     <= STATUS_CMD_ERR;
                    r_state                   <= ST_RESP_SEND;
                end
                else if (w_req_addr_unaligned) begin
                    r_resp_len_field_latched  <= 16'd0;
                    r_resp_data_count_latched <= 11'd0;
                    r_resp_status_latched     <= STATUS_ALIGN_ERR;
                    r_state                   <= ST_RESP_SEND;
                end
                else if (((r_req_cmd_latched == CMD_LITE_WRITE) ||
                          (r_req_cmd_latched == CMD_LITE_READ)) && (r_req_len_field_latched != 16'd4)) begin
                    r_resp_len_field_latched  <= 16'd0;
                    r_resp_data_count_latched <= 11'd0;
                    r_resp_status_latched     <= STATUS_LEN_ERR;
                    r_state                   <= ST_RESP_SEND;
                end
                else if ((r_req_cmd_latched == CMD_FULL_WRITE) &&
                         ((w_full_req_byte_count < 16'd4) ||
                          (w_full_req_byte_count > LP_MAX_FRAME_DATA_BYTES) ||
                          (w_full_req_byte_count[1:0] != 2'b00))) begin
                    r_resp_len_field_latched  <= 16'd0;
                    r_resp_data_count_latched <= 11'd0;
                    r_resp_status_latched     <= STATUS_LEN_ERR;
                    r_state                   <= ST_RESP_SEND;
                end
                else if ((r_req_cmd_latched == CMD_FULL_READ) &&
                         ((w_full_req_byte_count < 16'd1) ||
                          (w_full_req_byte_count > LP_MAX_FRAME_DATA_BYTES))) begin
                    r_resp_len_field_latched  <= 16'd0;
                    r_resp_data_count_latched <= 11'd0;
                    r_resp_status_latched     <= STATUS_LEN_ERR;
                    r_state                   <= ST_RESP_SEND;
                end
                else if ((r_req_cmd_latched == CMD_LITE_WRITE) || (r_req_cmd_latched == CMD_LITE_READ)) begin
                    o_axil_cmd_write <= (r_req_cmd_latched == CMD_LITE_WRITE);
                    o_axil_cmd_addr  <= r_req_addr_latched[AXI_ADDR_WIDTH-1:0];
                    o_axil_cmd_wdata <= w_lite_req_word;
                    r_state          <= ST_AXIL_START;
                end
                else begin
                    o_axif_cmd_write   <= (r_req_cmd_latched == CMD_FULL_WRITE);
                    o_axif_cmd_addr    <= r_req_addr_latched[AXI_ADDR_WIDTH-1:0];
                    o_axif_cmd_beats   <= (r_req_cmd_latched == CMD_FULL_WRITE) ? w_full_write_beats : w_full_read_beats;
                    r_axif_beats_latched <= (r_req_cmd_latched == CMD_FULL_WRITE) ? w_full_write_beats : w_full_read_beats;
                    r_axif_wr_word_idx   <= 9'd0;
                    r_axif_rd_byte_idx   <= 11'd0;
                    r_state              <= ST_AXIF_START;
                end
            end
            ST_AXIL_START: begin
                o_axil_cmd_valid <= 1'b1;
                if (i_axil_cmd_ready) begin
                    r_state <= ST_AXIL_WAIT;
                end
            end
            ST_AXIL_WAIT: begin
                if (i_axil_cmd_done) begin
                    if (i_axil_cmd_error || i_axil_cmd_timeout) begin
                        r_resp_len_field_latched  <= 16'd0;
                        r_resp_data_count_latched <= 11'd0;
                        r_resp_status_latched     <= STATUS_AXI_ERR;
                        r_state                   <= ST_RESP_SEND;
                    end
                    else if (r_req_cmd_latched == CMD_LITE_WRITE) begin
                        r_resp_len_field_latched  <= 16'd0;
                        r_resp_data_count_latched <= 11'd0;
                        r_resp_status_latched     <= STATUS_SUCCESS;
                        r_state                   <= ST_RESP_SEND;
                    end
                    else begin
                        r_resp_data_mem[8'd0]     <= i_axil_cmd_rdata[7:0];
                        r_resp_data_mem[8'd1]     <= i_axil_cmd_rdata[15:8];
                        r_resp_data_mem[8'd2]     <= i_axil_cmd_rdata[23:16];
                        r_resp_data_mem[8'd3]     <= i_axil_cmd_rdata[31:24];
                        r_resp_len_field_latched  <= 16'd4;
                        r_resp_data_count_latched <= 11'd4;
                        r_resp_status_latched     <= STATUS_SUCCESS;
                        r_copy_idx                <= 10'd0;
                        r_state                   <= ST_RESP_COPY;
                    end
                end
            end
            ST_AXIF_START: begin
                o_axif_cmd_valid <= 1'b1;
                if (i_axif_cmd_ready) begin
                    if (r_req_cmd_latched == CMD_FULL_WRITE) begin
                        r_state <= ST_AXIF_WRITE;
                    end
                    else begin
                        r_state <= ST_AXIF_READ;
                    end
                end
            end
            ST_AXIF_WRITE: begin
                if (i_axif_wr_ready && o_axif_wr_valid) begin
                    r_axif_wr_word_idx <= r_axif_wr_word_idx + 9'd1;
                end
                if (i_axif_cmd_done) begin
                    if (i_axif_cmd_error || i_axif_cmd_timeout) begin
                        r_resp_len_field_latched  <= 16'd0;
                        r_resp_data_count_latched <= 11'd0;
                        r_resp_status_latched     <= STATUS_AXI_ERR;
                    end
                    else begin
                        r_resp_len_field_latched  <= 16'd0;
                        r_resp_data_count_latched <= 11'd0;
                        r_resp_status_latched     <= STATUS_SUCCESS;
                    end
                    r_state <= ST_RESP_SEND;
                end
            end
            ST_AXIF_READ: begin
                o_axif_rd_ready <= 1'b1;
                if (i_axif_rd_valid) begin
                    r_axif_rd_byte_idx <= r_axif_rd_byte_idx + 11'd4;
                end
                if (i_axif_cmd_done) begin
                    if (i_axif_cmd_error || i_axif_cmd_timeout) begin
                        r_resp_len_field_latched  <= 16'd0;
                        r_resp_data_count_latched <= 11'd0;
                        r_resp_status_latched     <= STATUS_AXI_ERR;
                        r_state                   <= ST_RESP_SEND;
                    end
                    else begin
                        r_resp_len_field_latched  <= r_req_len_field_latched;
                        r_resp_data_count_latched <= r_req_len_field_latched[10:0];
                        r_resp_status_latched     <= STATUS_SUCCESS;
                        r_copy_idx                <= 10'd0;
                        r_state                   <= ST_RESP_COPY;
                    end
                end
            end
            ST_RESP_COPY: begin
                o_resp_data_wr_en   <= 1'b1;
                o_resp_data_wr_addr <= r_copy_idx;
                o_resp_data_wr_byte <= r_resp_data_mem[r_copy_idx];
                if ({1'b0, r_copy_idx} == (r_resp_data_count_latched - 11'd1)) begin
                    r_state <= ST_RESP_SEND;
                end
                r_copy_idx <= r_copy_idx + 10'd1;
            end
            ST_RESP_SEND: begin
                if (i_resp_ready) begin
                    o_resp_valid      <= 1'b1;
                    o_resp_len_field  <= r_resp_len_field_latched;
                    o_resp_data_count <= r_resp_data_count_latched;
                    o_resp_status     <= r_resp_status_latched;
                    r_state           <= ST_IDLE;
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
