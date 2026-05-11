`timescale 1ns / 1ps

//-------------------------------------------------------
//
//  author: 浜屼箰
//
//------------------------------------------------------

module startup_bridge #(
    parameter integer FPGA_FAMILY          = 0,
    parameter integer USE_STARTUP_FLASH_IO = 0
)(
    input  I_usr_cclk,   
    input  I_spi_cs_n,   
    input  [3:0] I_spi_dq_o,
    input  [3:0] I_spi_dq_oe,
    output [3:0] O_spi_dq_i,
    output O_spi_miso,   
    output O_eos         
    );

    localparam FPGA_FAMILY_7SERIES = 0;

    wire [3:0] W_di;
    wire [3:0] W_do;
    wire [3:0] W_dts;
    wire       W_fcsbo;
    wire       W_fcsbts;
    wire       W_eos;

    assign O_eos = W_eos;

    // STARTUPE3 DO/DTS map QSPI DQ[3:0]; DTS=0 drives, DTS=1 tri-states.
    assign W_do     = I_spi_dq_o;
    assign W_dts    = (USE_STARTUP_FLASH_IO != 0) ? ~I_spi_dq_oe : 4'b1111;
    assign W_fcsbo  = (USE_STARTUP_FLASH_IO != 0) ? I_spi_cs_n : 1'b1;
    assign W_fcsbts = (USE_STARTUP_FLASH_IO != 0) ? 1'b0 : 1'b1;

    generate
        if (FPGA_FAMILY == FPGA_FAMILY_7SERIES) begin : GEN_STARTUPE2
            
            assign O_spi_dq_i = 4'b0000;
            assign O_spi_miso = 1'b0;
            STARTUPE2 #(
                 .PROG_USR("FALSE"),
                 .SIM_CCLK_FREQ(0.0)
            )
            STARTUPE2_inst (
                 .CFGCLK(),
                 .CFGMCLK(),
                 .EOS(W_eos),
                 .PREQ(),
                 .CLK(1'b0),
                 .GSR(1'b0),
                 .GTS(1'b0),
                 .KEYCLEARB(1'b1),
                 .PACK(1'b1),
                 .USRCCLKO(I_usr_cclk),
                 .USRCCLKTS(1'b0),
                 .USRDONEO(1'b1),
                 .USRDONETS(1'b1)
            );
        end
        else begin : GEN_STARTUPE3
            
            assign O_spi_dq_i = (USE_STARTUP_FLASH_IO != 0) ? W_di : 4'b0000;
            assign O_spi_miso = (USE_STARTUP_FLASH_IO != 0) ? W_di[1] : 1'b0;
            STARTUPE3 #(
                 .PROG_USR("FALSE")
            )
            STARTUPE3_inst (
                 .CFGCLK(),
                 .CFGMCLK(),
                 .DI(W_di),
                 .EOS(W_eos),
                 .PREQ(),
                 .DO(W_do),
                 .DTS(W_dts),
                 .FCSBO(W_fcsbo),
                 .FCSBTS(W_fcsbts),
                 //.CLK(1'b0),
                 .GSR(1'b0),
                 .GTS(1'b0),
                 .KEYCLEARB(1'b1),
                 .PACK(1'b1),
                 .USRCCLKO(I_usr_cclk),
                 .USRCCLKTS(1'b0),
                 .USRDONEO(1'b1),
                 .USRDONETS(1'b1)
            );
        end
    endgenerate

endmodule
