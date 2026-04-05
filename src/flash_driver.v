`timescale 1ns / 1ps 


//---------------------------------------------------------------------------
//
//    author:二乐
//
//-------------------------------------------------------------------------

module flash_driver #(

    parameter SYS_CLK_FREQ       = 100000000 ,
    parameter FLASH_CLK_FREQ     = 10000000  ,
    parameter RD_DATA_MAX_LEN    = 1500      ,
    parameter WR_DATA_MAX_LEN    = 512       ,
    parameter FLASH_ADDR_WIDTH   = 32        ,
    parameter integer FLASH_MODEL = 0         
    )(
        input                                        I_clk_in         ,                // 时钟
        input                                        I_rst_n          ,                // 复位
             
        input       [3:0]                            I_mode           ,                // 模式选择       
        input                                        I_opt_en         ,                // 操作使能        
         
        input       [FLASH_ADDR_WIDTH-1:0]           I_wr_base_addr   ,                // 写入数据起始地址          
        input       [FLASH_ADDR_WIDTH-1:0]           I_rd_base_addr   ,                // 读出数据起始地址
        input       [FLASH_ADDR_WIDTH-1:0]           I_era_base_addr  ,                // 擦除数据起始地址
 
        input       [((WR_DATA_MAX_LEN << 3) - 1):0] I_wr_data        ,                // 写入数据

        input       [7:0]                            I_wr_cmd         ,                // 写指令寄存器
        input       [7:0]                            I_wr_cmd_data    ,                // 写指令寄存器数据
      
        output      [((RD_DATA_MAX_LEN << 3)-1):0]   O_rd_data        ,                // 读出数据
      
        input                                        I_data           ,                // 数据输入端口

        input       [7:0]                            I_rd_cmd         ,                // 读指令寄存器
        output      [7:0]                            O_rd_cmd_data    ,                // 读出的指令寄存器数据
                              
        output                                       O_cs             ,                // 片选输出
        output                                       O_sck            ,                // 时钟输出
        output                                       O_data           ,                // 数据输出

        output                                       O_opt_done       ,                // 操作结束标志
        output                                       O_opt_busy                        // 操作忙标志
    );       

    localparam  FLASH_MODEL_S25FL256S = 0;
    localparam  FLASH_MODEL_MT25QL    = 1;
    localparam  FLASH_MODEL_N25Q128A  = 2;

    localparam  R_CLK_DIVERD      = (SYS_CLK_FREQ/FLASH_CLK_FREQ);
    localparam  CMD_ADDR_WIDTH    = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 24 : 32;
    localparam  READ_CMD          = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h03 : 8'h13;
    localparam  WRITE_CMD         = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h02 : 8'h12;
    localparam  ENABLE_CMD        = 8'h06;
    localparam  CLEAR_STATUS_CMD  = 8'h50;
    localparam  ERASE_4K_CMD      = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h20 : 8'h21; // 4K bytes擦除
    localparam  ERASE_64K_CMD     = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'hD8 : 8'hDC; // 64K bytes擦除
    localparam  ERASE_ALL_CMD     = 8'hC7;
    localparam  READ_MAX_BIT_NUM  = RD_DATA_MAX_LEN << 3;         // ×8
    localparam  WRITE_MAX_BIT_NUM = WR_DATA_MAX_LEN << 3;

    reg [31:0]  R_clk_cnt  ;
    reg [1:0]   R_opt_en   ;
    reg         R_cs       ;
    reg         R_clk      ;

    reg         R_rd_data_out     ;
    reg         R_wr_data_out     ;
    reg         R_era_data_out    ;
    reg         R_wr_cmd_data_out ;
    reg         R_rd_cmd_data_out ;
    reg [7:0]   R_rd_cmd_data     ;

    reg [7:0]   R_rd_data [RD_DATA_MAX_LEN-1:0];
    reg [15:0]  R_rd_bit_cnt  ;
    reg [15:0]  R_rd_byte_cnt ;
    reg [15:0]  R_wr_bit_cnt  ;
    reg [15:0]  R_era_bit_cnt ;
    reg [15:0]  R_wr_cmd_bit_cnt ;
    reg [15:0]  R_rd_cmd_bit_cnt ;

    reg [7:0]   R_rd_cmd ;
    reg [7:0]   R_wr_cmd ;
    reg [7:0]   R_era_cmd;
    reg [7:0]   R_en_cmd ;
    reg         R_opt_done;
    reg         R_opt_busy;



    wire        W_opt_en;
    wire        SCK_H   ;
    wire        SCK_L   ;
    wire        SCK_HALF_L;
    wire        SCK_HALF_H;


    assign  O_cs   = R_cs;
    assign  O_sck  = R_clk;
    assign  O_data = R_rd_data_out | R_wr_data_out | R_era_data_out | R_wr_cmd_data_out | R_rd_cmd_data_out;
    assign  O_rd_cmd_data = R_rd_cmd_data;
    assign  O_opt_done = R_opt_done;
    assign  O_opt_busy = R_opt_busy;

    assign  W_opt_en = R_opt_en[0] & ~R_opt_en[1];
    assign  SCK_L    = (R_clk_cnt == (R_CLK_DIVERD - 1)) ? 1'b1 : 1'b0;
    assign  SCK_H    = (R_clk_cnt == (R_CLK_DIVERD >> 1)) ? 1'b1 : 1'b0;
    assign  SCK_HALF_L = (R_clk_cnt == (R_CLK_DIVERD >> 2)) ? 1'b1 : 1'b0;
    assign  SCK_HALF_H = (R_clk_cnt == ((R_CLK_DIVERD >> 1) + (R_CLK_DIVERD >> 2))) ? 1'b1 : 1'b0;

  
    generate
       for (genvar i = 0; i <= RD_DATA_MAX_LEN - 1; i = i + 1) begin
            for (genvar j = 0; j <= 7; j = j + 1) begin
                 assign O_rd_data[((RD_DATA_MAX_LEN - 1 - i)<<3)+j] = R_rd_data[i][j];
            end
       end
    endgenerate

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_opt_en <= 2'b00;
        else
            R_opt_en <= {R_opt_en[0], I_opt_en};
    end


    localparam IDLE                     = 26'b00_0000_0000_0000_0000_0000_0000;

    localparam WRITE_ENABLE_NOP         = 26'b00_0000_0000_0000_0000_0000_0001;
    localparam WRITE_ENABLE             = 26'b00_0000_0000_0000_0000_0000_0010;
    localparam WRITE_ENABLE_END         = 26'b00_0000_0000_0000_0000_0000_0100;

    localparam WRITE_WR_CMD_NOP         = 26'b00_0000_0000_0000_0000_0000_1000;
    localparam WRITE_WR_CMD             = 26'b00_0000_0000_0000_0000_0001_0000;
    localparam WRITE_WR_ADDR            = 26'b00_0000_0000_0000_0000_0010_0000;
    localparam WRITE_SINGLE_DATA        = 26'b00_0000_0000_0000_0000_0100_0000;
    localparam WRITE_MULTI_DATA         = 26'b00_0000_0000_0000_0000_1000_0000;

    localparam WRITE_RD_CMD_NOP         = 26'b00_0000_0000_0000_0001_0000_0000;
    localparam WRITE_RD_CMD             = 26'b00_0000_0000_0000_0010_0000_0000;
    localparam WRITE_RD_ADDR            = 26'b00_0000_0000_0000_0100_0000_0000;
    localparam READ_SINGLE_DATA         = 26'b00_0000_0000_0000_1000_0000_0000;
    localparam READ_MULTI_DATA          = 26'b00_0000_0000_0001_0000_0000_0000;

    localparam WRITE_ERASE_CMD_NOP      = 26'b00_0000_0000_0010_0000_0000_0000;
    localparam WRITE_ERASE_CMD          = 26'b00_0000_0000_0100_0000_0000_0000;
    localparam WRITE_ERASE_ADDR         = 26'b00_0000_0000_1000_0000_0000_0000;

    localparam WRITE_ERASE_ALL_CMD_NOP  = 26'b00_0000_0001_0000_0000_0000_0000;
    localparam WRITE_ERASE_ALL_CMD      = 26'b00_0000_0010_0000_0000_0000_0000;

    localparam READ_REG_CMD_NOP         = 26'b00_0000_0100_0000_0000_0000_0000;
    localparam READ_REG_CMD             = 26'b00_0000_1000_0000_0000_0000_0000;
    localparam READ_REG_CMD_DATA        = 26'b00_0001_0000_0000_0000_0000_0000; 

    localparam WRITE_REG_CMD_NOP        = 26'b00_0010_0000_0000_0000_0000_0000; 
    localparam WRITE_REG_CMD            = 26'b00_0100_0000_0000_0000_0000_0000; 
    localparam WRITE_REG_CMD_DATA       = 26'b00_1000_0000_0000_0000_0000_0000; 

    localparam WRITE_ENABLE_LAST        = 26'b10_0000_0000_0000_0000_0000_0000;
    localparam WRITE_ERASE_ALL_LAST     = 26'b10_0000_0000_0000_0000_0000_0001;
    localparam WRITE_REG_LAST           = 26'b10_0000_0000_0000_0000_0000_0010;

    localparam OPT_END                  = 26'b01_0000_0000_0010_0000_0000_0000;



    reg [25:0] cur_state, nxt_state;

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            cur_state <= IDLE;
        else
            cur_state <= nxt_state;
    end

    always @(*) begin
        case (cur_state)
            IDLE:begin
                if (W_opt_en) begin
                    if (I_mode == 4'd0 || I_mode == 4'd1)                 
                        nxt_state = WRITE_ENABLE_NOP;
                    else if (I_mode == 4'd2 || I_mode == 4'd3)           
                        nxt_state = WRITE_RD_CMD_NOP;
                    else if (I_mode == 4'd4 || I_mode == 4'd5 || I_mode == 4'd6 || I_mode == 4'd7)           
                        nxt_state = WRITE_ENABLE_NOP;
                    else if (I_mode == 4'd8)
                        nxt_state = READ_REG_CMD_NOP;
                    else if (I_mode == 4'd9)
                        nxt_state = WRITE_REG_CMD_NOP;
                    else
                        nxt_state = WRITE_ENABLE;
                end 
                else begin
                    nxt_state = IDLE;
                end
            end
            //          WRITE
            WRITE_RD_CMD_NOP:begin
                nxt_state = WRITE_RD_CMD;
            end
            WRITE_RD_CMD:begin
                if (R_rd_bit_cnt >= 'd7) 
                    nxt_state = WRITE_RD_ADDR;
                else 
                    nxt_state = WRITE_RD_CMD;
            end
            WRITE_RD_ADDR:begin
                if (R_rd_bit_cnt >= CMD_ADDR_WIDTH && SCK_H) begin
                    if (I_mode == 4'd2)
                        nxt_state = READ_SINGLE_DATA;
                    else
                        nxt_state = READ_MULTI_DATA;
                end
                else
                    nxt_state = WRITE_RD_ADDR;
            end
            READ_SINGLE_DATA:begin
                if (R_rd_bit_cnt >= 'd8 && SCK_L) 
                    nxt_state = OPT_END;
                else
                    nxt_state = READ_SINGLE_DATA;
            end
            READ_MULTI_DATA:begin
                if (((R_rd_byte_cnt << 3) >= READ_MAX_BIT_NUM) && SCK_HALF_L)
                    nxt_state = OPT_END;
                else 
                    nxt_state = READ_MULTI_DATA;
            end

            //    READ
            WRITE_ENABLE_NOP:begin
                nxt_state = WRITE_ENABLE;
            end
            WRITE_ENABLE:begin
                if ((R_wr_bit_cnt >= 'd6 || R_era_bit_cnt >= 'd6 || R_wr_cmd_bit_cnt >= 'd6)&& SCK_L)
                    nxt_state = WRITE_ENABLE_LAST;
                else
                    nxt_state = WRITE_ENABLE;
            end
            WRITE_ENABLE_LAST:begin
                if (SCK_L)
                    nxt_state = WRITE_ENABLE_END;
                else
                    nxt_state = WRITE_ENABLE_LAST;
            end
            WRITE_ENABLE_END:begin
                if (R_wr_bit_cnt > 'd100 || R_era_bit_cnt > 'd100 || R_wr_cmd_bit_cnt > 'd100) begin
                    if (I_mode == 4'd0 || I_mode == 4'd1)
                        nxt_state = WRITE_WR_CMD_NOP;
                    else if (I_mode == 4'd4 || I_mode == 4'd5)
                        nxt_state = WRITE_ERASE_CMD_NOP;
                    else if (I_mode == 4'd6)
                        nxt_state = WRITE_ERASE_ALL_CMD_NOP;
                    else if (I_mode == 4'd7)
                        nxt_state = WRITE_REG_CMD_NOP;
                    else
                        nxt_state = WRITE_WR_CMD_NOP;
                end  
                else
                    nxt_state = WRITE_ENABLE_END;
            end
            WRITE_WR_CMD_NOP:begin
                nxt_state = WRITE_WR_CMD;
            end
            WRITE_WR_CMD:begin
                if (R_wr_bit_cnt >= 'd7)
                    nxt_state = WRITE_WR_ADDR;
                else
                    nxt_state = WRITE_WR_CMD;
            end
            WRITE_WR_ADDR:begin
                if (R_wr_bit_cnt >= CMD_ADDR_WIDTH) begin
                    if (I_mode == 4'd0)
                        nxt_state = WRITE_SINGLE_DATA;
                    else
                        nxt_state = WRITE_MULTI_DATA;
                end
                else 
                    nxt_state = WRITE_WR_ADDR;
            end
            WRITE_SINGLE_DATA:begin
                 if (R_wr_bit_cnt >= 'd8 && SCK_L)
                    nxt_state = OPT_END;
                else
                    nxt_state = WRITE_SINGLE_DATA;
            end
            WRITE_MULTI_DATA:begin
                if (R_wr_bit_cnt >= WRITE_MAX_BIT_NUM && SCK_L)
                    nxt_state = OPT_END;
                else
                    nxt_state = WRITE_MULTI_DATA;
            end
            WRITE_ERASE_CMD_NOP:begin
                nxt_state = WRITE_ERASE_CMD;
            end
            WRITE_ERASE_CMD:begin
                if (R_era_bit_cnt >= 'd7)
                    nxt_state = WRITE_ERASE_ADDR;
                else
                    nxt_state = WRITE_ERASE_CMD;
            end
            WRITE_ERASE_ADDR:begin
                if (R_era_bit_cnt >= CMD_ADDR_WIDTH && SCK_L) begin
                    nxt_state = OPT_END;
                end
                else begin
                    nxt_state = WRITE_ERASE_ADDR;
                end
            end
            WRITE_ERASE_ALL_CMD_NOP:begin
                nxt_state = WRITE_ERASE_ALL_CMD;
            end
            WRITE_ERASE_ALL_CMD:begin
                if (R_era_bit_cnt >= 'd6 && SCK_L)
                    nxt_state = WRITE_ERASE_ALL_LAST;
                else
                    nxt_state = WRITE_ERASE_ALL_CMD;
            end
            WRITE_ERASE_ALL_LAST:begin
                if (SCK_L)
                    nxt_state = OPT_END;
                else
                    nxt_state = WRITE_ERASE_ALL_LAST;
            end
            WRITE_REG_CMD_NOP:begin
                nxt_state = WRITE_REG_CMD;
            end
            WRITE_REG_CMD:begin
                if (R_wr_cmd_bit_cnt >= 'd6 && SCK_L)
                    nxt_state = WRITE_REG_LAST;
                else
                    nxt_state = WRITE_REG_CMD;
            end
            WRITE_REG_LAST:begin
                if (SCK_L) begin
                    if (I_mode == 4'd9)
                        nxt_state = OPT_END;
                    else
                        nxt_state = WRITE_REG_CMD_DATA;
                end
                else
                    nxt_state = WRITE_REG_LAST;
            end
            WRITE_REG_CMD_DATA:begin
                if (R_wr_cmd_bit_cnt >= 8 && SCK_L) begin
                    nxt_state = OPT_END;
                end
                else begin
                    nxt_state = WRITE_REG_CMD_DATA;
                end
            end
            READ_REG_CMD_NOP:begin
                nxt_state = READ_REG_CMD;
            end
            READ_REG_CMD:begin
                if (R_rd_cmd_bit_cnt >= 'd7 && SCK_H)
                    nxt_state = READ_REG_CMD_DATA;
                else
                    nxt_state = READ_REG_CMD;
            end
            READ_REG_CMD_DATA:begin
                if (R_rd_cmd_bit_cnt >= 'd8 && SCK_L)
                    nxt_state = OPT_END;
                else
                    nxt_state = READ_REG_CMD_DATA;
            end
            OPT_END:begin
                nxt_state = IDLE;
            end
            default:begin
                nxt_state = IDLE;
            end
        endcase
    end


    
    //        读相关

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_rd_bit_cnt <= 'd0;
            R_rd_cmd     <= READ_CMD;
            R_rd_byte_cnt <= 'd0;
        end
        else begin
            case (cur_state)
                IDLE: begin
                    R_rd_data_out <= 1'b0;
                end
                WRITE_RD_CMD_NOP:begin
                    R_rd_data_out <= R_rd_cmd[7];
                end
                WRITE_RD_CMD:begin
                    if (SCK_L) begin
                        R_rd_data_out       <= R_rd_cmd[6-R_rd_bit_cnt];
                        R_rd_bit_cnt <= R_rd_bit_cnt + 1'b1;
                    end
                    else begin
                        R_rd_data_out <= R_rd_data_out;
                        if (R_rd_bit_cnt >= 'd7)
                            R_rd_bit_cnt <= 'd0;
                        else 
                            R_rd_bit_cnt <= R_rd_bit_cnt;
                    end
                end
                WRITE_RD_ADDR:begin
                    if (SCK_L) begin
                        R_rd_data_out       <= I_rd_base_addr[CMD_ADDR_WIDTH - 1 - R_rd_bit_cnt];
                        R_rd_bit_cnt <= R_rd_bit_cnt + 1'b1;
                    end
                    else begin
                        R_rd_data_out <= R_rd_data_out;
                        if (R_rd_bit_cnt >= CMD_ADDR_WIDTH && SCK_H)
                            R_rd_bit_cnt <= 'd0;
                        else
                            R_rd_bit_cnt <= R_rd_bit_cnt;
                    end
                end
                READ_SINGLE_DATA:begin
                    if (SCK_H) begin
                        R_rd_data[0][7-R_rd_bit_cnt] <= I_data;
                        R_rd_bit_cnt <= R_rd_bit_cnt + 1'b1;
                    end
                    else begin
                         if (R_rd_bit_cnt >= 'd8 && SCK_L)
                            R_rd_bit_cnt <= 'd0;
                        else
                            R_rd_bit_cnt <= R_rd_bit_cnt;
                    end
                end
                READ_MULTI_DATA:begin
                    if (SCK_H) begin                
                        R_rd_data[R_rd_byte_cnt][7-R_rd_bit_cnt] <= I_data;
                        R_rd_bit_cnt <= R_rd_bit_cnt + 1'b1;
                    end
                    else begin
                         if (R_rd_bit_cnt >= 'd8 && SCK_L) begin
                            R_rd_bit_cnt <= 'd0;
                            R_rd_byte_cnt <= R_rd_byte_cnt + 1'b1;
                        end
                        else begin
                            R_rd_bit_cnt <= R_rd_bit_cnt;
                        end
                    end
                end
                OPT_END:begin
                    R_rd_byte_cnt <= 'd0;
                    R_rd_data_out <= 1'b0;
                end
            endcase
        end
    end


    //          写相关

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_wr_bit_cnt <= 'd0;
            R_wr_cmd     <= WRITE_CMD;
            R_en_cmd     <= ENABLE_CMD;
        end
        else begin
            case (cur_state)
                IDLE:begin
                    R_wr_data_out <= 1'b0;
                end
                WRITE_ENABLE_NOP:begin
                    R_wr_data_out <= R_en_cmd[7];
                end
                WRITE_ENABLE:begin
                    if (R_wr_bit_cnt <= 'd6) begin
                        if (SCK_L) begin
                            R_wr_data_out <= R_en_cmd[6-R_wr_bit_cnt];
                            R_wr_bit_cnt  <= R_wr_bit_cnt + 1'b1;
                        end
                        else
                            R_wr_data_out <= R_wr_data_out;
                    end  
                    else begin
                        R_wr_data_out <= R_wr_data_out;
                        R_wr_bit_cnt <= R_wr_bit_cnt;
                    end
                end
                WRITE_ENABLE_LAST:begin
                    R_wr_data_out <= R_wr_data_out;
                    if (SCK_L)
                        R_wr_bit_cnt <= 'd0;
                    else
                        R_wr_bit_cnt <= R_wr_bit_cnt;
                end
                WRITE_ENABLE_END:begin

                    if (R_wr_bit_cnt <= 'd100)          // 1US
                        R_wr_bit_cnt <= R_wr_bit_cnt + 1'b1;
                    else
                        R_wr_bit_cnt <= 'd0;
                end
                WRITE_WR_CMD_NOP:begin
                    R_wr_data_out <= R_wr_cmd[7];
                end
                WRITE_WR_CMD:begin
                    if (SCK_L) begin
                        R_wr_data_out <= R_wr_cmd[6-R_wr_bit_cnt];
                        R_wr_bit_cnt <= R_wr_bit_cnt + 1'b1;
                    end
                    else begin
                        R_wr_data_out <= R_wr_data_out;
                        if (R_wr_bit_cnt >= 'd7)
                            R_wr_bit_cnt <= 'd0;
                        else
                            R_wr_bit_cnt <= R_wr_bit_cnt;
                    end
                end
                WRITE_WR_ADDR:begin
                    if (SCK_L) begin
                        R_wr_data_out <= I_wr_base_addr[CMD_ADDR_WIDTH-1-R_wr_bit_cnt];
                        R_wr_bit_cnt <= R_wr_bit_cnt + 1'b1;
                    end
                    else begin
                        R_wr_data_out <= R_wr_data_out;
                        if (R_wr_bit_cnt >= CMD_ADDR_WIDTH)
                            R_wr_bit_cnt <= 'd0;
                        else
                            R_wr_bit_cnt <= R_wr_bit_cnt;
                    end
                end
                WRITE_SINGLE_DATA:begin
                    if (R_wr_bit_cnt <= 'd7) begin
                        if (SCK_L) begin
                            R_wr_data_out <= I_wr_data[7-R_wr_bit_cnt];
                            R_wr_bit_cnt <= R_wr_bit_cnt + 1'b1;
                        end
                        else
                             R_wr_data_out <= R_wr_data_out;
                    end
                    else begin
                        R_wr_data_out <= R_wr_data_out;
                        if (SCK_L)
                            R_wr_bit_cnt <= 'd0;
                        else
                            R_wr_bit_cnt <= R_wr_bit_cnt;
                    end
                end
                WRITE_MULTI_DATA:begin
                    if (R_wr_bit_cnt <= WRITE_MAX_BIT_NUM - 1) begin
                        if (SCK_L) begin
                            R_wr_data_out <= I_wr_data[WRITE_MAX_BIT_NUM - 1 - R_wr_bit_cnt];
                            R_wr_bit_cnt <= R_wr_bit_cnt + 1'b1;
                        end
                        else
                            R_wr_data_out <= R_wr_data_out;
                    end
                    else begin
                        R_wr_data_out <= R_wr_data_out;
                        if (SCK_L)
                            R_wr_bit_cnt <= 'd0;
                        else
                            R_wr_bit_cnt <= R_wr_bit_cnt;
                    end
                end
            endcase
        end
    end


    // 擦除
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_era_bit_cnt <= 'd0;
            R_era_cmd     <= ERASE_4K_CMD;
        end
        else begin
            case (cur_state)
                IDLE:begin
                    R_era_data_out <= 1'b0;
                end
                WRITE_ENABLE_NOP:begin
                    R_era_data_out <= R_en_cmd[7];
                    if (I_mode == 'd4)
                        R_era_cmd <= ERASE_4K_CMD;
                    else if (I_mode == 'd5)
                        R_era_cmd <= ERASE_64K_CMD;
                    else 
                        R_era_cmd <= ERASE_ALL_CMD;
                end
                WRITE_ENABLE:begin
                    if (R_era_bit_cnt <= 'd6) begin
                        if (SCK_L) begin
                            R_era_data_out <= R_en_cmd[6-R_era_bit_cnt];
                            R_era_bit_cnt  <= R_era_bit_cnt + 1'b1;
                        end
                        else
                            R_era_data_out <= R_era_data_out;
                    end  
                    else begin
                        R_era_data_out <= R_era_data_out;
                        R_era_bit_cnt <= R_era_bit_cnt;
                    end
                end
                WRITE_ENABLE_LAST:begin
                    R_era_data_out <= R_era_data_out;
                    if (SCK_L)
                        R_era_bit_cnt <= 'd0;
                    else
                        R_era_bit_cnt <= R_era_bit_cnt;
                end
                WRITE_ENABLE_END:begin
                    if (R_era_bit_cnt <= 'd100)
                        R_era_bit_cnt <= R_era_bit_cnt + 1'b1;
                    else
                        R_era_bit_cnt <= 'd0;
                end
                WRITE_ERASE_ALL_CMD_NOP:begin
                    R_era_data_out <= R_era_cmd[7];
                end
                WRITE_ERASE_ALL_CMD:begin
                    if (R_era_bit_cnt <= 'd6) begin
                        if (SCK_L) begin
                            R_era_data_out <= R_era_cmd[6-R_era_bit_cnt];
                            R_era_bit_cnt  <= R_era_bit_cnt + 1'b1;
                        end
                        else
                            R_era_data_out <= R_era_data_out;
                    end  
                    else begin
                        R_era_data_out <= R_era_data_out;
                        R_era_bit_cnt <= R_era_bit_cnt;
                    end
                end
                WRITE_ERASE_ALL_LAST:begin
                    R_era_data_out <= R_era_data_out;
                    if (SCK_L)
                        R_era_bit_cnt <= 'd0;
                    else
                        R_era_bit_cnt <= R_era_bit_cnt;
                end
                WRITE_ERASE_CMD_NOP:begin
                    R_era_data_out <= R_era_cmd[7];
                end
                WRITE_ERASE_CMD:begin
                    if (SCK_L) begin
                        R_era_data_out <= R_era_cmd[6-R_era_bit_cnt];
                        R_era_bit_cnt <= R_era_bit_cnt + 1'b1;
                    end
                    else begin
                        R_era_data_out <= R_era_data_out;
                        if (R_era_bit_cnt >= 'd7)
                            R_era_bit_cnt <= 'd0;
                        else
                            R_era_bit_cnt <= R_era_bit_cnt;
                    end
                end
                WRITE_ERASE_ADDR:begin
                    if (R_era_bit_cnt <= CMD_ADDR_WIDTH - 1) begin
                        if (SCK_L) begin
                            R_era_data_out <= I_era_base_addr[CMD_ADDR_WIDTH-1-R_era_bit_cnt];
                            R_era_bit_cnt <= R_era_bit_cnt + 1'b1;
                        end
                        else begin
                            R_era_data_out <= R_era_data_out;
                        end
                    end
                    else begin
                         R_era_data_out <= R_era_data_out;
                        if (SCK_L)
                            R_era_bit_cnt <= 'd0;
                        else
                            R_era_bit_cnt <= R_era_bit_cnt;
                    end
                end
            endcase
        end
    end


    // 写指令寄存器

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_wr_cmd_bit_cnt <= 'd0;
        end
        else begin
            case (cur_state)
                IDLE:begin
                    R_wr_cmd_data_out <= 1'b0;
                end
                WRITE_ENABLE_NOP:begin
                    R_wr_cmd_data_out <= R_en_cmd[7];
                end
                WRITE_ENABLE:begin
                    if (R_wr_cmd_bit_cnt <= 'd6) begin
                        if (SCK_L) begin
                            R_wr_cmd_data_out <= R_en_cmd[6-R_era_bit_cnt];
                            R_wr_cmd_bit_cnt  <= R_wr_cmd_bit_cnt + 1'b1;
                        end
                        else
                            R_wr_cmd_data_out <= R_wr_cmd_data_out;
                    end  
                    else begin
                        R_wr_cmd_data_out <= R_wr_cmd_data_out;
                        R_wr_cmd_bit_cnt <= R_wr_cmd_bit_cnt;
                    end
                end
                WRITE_ENABLE_LAST:begin
                    R_wr_cmd_data_out <= R_wr_cmd_data_out;
                    if (SCK_H)
                        R_wr_cmd_bit_cnt <= 'd0;
                    else
                        R_wr_cmd_bit_cnt <= R_wr_cmd_bit_cnt;
                end
                WRITE_ENABLE_END:begin
                    if (R_wr_cmd_bit_cnt <= 'd100)
                        R_wr_cmd_bit_cnt <= R_wr_cmd_bit_cnt + 1'b1;
                    else
                        R_wr_cmd_bit_cnt <= 'd0;
                end
                WRITE_REG_CMD_NOP:begin
                    if (I_mode == 4'd9)
                        R_wr_cmd_data_out <= CLEAR_STATUS_CMD[7];
                    else
                        R_wr_cmd_data_out <= I_wr_cmd[7];
                end
                WRITE_REG_CMD:begin
                    if (SCK_L) begin
                        if (I_mode == 4'd9)
                            R_wr_cmd_data_out <= CLEAR_STATUS_CMD[6-R_wr_cmd_bit_cnt];
                        else
                            R_wr_cmd_data_out <= I_wr_cmd[6-R_wr_cmd_bit_cnt];
                        R_wr_cmd_bit_cnt <= R_wr_cmd_bit_cnt + 1'b1;
                    end
                    else begin
                        R_wr_cmd_data_out <= R_wr_cmd_data_out;
                        R_wr_cmd_bit_cnt <= R_wr_cmd_bit_cnt;
                    end
                end
                WRITE_REG_LAST:begin
                    R_wr_cmd_data_out <= R_wr_cmd_data_out;
                    if (SCK_L)
                        R_wr_cmd_bit_cnt <= 'd0;
                    else
                        R_wr_cmd_bit_cnt <= R_wr_cmd_bit_cnt;
                end
                WRITE_REG_CMD_DATA:begin
                    if (R_wr_cmd_bit_cnt <= 7) begin
                        if (SCK_L) begin
                            R_wr_cmd_data_out <= I_wr_cmd_data[7-R_wr_cmd_bit_cnt];
                            R_wr_cmd_bit_cnt <= R_wr_cmd_bit_cnt + 1'b1;
                        end
                        else begin
                            R_wr_cmd_data_out <=  R_wr_cmd_data_out;
                        end
                    end
                    else begin
                        R_wr_cmd_data_out <= R_wr_cmd_data_out;
                        if (SCK_L)
                            R_wr_cmd_bit_cnt <= 'd0;
                        else
                            R_wr_cmd_bit_cnt <= R_wr_cmd_bit_cnt;
                    end
                end

            endcase
        end
    end

    // 读指令寄存器

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_rd_cmd_bit_cnt <= 'd0;
        end
        else begin
            case (cur_state)
                IDLE:begin
                    R_rd_cmd_data_out <= 1'b0;
                end
                READ_REG_CMD_NOP:begin
                    R_rd_cmd_data_out <= I_rd_cmd[7];
                end
                READ_REG_CMD:begin
                    if (SCK_L) begin
                        R_rd_cmd_data_out <= I_rd_cmd[6-R_rd_cmd_bit_cnt];
                        R_rd_cmd_bit_cnt <= R_rd_cmd_bit_cnt + 1'b1;
                    end
                    else begin
                        R_rd_cmd_data_out <= R_rd_cmd_data_out;
                        if (R_rd_cmd_bit_cnt >= 'd7 && SCK_H)
                            R_rd_cmd_bit_cnt <= 'd0;
                        else
                            R_rd_cmd_bit_cnt <= R_rd_cmd_bit_cnt;
                    end
                end
                READ_REG_CMD_DATA:begin
                    if (SCK_H) begin
                        R_rd_cmd_data[7-R_rd_cmd_bit_cnt] <= I_data;
                        R_rd_cmd_bit_cnt <= R_rd_cmd_bit_cnt + 1'b1;
                    end
                    else begin
                        if (R_rd_cmd_bit_cnt >= 'd8 && SCK_L)
                            R_rd_cmd_bit_cnt <= 'd0;
                        else
                            R_rd_cmd_bit_cnt <= R_rd_cmd_bit_cnt;
                    end
                end
            endcase
        end
    end

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_opt_done <= 1'b0;
        end
        else begin
            case (cur_state)
                IDLE:
                    R_opt_done <= 1'b0;
                OPT_END:
                    R_opt_done <= 1'b1;
            endcase
        end
    end


    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_cs <= 1'b1;
        else begin
            if (cur_state == IDLE && W_opt_en)
                R_cs <= 1'b0;
            else if (cur_state == WRITE_ENABLE_END) begin
                if (R_wr_bit_cnt >= R_CLK_DIVERD || R_era_bit_cnt >= R_CLK_DIVERD || R_wr_cmd_bit_cnt >= R_CLK_DIVERD)
                    R_cs <= 1'b1;
                else
                    R_cs <= 1'b0;
            end
            else if (cur_state == WRITE_WR_CMD_NOP)
                R_cs <= 1'b0;
            else if (cur_state == WRITE_ERASE_CMD_NOP)
                R_cs <= 1'b0;
            else if (cur_state == WRITE_ERASE_ALL_CMD_NOP)
                R_cs <= 1'b0;
            else if (cur_state == WRITE_REG_CMD_NOP)
                R_cs <= 1'b0;
            else if (cur_state == READ_REG_CMD_NOP)
                R_cs <= 1'b0;
            else if (cur_state == OPT_END)
                R_cs <= 1'b1;
            else
                R_cs <= R_cs;
        end
    end

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_clk <= 1'b0;
        else begin
            if (cur_state == IDLE || cur_state == OPT_END || cur_state == WRITE_ENABLE_END ||
                cur_state == WRITE_ENABLE_NOP || cur_state == WRITE_WR_CMD_NOP ||
                cur_state == WRITE_RD_CMD_NOP || cur_state == WRITE_ERASE_CMD_NOP ||
                cur_state == WRITE_ERASE_ALL_CMD_NOP || cur_state == WRITE_REG_CMD_NOP ||
                cur_state == READ_REG_CMD_NOP)
                R_clk <= 1'b0;
            else if (R_clk_cnt == R_CLK_DIVERD >> 1)
                R_clk <= 1'b1;
            else if (R_clk_cnt == R_CLK_DIVERD -1)
                R_clk <= 1'b0;
            else
                R_clk <= R_clk;
        end
    end


    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_clk_cnt <= 'd0;
        else begin
            if (cur_state != IDLE) begin
                 if (cur_state == WRITE_ENABLE_END) begin
                    R_clk_cnt <= 'd0;
                 end
                 else begin
                    if (R_clk_cnt == R_CLK_DIVERD -1)
                        R_clk_cnt <= 'd0;
                    else
                        R_clk_cnt <= R_clk_cnt + 1'b1;
                 end
            end  
            else
                R_clk_cnt <= 'd0; 
        end
    end

    // R_opt_busy
    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            R_opt_busy <= 1'b0;
        else begin
            case (cur_state)
                IDLE:begin
                    if (W_opt_en)
                        R_opt_busy <= 1'b1;
                    else
                        R_opt_busy <= R_opt_busy;
                end
                OPT_END:
                    R_opt_busy <= 1'b0;
            endcase
        end
    end


endmodule


