`timescale 1ns / 1ps

module tb_spi_flash_model #(
    parameter integer FLASH_MODEL            = 0,
    parameter integer MEM_BYTES              = 262144,
    parameter integer P_BUSY_POLLS_PP        = 2,
    parameter integer P_BUSY_POLLS_ERASE_4K  = 4,
    parameter integer P_BUSY_POLLS_ERASE_64K = 8,
    parameter integer P_INJECT_ERASE_ERROR   = 0,
    parameter integer P_INJECT_WRITE_ERROR   = 0,
    parameter integer P_STATUS_STUCK_BUSY    = 0,
    parameter integer P_POST_ERASE_STATUS_GUARD_NS = 0
)(
    input  wire       I_rst_n,
    input  wire       I_cs_n,
    input  wire       I_sck,
    input  wire       I_mosi,
    output reg        O_miso,
    output reg [7:0]  O_last_cmd,
    output reg [31:0] O_last_addr,
    output reg [2:0]  O_last_addr_bytes,
    output reg [31:0] O_clear_status_count,
    output reg [31:0] O_pp_count,
    output reg [31:0] O_erase_4k_count,
    output reg [31:0] O_erase_64k_count
);

    localparam integer FLASH_MODEL_S25FL256S = 0;
    localparam integer FLASH_MODEL_MT25QL    = 1;
    localparam integer FLASH_MODEL_N25Q128A  = 2;

    localparam integer CMD_ADDR_BITS  = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 24 : 32;
    localparam integer CMD_ADDR_BYTES = CMD_ADDR_BITS / 8;

    localparam [7:0] CMD_WREN      = 8'h06;
    localparam [7:0] CMD_PP        = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h02 : 8'h12;
    localparam [7:0] CMD_READ      = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h03 : 8'h13;
    localparam [7:0] CMD_ERASE_4K  = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h20 : 8'h21;
    localparam [7:0] CMD_ERASE_64K = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'hD8 : 8'hDC;
    localparam [7:0] CMD_ERASE_ALL = 8'hC7;
    localparam [7:0] CMD_RDSR      = 8'h05;
    localparam [7:0] CMD_RDFSR     = 8'h70;
    localparam [7:0] CMD_CLFSR     = 8'h50;

    localparam [2:0] MODE_GET_CMD   = 3'd0;
    localparam [2:0] MODE_GET_ADDR  = 3'd1;
    localparam [2:0] MODE_PP_DATA   = 3'd2;
    localparam [2:0] MODE_READ_DATA = 3'd3;
    localparam [2:0] MODE_STATUS    = 3'd4;
    localparam [2:0] MODE_IGNORE    = 3'd5;

    reg [7:0] R_mem [0:MEM_BYTES-1];

    reg [2:0]  R_mode;
    reg [7:0]  R_cmd_shift;
    reg [3:0]  R_cmd_bit_cnt;
    reg [7:0]  R_cmd_latched;
    reg        R_cmd_valid;

    reg [31:0] R_addr_shift;
    reg [5:0]  R_addr_bit_cnt;
    reg [31:0] R_addr_latched;
    reg [31:0] R_read_addr;
    reg [31:0] R_prog_addr;

    reg [7:0]  R_pp_shift;
    reg [2:0]  R_pp_bit_cnt;

    reg [7:0]  R_out_shift;
    reg [3:0]  R_out_bits_left;

    reg        R_wel;
    reg [15:0] R_busy_polls_remain;
    reg        R_erase_error_latched;
    reg        R_write_error_latched;
    reg [7:0]  R_temp_byte;
    time       R_status_guard_end_time;

    integer i;
    integer j;

    function [7:0] F_mem_rd8;
        input [31:0] I_addr;
        begin
            if (I_addr < MEM_BYTES)
                F_mem_rd8 = R_mem[I_addr];
            else
                F_mem_rd8 = 8'hFF;
        end
    endfunction

    function [7:0] F_status_byte;
        input I_force_not_busy;
        reg [7:0] R_status;
        begin
            R_status = 8'h00;
            if (FLASH_MODEL == FLASH_MODEL_S25FL256S) begin
                if ((!I_force_not_busy) && ((R_busy_polls_remain != 0) || (P_STATUS_STUCK_BUSY != 0)))
                    R_status[0] = 1'b1;
                if (R_erase_error_latched)
                    R_status[5] = 1'b1;
                if (R_write_error_latched)
                    R_status[6] = 1'b1;
            end
            else begin
                R_status = 8'h80;
                if ((!I_force_not_busy) && ((R_busy_polls_remain != 0) || (P_STATUS_STUCK_BUSY != 0)))
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

    task T_erase_4k;
        input [31:0] I_addr;
        reg [31:0] R_base;
        begin
            R_base = {I_addr[31:12], 12'h000};
            for (j = 0; j < 4096; j = j + 1) begin
                if ((R_base + j) < MEM_BYTES)
                    R_mem[R_base + j] = 8'hFF;
            end
        end
    endtask

    task T_erase_64k;
        input [31:0] I_addr;
        reg [31:0] R_base;
        begin
            R_base = {I_addr[31:16], 16'h0000};
            for (j = 0; j < 65536; j = j + 1) begin
                if ((R_base + j) < MEM_BYTES)
                    R_mem[R_base + j] = 8'hFF;
            end
        end
    endtask

    task T_erase_all;
        begin
            for (j = 0; j < MEM_BYTES; j = j + 1)
                R_mem[j] = 8'hFF;
        end
    endtask

    initial begin
        for (i = 0; i < MEM_BYTES; i = i + 1)
            R_mem[i] = 8'hFF;

        O_miso               = 1'b0;
        O_last_cmd           = 8'h00;
        O_last_addr          = 32'd0;
        O_last_addr_bytes    = 3'd0;
        O_clear_status_count = 32'd0;
        O_pp_count           = 32'd0;
        O_erase_4k_count     = 32'd0;
        O_erase_64k_count    = 32'd0;

        R_mode               = MODE_GET_CMD;
        R_cmd_shift          = 8'h00;
        R_cmd_bit_cnt        = 4'd0;
        R_cmd_latched        = 8'h00;
        R_cmd_valid          = 1'b0;
        R_addr_shift         = 32'd0;
        R_addr_bit_cnt       = 6'd0;
        R_addr_latched       = 32'd0;
        R_read_addr          = 32'd0;
        R_prog_addr          = 32'd0;
        R_pp_shift           = 8'h00;
        R_pp_bit_cnt         = 3'd0;
        R_out_shift          = 8'h00;
        R_out_bits_left      = 4'd0;
        R_wel                = 1'b0;
        R_busy_polls_remain  = 16'd0;
        R_erase_error_latched= 1'b0;
        R_write_error_latched= 1'b0;
        R_temp_byte          = 8'h00;
        R_status_guard_end_time = 0;
    end

    always @(negedge I_cs_n or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_miso          <= 1'b0;
            R_mode          <= MODE_GET_CMD;
            R_cmd_shift     <= 8'h00;
            R_cmd_bit_cnt   <= 4'd0;
            R_cmd_latched   <= 8'h00;
            R_cmd_valid     <= 1'b0;
            R_addr_shift    <= 32'd0;
            R_addr_bit_cnt  <= 6'd0;
            R_addr_latched  <= 32'd0;
            R_read_addr     <= 32'd0;
            R_prog_addr     <= 32'd0;
            R_pp_shift      <= 8'h00;
            R_pp_bit_cnt    <= 3'd0;
            R_out_shift     <= 8'h00;
            R_out_bits_left <= 4'd0;
        end
        else begin
            O_miso          <= 1'b0;
            R_mode          <= MODE_GET_CMD;
            R_cmd_shift     <= 8'h00;
            R_cmd_bit_cnt   <= 4'd0;
            R_cmd_latched   <= 8'h00;
            R_cmd_valid     <= 1'b0;
            R_addr_shift    <= 32'd0;
            R_addr_bit_cnt  <= 6'd0;
            R_addr_latched  <= 32'd0;
            R_read_addr     <= 32'd0;
            R_prog_addr     <= 32'd0;
            R_pp_shift      <= 8'h00;
            R_pp_bit_cnt    <= 3'd0;
            R_out_shift     <= 8'h00;
            R_out_bits_left <= 4'd0;
        end
    end

    always @(posedge I_cs_n or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_wel                 <= 1'b0;
            R_busy_polls_remain   <= 16'd0;
            R_erase_error_latched <= 1'b0;
            R_write_error_latched <= 1'b0;
            R_status_guard_end_time <= 0;
            O_last_cmd            <= 8'h00;
            O_last_addr           <= 32'd0;
            O_last_addr_bytes     <= 3'd0;
            O_clear_status_count  <= 32'd0;
            O_pp_count            <= 32'd0;
            O_erase_4k_count      <= 32'd0;
            O_erase_64k_count     <= 32'd0;
        end
        else begin
            if (R_cmd_valid) begin
                O_last_cmd <= R_cmd_latched;
                if ((R_cmd_latched == CMD_PP) || (R_cmd_latched == CMD_READ) ||
                    (R_cmd_latched == CMD_ERASE_4K) || (R_cmd_latched == CMD_ERASE_64K)) begin
                    O_last_addr       <= R_addr_latched;
                    O_last_addr_bytes <= CMD_ADDR_BYTES[2:0];
                end
                else begin
                    O_last_addr       <= 32'd0;
                    O_last_addr_bytes <= 3'd0;
                end

                case (R_cmd_latched)
                    CMD_WREN: begin
                        R_wel <= 1'b1;
                    end

                    CMD_PP: begin
                        if (R_wel) begin
                            O_pp_count <= O_pp_count + 1'b1;
                            if (P_STATUS_STUCK_BUSY == 0)
                                R_busy_polls_remain <= P_BUSY_POLLS_PP[15:0];
                            if (P_INJECT_WRITE_ERROR != 0)
                                R_write_error_latched <= 1'b1;
                        end
                        R_wel <= 1'b0;
                    end

                    CMD_ERASE_4K: begin
                        if (R_wel) begin
                            T_erase_4k(R_addr_latched);
                            O_erase_4k_count <= O_erase_4k_count + 1'b1;
                            if (P_STATUS_STUCK_BUSY == 0)
                                R_busy_polls_remain <= P_BUSY_POLLS_ERASE_4K[15:0];
                            if (P_INJECT_ERASE_ERROR != 0)
                                R_erase_error_latched <= 1'b1;
                            if (P_POST_ERASE_STATUS_GUARD_NS != 0)
                                R_status_guard_end_time <= $time + P_POST_ERASE_STATUS_GUARD_NS;
                        end
                        R_wel <= 1'b0;
                    end

                    CMD_ERASE_64K: begin
                        if (R_wel) begin
                            T_erase_64k(R_addr_latched);
                            O_erase_64k_count <= O_erase_64k_count + 1'b1;
                            if (P_STATUS_STUCK_BUSY == 0)
                                R_busy_polls_remain <= P_BUSY_POLLS_ERASE_64K[15:0];
                            if (P_INJECT_ERASE_ERROR != 0)
                                R_erase_error_latched <= 1'b1;
                            if (P_POST_ERASE_STATUS_GUARD_NS != 0)
                                R_status_guard_end_time <= $time + P_POST_ERASE_STATUS_GUARD_NS;
                        end
                        R_wel <= 1'b0;
                    end

                    CMD_ERASE_ALL: begin
                        if (R_wel) begin
                            T_erase_all();
                            if (P_STATUS_STUCK_BUSY == 0)
                                R_busy_polls_remain <= P_BUSY_POLLS_ERASE_64K[15:0];
                            if (P_INJECT_ERASE_ERROR != 0)
                                R_erase_error_latched <= 1'b1;
                            if (P_POST_ERASE_STATUS_GUARD_NS != 0)
                                R_status_guard_end_time <= $time + P_POST_ERASE_STATUS_GUARD_NS;
                        end
                        R_wel <= 1'b0;
                    end

                    CMD_RDSR,
                    CMD_RDFSR: begin
                        if (($time >= R_status_guard_end_time) && (R_busy_polls_remain != 0) && (P_STATUS_STUCK_BUSY == 0))
                            R_busy_polls_remain <= R_busy_polls_remain - 1'b1;
                    end

                    CMD_CLFSR: begin
                        R_erase_error_latched <= 1'b0;
                        R_write_error_latched <= 1'b0;
                        O_clear_status_count  <= O_clear_status_count + 1'b1;
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

    always @(posedge I_sck or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_mode         <= MODE_GET_CMD;
            R_cmd_shift    <= 8'h00;
            R_cmd_bit_cnt  <= 4'd0;
            R_cmd_latched  <= 8'h00;
            R_cmd_valid    <= 1'b0;
            R_addr_shift   <= 32'd0;
            R_addr_bit_cnt <= 6'd0;
            R_addr_latched <= 32'd0;
            R_read_addr    <= 32'd0;
            R_prog_addr    <= 32'd0;
            R_pp_shift     <= 8'h00;
            R_pp_bit_cnt   <= 3'd0;
        end
        else if (!I_cs_n) begin
            case (R_mode)
                MODE_GET_CMD: begin
                    R_cmd_shift   <= {R_cmd_shift[6:0], I_mosi};
                    R_cmd_bit_cnt <= R_cmd_bit_cnt + 1'b1;
                    if (R_cmd_bit_cnt == 4'd7) begin
                        R_cmd_latched <= {R_cmd_shift[6:0], I_mosi};
                        R_cmd_valid   <= 1'b1;
                        R_cmd_bit_cnt <= 4'd0;
                        if (({R_cmd_shift[6:0], I_mosi} == CMD_PP) ||
                            ({R_cmd_shift[6:0], I_mosi} == CMD_READ) ||
                            ({R_cmd_shift[6:0], I_mosi} == CMD_ERASE_4K) ||
                            ({R_cmd_shift[6:0], I_mosi} == CMD_ERASE_64K)) begin
                            R_mode         <= MODE_GET_ADDR;
                            R_addr_shift   <= 32'd0;
                            R_addr_bit_cnt <= 6'd0;
                        end
                        else if (({R_cmd_shift[6:0], I_mosi} == CMD_RDSR) ||
                                 ({R_cmd_shift[6:0], I_mosi} == CMD_RDFSR)) begin
                            R_mode <= MODE_STATUS;
                        end
                        else begin
                            R_mode <= MODE_IGNORE;
                        end
                    end
                end

                MODE_GET_ADDR: begin
                    R_addr_shift   <= {R_addr_shift[30:0], I_mosi};
                    R_addr_bit_cnt <= R_addr_bit_cnt + 1'b1;
                    if (R_addr_bit_cnt == (CMD_ADDR_BITS - 1)) begin
                        R_addr_latched <= {R_addr_shift[30:0], I_mosi};
                        if (R_cmd_latched == CMD_READ) begin
                            R_mode      <= MODE_READ_DATA;
                            R_read_addr <= {R_addr_shift[30:0], I_mosi};
                        end
                        else if (R_cmd_latched == CMD_PP) begin
                            R_mode      <= MODE_PP_DATA;
                            R_prog_addr <= {R_addr_shift[30:0], I_mosi};
                            R_pp_shift  <= 8'h00;
                            R_pp_bit_cnt<= 3'd0;
                        end
                        else begin
                            R_mode <= MODE_IGNORE;
                        end
                    end
                end

                MODE_PP_DATA: begin
                    R_pp_shift   <= {R_pp_shift[6:0], I_mosi};
                    R_pp_bit_cnt <= R_pp_bit_cnt + 1'b1;
                    if (R_pp_bit_cnt == 3'd7) begin
                        if (R_wel && (R_prog_addr < MEM_BYTES))
                            R_mem[R_prog_addr] <= R_mem[R_prog_addr] & {R_pp_shift[6:0], I_mosi};
                        R_prog_addr <= R_prog_addr + 1'b1;
                        R_pp_shift  <= 8'h00;
                        R_pp_bit_cnt<= 3'd0;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    always @(negedge I_sck or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_miso          <= 1'b0;
            R_out_shift     <= 8'h00;
            R_out_bits_left <= 4'd0;
            R_temp_byte     <= 8'h00;
        end
        else if (!I_cs_n) begin
            if ((R_mode == MODE_STATUS) || (R_mode == MODE_READ_DATA)) begin
                if (R_out_bits_left == 0) begin
                    if (R_mode == MODE_STATUS) begin
                        R_temp_byte = F_status_byte((P_POST_ERASE_STATUS_GUARD_NS != 0) && ($time < R_status_guard_end_time));
                    end
                    else begin
                        R_temp_byte = F_mem_rd8(R_read_addr);
                        R_read_addr <= R_read_addr + 1'b1;
                    end
                    O_miso          <= R_temp_byte[7];
                    R_out_shift     <= {R_temp_byte[6:0], 1'b0};
                    R_out_bits_left <= 4'd7;
                end
                else begin
                    O_miso          <= R_out_shift[7];
                    R_out_shift     <= {R_out_shift[6:0], 1'b0};
                    R_out_bits_left <= R_out_bits_left - 1'b1;
                end
            end
            else begin
                O_miso <= 1'b0;
            end
        end
        else begin
            O_miso <= 1'b0;
        end
    end

endmodule
