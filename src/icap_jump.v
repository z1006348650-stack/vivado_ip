`timescale 1ns / 1ps

//-------------------------------------------------------
//
//  author:二乐
//
//------------------------------------------------------

module icap_jump #(
     parameter integer FLASH_ADDR_WIDTH         = 32           ,
     parameter         DEVICE_ID                = 32'h3651093  ,
     parameter integer FPGA_FAMILY              = 0            ,
     parameter integer MULTIBOOT_ADDR_SHIFT     = 0
    )(

    input                               I_clk,                 //       时钟输入
    input                               I_rst_n,               //       复位输入
    input                               I_opt_en,              //       使能输入
    input [FLASH_ADDR_WIDTH-1:0]        I_update_addr,
    output                              O_opt_done             //       操作结束标志

    );


    reg         R_en       ;
    reg         R_rw       ;

    wire [31:0] W_cmd_data;
    reg  [2:0]  R_sta;
    reg  [1:0]  R_opt_en;
    reg  [3:0]  R_cnt;
    reg         R_opt_done;
    wire [31:0] W_cmd_data_temp;
    wire [31:0] W_wbstar_addr;


    wire       W_opt_en_pos;

    // FPGA 系列选择：0-7Series，1-UltraScale/UltraScale+
    localparam FPGA_FAMILY_7SERIES    = 0;
    localparam FPGA_FAMILY_ULTRASCALE = 1;


    //---------------------- IPROG SET PARAMETER --------------------------- //

    localparam WR_WORD0 = 32'hFFFF_FFFF;        // Dummy Word
    localparam WR_WORD1 = 32'hAA99_5566;        // Sync Word
    localparam WR_WORD2 = 32'h2000_0000;
    localparam WR_WORD3 = 32'h3002_0001;
    localparam WR_WORD5 = 32'h3000_8001;
    localparam WR_WORD6 = 32'h0000_000F;        // IPROG Cmd
    localparam WR_WORD7 = 32'h2000_0000;




    //--------------------------------------------------------------------- //


    localparam IDLE    = 3'b000;
    localparam WRITE   = 3'b001;
    localparam OPT_END = 3'b010;

    assign W_opt_en_pos = R_opt_en[0] & ~R_opt_en[1];
    assign O_opt_done   = R_opt_done;


    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            R_opt_en <= 2'b00;
        else
            R_opt_en <= {R_opt_en[0], I_opt_en};
    end



    // WBSTAR 统一地址换算：上层传字节地址，这里通过右移适配不同器件编码
    assign W_wbstar_addr = I_update_addr >> MULTIBOOT_ADDR_SHIFT;

    // --------------------------- DATA SWAP ------------------------------------------------------- //

    assign W_cmd_data_temp = (R_cnt == 4'd0) ? WR_WORD0 : (R_cnt == 4'd1) ? WR_WORD1 :
                             (R_cnt == 4'd2) ? WR_WORD2 : (R_cnt == 4'd3) ? WR_WORD3 :
                             (R_cnt == 4'd4) ? W_wbstar_addr : (R_cnt == 4'd5) ? WR_WORD5 :
                             (R_cnt == 4'd6) ? WR_WORD6 : (R_cnt == 4'd7) ? WR_WORD7 : WR_WORD7;

    assign W_cmd_data = {W_cmd_data_temp[24],W_cmd_data_temp[25],W_cmd_data_temp[26],W_cmd_data_temp[27],W_cmd_data_temp[28],W_cmd_data_temp[29],W_cmd_data_temp[30],W_cmd_data_temp[31]  ,
                            W_cmd_data_temp[16],W_cmd_data_temp[17],W_cmd_data_temp[18],W_cmd_data_temp[19],W_cmd_data_temp[20],W_cmd_data_temp[21],W_cmd_data_temp[22],W_cmd_data_temp[23] ,
                            W_cmd_data_temp[8],W_cmd_data_temp[9],W_cmd_data_temp[10],W_cmd_data_temp[11],W_cmd_data_temp[12],W_cmd_data_temp[13],W_cmd_data_temp[14],W_cmd_data_temp[15]  ,
                            W_cmd_data_temp[0],W_cmd_data_temp[1],W_cmd_data_temp[2],W_cmd_data_temp[3],W_cmd_data_temp[4],W_cmd_data_temp[5],W_cmd_data_temp[6],W_cmd_data_temp[7]};


    always @(negedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_sta <= IDLE;
            R_rw  <= 1'b0;
            R_en  <= 1'b1;
            R_cnt <= 4'd0;
            R_opt_done <= 1'b0;
        end
        else begin
            case (R_sta)
                IDLE:begin
                    if (W_opt_en_pos) begin
                        R_en  <= 1'b0;
                        R_sta <= WRITE;
                    end
                    else begin
                        R_sta <= IDLE;
                        R_opt_done <= 1'b0;
                    end
                end
                WRITE:begin
                    if (R_cnt <= 4'd6) begin
                        R_cnt <= R_cnt + 1'b1;
                    end
                    else begin
                        R_sta <= OPT_END;
                        R_en  <= 1'b1;
                        R_opt_done <= 1'b1;
                        R_cnt <= 4'd0;
                    end
                end
                OPT_END:begin
                    R_opt_done <= 1'b0;
                    R_sta <= IDLE;
                end
            endcase
        end
    end


    // ICAP 原语按系列选择，保持同一套上层接口
    generate
        if (FPGA_FAMILY == FPGA_FAMILY_7SERIES) begin : GEN_ICAPE2
            ICAPE2 #(
              .DEVICE_ID(DEVICE_ID),
              .ICAP_WIDTH("X32"),
              .SIM_CFG_FILE_NAME("NONE")
           )
           ICAPE2_inst (
              .O(),
              .CLK(I_clk),
              .CSIB(R_en),
              .I(W_cmd_data),
              .RDWRB(R_rw)
           );
        end
        else begin : GEN_ICAPE3
            ICAPE3 #(
              .DEVICE_ID(DEVICE_ID),
              .ICAP_AUTO_SWITCH("DISABLE"),
              .SIM_CFG_FILE_NAME("NONE")
           )
           ICAPE3_inst (
              .AVAIL(),
              .O(),
              .PRDONE(),
              .PRERROR(),
              .CLK(I_clk),
              .CSIB(R_en),
              .I(W_cmd_data),
              .RDWRB(R_rw)
           );
        end
    endgenerate


endmodule