`timescale 1ns / 1ps

//---------------------------------------------------------------------------
//
//    author:二乐
//
//-------------------------------------------------------------------------

module tb_flash_driver();

    localparam FLASH_ADDR_WIDTH = 32;
    localparam RD_DATA_MAX_LEN  = 3;
    localparam WR_DATA_MAX_LEN  = 3;

    localparam WR_DATA_MAX_BIT_NUM = WR_DATA_MAX_LEN << 3;

    reg                                         I_clk_in        ;
    reg                                         I_rst_n         ;
    reg       [3:0]                             I_mode          ;
    reg                                         I_opt_en        ;
    reg       [FLASH_ADDR_WIDTH-1:0]            I_wr_base_addr  ;
    reg       [FLASH_ADDR_WIDTH-1:0]            I_rd_base_addr  ;
    reg       [FLASH_ADDR_WIDTH-1:0]            I_era_base_addr ; 
    reg                                         I_data          ;
    reg       [((WR_DATA_MAX_LEN << 3) - 1):0]  I_wr_data       ;
               
    wire                                        O_cs            ;
    wire                                        O_sck           ;
    wire                                        O_data          ;
    wire      [((RD_DATA_MAX_LEN << 3)-1):0]    O_rd_data       ;

    reg       [7:0]                             I_wr_cmd        ;
    reg       [7:0]                             I_wr_cmd_data   ; 

    reg       [7:0]                             I_rd_cmd         ;
    wire      [7:0]                             O_rd_cmd_data    ;
    wire                                        O_opt_done       ;
    wire                                        O_opt_busy       ;



    task WriteRegCmd;
        input [7:0] reg_cmd;
        input [7:0] reg_cmd_data;
    begin
         I_mode   = 4'd7;
         I_opt_en = 1'b0;
         I_wr_cmd = reg_cmd;
         I_wr_cmd_data = reg_cmd_data;
         #100
         I_opt_en = 1'b1;
    end
    endtask


    task ReadRegCmd;
        input [7:0] rd_cmd;
    begin
         I_mode   = 4'd8;
         I_opt_en = 1'b0;
         I_rd_cmd = rd_cmd;
         #100
         I_opt_en = 1'b1;
    end
    endtask


    task ReadOneByte;
        input [FLASH_ADDR_WIDTH-1:0] rd_addr;
    begin

        I_mode   = 4'd2;
        I_opt_en = 1'b0;
        I_rd_base_addr = rd_addr;
        #100
        I_opt_en = 1'b1;
    end
    endtask



     task ReadMultByte;
        input [FLASH_ADDR_WIDTH-1:0] rd_addr;
    begin
        I_mode  = 4'd3;
        I_opt_en = 1'b0;
        I_rd_base_addr = rd_addr;
        #100
        I_opt_en = 1'b1;
    end
    endtask



    task WriteOneByte;
        input [FLASH_ADDR_WIDTH-1:0] wr_addr;
        input [7:0] wr_data;
    begin
        I_mode   = 4'd0;
        I_opt_en = 1'b0;
        I_wr_base_addr   = wr_addr;
        I_wr_data[7:0]   = wr_data;
        #100
        I_opt_en = 1'b1;
    end
    endtask

    task WriteMultBytes;
         input [FLASH_ADDR_WIDTH-1:0] wr_addr;
         input [WR_DATA_MAX_BIT_NUM-1:0] wr_data;
    begin
        I_mode   = 4'd1;
        I_opt_en = 1'b0;
        I_wr_base_addr   = wr_addr;
        I_wr_data        = wr_data;
        #100
        I_opt_en = 1'b1;
    end
    endtask

    task Erase64Kbytes;
        input [FLASH_ADDR_WIDTH-1:0] era_addr;
    begin
        I_mode   = 4'd5;
        I_opt_en = 1'b0;
        I_era_base_addr   = era_addr;
        #100
        I_opt_en = 1'b1;
    end
    endtask

    task Erase4Kbytes;
        input [FLASH_ADDR_WIDTH-1:0] era_addr;
    begin
        I_mode   = 4'd4;
        I_opt_en = 1'b0;
        I_era_base_addr   = era_addr;
        #100
        I_opt_en = 1'b1;
    end
    endtask

    task EraseAll;
    begin
        I_mode   = 4'd6;
        I_opt_en = 1'b0;
        #100
        I_opt_en = 1'b1;
    end
    endtask



    initial begin
        
        I_clk_in = 1'b0;
        I_rst_n  = 1'b0;
        I_mode   = 4'd2;
        I_opt_en = 1'b0;


        #200

        I_rst_n  = 1'b1;

        #10000

        ReadRegCmd(8'h5a);

        #10000


        WriteRegCmd(8'h5a, 8'h7e);

        #10000


        EraseAll();

        #10000

        Erase4Kbytes(32'h5a5a7e7e);

        #10000

        Erase64Kbytes(32'h5a5a7e7e);

        #10000

        WriteOneByte(32'h5a5a7e7e, 8'h5a);

        #10000

        WriteMultBytes(32'h5a5a7e7e, 24'h7a5a5a);

        #10000

        ReadOneByte(32'h5a5a7e7e);

        #10000
        ReadMultByte(32'h5a5aa5a5);

        #10000
        ReadMultByte(32'h5a5aa5a5);



    end


    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
            I_data <= 1'b0;
        end
        else begin
            if ((flash_driver_inst.cur_state == flash_driver_inst.READ_SINGLE_DATA || flash_driver_inst.cur_state == flash_driver_inst.READ_MULTI_DATA || flash_driver_inst.cur_state == flash_driver_inst.READ_REG_CMD_DATA) && flash_driver_inst.SCK_L)
                I_data <= ~I_data;
            else
                I_data <= I_data;
        end
    end


    flash_driver #(

            .SYS_CLK_FREQ       (100000000)  ,
            .FLASH_CLK_FREQ     (10000000)   ,
            .RD_DATA_MAX_LEN    (RD_DATA_MAX_LEN)          ,
            .WR_DATA_MAX_LEN    (WR_DATA_MAX_LEN)       ,
            .FLASH_ADDR_WIDTH   (32)  

    ) flash_driver_inst(

        .I_clk_in           (I_clk_in),
        .I_rst_n            (I_rst_n),
 
        .I_mode             (I_mode),                        // 操作模式
        .I_opt_en           (I_opt_en),                      // 操作使能

        .I_wr_base_addr     (I_wr_base_addr),                // 写入的起始地址
        .I_rd_base_addr     (I_rd_base_addr),                // 读出的起始地址
        .I_era_base_addr    (I_era_base_addr),               // 擦除的起始地址

        .I_wr_cmd           (I_wr_cmd),
        .I_wr_cmd_data      (I_wr_cmd_data), 


        .I_wr_data          (I_wr_data)   ,   
        .O_rd_data          (O_rd_data)   ,
        .I_data             (I_data)      , 

        .I_rd_cmd           (I_rd_cmd),
        .O_rd_cmd_data      (O_rd_cmd_data),
                
        .O_cs               (O_cs)        ,
        .O_sck              (O_sck)       ,
        .O_data             (O_data)      ,

        .O_opt_done         (O_opt_done)  ,
        .O_opt_busy         (O_opt_busy)

    );

    always #5 I_clk_in = ~I_clk_in;



endmodule
