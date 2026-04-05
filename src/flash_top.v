`timescale 1ns / 1ps

//-------------------------------------------------------
//
//  author:¶þÀÖ
//
//------------------------------------------------------

module flash_top #(
    parameter SYS_CLK_FREQ     = 100000000  ,
    parameter FLASH_CLK_FREQ   = 100000000  ,
    parameter RD_DATA_MAX_LEN  = 4          ,
    parameter WR_DATA_MAX_LEN  = 4          ,
    parameter FLASH_ADDR_WIDTH = 32         ,
    parameter FLASH_MODEL      = 0          ,
    parameter S25_TBPARM_TOP   = 0          ,
    parameter ERASE_TIMEOUT_4K_CYCLES       = 200000000  ,
    parameter ERASE_TIMEOUT_64K_CYCLES      = 300000000  ,
    parameter POST_ERASE_STATUS_GUARD_CYCLES = 10
    )(

    input                                        I_clk_in       ,
    input                                        I_rst_n        ,

    // ---------------- from cmd_decoder ------------------ //
    input                                        I_opt_begin    ,
    input                                        I_drv_mode     ,
                                             
    input [FLASH_ADDR_WIDTH-1:0]                 I_update_addr  ,
    input [31:0]                                 I_bin_size     ,

    input                                        s_axis_tvalid  ,
    output                                       s_axis_tready  ,
    input    [((WR_DATA_MAX_LEN << 3) - 1) : 0]  s_axis_tdata   ,


    output                                       O_drv_opt_busy ,   
    output                                       O_drv_opt_ok   ,  
    output                                       O_err          ,  
    output                                       O_timeout_err  ,
    output [4:0]                                 O_last_fail_stage ,

    input                                        I_data         ,
    output                                       O_cs           ,
    output                                       O_sck          ,
    output                                       O_data         

    );


    wire                                        W_axis_tvalid     ;
    wire                                        W_axis_tready     ;
    wire [((WR_DATA_MAX_LEN << 3) - 1) : 0]     W_axis_tdata      ;
    wire                                        W_almost_empty    ;
    wire                                        W_almost_full     ;

    wire [((RD_DATA_MAX_LEN << 3)-1) : 0]       W_rd_data        ;    
    wire [((WR_DATA_MAX_LEN << 3) - 1) : 0]     W_wr_data        ; 

    wire                                        W_opt_busy       ;
    wire                                        W_opt_done       ;

    wire                                        W_drv_opt_en     ;
    wire       [3:0]                            W_mode           ;
    
    wire       [FLASH_ADDR_WIDTH-1:0]           W_wr_base_addr  ;
    wire       [FLASH_ADDR_WIDTH-1:0]           W_rd_base_addr  ;
    wire       [FLASH_ADDR_WIDTH-1:0]           W_era_base_addr ;  

    wire       [7:0]                            W_rd_cmd         ;
    wire       [7:0]                            W_rd_cmd_data    ;  




    flash_ctrl #(
        .RD_DATA_MAX_LEN    (RD_DATA_MAX_LEN)      ,
        .WR_DATA_MAX_LEN    (WR_DATA_MAX_LEN)      ,
        .FLASH_ADDR_WIDTH   (FLASH_ADDR_WIDTH)     ,
        .FLASH_MODEL        (FLASH_MODEL)          ,
        .S25_TBPARM_TOP     (S25_TBPARM_TOP)       ,
        .ERASE_TIMEOUT_4K_CYCLES       (ERASE_TIMEOUT_4K_CYCLES)       ,
        .ERASE_TIMEOUT_64K_CYCLES      (ERASE_TIMEOUT_64K_CYCLES)      ,
        .POST_ERASE_STATUS_GUARD_CYCLES(POST_ERASE_STATUS_GUARD_CYCLES)
    ) flash_ctrl_inst(

        .I_clk_in         (I_clk_in             ),
        .I_rst_n          (I_rst_n              ),
                
        .I_opt_begin      (I_opt_begin          ),           
        .I_mode           (I_drv_mode           ),           
                    
        .I_update_addr    (I_update_addr        ),         
        .I_bin_size       (I_bin_size           ),
    
        .I_rd_data        (W_rd_data            ),            
        .O_wr_data        (W_wr_data            ),    
    
        .I_opt_busy       (W_opt_busy           ),            
        .I_flash_opt_done (W_opt_done           ),            
     
        .O_opt_en         (W_drv_opt_en         ),
        .O_opt_mode       (W_mode               ),        
  
        .O_wr_addr        (W_wr_base_addr       ),
        .O_rd_addr        (W_rd_base_addr       ), 
        .O_era_addr       (W_era_base_addr      ), 
    
        .I_rd_cmd_data    (W_rd_cmd_data        ),
        .O_rd_cmd         (W_rd_cmd             ),
    
       .I_axis_tvalid     (W_axis_tvalid        ),
       .O_axis_tready     (W_axis_tready        ),
    
       .I_axis_tdata      (W_axis_tdata         ), 
       .I_almost_empty    (W_almost_empty       ),
    
       .O_drv_opt_busy    (O_drv_opt_busy       ),
       .O_drv_opt_ok      (O_drv_opt_ok         ),
       .O_err             (O_err                ),
       .O_timeout_err     (O_timeout_err        ),
       .O_last_fail_stage (O_last_fail_stage    )

    );



    flash_driver #(
            .SYS_CLK_FREQ       (SYS_CLK_FREQ)          ,
            .FLASH_CLK_FREQ     (FLASH_CLK_FREQ)        ,
            .RD_DATA_MAX_LEN    (RD_DATA_MAX_LEN)       ,
            .WR_DATA_MAX_LEN    (WR_DATA_MAX_LEN)       ,
            .FLASH_ADDR_WIDTH   (FLASH_ADDR_WIDTH)      ,
            .FLASH_MODEL        (FLASH_MODEL)
    ) flash_driver_inst(

        .I_clk_in           (I_clk_in        ),
        .I_rst_n            (I_rst_n         ),
  
        .I_mode             (W_mode          ),                        
        .I_opt_en           (W_drv_opt_en    ),                      

        .I_wr_base_addr     (W_wr_base_addr  ),                
        .I_rd_base_addr     (W_rd_base_addr  ),                
        .I_era_base_addr    (W_era_base_addr ),               

        .I_wr_cmd           (),
        .I_wr_cmd_data      (), 


        .I_wr_data          (W_wr_data      ),   
        .O_rd_data          (W_rd_data      ),
        .I_data             (I_data         ), 

        .I_rd_cmd           (W_rd_cmd       ),
        .O_rd_cmd_data      (W_rd_cmd_data  ),
                
        .O_cs               (O_cs           ),
        .O_sck              (O_sck          ),
        .O_data             (O_data         ),

        .O_opt_done         (W_opt_done     ),
        .O_opt_busy         (W_opt_busy     )

    );


    generate
        case (WR_DATA_MAX_LEN)
            4:begin
                axis_data_fifo_4bytes axis_data_fifo_4bytes_inst (

                    .s_axis_aresetn     (I_rst_n        ),    // input wire s_axis_aresetn
                    .s_axis_aclk        (I_clk_in       ),    // input wire s_axis_aclk
                   
                    .s_axis_tvalid      (s_axis_tvalid  ),    // input wire s_axis_tvalid
                    .s_axis_tready      (s_axis_tready  ),    // output wire s_axis_tready
                    .s_axis_tdata       (s_axis_tdata   ),    // input wire [31 : 0] s_axis_tdata


                    .m_axis_tvalid      (W_axis_tvalid  ),    // output wire m_axis_tvalid
                    .m_axis_tready      (W_axis_tready  ),    // input wire m_axis_tready
                    .m_axis_tdata       (W_axis_tdata   ),    // output wire [31 : 0] m_axis_tdata
                    
                    .almost_empty       (W_almost_empty ),    // output wire almost_empty
                    .almost_full        (W_almost_full  )     // output wire almost_full
                );
            end
            8:begin
                axis_data_fifo_8bytes axis_data_fifo_8bytes_inst (

                    .s_axis_aresetn     (I_rst_n        ),    // input wire s_axis_aresetn
                    .s_axis_aclk        (I_clk_in       ),    // input wire s_axis_aclk

                    .s_axis_tvalid      (s_axis_tvalid  ),    // input wire s_axis_tvalid
                    .s_axis_tready      (s_axis_tready  ),    // output wire s_axis_tready
                    .s_axis_tdata       (s_axis_tdata   ),    // input wire [31 : 0] s_axis_tdata

                    .m_axis_tvalid      (W_axis_tvalid  ),    // output wire m_axis_tvalid
                    .m_axis_tready      (W_axis_tready  ),    // input wire m_axis_tready
                    .m_axis_tdata       (W_axis_tdata   ),    // output wire [31 : 0] m_axis_tdata

                    .almost_empty       (W_almost_empty ),    // output wire almost_empty
                    .almost_full        (W_almost_full  )     // output wire almost_full
                );
            end
            16:begin
                axis_data_fifo_16bytes axis_data_fifo_16bytes_inst (

                    .s_axis_aresetn     (I_rst_n        ),    // input wire s_axis_aresetn
                    .s_axis_aclk        (I_clk_in       ),    // input wire s_axis_aclk

                    .s_axis_tvalid      (s_axis_tvalid  ),    // input wire s_axis_tvalid
                    .s_axis_tready      (s_axis_tready  ),    // output wire s_axis_tready
                    .s_axis_tdata       (s_axis_tdata   ),    // input wire [31 : 0] s_axis_tdata

                    .m_axis_tvalid      (W_axis_tvalid  ),    // output wire m_axis_tvalid
                    .m_axis_tready      (W_axis_tready  ),    // input wire m_axis_tready
                    .m_axis_tdata       (W_axis_tdata   ),    // output wire [31 : 0] m_axis_tdata

                    .almost_empty       (W_almost_empty ),    // output wire almost_empty
                    .almost_full        (W_almost_full  )     // output wire almost_full
                );
            end
            32:begin
                axis_data_fifo_32bytes axis_data_fifo_32bytes_inst (

                    .s_axis_aresetn     (I_rst_n        ),    // input wire s_axis_aresetn
                    .s_axis_aclk        (I_clk_in       ),    // input wire s_axis_aclk

                    .s_axis_tvalid      (s_axis_tvalid  ),    // input wire s_axis_tvalid
                    .s_axis_tready      (s_axis_tready  ),    // output wire s_axis_tready
                    .s_axis_tdata       (s_axis_tdata   ),    // input wire [31 : 0] s_axis_tdata

                    .m_axis_tvalid      (W_axis_tvalid  ),    // output wire m_axis_tvalid
                    .m_axis_tready      (W_axis_tready  ),    // input wire m_axis_tready
                    .m_axis_tdata       (W_axis_tdata   ),    // output wire [31 : 0] m_axis_tdata

                    .almost_empty       (W_almost_empty ),    // output wire almost_empty
                    .almost_full        (W_almost_full  )     // output wire almost_full
                );
            end
            64:begin
                axis_data_fifo_64bytes axis_data_fifo_64bytes_inst (

                    .s_axis_aresetn     (I_rst_n        ),    // input wire s_axis_aresetn
                    .s_axis_aclk        (I_clk_in       ),    // input wire s_axis_aclk

                    .s_axis_tvalid      (s_axis_tvalid  ),    // input wire s_axis_tvalid
                    .s_axis_tready      (s_axis_tready  ),    // output wire s_axis_tready
                    .s_axis_tdata       (s_axis_tdata   ),    // input wire [31 : 0] s_axis_tdata

                    .m_axis_tvalid      (W_axis_tvalid  ),    // output wire m_axis_tvalid
                    .m_axis_tready      (W_axis_tready  ),    // input wire m_axis_tready
                    .m_axis_tdata       (W_axis_tdata   ),    // output wire [31 : 0] m_axis_tdata

                    .almost_empty       (W_almost_empty ),    // output wire almost_empty
                    .almost_full        (W_almost_full  )     // output wire almost_full
                );
            end
            128:begin
                axis_data_fifo_128bytes axis_data_fifo_128bytes_inst (

                    .s_axis_aresetn     (I_rst_n        ),    // input wire s_axis_aresetn
                    .s_axis_aclk        (I_clk_in       ),    // input wire s_axis_aclk

                    .s_axis_tvalid      (s_axis_tvalid  ),    // input wire s_axis_tvalid
                    .s_axis_tready      (s_axis_tready  ),    // output wire s_axis_tready
                    .s_axis_tdata       (s_axis_tdata   ),    // input wire [31 : 0] s_axis_tdata

                    .m_axis_tvalid      (W_axis_tvalid  ),    // output wire m_axis_tvalid
                    .m_axis_tready      (W_axis_tready  ),    // input wire m_axis_tready
                    .m_axis_tdata       (W_axis_tdata   ),    // output wire [31 : 0] m_axis_tdata

                    .almost_empty       (W_almost_empty ),    // output wire almost_empty
                    .almost_full        (W_almost_full  )     // output wire almost_full
                );
            end
            256:begin
                axis_data_fifo_256bytes axis_data_fifo_256bytes_inst (

                    .s_axis_aresetn     (I_rst_n        ),    // input wire s_axis_aresetn
                    .s_axis_aclk        (I_clk_in       ),    // input wire s_axis_aclk

                    .s_axis_tvalid      (s_axis_tvalid  ),    // input wire s_axis_tvalid
                    .s_axis_tready      (s_axis_tready  ),    // output wire s_axis_tready
                    .s_axis_tdata       (s_axis_tdata   ),    // input wire [31 : 0] s_axis_tdata

                    .m_axis_tvalid      (W_axis_tvalid  ),    // output wire m_axis_tvalid
                    .m_axis_tready      (W_axis_tready  ),    // input wire m_axis_tready
                    .m_axis_tdata       (W_axis_tdata   ),    // output wire [31 : 0] m_axis_tdata

                    .almost_empty       (W_almost_empty ),    // output wire almost_empty
                    .almost_full        (W_almost_full  )     // output wire almost_full
                );
            end
            default:begin
                 axis_data_fifo_4bytes axis_data_fifo_4bytes_inst (

                    .s_axis_aresetn     (I_rst_n        ),    // input wire s_axis_aresetn
                    .s_axis_aclk        (I_clk_in       ),    // input wire s_axis_aclk

                    .s_axis_tvalid      (s_axis_tvalid  ),    // input wire s_axis_tvalid
                    .s_axis_tready      (s_axis_tready  ),    // output wire s_axis_tready
                    .s_axis_tdata       (s_axis_tdata   ),    // input wire [31 : 0] s_axis_tdata

                    .m_axis_tvalid      (W_axis_tvalid  ),    // output wire m_axis_tvalid
                    .m_axis_tready      (W_axis_tready  ),    // input wire m_axis_tready
                    .m_axis_tdata       (W_axis_tdata   ),    // output wire [31 : 0] m_axis_tdata

                    .almost_empty       (W_almost_empty ),    // output wire almost_empty
                    .almost_full        (W_almost_full  )     // output wire almost_full
                );
            end
        endcase
    endgenerate


endmodule

