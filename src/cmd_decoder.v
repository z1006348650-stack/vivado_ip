`timescale 1ns / 1ps

//-------------------------------------------------------
//
//  author: erle/codex
//
//------------------------------------------------------

module cmd_decoder #(
    parameter integer C_S_AXI_DATA_WIDTH    = 32,
    parameter         UPDATE_BASE_ADDR      = 32'h00500000,
    parameter integer FLASH_ADDR_WIDTH      = 32
    )(

    input                                   I_clk_in,
    input                                   I_rst_n,

    input [C_S_AXI_DATA_WIDTH-1:0]          slv_reg0,
    input [C_S_AXI_DATA_WIDTH-1:0]          slv_reg1,
    input [C_S_AXI_DATA_WIDTH-1:0]          slv_reg2,
    input [C_S_AXI_DATA_WIDTH-1:0]          slv_reg3,
    input [C_S_AXI_DATA_WIDTH-1:0]          slv_reg4,

    output [C_S_AXI_DATA_WIDTH-1:0]         O_fb_data,

    output                                  O_aux_rst_n,
    output                                  O_drv_mode,
    output [FLASH_ADDR_WIDTH-1:0]           O_update_addr,
    output [31:0]                           O_bin_size,
    output                                  O_opt_begin,
    output                                  O_icap_en,
    output [FLASH_ADDR_WIDTH-1:0]           O_update_base_addr,

    input                                   I_drv_opt_busy,
    input                                   I_drv_opt_ok,
    input                                   I_err,
    input                                   I_timeout_err,
    input [4:0]                             I_last_fail_stage,
    input                                   I_icap_done

    );

    localparam [7:0] CMD_DEFAULT  = 8'h5A;
    localparam [7:0] CMD_PASS     = 8'h55;
    localparam [7:0] CMD_FAIL     = 8'hAA;

    // 失败阶段编码（与 flash_ctrl/上层文档保持一致）
    localparam [4:0] FAIL_STAGE_NONE          = 5'd0;
    localparam [4:0] FAIL_STAGE_ICAP_TIMEOUT  = 5'd16;

    // ICAP 等待超时阈值（系统时钟周期）
    localparam [31:0] ICAP_TIMEOUT_CYCLES     = 32'd100000;

    localparam [1:0] OP_NONE   = 2'd0;
    localparam [1:0] OP_FLASH  = 2'd1;
    localparam [1:0] OP_ICAP   = 2'd2;
    localparam [1:0] OP_RESET  = 2'd3;

    reg                                     R_aux_rst_n;
    reg                                     R_drv_mode;
    reg [FLASH_ADDR_WIDTH-1:0]              R_update_addr;
    reg [31:0]                              R_bin_size;
    reg                                     R_opt_begin;
    reg                                     R_icap_en;
    reg [FLASH_ADDR_WIDTH-1:0]              R_update_base_addr;

    reg [7:0]                               R_status_code;
    reg                                     R_flash_err;
    reg                                     R_icap_err;
    reg                                     R_timeout_err;
    reg [4:0]                               R_last_fail_stage;

    reg [1:0]                               R_cmd_en;
    reg [1:0]                               R_cur_op;

    reg [5:0]                               cur_state, nxt_state;
    reg [7:0]                               R_rst_cnt;
    reg [31:0]                              R_icap_wait_cnt;

    wire                                    W_cmd_en;
    wire                                    W_icap_timeout;

    localparam [5:0] IDLE             = 6'b00_0001;
    localparam [5:0] GET_OPT_MODE     = 6'b00_0010;
    localparam [5:0] GET_DRV_INFO     = 6'b00_0100;
    localparam [5:0] GET_ICAP_INFO    = 6'b00_1000;
    localparam [5:0] GET_RST_INFO     = 6'b01_0000;
    localparam [5:0] WAIT_ICAP_DONE   = 6'b10_0000;
    localparam [5:0] OPT_END          = 6'b11_0000;

    assign O_aux_rst_n        = R_aux_rst_n;
    assign O_drv_mode         = R_drv_mode;
    assign O_update_addr      = R_update_addr;
    assign O_bin_size         = R_bin_size;
    assign O_opt_begin        = R_opt_begin;
    assign O_icap_en          = R_icap_en;
    assign O_update_base_addr = R_update_base_addr;
    assign O_fb_data          = {16'd0, R_last_fail_stage, R_timeout_err, R_icap_err, R_flash_err, R_status_code};

    assign W_cmd_en       = ~R_cmd_en[1] & R_cmd_en[0];
    assign W_icap_timeout = (R_icap_wait_cnt >= ICAP_TIMEOUT_CYCLES);

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_cmd_en <= 2'b00;
        else
            R_cmd_en <= {R_cmd_en[0], slv_reg0[0]};
    end

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            cur_state <= IDLE;
        else
            cur_state <= nxt_state;
    end

    always @(*) begin
        case (cur_state)
            IDLE: begin
                if (W_cmd_en)
                    nxt_state = GET_OPT_MODE;
                else
                    nxt_state = IDLE;
            end
            GET_OPT_MODE: begin
                if (slv_reg0[13])
                    nxt_state = GET_RST_INFO;
                else if (slv_reg0[14])
                    nxt_state = GET_DRV_INFO;
                else if (slv_reg0[15])
                    nxt_state = GET_ICAP_INFO;
                else
                    nxt_state = IDLE;
            end
            GET_RST_INFO: begin
                if (R_rst_cnt >= 8'd10)
                    nxt_state = OPT_END;
                else
                    nxt_state = GET_RST_INFO;
            end
            GET_DRV_INFO: begin
                if (I_drv_opt_busy)
                    nxt_state = OPT_END;
                else
                    nxt_state = GET_DRV_INFO;
            end
            GET_ICAP_INFO: begin
                nxt_state = WAIT_ICAP_DONE;
            end
            WAIT_ICAP_DONE: begin
                if (I_icap_done)
                    nxt_state = OPT_END;
                else if (W_icap_timeout)
                    nxt_state = OPT_END;
                else
                    nxt_state = WAIT_ICAP_DONE;
            end
            OPT_END: begin
                nxt_state = IDLE;
            end
            default: begin
                nxt_state = IDLE;
            end
        endcase
    end

    // 记录当前命令类别，用于状态判定和错误归类
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_cur_op <= OP_NONE;
        else begin
            if (W_cmd_en) begin
                if (slv_reg0[14])
                    R_cur_op <= OP_FLASH;
                else if (slv_reg0[15])
                    R_cur_op <= OP_ICAP;
                else if (slv_reg0[13])
                    R_cur_op <= OP_RESET;
                else
                    R_cur_op <= OP_NONE;
            end
            else begin
                case (R_cur_op)
                    OP_FLASH: begin
                        if (I_err || I_drv_opt_ok)
                            R_cur_op <= OP_NONE;
                        else
                            R_cur_op <= R_cur_op;
                    end
                    OP_ICAP: begin
                        if (I_icap_done || W_icap_timeout)
                            R_cur_op <= OP_NONE;
                        else
                            R_cur_op <= R_cur_op;
                    end
                    default: begin
                        R_cur_op <= R_cur_op;
                    end
                endcase
            end
        end
    end

    // 软复位输出控制
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_aux_rst_n <= 1'b1;
            R_rst_cnt   <= 8'd0;
        end
        else begin
            case (cur_state)
                IDLE: begin
                    R_rst_cnt   <= 8'd0;
                    R_aux_rst_n <= 1'b1;
                end
                GET_RST_INFO: begin
                    if (R_rst_cnt < 8'd10) begin
                        R_rst_cnt   <= R_rst_cnt + 1'b1;
                        R_aux_rst_n <= 1'b0;
                    end
                    else begin
                        R_rst_cnt   <= 8'd0;
                        R_aux_rst_n <= 1'b1;
                    end
                end
                default: begin
                    R_rst_cnt   <= R_rst_cnt;
                    R_aux_rst_n <= R_aux_rst_n;
                end
            endcase
        end
    end

    // flash 控制信息输出
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_drv_mode    <= 1'b0;
            R_update_addr <= UPDATE_BASE_ADDR;
            R_bin_size    <= 32'd0;
            R_opt_begin   <= 1'b0;
        end
        else begin
            case (cur_state)
                IDLE: begin
                    R_opt_begin <= 1'b0;
                end
                GET_DRV_INFO: begin
                    if (!I_drv_opt_busy) begin
                        R_opt_begin   <= 1'b1;
                        R_update_addr <= slv_reg2;
                        R_bin_size    <= slv_reg3;
                        R_drv_mode    <= slv_reg4[0];
                    end
                    else begin
                        R_opt_begin <= R_opt_begin;
                    end
                end
                OPT_END: begin
                    R_opt_begin <= 1'b0;
                end
                default: begin
                    R_opt_begin <= R_opt_begin;
                end
            endcase
        end
    end

    // ICAP 控制信息输出
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_icap_en           <= 1'b0;
            R_update_base_addr  <= UPDATE_BASE_ADDR;
        end
        else begin
            case (cur_state)
                IDLE: begin
                    R_icap_en <= 1'b0;
                end
                GET_ICAP_INFO: begin
                    R_icap_en          <= 1'b1;
                    R_update_base_addr <= slv_reg2;
                end
                WAIT_ICAP_DONE: begin
                    // 保持使能，等待 I_icap_done 或超时
                    R_icap_en          <= 1'b1;
                    R_update_base_addr <= R_update_base_addr;
                end
                OPT_END: begin
                    R_icap_en <= 1'b0;
                end
                default: begin
                    R_icap_en <= R_icap_en;
                end
            endcase
        end
    end

    // ICAP 等待计数
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_icap_wait_cnt <= 32'd0;
        else begin
            if (cur_state == GET_ICAP_INFO)
                R_icap_wait_cnt <= 32'd0;
            else if (cur_state == WAIT_ICAP_DONE)
                R_icap_wait_cnt <= R_icap_wait_cnt + 1'b1;
            else
                R_icap_wait_cnt <= 32'd0;
        end
    end

    // 反馈状态位与状态码
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_status_code     <= CMD_DEFAULT;
            R_flash_err       <= 1'b0;
            R_icap_err        <= 1'b0;
            R_timeout_err     <= 1'b0;
            R_last_fail_stage <= FAIL_STAGE_NONE;
        end
        else begin
            // 新命令触发后，清空上一条命令错误信息
            if (W_cmd_en) begin
                R_status_code     <= CMD_DEFAULT;
                R_flash_err       <= 1'b0;
                R_icap_err        <= 1'b0;
                R_timeout_err     <= 1'b0;
                R_last_fail_stage <= FAIL_STAGE_NONE;
            end
            else begin
                // Flash 操作上报
                if (R_cur_op == OP_FLASH) begin
                    if (I_err) begin
                        R_status_code <= CMD_FAIL;
                        R_flash_err   <= 1'b1;
                        if (I_timeout_err)
                            R_timeout_err <= 1'b1;
                        if (I_last_fail_stage != FAIL_STAGE_NONE)
                            R_last_fail_stage <= I_last_fail_stage;
                        else
                            R_last_fail_stage <= R_last_fail_stage;
                    end
                    else if (I_drv_opt_ok) begin
                        R_status_code <= CMD_PASS;
                    end
                    else if (I_drv_opt_busy) begin
                        R_status_code <= CMD_DEFAULT;
                    end
                end

                // ICAP 操作上报
                if (R_cur_op == OP_ICAP) begin
                    if (I_icap_done) begin
                        R_status_code <= CMD_PASS;
                    end
                    else if ((cur_state == WAIT_ICAP_DONE) && W_icap_timeout) begin
                        R_status_code     <= CMD_FAIL;
                        R_icap_err        <= 1'b1;
                        R_timeout_err     <= 1'b1;
                        R_last_fail_stage <= FAIL_STAGE_ICAP_TIMEOUT;
                    end
                    else begin
                        R_status_code <= CMD_DEFAULT;
                    end
                end
            end
        end
    end

endmodule
