


//---------------------------------------------------------------------------
//
//    author:婵炲瓨绮屾總鏃傜�??
//
//-------------------------------------------------------------------------

module flash_driver #(

    parameter SYS_CLK_FREQ       = 100000000 ,
    parameter FLASH_CLK_FREQ     = 10000000  ,
    parameter RD_DATA_MAX_LEN    = 1500      ,
    parameter WR_DATA_MAX_LEN    = 512       ,
    parameter FLASH_ADDR_WIDTH   = 32        ,
    parameter integer FLASH_MODEL = 0        ,
    parameter integer SPI_BUS_WIDTH = 1
    )(
        input                                        I_clk_in         ,                // 闂佸搫鍟悥濂稿�??
        input                                        I_rst_n          ,                // 婵犮垼娉涚粔宕囩�??
             
        input       [3:0]                            I_mode           ,                // 濠碘槅鍨埀顒€纾涵鈧梻渚囧亜椤︽壆�??      
        input                                        I_opt_en         ,                // 闂佺懓鐏濈粔宕囩礊閺冣偓閹峰懘鎳楅姘�?        
         
        input       [FLASH_ADDR_WIDTH-1:0]           I_wr_base_addr   ,                // 闂佸憡鍔栭悷銉╁矗閸℃稑鏋侀柣妤€鐗嗙粊锕傛偣瑜嶉崲鏌ワ綖閹版澘鎹堕柡澶嬪�??         
        input       [FLASH_ADDR_WIDTH-1:0]           I_rd_base_addr   ,                // 闁荤姴娲╅褔宕甸銏犳瀬闁绘鐗嗙粊锕傛偣瑜嶉崲鏌ワ綖閹版澘鎹堕柡澶嬪缁?
        input       [FLASH_ADDR_WIDTH-1:0]           I_era_base_addr  ,                // 闂佺懓灏呯粻鎾斥枍鎼淬劌鏋侀柣妤€鐗嗙粊锕傛偣瑜嶉崲鏌ワ綖閹版澘鎹堕柡澶嬪�??
 
        input       [((WR_DATA_MAX_LEN << 3) - 1):0] I_wr_data        ,                // 闂佸憡鍔栭悷銉╁矗閸℃稑鏋侀柣妤€鐗嗙粊?

        input       [7:0]                            I_wr_cmd         ,                // 闂佸憡鍔栭悷锔锯偓鍨缁傛帡濡堕崨顖涱潠闁诲孩绋掗敋婵?
        input       [15:0]                           I_wr_cmd_data    ,                // 闂佸憡鍔栭悷锔锯偓鍨缁傛帡濡堕崨顖涱潠闁诲孩绋掗敋婵炲懏甯�?�顐︽偋閸繄�??
      
        output      [((RD_DATA_MAX_LEN << 3)-1):0]   O_rd_data        ,                // 闁荤姴娲╅褔宕甸銏犳瀬闁绘鐗嗙�??
      
        input                                        I_data           ,                // legacy x1 MISO input
        input       [3:0]                            I_dq             ,                // QSPI DQ input

        input       [7:0]                            I_rd_cmd         ,                // read register command
        output      [7:0]                            O_rd_cmd_data    ,                // read register data
                              
        output                                       O_cs             ,                // chip select
        output                                       O_sck            ,                // serial clock
        output                                       O_data           ,                // x1 data output
        output      [3:0]                            O_dq             ,                // QSPI DQ output
        output      [3:0]                            O_dq_oe          ,                // QSPI DQ output enable

        output                                       O_opt_done       ,                // operation done
        output                                       O_opt_busy
    );

    localparam  FLASH_MODEL_S25FL256S = 0;
    localparam  FLASH_MODEL_MT25QL    = 1;
    localparam  FLASH_MODEL_N25Q128A  = 2;

    localparam  R_CLK_DIVERD      = (SYS_CLK_FREQ/FLASH_CLK_FREQ);
    localparam  USE_X4            = (SPI_BUS_WIDTH == 4);
    localparam  CMD_ADDR_WIDTH    = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 24 : 32;
    localparam  READ_CMD_X1       = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h03 : 8'h13;
    localparam  WRITE_CMD_X1      = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h02 : 8'h12;
    localparam  READ_CMD_X4       = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h6B : 8'h6C;
    localparam  WRITE_CMD_X4      = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h32 : 8'h34;
    localparam  READ_CMD          = USE_X4 ? READ_CMD_X4  : READ_CMD_X1;
    localparam  WRITE_CMD         = USE_X4 ? WRITE_CMD_X4 : WRITE_CMD_X1;
    localparam  READ_DUMMY_CYCLES = USE_X4 ? 8 : 0;
    localparam  READ_ADDR_TOTAL_CYCLES = CMD_ADDR_WIDTH + READ_DUMMY_CYCLES;
    localparam  ENABLE_CMD        = 8'h06;
    localparam  CLEAR_STATUS_CMD  = 8'h50;
    localparam  ERASE_4K_CMD      = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'h20 : 8'h21; // 4K bytes闂佺懓灏呯粻鎾斥�??
    localparam  ERASE_64K_CMD     = (FLASH_MODEL == FLASH_MODEL_N25Q128A) ? 8'hD8 : 8'hDC; // 64K bytes闂佺懓灏呯粻鎾斥�??
    localparam  ERASE_ALL_CMD     = 8'hC7;
    localparam  READ_MAX_BIT_NUM  = RD_DATA_MAX_LEN << 3;         // �??
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
    reg [3:0]   R_wr_quad_data_out;



    wire        W_opt_en;
    wire        SCK_H   ;
    wire        SCK_L   ;
    wire        SCK_HALF_L;
    wire        SCK_HALF_H;


    wire        W_spi_mosi;
    wire        W_spi_miso;
    wire [3:0]  W_qspi_data_out;
    wire        W_quad_write_data_phase;
    wire        W_read_addr_dummy_phase;
    wire [4:0]  W_wr_cmd_data_bits;


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

    


    assign  W_spi_mosi = R_rd_data_out | R_wr_data_out | R_era_data_out | R_wr_cmd_data_out | R_rd_cmd_data_out;
    assign  W_spi_miso = USE_X4 ? I_dq[1] : I_data;
    assign  W_quad_write_data_phase = USE_X4 && ((cur_state == WRITE_SINGLE_DATA) || (cur_state == WRITE_MULTI_DATA));
    assign  W_read_addr_dummy_phase = USE_X4 && (cur_state == WRITE_RD_ADDR) && (R_rd_bit_cnt >= CMD_ADDR_WIDTH);
    assign  W_wr_cmd_data_bits = ((FLASH_MODEL == FLASH_MODEL_S25FL256S) && (I_wr_cmd == 8'h01)) ? 5'd16 : 5'd8;
    assign  W_qspi_data_out = W_quad_write_data_phase ? R_wr_quad_data_out : {3'b000, W_spi_mosi};

    assign  O_cs   = R_cs;
    assign  O_sck  = R_clk;
    assign  O_data = W_qspi_data_out[0];
    assign  O_dq   = W_qspi_data_out;
    assign  O_dq_oe = (R_cs || W_read_addr_dummy_phase ||
                      (USE_X4 && ((cur_state == READ_SINGLE_DATA) || (cur_state == READ_MULTI_DATA)))) ? 4'b0000 :
                      (W_quad_write_data_phase ? 4'b1111 : 4'b0001);
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
                if (R_rd_bit_cnt >= READ_ADDR_TOTAL_CYCLES && SCK_H) begin
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
                if (R_wr_cmd_bit_cnt >= W_wr_cmd_data_bits && SCK_L) begin
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


    
    //        闁荤姴娲╁畷闈浢规径鎰�??

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
                        if (R_rd_bit_cnt < CMD_ADDR_WIDTH)
                            R_rd_data_out <= I_rd_base_addr[CMD_ADDR_WIDTH - 1 - R_rd_bit_cnt];
                        else
                            R_rd_data_out <= 1'b0;
                        R_rd_bit_cnt <= R_rd_bit_cnt + 1'b1;
                    end
                    else begin
                        R_rd_data_out <= R_rd_data_out;
                        if (R_rd_bit_cnt >= READ_ADDR_TOTAL_CYCLES && SCK_H)
                            R_rd_bit_cnt <= 'd0;
                        else
                            R_rd_bit_cnt <= R_rd_bit_cnt;
                    end
                end
                READ_SINGLE_DATA:begin
                    if (SCK_H) begin
                        if (USE_X4) begin
                            R_rd_data[0][7 - R_rd_bit_cnt -: 4] <= I_dq;
                            R_rd_bit_cnt <= R_rd_bit_cnt + 'd4;
                        end
                        else begin
                            R_rd_data[0][7-R_rd_bit_cnt] <= W_spi_miso;
                            R_rd_bit_cnt <= R_rd_bit_cnt + 1'b1;
                        end
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
                        if (USE_X4) begin
                            R_rd_data[R_rd_byte_cnt][7 - R_rd_bit_cnt -: 4] <= I_dq;
                            R_rd_bit_cnt <= R_rd_bit_cnt + 'd4;
                        end
                        else begin
                            R_rd_data[R_rd_byte_cnt][7-R_rd_bit_cnt] <= W_spi_miso;
                            R_rd_bit_cnt <= R_rd_bit_cnt + 1'b1;
                        end
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


    //          闂佸憡鍔栭悷褍霉婢舵劕绀?

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_wr_bit_cnt <= 'd0;
            R_wr_cmd     <= WRITE_CMD;
            R_en_cmd     <= ENABLE_CMD;
            R_wr_quad_data_out <= 4'h0;
        end
        else begin
            case (cur_state)
                IDLE:begin
                    R_wr_data_out <= 1'b0;
                    R_wr_quad_data_out <= 4'h0;
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
                            if (USE_X4) begin
                                R_wr_quad_data_out <= I_wr_data[7 - R_wr_bit_cnt -: 4];
                                R_wr_data_out <= I_wr_data[7 - R_wr_bit_cnt];
                                R_wr_bit_cnt <= R_wr_bit_cnt + 'd4;
                            end
                            else begin
                                R_wr_data_out <= I_wr_data[7-R_wr_bit_cnt];
                                R_wr_bit_cnt <= R_wr_bit_cnt + 1'b1;
                            end
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
                            if (USE_X4) begin
                                R_wr_quad_data_out <= I_wr_data[WRITE_MAX_BIT_NUM - 1 - R_wr_bit_cnt -: 4];
                                R_wr_data_out <= I_wr_data[WRITE_MAX_BIT_NUM - 1 - R_wr_bit_cnt];
                                R_wr_bit_cnt <= R_wr_bit_cnt + 'd4;
                            end
                            else begin
                                R_wr_data_out <= I_wr_data[WRITE_MAX_BIT_NUM - 1 - R_wr_bit_cnt];
                                R_wr_bit_cnt <= R_wr_bit_cnt + 1'b1;
                            end
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


    // 闂佺懓灏呯粻鎾斥�??
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


    // 闂佸憡鍔栭悷锔锯偓鍨缁傛帡濡堕崨顖涱潠闁诲孩绋掗敋婵?

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
                    if (SCK_L) begin
                        if (I_mode != 4'd9)
                            R_wr_cmd_data_out <= I_wr_cmd_data[W_wr_cmd_data_bits - 1];
                        else
                            R_wr_cmd_data_out <= R_wr_cmd_data_out;
                        if (I_mode == 4'd9)
                            R_wr_cmd_bit_cnt <= 'd0;
                        else
                            R_wr_cmd_bit_cnt <= 'd1;
                    end
                    else begin
                        R_wr_cmd_data_out <= R_wr_cmd_data_out;
                        R_wr_cmd_bit_cnt <= R_wr_cmd_bit_cnt;
                    end
                end
                WRITE_REG_CMD_DATA:begin
                    if (R_wr_cmd_bit_cnt < W_wr_cmd_data_bits) begin
                        if (SCK_L) begin
                            R_wr_cmd_data_out <= I_wr_cmd_data[W_wr_cmd_data_bits - 1 - R_wr_cmd_bit_cnt];
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

    // 闁荤姴娲ㄧ划顖溾偓鍨缁傛帡濡堕崨顖涱潠闁诲孩绋掗敋婵?

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
                        R_rd_cmd_data[7-R_rd_cmd_bit_cnt] <= W_spi_miso;
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



