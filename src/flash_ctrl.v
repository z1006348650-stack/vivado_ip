`timescale 1ns / 1ps


//---------------------------------------------------------------------------
//
//    author: erle
//
//-------------------------------------------------------------------------

module flash_ctrl #(
    parameter RD_DATA_MAX_LEN    = 256       ,
    parameter WR_DATA_MAX_LEN    = 256       ,
    parameter FLASH_ADDR_WIDTH   = 32        ,
    parameter integer FLASH_MODEL = 0         ,
    parameter integer SPI_BUS_WIDTH = 1       ,
    parameter S25_TBPARM_TOP     = 0         ,
    // Erase-status polling timeout limits, in system clock cycles.
    parameter ERASE_TIMEOUT_4K_CYCLES       = 200000000 ,
    parameter ERASE_TIMEOUT_64K_CYCLES      = 300000000 ,
    // Keep CS# high for a short guard window after erase before issuing the first status poll.
    parameter POST_ERASE_STATUS_GUARD_CYCLES = 10
)
(

    input                                                           I_clk_in                ,
    input                                                           I_rst_n                 ,

    input                                                           I_opt_begin             ,
    input                                                           I_mode                  ,

    input [FLASH_ADDR_WIDTH-1:0]                                    I_update_addr           ,
    input [31:0]                                                    I_bin_size              ,

    input                                                           I_opt_busy              ,
    input                                                           I_flash_opt_done        ,
    input [((RD_DATA_MAX_LEN << 3)-1):0]                            I_rd_data               ,
    output   [((WR_DATA_MAX_LEN << 3) - 1) : 0]                     O_wr_data               ,

    output                                                          O_opt_en                ,
    output [3:0]                                                    O_opt_mode              ,

    output [FLASH_ADDR_WIDTH-1:0]                                   O_wr_addr               ,
    output [FLASH_ADDR_WIDTH-1:0]                                   O_rd_addr               ,
    output [FLASH_ADDR_WIDTH-1:0]                                   O_era_addr              ,
    output [7:0]                                                    O_wr_cmd                ,
    output [15:0]                                                   O_wr_cmd_data           ,
    input  [7:0]                                                    I_rd_cmd_data           ,
    output [7:0]                                                    O_rd_cmd                ,

    input                                                           I_axis_tvalid           ,
    output                                                          O_axis_tready           ,

    input   [((WR_DATA_MAX_LEN << 3) - 1) : 0]                      I_axis_tdata            ,
    input                                                           I_almost_empty          ,

    output                                                          O_drv_opt_busy          ,
    output                                                          O_drv_opt_ok            ,
    output                                                          O_err                   ,
    output                                                          O_timeout_err           ,
    output [4:0]                                                    O_last_fail_stage       ,
    output [7:0]                                                    O_dbg_rd_cmd_data       ,
    output [7:0]                                                    O_dbg_sr1_shadow        ,
    output [7:0]                                                    O_dbg_cr1_shadow        ,
    output [15:0]                                                   O_dbg_wr_cmd_data       ,
    output [4:0]                                                    O_dbg_cur_state


    );

    localparam FLASH_MODEL_S25FL256S = 0;
    localparam FLASH_MODEL_MT25QL    = 1;
    localparam FLASH_MODEL_N25Q128A  = 2;

    localparam [31:0] ERASE_SIZE_4K     = 32'h0000_1000;
    localparam [31:0] ERASE_SIZE_64K    = 32'h0001_0000;

        // S25FL256S Hybrid parameter-region boundary.
    // TBPARM=0 (default): bottom 0x0000_0000 ~ 0x0001_FFFF is 4KB parameter sectors.
    // TBPARM=1: top 0x01FE_0000 ~ 0x01FF_FFFF is 4KB parameter sectors.
    localparam [FLASH_ADDR_WIDTH-1:0] S25_BOTTOM_PARAM_END = 32'h0002_0000;
    localparam [FLASH_ADDR_WIDTH-1:0] S25_TOP_PARAM_BASE   = 32'h01FE_0000;

    // Status register read command: S25 uses 0x05, MT25/N25Q use 0x70 (Flag Status Register).
    localparam [7:0] STATUS_CMD_S25     = 8'h05;
    localparam [7:0] STATUS_CMD_MT25    = 8'h70;
    localparam [7:0] CONFIG_CMD_S25     = 8'h35;
    localparam [7:0] WRITE_REG_CMD_S25  = 8'h01;
    localparam [7:0] S25_QE_MASK        = 8'h02;

    localparam [4:0] IDLE                    = 5'd0;
    localparam [4:0] ERASE_64K               = 5'd1;
    localparam [4:0] ERASE_4K                = 5'd2;
    localparam [4:0] RD_ERA_64K_STATUS       = 5'd3;
    localparam [4:0] RD_ERA_64K_STATUS_CHECK = 5'd4;
    localparam [4:0] RD_ERA_4K_STATUS        = 5'd5;
    localparam [4:0] RD_ERA_4K_STATUS_CHECK  = 5'd6;
    localparam [4:0] POST_ERASE_64K_GUARD    = 5'd7;
    localparam [4:0] POST_ERASE_4K_GUARD     = 5'd8;
    localparam [4:0] ERASE_CHECK_RD          = 5'd9;
    localparam [4:0] ERASE_CHECK_CMPR        = 5'd10;
    localparam [4:0] ERA_CHECK_ERROR         = 5'd11;
    localparam [4:0] WRITE                   = 5'd12;
    localparam [4:0] RD_WRITE_STATUS         = 5'd13;
    localparam [4:0] RD_WRITE_STATUE_CHECK   = 5'd14;
    localparam [4:0] WRITE_CHECK_RD          = 5'd15;
    localparam [4:0] WRITE_CHECK_CMPR        = 5'd16;
    localparam [4:0] WRITE_CHECK_ERR         = 5'd17;
    localparam [4:0] FINISH                  = 5'd18;
    localparam [4:0] CLEAR_STATUS            = 5'd19;
    localparam [4:0] QE_READ_SR1             = 5'd20;
    localparam [4:0] QE_READ_SR1_CHECK       = 5'd21;
    localparam [4:0] QE_READ_CR1             = 5'd22;
    localparam [4:0] QE_READ_CR1_CHECK       = 5'd23;
    localparam [4:0] QE_WRITE_REG            = 5'd24;
    localparam [4:0] QE_READ_CR1_VERIFY      = 5'd25;
    localparam [4:0] QE_READ_CR1_VERIFY_CHECK= 5'd26;

    // ?????????????????????????????????????????
    localparam [4:0] FAIL_STAGE_NONE                 = 5'd0;
    localparam [4:0] FAIL_STAGE_ERASE_ADDR_INVALID   = 5'd1;
    localparam [4:0] FAIL_STAGE_ERASE_TIMEOUT_64K    = 5'd2;
    localparam [4:0] FAIL_STAGE_ERASE_TIMEOUT_4K     = 5'd3;
    localparam [4:0] FAIL_STAGE_ERASE_STATUS_ERROR   = 5'd4;
    localparam [4:0] FAIL_STAGE_ERASE_NEXT_INVALID   = 5'd5;
    localparam [4:0] FAIL_STAGE_ERASE_VERIFY_ERROR   = 5'd6;
    localparam [4:0] FAIL_STAGE_WRITE_STATUS_ERROR   = 5'd7;
    localparam [4:0] FAIL_STAGE_WRITE_VERIFY_ERROR   = 5'd8;
    localparam [4:0] FAIL_STAGE_WRITE_OVERFLOW       = 5'd9;
    localparam [4:0] FAIL_STAGE_ERASE_BUSY_NOT_SEEN  = 5'd10;
    localparam [4:0] FAIL_STAGE_QE_ENABLE_FAILED     = 5'd11;


    reg [4:0]                                                           cur_state, nxt_state;
    reg [1:0]                                                           R_opt_begin;
    reg [31:0]                                                          R_era_64k_cnt;
    reg [31:0]                                                          R_era_4k_cnt;
    reg [31:0]                                                          R_era_chk_cnt;
    reg [31:0]                                                          R_wr_cnt;
    reg [31:0]                                                          R_wr_chk_cnt;
    reg [31:0]                                                          R_era_remain_bytes;
    reg [31:0]                                                          R_erase_timeout_cnt;
    reg [31:0]                                                          R_post_erase_status_guard_cnt;
    reg                                                                 R_erase_busy_seen;

    reg                                                                 R_opt_en              ;
    reg [3:0]                                                           R_opt_mode            ;
    reg                                                                 R_axis_tready         ;
    reg                                                                 R_drv_opt_busy        ;
    reg                                                                 R_drv_opt_ok          ;
    reg                                                                 R_err                 ;
    reg                                                                 R_timeout_err         ;
    reg [4:0]                                                           R_last_fail_stage     ;

    reg [FLASH_ADDR_WIDTH-1:0]               R_wr_addr       ;
    reg [FLASH_ADDR_WIDTH-1:0]               R_rd_addr       ;
    reg [FLASH_ADDR_WIDTH-1:0]               R_era_addr      ;
    reg [7:0]                                R_wr_cmd        ;
    reg [15:0]                               R_wr_cmd_data   ;
    reg [7:0]                                R_rd_cmd        ;
    reg [7:0]                                R_sr1_shadow    ;
    reg [7:0]                                R_cr1_shadow    ;
    reg [((WR_DATA_MAX_LEN << 3) - 1) : 0]   R_wr_data       ;



    wire      W_opt_begin_pos;

    wire       W_need_clear_status;
    wire [7:0] W_status_cmd;
    wire       W_status_busy;
    wire       W_erase_status_error;
    wire       W_write_status_error;

    wire       W_erase_start_use_4k;
    wire       W_erase_start_invalid;

    wire [FLASH_ADDR_WIDTH-1:0]  W_era_addr_next_4k;
    wire [FLASH_ADDR_WIDTH-1:0]  W_era_addr_next_64k;
    wire [31:0]                  W_era_remain_next_4k;
    wire [31:0]                  W_era_remain_next_64k;

    wire       W_erase_done_after_4k;
    wire       W_erase_done_after_64k;

    wire       W_erase_use_4k_after_4k;
    wire       W_erase_use_4k_after_64k;
    wire       W_erase_invalid_after_4k;
    wire       W_erase_invalid_after_64k;
    wire [31:0] W_wr_total_beats;
    wire        W_axis_fire;
    wire        W_wr_count_overflow;
    wire        W_need_qe_prepare;
    wire        W_qe_enabled;
    wire        W_sr1_status_error;
    wire        W_sr1_unlock_required;

    wire        W_err_evt_erase_addr_invalid;
    wire        W_err_evt_erase_timeout_64k;
    wire        W_err_evt_erase_timeout_4k;
    wire        W_err_evt_erase_status;
    wire        W_err_evt_erase_next_invalid;
    wire        W_err_evt_erase_verify;
    wire        W_err_evt_erase_busy_not_seen;
    wire        W_err_evt_write_status;
    wire        W_err_evt_write_verify;
    wire        W_err_evt_write_overflow;
    wire        W_err_evt_qe_enable;
    wire        W_err_evt_any;
    wire        W_err_evt_timeout;
    wire [4:0]  W_err_stage_code;
    wire        W_post_erase_status_guard_done;


    assign W_opt_begin_pos                   = R_opt_begin[0] & ~R_opt_begin[1];
    assign O_opt_en                          = R_opt_en;
    assign O_opt_mode                        = R_opt_mode;
    assign O_wr_addr                         = R_wr_addr;
    assign O_rd_addr                         = R_rd_addr;
    assign O_era_addr                        = R_era_addr;
    assign O_wr_cmd                          = R_wr_cmd;
    assign O_wr_cmd_data                     = R_wr_cmd_data;
    assign O_rd_cmd                          = R_rd_cmd;
    assign O_axis_tready                     = R_axis_tready;
    assign O_wr_data                         = R_wr_data;
    assign O_drv_opt_ok                      = R_drv_opt_ok;
    assign O_err                             = R_err;
    assign O_drv_opt_busy                    = R_drv_opt_busy;
    assign O_timeout_err                     = R_timeout_err;
    assign O_last_fail_stage                 = R_last_fail_stage;
    assign O_dbg_rd_cmd_data                 = I_rd_cmd_data;
    assign O_dbg_sr1_shadow                  = R_sr1_shadow;
    assign O_dbg_cr1_shadow                  = R_cr1_shadow;
    assign O_dbg_wr_cmd_data                 = R_wr_cmd_data;
    assign O_dbg_cur_state                   = cur_state;

    // ?????Flash ?????????????????????????????????????????????????
    assign W_need_clear_status               = (FLASH_MODEL != FLASH_MODEL_S25FL256S);
    assign W_status_cmd                      = (FLASH_MODEL == FLASH_MODEL_S25FL256S) ? STATUS_CMD_S25 : STATUS_CMD_MT25;
    assign W_status_busy                     = (FLASH_MODEL == FLASH_MODEL_S25FL256S) ? I_rd_cmd_data[0] : (~I_rd_cmd_data[7]);
    assign W_erase_status_error              = (FLASH_MODEL == FLASH_MODEL_S25FL256S) ? I_rd_cmd_data[5] : (I_rd_cmd_data[5] | I_rd_cmd_data[1]);
    assign W_write_status_error              = (FLASH_MODEL == FLASH_MODEL_S25FL256S) ? I_rd_cmd_data[6] : (I_rd_cmd_data[4] | I_rd_cmd_data[1]);
    assign W_need_qe_prepare                 = (FLASH_MODEL == FLASH_MODEL_S25FL256S) && (SPI_BUS_WIDTH == 4);
    assign W_qe_enabled                      = I_rd_cmd_data[1];
    assign W_sr1_status_error                = R_sr1_shadow[6] | R_sr1_shadow[5];
    assign W_sr1_unlock_required             = R_sr1_shadow[7] | (|R_sr1_shadow[4:2]);

    assign W_era_addr_next_4k                = R_era_addr + 'h1000;
    assign W_era_addr_next_64k               = R_era_addr + 'h10000;
    assign W_era_remain_next_4k              = (R_era_remain_bytes > ERASE_SIZE_4K)  ? (R_era_remain_bytes - ERASE_SIZE_4K)  : 32'd0;
    assign W_era_remain_next_64k             = (R_era_remain_bytes > ERASE_SIZE_64K) ? (R_era_remain_bytes - ERASE_SIZE_64K) : 32'd0;

    assign W_erase_done_after_4k             = (R_era_remain_bytes <= ERASE_SIZE_4K);
    assign W_erase_done_after_64k            = (R_era_remain_bytes <= ERASE_SIZE_64K);
    assign W_post_erase_status_guard_done    = (POST_ERASE_STATUS_GUARD_CYCLES == 0) ||
                                               (R_post_erase_status_guard_cnt >= (POST_ERASE_STATUS_GUARD_CYCLES - 1));


    (*MARK_DEBUG = "TRUE"*)reg [4:0]                                                     ila_cur_state;
    (*MARK_DEBUG = "TRUE"*)reg                                                           ila_R_err;
    (*MARK_DEBUG = "TRUE"*)reg [((RD_DATA_MAX_LEN << 3)-1):0]                            ila_I_rd_data;
    (*MARK_DEBUG = "TRUE"*)reg  [7:0]                                                    ila_I_rd_cmd_data;
    (*MARK_DEBUG = "TRUE"*)reg                                                           ila_I_axis_tvalid;
    (*MARK_DEBUG = "TRUE"*)reg                                                           ila_O_axis_tready     ;
    (*MARK_DEBUG = "TRUE"*)reg                                                           ila_R_opt_en         ;
    (*MARK_DEBUG = "TRUE"*)reg [3:0]                                                     ila_R_opt_mode       ;

    (*MARK_DEBUG = "TRUE"*)reg   [((WR_DATA_MAX_LEN << 3) - 1) : 0]                      ila_I_axis_tdata    ;
    (*MARK_DEBUG = "TRUE"*)reg                                                           ila_I_almost_empty  ;
    (*MARK_DEBUG = "TRUE"*)reg [FLASH_ADDR_WIDTH-1:0]                                    ila_R_wr_addr       ;
    (*MARK_DEBUG = "TRUE"*)reg [FLASH_ADDR_WIDTH-1:0]                                    ila_R_rd_addr       ;
    (*MARK_DEBUG = "TRUE"*)reg [FLASH_ADDR_WIDTH-1:0]                                    ila_R_era_addr      ;
    (*MARK_DEBUG = "TRUE"*)reg [31:0]                                                    ila_R_era_remain    ;

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            ila_cur_state         <= 'd0;
            ila_R_err             <= 'd0;
            ila_I_rd_data         <= 'd0;
            ila_I_rd_cmd_data     <= 'd0;
            ila_I_axis_tvalid     <= 'd0;
            ila_O_axis_tready     <= 'd0;
            ila_I_axis_tdata      <= 'd0;
            ila_I_almost_empty    <= 'd0;
            ila_R_opt_en          <= 'd0;
            ila_R_opt_mode        <= 'd0;
            ila_R_wr_addr         <= 'd0;
            ila_R_rd_addr         <= 'd0;
            ila_R_era_addr        <= 'd0;
            ila_R_era_remain      <= 'd0;
        end
        else begin
            ila_cur_state         <= cur_state     ;
            ila_R_err             <= R_err         ;
            ila_I_rd_data         <= I_rd_data     ;
            ila_I_rd_cmd_data     <= I_rd_cmd_data ;
            ila_I_axis_tvalid     <= I_axis_tvalid ;
            ila_O_axis_tready     <= O_axis_tready ;
            ila_I_axis_tdata      <= I_axis_tdata  ;
            ila_I_almost_empty    <= I_almost_empty;
            ila_R_opt_en          <= R_opt_en      ;
            ila_R_opt_mode        <= R_opt_mode    ;
            ila_R_wr_addr         <= R_wr_addr     ;
            ila_R_rd_addr         <= R_rd_addr     ;
            ila_R_era_addr        <= R_era_addr    ;
            ila_R_era_remain      <= R_era_remain_bytes;
        end
    end


    function integer clogb2 (input integer bit_depth);
        begin
            for (clogb2 = 0; bit_depth > 0; clogb2 = clogb2 + 1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    function F_is_s25_4k_region;
        input [FLASH_ADDR_WIDTH-1:0] I_addr;
        begin
            // Select S25 4KB parameter region by TBPARM setting.
            if (S25_TBPARM_TOP == 0)
                F_is_s25_4k_region = (I_addr < S25_BOTTOM_PARAM_END);
            else
                F_is_s25_4k_region = (I_addr >= S25_TOP_PARAM_BASE);
        end
    endfunction

    function F_need_4k_erase;
        input [FLASH_ADDR_WIDTH-1:0] I_addr;
        input [31:0]                 I_remain;
        begin
            if (I_remain == 32'd0)
                F_need_4k_erase = 1'b0;
            else if (FLASH_MODEL == FLASH_MODEL_S25FL256S)
                // S25 hybrid: parameter region uses 4KB erase, others use 64KB erase.
                F_need_4k_erase = F_is_s25_4k_region(I_addr);
            else begin
                // MT25 uniform sectors: prefer 64KB when aligned and enough remain.
                if ((I_addr[15:0] == 16'h0000) && (I_remain >= ERASE_SIZE_64K))
                    F_need_4k_erase = 1'b0;
                else
                    F_need_4k_erase = 1'b1;
            end
        end
    endfunction

    function F_erase_req_invalid;
        input [FLASH_ADDR_WIDTH-1:0] I_addr;
        input [31:0]                 I_remain;
        begin
            F_erase_req_invalid = 1'b0;
            if (I_remain == 32'd0)
                F_erase_req_invalid = 1'b0;
            else if (I_addr[11:0] != 12'h000)
                // Unified minimum requirement: erase start address must be 4KB aligned.
                F_erase_req_invalid = 1'b1;
            else if (FLASH_MODEL == FLASH_MODEL_S25FL256S) begin
                if (!F_is_s25_4k_region(I_addr)) begin
                    if (I_addr[15:0] != 16'h0000)
                        // In S25 non-parameter region, erase command must be 64KB aligned.
                        F_erase_req_invalid = 1'b1;
                    else
                        // Allow last remainder (<64KB) by covering it with one final 64KB erase.
                        F_erase_req_invalid = 1'b0;
                end
            end
        end
    endfunction


    localparam integer RD_TIMES = clogb2(RD_DATA_MAX_LEN-1);
    localparam integer WR_TIMES = clogb2(WR_DATA_MAX_LEN-1);


    assign W_erase_start_use_4k   = F_need_4k_erase(I_update_addr, I_bin_size);
    assign W_erase_start_invalid  = F_erase_req_invalid(I_update_addr, I_bin_size);

    assign W_erase_use_4k_after_4k   = F_need_4k_erase(W_era_addr_next_4k, W_era_remain_next_4k);
    assign W_erase_use_4k_after_64k  = F_need_4k_erase(W_era_addr_next_64k, W_era_remain_next_64k);
    assign W_erase_invalid_after_4k  = F_erase_req_invalid(W_era_addr_next_4k, W_era_remain_next_4k);
    assign W_erase_invalid_after_64k = F_erase_req_invalid(W_era_addr_next_64k, W_era_remain_next_64k);
    assign W_wr_total_beats          = (I_bin_size >> WR_TIMES);
    assign W_axis_fire               = I_axis_tvalid & R_axis_tready;
    assign W_wr_count_overflow       = (R_wr_cnt > W_wr_total_beats);

    // ?????????????????????????last_fail_stage/timeout_err
    assign W_err_evt_erase_addr_invalid = (cur_state == IDLE) && W_opt_begin_pos && (I_bin_size != 32'd0) && W_erase_start_invalid;
    assign W_err_evt_erase_timeout_64k  = (cur_state == RD_ERA_64K_STATUS_CHECK) && W_status_busy && (R_erase_timeout_cnt >= ERASE_TIMEOUT_64K_CYCLES);
    assign W_err_evt_erase_timeout_4k   = (cur_state == RD_ERA_4K_STATUS_CHECK)  && W_status_busy && (R_erase_timeout_cnt >= ERASE_TIMEOUT_4K_CYCLES);
    assign W_err_evt_erase_status       = ((cur_state == RD_ERA_64K_STATUS_CHECK) || (cur_state == RD_ERA_4K_STATUS_CHECK)) && W_erase_status_error;
    assign W_err_evt_erase_busy_not_seen= ((cur_state == RD_ERA_64K_STATUS_CHECK) || (cur_state == RD_ERA_4K_STATUS_CHECK)) &&
                                          (!W_status_busy) && (!W_erase_status_error) && (!R_erase_busy_seen);
    assign W_err_evt_erase_next_invalid = ((cur_state == RD_ERA_64K_STATUS_CHECK) && (!W_status_busy) && (!W_erase_status_error) && (!W_erase_done_after_64k) && W_erase_invalid_after_64k) ||
                                          ((cur_state == RD_ERA_4K_STATUS_CHECK)  && (!W_status_busy) && (!W_erase_status_error) && (!W_erase_done_after_4k)  && W_erase_invalid_after_4k);
    assign W_err_evt_erase_verify       = (cur_state == ERASE_CHECK_CMPR) && (!(&I_rd_data));
    assign W_err_evt_write_overflow     = (cur_state == RD_WRITE_STATUE_CHECK) && W_wr_count_overflow;
    assign W_err_evt_write_status       = (cur_state == RD_WRITE_STATUE_CHECK) && (!W_wr_count_overflow) && (!W_status_busy) && W_write_status_error;
    assign W_err_evt_write_verify       = (cur_state == WRITE_CHECK_CMPR) && (I_rd_data != R_wr_data);
    assign W_err_evt_qe_enable          = (cur_state == QE_READ_CR1_VERIFY_CHECK) && (!W_qe_enabled);

    assign W_err_evt_any     = W_err_evt_erase_addr_invalid | W_err_evt_erase_timeout_64k | W_err_evt_erase_timeout_4k |
                               W_err_evt_erase_status | W_err_evt_erase_busy_not_seen | W_err_evt_erase_next_invalid | W_err_evt_erase_verify |
                               W_err_evt_write_status | W_err_evt_write_verify | W_err_evt_write_overflow | W_err_evt_qe_enable;
    assign W_err_evt_timeout = W_err_evt_erase_timeout_64k | W_err_evt_erase_timeout_4k;

    assign W_err_stage_code = W_err_evt_erase_timeout_64k  ? FAIL_STAGE_ERASE_TIMEOUT_64K  :
                              W_err_evt_erase_timeout_4k   ? FAIL_STAGE_ERASE_TIMEOUT_4K   :
                              W_err_evt_erase_addr_invalid ? FAIL_STAGE_ERASE_ADDR_INVALID  :
                              W_err_evt_erase_status       ? FAIL_STAGE_ERASE_STATUS_ERROR  :
                              W_err_evt_erase_busy_not_seen? FAIL_STAGE_ERASE_BUSY_NOT_SEEN :
                              W_err_evt_erase_next_invalid ? FAIL_STAGE_ERASE_NEXT_INVALID  :
                              W_err_evt_erase_verify       ? FAIL_STAGE_ERASE_VERIFY_ERROR  :
                              W_err_evt_write_overflow     ? FAIL_STAGE_WRITE_OVERFLOW      :
                              W_err_evt_write_status       ? FAIL_STAGE_WRITE_STATUS_ERROR  :
                              W_err_evt_write_verify       ? FAIL_STAGE_WRITE_VERIFY_ERROR   :
                              W_err_evt_qe_enable          ? FAIL_STAGE_QE_ENABLE_FAILED    :
                                                             FAIL_STAGE_NONE;


    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_opt_begin <= 2'b00;
        else
            R_opt_begin <= {R_opt_begin[0], I_opt_begin};
    end


    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            cur_state <= IDLE;
        else
            cur_state <= nxt_state;
    end


    always @(*) begin
        case (cur_state)
            IDLE:begin
                if (W_opt_begin_pos) begin
                    if (I_bin_size == 32'd0)
                        nxt_state = FINISH;
                    else if (W_need_qe_prepare)
                        nxt_state = QE_READ_SR1;
                    else if (W_erase_start_invalid)
                        nxt_state = ERA_CHECK_ERROR;
                    else if (W_need_clear_status)
                        nxt_state = CLEAR_STATUS;
                    else if (W_erase_start_use_4k)
                        nxt_state = ERASE_4K;
                    else
                        nxt_state = ERASE_64K;
                end
                else
                    nxt_state = IDLE;
            end
            QE_READ_SR1:begin
                if (I_flash_opt_done)
                    nxt_state = QE_READ_SR1_CHECK;
                else
                    nxt_state = QE_READ_SR1;
            end
            QE_READ_SR1_CHECK:begin
                if (W_sr1_status_error)
                    nxt_state = CLEAR_STATUS;
                else
                    nxt_state = QE_READ_CR1;
            end
            QE_READ_CR1:begin
                if (I_flash_opt_done)
                    nxt_state = QE_READ_CR1_CHECK;
                else
                    nxt_state = QE_READ_CR1;
            end
            QE_READ_CR1_CHECK:begin
                if (W_qe_enabled && !W_sr1_unlock_required) begin
                    if (W_erase_start_invalid)
                        nxt_state = ERA_CHECK_ERROR;
                    else if (W_need_clear_status)
                        nxt_state = CLEAR_STATUS;
                    else if (W_erase_start_use_4k)
                        nxt_state = ERASE_4K;
                    else
                        nxt_state = ERASE_64K;
                end
                else
                    nxt_state = QE_WRITE_REG;
            end
            QE_WRITE_REG:begin
                if (I_flash_opt_done)
                    nxt_state = QE_READ_CR1_VERIFY;
                else
                    nxt_state = QE_WRITE_REG;
            end
            QE_READ_CR1_VERIFY:begin
                if (I_flash_opt_done)
                    nxt_state = QE_READ_CR1_VERIFY_CHECK;
                else
                    nxt_state = QE_READ_CR1_VERIFY;
            end
            QE_READ_CR1_VERIFY_CHECK:begin
                if (W_qe_enabled && !W_sr1_unlock_required) begin
                    if (W_erase_start_invalid)
                        nxt_state = ERA_CHECK_ERROR;
                    else if (W_need_clear_status)
                        nxt_state = CLEAR_STATUS;
                    else if (W_erase_start_use_4k)
                        nxt_state = ERASE_4K;
                    else
                        nxt_state = ERASE_64K;
                end
                else
                    nxt_state = ERA_CHECK_ERROR;
            end
            CLEAR_STATUS:begin
                if (I_flash_opt_done) begin
                    if (W_need_qe_prepare)
                        nxt_state = QE_READ_SR1;
                    else if (W_erase_start_use_4k)
                        nxt_state = ERASE_4K;
                    else
                        nxt_state = ERASE_64K;
                end
                else
                    nxt_state = CLEAR_STATUS;
            end
            ERASE_64K:begin
                if (I_flash_opt_done)
                    if (POST_ERASE_STATUS_GUARD_CYCLES == 0)
                        nxt_state = RD_ERA_64K_STATUS;
                    else
                        nxt_state = POST_ERASE_64K_GUARD;
                else
                    nxt_state = ERASE_64K;
            end
            POST_ERASE_64K_GUARD:begin
                if (W_post_erase_status_guard_done)
                    nxt_state = RD_ERA_64K_STATUS;
                else
                    nxt_state = POST_ERASE_64K_GUARD;
            end
            RD_ERA_64K_STATUS:begin
                if (I_flash_opt_done)
                    nxt_state = RD_ERA_64K_STATUS_CHECK;
                else
                    nxt_state = RD_ERA_64K_STATUS;
            end
            RD_ERA_64K_STATUS_CHECK:begin
                if (W_erase_status_error) begin
                    nxt_state = ERA_CHECK_ERROR;
                end
                else if (W_status_busy) begin
                    // Stop retrying the same sector forever. Switch to explicit status polling with timeout protection.
                        if (R_erase_timeout_cnt >= ERASE_TIMEOUT_64K_CYCLES)
                        nxt_state = ERA_CHECK_ERROR;
                    else
                        nxt_state = RD_ERA_64K_STATUS;
                end
                else if (!R_erase_busy_seen) begin
                    nxt_state = ERA_CHECK_ERROR;
                end
                else begin
                    if (W_erase_done_after_64k) begin
                        if (I_mode)
                            nxt_state = ERASE_CHECK_RD;
                        else
                            nxt_state = WRITE;
                    end
                    else if (W_erase_invalid_after_64k)
                        nxt_state = ERA_CHECK_ERROR;
                    else if (W_erase_use_4k_after_64k)
                        nxt_state = ERASE_4K;
                    else
                        nxt_state = ERASE_64K;
                end
            end
            ERASE_4K:begin
                if (I_flash_opt_done)
                    if (POST_ERASE_STATUS_GUARD_CYCLES == 0)
                        nxt_state = RD_ERA_4K_STATUS;
                    else
                        nxt_state = POST_ERASE_4K_GUARD;
                else
                    nxt_state = ERASE_4K;
            end
            POST_ERASE_4K_GUARD:begin
                if (W_post_erase_status_guard_done)
                    nxt_state = RD_ERA_4K_STATUS;
                else
                    nxt_state = POST_ERASE_4K_GUARD;
            end
            RD_ERA_4K_STATUS:begin
                if (I_flash_opt_done)
                    nxt_state = RD_ERA_4K_STATUS_CHECK;
                else
                    nxt_state = RD_ERA_4K_STATUS;
            end
            RD_ERA_4K_STATUS_CHECK:begin
                if (W_erase_status_error) begin
                    nxt_state = ERA_CHECK_ERROR;
                end
                else if (W_status_busy) begin
                    if (R_erase_timeout_cnt >= ERASE_TIMEOUT_4K_CYCLES)
                        nxt_state = ERA_CHECK_ERROR;
                    else
                        nxt_state = RD_ERA_4K_STATUS;
                end
                else if (!R_erase_busy_seen) begin
                    nxt_state = ERA_CHECK_ERROR;
                end
                else begin
                    if (W_erase_done_after_4k) begin
                        if (I_mode)
                            nxt_state = ERASE_CHECK_RD;
                        else
                            nxt_state = WRITE;
                    end
                    else if (W_erase_invalid_after_4k)
                        nxt_state = ERA_CHECK_ERROR;
                    else if (W_erase_use_4k_after_4k)
                        nxt_state = ERASE_4K;
                    else
                        nxt_state = ERASE_64K;
                end
            end
            ERASE_CHECK_RD:begin
                if (I_flash_opt_done)
                    nxt_state = ERASE_CHECK_CMPR;
                else
                    nxt_state = ERASE_CHECK_RD;
            end
            ERASE_CHECK_CMPR:begin
                if (&I_rd_data) begin
                    if (R_era_chk_cnt >= (I_bin_size >> RD_TIMES))
                        nxt_state = WRITE;
                    else
                        nxt_state = ERASE_CHECK_RD;
                end
                else
                    nxt_state = ERA_CHECK_ERROR;
            end
            WRITE:begin
                if (I_flash_opt_done && R_opt_en)
                    nxt_state = RD_WRITE_STATUS;
                else
                    nxt_state = WRITE;
            end
            RD_WRITE_STATUS:begin
                if (I_flash_opt_done)
                    nxt_state = RD_WRITE_STATUE_CHECK;
                else
                    nxt_state = RD_WRITE_STATUS;
            end
            RD_WRITE_STATUE_CHECK:begin
                // Protection check: the completed write-beat count must never exceed the planned total beat count.
                    if (W_wr_count_overflow)
                    nxt_state = WRITE_CHECK_ERR;
                else if (W_status_busy)
                    nxt_state = RD_WRITE_STATUS;
                else if (W_write_status_error)
                    nxt_state = WRITE_CHECK_ERR;
                else begin
                    if (R_wr_cnt >= W_wr_total_beats) begin
                        if (I_mode)
                            nxt_state = WRITE_CHECK_RD;
                        else
                            nxt_state = FINISH;
                    end
                    else begin
                        if (I_mode)
                            nxt_state = WRITE_CHECK_RD;
                        else
                            nxt_state = WRITE;
                    end
                end
            end
            WRITE_CHECK_RD:begin
                if (I_flash_opt_done)
                    nxt_state = WRITE_CHECK_CMPR;
                else
                    nxt_state = WRITE_CHECK_RD;
            end
            WRITE_CHECK_CMPR:begin
                if (I_rd_data == R_wr_data) begin
                    if (R_wr_chk_cnt >= (I_bin_size >> RD_TIMES))
                        nxt_state = FINISH;
                    else
                        nxt_state = WRITE;
                end
                else
                    nxt_state = WRITE_CHECK_ERR;
            end
            ERA_CHECK_ERROR:begin
                nxt_state = IDLE;
            end
            FINISH:begin
                nxt_state = IDLE;
            end
            WRITE_CHECK_ERR:begin
                nxt_state = IDLE;
            end
            default:begin
                nxt_state = IDLE;
            end
        endcase
    end

    // R_opt_en,R_opt_mode

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_opt_en   <= 1'b0;
            R_opt_mode <= 4'd0;
        end
        else begin
            case (cur_state)
                IDLE:begin
                    R_opt_en   <= 1'b0;
                    R_opt_mode <= 4'd0;
                end
                QE_READ_SR1:begin
                    R_opt_mode <= 4'd8;
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else
                        R_opt_en <= 1'b1;
                end
                QE_READ_SR1_CHECK:begin
                    R_opt_en <= R_opt_en;
                end
                QE_READ_CR1:begin
                    R_opt_mode <= 4'd8;
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else
                        R_opt_en <= 1'b1;
                end
                QE_READ_CR1_CHECK:begin
                    R_opt_en <= R_opt_en;
                end
                QE_WRITE_REG:begin
                    R_opt_mode <= 4'd7;
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else
                        R_opt_en <= 1'b1;
                end
                QE_READ_CR1_VERIFY:begin
                    R_opt_mode <= 4'd8;
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else
                        R_opt_en <= 1'b1;
                end
                QE_READ_CR1_VERIFY_CHECK:begin
                    R_opt_en <= R_opt_en;
                end
                CLEAR_STATUS:begin
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else begin
                        R_opt_en   <= 1'b1;
                        R_opt_mode <= 4'd9;
                    end
                end
                ERASE_64K:begin
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else begin
                        R_opt_en   <= 1'b1;
                        R_opt_mode <= 4'd5;
                    end
                end
                POST_ERASE_64K_GUARD:begin
                    R_opt_en <= 1'b0;
                end
                RD_ERA_64K_STATUS:begin
                    R_opt_mode <= 4'd8;
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else
                        R_opt_en <= 1'b1;
                end
                RD_ERA_64K_STATUS_CHECK:begin
                    R_opt_en <= R_opt_en;
                end
                ERASE_4K:begin
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else begin
                        R_opt_en   <= 1'b1;
                        R_opt_mode <= 4'd4;
                    end
                end
                POST_ERASE_4K_GUARD:begin
                    R_opt_en <= 1'b0;
                end
                RD_ERA_4K_STATUS:begin
                    R_opt_mode <= 4'd8;
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else
                        R_opt_en <= 1'b1;
                end
                RD_ERA_4K_STATUS_CHECK:begin
                    R_opt_en <= R_opt_en;
                end
                ERASE_CHECK_RD:begin
                    R_opt_mode <= 4'd3;
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else
                        R_opt_en <= 1'b1;
                end
                ERASE_CHECK_CMPR:begin
                    R_opt_en <= R_opt_en;
                end
                WRITE:begin
                    if (I_flash_opt_done) begin
                        R_opt_en <= 1'b0;
                    end
                    else begin
                        // Only launch one write operation per AXIS handshake to keep a strict one-beat-per-write mapping.
                            if (W_axis_fire && (R_wr_cnt < W_wr_total_beats)) begin
                            R_opt_en   <= 1'b1;
                            R_opt_mode <= 4'd1;
                        end
                        else begin
                            R_opt_en <= R_opt_en;
                        end
                    end
                end
                RD_WRITE_STATUS:begin
                    R_opt_mode <= 4'd8;
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else
                        R_opt_en <= 1'b1;
                end
                RD_WRITE_STATUE_CHECK:begin
                    R_opt_en <= R_opt_en;
                end
                WRITE_CHECK_RD:begin
                    R_opt_mode <= 4'd3;
                    if (I_flash_opt_done)
                        R_opt_en <= 1'b0;
                    else
                        R_opt_en <= 1'b1;
                end
                WRITE_CHECK_CMPR:begin
                    R_opt_en <= R_opt_en;
                end
                ERA_CHECK_ERROR:begin
                    R_opt_en <= 1'b0;
                end
                WRITE_CHECK_ERR:begin
                    R_opt_en <= 1'b0;
                end
                FINISH:begin
                    R_opt_en <= 1'b0;
                end
                default:begin
                    R_opt_en <= 1'b0;
                end
            endcase
        end
    end


    // R_era_64k_cnt,R_era_4k_cnt,R_era_chk_cnt,R_wr_cnt,R_wr_chk_cnt,R_era_addr,R_rd_cmd,R_rd_addr,R_wr_addr

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_era_64k_cnt      <= 'd0;
            R_era_4k_cnt       <= 'd0;
            R_era_chk_cnt      <= 'd0;
            R_wr_cnt           <= 'd0;
            R_wr_chk_cnt       <= 'd0;
            R_era_remain_bytes <= 'd0;
            R_era_addr         <= 'd0;
            R_rd_addr          <= 'd0;
            R_wr_addr          <= 'd0;
            R_wr_cmd           <= WRITE_REG_CMD_S25;
            R_wr_cmd_data      <= 16'h0002;
            R_rd_cmd           <= STATUS_CMD_S25;
            R_sr1_shadow       <= 8'h00;
            R_cr1_shadow       <= 8'h00;
        end
        else begin
            case (cur_state)
                IDLE:begin
                    if (W_opt_begin_pos) begin
                        R_era_64k_cnt      <= 'd0;
                        R_era_4k_cnt       <= 'd0;
                        R_era_chk_cnt      <= 'd0;
                        R_wr_cnt           <= 'd0;
                        R_wr_chk_cnt       <= 'd0;
                        R_era_remain_bytes <= I_bin_size;
                        R_era_addr         <= I_update_addr;
                        R_rd_addr          <= I_update_addr;
                        R_wr_addr          <= I_update_addr;
                        R_wr_cmd           <= WRITE_REG_CMD_S25;
                        R_wr_cmd_data      <= 16'h0002;
                        R_rd_cmd           <= W_status_cmd;
                        R_sr1_shadow       <= 8'h00;
                        R_cr1_shadow       <= 8'h00;
                    end
                    else begin
                        R_era_64k_cnt      <= 'd0;
                        R_era_4k_cnt       <= 'd0;
                        R_era_chk_cnt      <= 'd0;
                        R_wr_cnt           <= 'd0;
                        R_wr_chk_cnt       <= 'd0;
                        R_era_remain_bytes <= 'd0;
                        R_era_addr         <= 'd0;
                        R_rd_addr          <= 'd0;
                        R_wr_addr          <= 'd0;
                        R_wr_cmd           <= WRITE_REG_CMD_S25;
                        R_wr_cmd_data      <= 16'h0002;
                        R_rd_cmd           <= W_status_cmd;
                        R_sr1_shadow       <= 8'h00;
                        R_cr1_shadow       <= 8'h00;
                    end
                end
                QE_READ_SR1:begin
                    R_rd_cmd <= STATUS_CMD_S25;
                end
                QE_READ_SR1_CHECK:begin
                    R_sr1_shadow <= I_rd_cmd_data;
                end
                QE_READ_CR1:begin
                    R_rd_cmd <= CONFIG_CMD_S25;
                end
                QE_READ_CR1_CHECK:begin
                    R_cr1_shadow  <= I_rd_cmd_data;
                    R_wr_cmd      <= WRITE_REG_CMD_S25;
                    R_wr_cmd_data <= {8'h00, (I_rd_cmd_data | S25_QE_MASK)};
                end
                QE_WRITE_REG:begin
                    R_wr_cmd      <= WRITE_REG_CMD_S25;
                    R_wr_cmd_data <= {8'h00, (R_cr1_shadow | S25_QE_MASK)};
                end
                QE_READ_CR1_VERIFY:begin
                    R_rd_cmd <= CONFIG_CMD_S25;
                end
                QE_READ_CR1_VERIFY_CHECK:begin
                    R_cr1_shadow <= I_rd_cmd_data;
                end
                CLEAR_STATUS:begin
                    R_rd_cmd <= W_status_cmd;
                end
                ERASE_64K:begin
                    R_rd_cmd <= W_status_cmd;
                end
                POST_ERASE_64K_GUARD:begin
                    R_rd_cmd <= W_status_cmd;
                end
                RD_ERA_64K_STATUS:begin
                    R_rd_cmd <= W_status_cmd;
                end
                RD_ERA_64K_STATUS_CHECK:begin
                    if (!W_status_busy && !W_erase_status_error) begin
                        R_era_64k_cnt <= R_era_64k_cnt + 1'b1;
                        if (W_erase_done_after_64k)
                            R_era_remain_bytes <= 32'd0;
                        else begin
                            R_era_addr         <= W_era_addr_next_64k;
                            R_era_remain_bytes <= W_era_remain_next_64k;
                        end
                    end
                end
                ERASE_4K:begin
                    R_rd_cmd <= W_status_cmd;
                end
                POST_ERASE_4K_GUARD:begin
                    R_rd_cmd <= W_status_cmd;
                end
                RD_ERA_4K_STATUS:begin
                    R_rd_cmd <= W_status_cmd;
                end
                RD_ERA_4K_STATUS_CHECK:begin
                    if (!W_status_busy && !W_erase_status_error) begin
                        R_era_4k_cnt <= R_era_4k_cnt + 1'b1;
                        if (W_erase_done_after_4k)
                            R_era_remain_bytes <= 32'd0;
                        else begin
                            R_era_addr         <= W_era_addr_next_4k;
                            R_era_remain_bytes <= W_era_remain_next_4k;
                        end
                    end
                end
                ERASE_CHECK_RD:begin
                    if (I_flash_opt_done) begin
                        R_era_chk_cnt <= R_era_chk_cnt + 1'b1;
                        R_rd_addr     <= R_rd_addr + RD_DATA_MAX_LEN;
                    end
                end
                ERASE_CHECK_CMPR:begin
                    if (R_era_chk_cnt >= (I_bin_size >> RD_TIMES))
                        R_rd_addr <= I_update_addr;
                end
                WRITE:begin
                    if (I_flash_opt_done && R_opt_en) begin
                        R_wr_cnt  <= R_wr_cnt + 1'b1;
                        R_wr_addr <= R_wr_addr + WR_DATA_MAX_LEN;
                    end
                end
                RD_WRITE_STATUS:begin
                    R_rd_cmd <= W_status_cmd;
                end
                RD_WRITE_STATUE_CHECK:begin
                    R_rd_cmd <= W_status_cmd;
                end
                WRITE_CHECK_RD:begin
                    if (I_flash_opt_done) begin
                        R_wr_chk_cnt <= R_wr_chk_cnt + 1'b1;
                        R_rd_addr    <= R_rd_addr + RD_DATA_MAX_LEN;
                    end
                end
                WRITE_CHECK_CMPR:begin
                    R_wr_chk_cnt <= R_wr_chk_cnt;
                    R_rd_addr    <= R_rd_addr;
                end
                default:begin
                    ;
                end
            endcase
        end
    end


    // R_axis_tready

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_axis_tready <= 1'b0;
        end
        else begin
            case (cur_state)
                IDLE:begin
                    R_axis_tready <= 1'b0;
                end
                WRITE:begin
                    if (!R_opt_en && (R_wr_cnt < W_wr_total_beats)) begin
                        if (W_axis_fire)
                            R_axis_tready <= 1'b0;
                        else
                            R_axis_tready <= 1'b1;
                    end
                    else begin
                        R_axis_tready <= 1'b0;
                    end
                end
                default:begin
                    R_axis_tready <= 1'b0;
                end
            endcase
        end
    end

    // R_wr_data

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_wr_data <= 'd0;
        end
        else begin
            case (cur_state)
                IDLE:begin
                    R_wr_data <= 'd0;
                end
                WRITE:begin
                    // ??????????????????????????????????????????????????????/??????????
                        if (W_axis_fire) begin
                        R_wr_data <= I_axis_tdata;
                    end
                    else begin
                        R_wr_data <= R_wr_data;
                    end
                end
                default:begin
                    R_wr_data <= R_wr_data;
                end
            endcase
        end
    end

    // R_drv_opt_ok

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_drv_opt_ok <= 1'b0;
        else begin
            case (cur_state)
                IDLE:begin
                    R_drv_opt_ok <= 1'b0;
                end
                FINISH:begin
                    R_drv_opt_ok <= 1'b1;
                end
                default:begin
                    R_drv_opt_ok <= 1'b0;
                end
            endcase
        end

    end

    // R_err

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_err <= 1'b0;
        else begin
            case (cur_state)
                IDLE:begin
                    if (W_opt_begin_pos)
                        R_err <= 1'b0;
                    else
                        R_err <= R_err;
                end
                ERA_CHECK_ERROR:begin
                    R_err <= 1'b1;
                end
                WRITE_CHECK_ERR:begin
                    R_err <= 1'b1;
                end
                default:begin
                    R_err <= R_err;
                end
            endcase
        end
    end

    // R_timeout_err, R_last_fail_stage
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_timeout_err     <= 1'b0;
            R_last_fail_stage <= FAIL_STAGE_NONE;
        end
        else begin
            if (W_err_evt_any) begin
                R_timeout_err     <= W_err_evt_timeout;
                R_last_fail_stage <= W_err_stage_code;
            end
            else if (W_opt_begin_pos) begin
                R_timeout_err     <= 1'b0;
                R_last_fail_stage <= FAIL_STAGE_NONE;
            end
            else begin
                R_timeout_err     <= R_timeout_err;
                R_last_fail_stage <= R_last_fail_stage;
            end
        end
    end

    // R_drv_opt_busy

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_drv_opt_busy <= 1'b0;
        else begin
            if (cur_state == IDLE)
                R_drv_opt_busy <= 1'b0;
            else if (cur_state == FINISH)
                R_drv_opt_busy <= 1'b0;
            else if (cur_state == ERA_CHECK_ERROR)
                R_drv_opt_busy <= 1'b0;
            else if (cur_state == WRITE_CHECK_ERR)
                R_drv_opt_busy <= 1'b0;
            else
                R_drv_opt_busy <= 1'b1;
        end

    end

    // R_post_erase_status_guard_cnt
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_post_erase_status_guard_cnt <= 'd0;
        else begin
            case (cur_state)
                POST_ERASE_64K_GUARD,
                POST_ERASE_4K_GUARD: begin
                    if (!W_post_erase_status_guard_done)
                        R_post_erase_status_guard_cnt <= R_post_erase_status_guard_cnt + 1'b1;
                    else
                        R_post_erase_status_guard_cnt <= R_post_erase_status_guard_cnt;
                end
                default: begin
                    R_post_erase_status_guard_cnt <= 'd0;
                end
            endcase
        end
    end

    // R_erase_busy_seen
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_erase_busy_seen <= 1'b0;
        else begin
            case (cur_state)
                IDLE,
                CLEAR_STATUS,
                ERASE_64K,
                ERASE_4K: begin
                    R_erase_busy_seen <= 1'b0;
                end
                RD_ERA_64K_STATUS_CHECK,
                RD_ERA_4K_STATUS_CHECK: begin
                    if (W_status_busy)
                        R_erase_busy_seen <= 1'b1;
                    else
                        R_erase_busy_seen <= R_erase_busy_seen;
                end
                default: begin
                    R_erase_busy_seen <= R_erase_busy_seen;
                end
            endcase
        end
    end

    // R_erase_timeout_cnt

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_erase_timeout_cnt <= 'd0;
        end
        else begin
            case (cur_state)
                // Hold the timeout counter across the erase-status polling loop instead of clearing it on every
                // return to RD_ERA_*_STATUS.
                RD_ERA_64K_STATUS:begin
                    R_erase_timeout_cnt <= R_erase_timeout_cnt;
                end
                RD_ERA_64K_STATUS_CHECK:begin
                    if (W_status_busy)
                        R_erase_timeout_cnt <= R_erase_timeout_cnt + 1'b1;
                    else
                        R_erase_timeout_cnt <= 'd0;
                end
                RD_ERA_4K_STATUS:begin
                    R_erase_timeout_cnt <= R_erase_timeout_cnt;
                end
                RD_ERA_4K_STATUS_CHECK:begin
                    if (W_status_busy)
                        R_erase_timeout_cnt <= R_erase_timeout_cnt + 1'b1;
                    else
                        R_erase_timeout_cnt <= 'd0;
                end
                default:begin
                    R_erase_timeout_cnt <= 'd0;
                end
            endcase
        end
    end

endmodule
