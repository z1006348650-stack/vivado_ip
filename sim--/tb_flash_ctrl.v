`timescale 1ns / 1ps

module tb_flash_ctrl();


    localparam SYS_CLK_FREQ     = 100000000;
    localparam FLASH_CLK_FREQ   = 10000000;
    localparam RD_DATA_MAX_LEN  = 4;
    localparam WR_DATA_MAX_LEN  = 4;
    localparam FLASH_ADDR_WIDTH = 32;




    // ----------------- flash driver ------------------- //

    reg                                         I_clk_in        ;
    reg                                         I_rst_n         ;
    wire       [3:0]                            I_mode          ;
    wire                                        I_opt_en        ;
    wire       [FLASH_ADDR_WIDTH-1:0]           I_wr_base_addr  ;
    wire       [FLASH_ADDR_WIDTH-1:0]           I_rd_base_addr  ;
    wire       [FLASH_ADDR_WIDTH-1:0]           I_era_base_addr ; 
    reg                                         I_data          ;
    wire       [((WR_DATA_MAX_LEN << 3) - 1):0] I_wr_data       ;
               
    wire                                        O_cs            ;
    wire                                        O_sck           ;
    wire                                        O_data          ;
    wire      [((RD_DATA_MAX_LEN << 3)-1):0]    O_rd_data       ;

    reg       [7:0]                             I_wr_cmd        ;
    reg       [7:0]                             I_wr_cmd_data   ; 

    wire      [7:0]                             I_rd_cmd         ;
    wire      [7:0]                             O_rd_cmd_data    ;
    wire                                        O_opt_done       ;
    wire                                        O_opt_busy       ;


    // ------------------ flash ctrl ----------------------- //

                          
    reg                                         I_opt_begin      ;    
    reg                                         I_ctrl_mode      ;    
                                        
    reg [FLASH_ADDR_WIDTH-1:0]                  I_update_addr    ;    
    reg [31:0]                                  I_bin_size       ;    
    wire [((RD_DATA_MAX_LEN << 3)-1):0]         I_rd_data        ;    
    wire [((WR_DATA_MAX_LEN << 3) - 1) : 0]     O_wr_data        ;    


    wire                                        W_axis_tvalid    ;
    wire                                        W_axis_tready    ;
    wire  [((WR_DATA_MAX_LEN << 3) - 1) : 0]    W_axis_tdata     ; 
    wire                                        W_almost_empty   ;
    wire                                        W_almost_full    ;
    wire  [31 : 0]                              axis_wr_data_count;
    reg                                         s_axis_tvalid     ;
    wire                                        s_axis_tready     ;
    reg  [((WR_DATA_MAX_LEN << 3) - 1) : 0]     s_axis_tdata      ;
    wire                                        s_axis_tlast      ;
    wire                                        W_drv_opt_busy    ;
    wire                                        W_drv_opt_ok      ;
    wire                                        W_err             ;
         
    task flash_ctrl_begin;
        input [FLASH_ADDR_WIDTH-1:0] update_addr ;
        input [FLASH_ADDR_WIDTH-1:0] bin_size    ;
    begin
        I_update_addr = update_addr              ;
        I_bin_size    = bin_size                 ;
        I_opt_begin   = 1'b0                     ;
        I_ctrl_mode   = 1'b1                     ;

        #200
        I_opt_begin   = 1'b1                     ;

    end
    endtask
                  
    initial begin
        
       I_clk_in = 1'b0;
       I_rst_n  = 1'b0;
       #200
       I_rst_n  = 1'b1;

       #1000
       flash_ctrl_begin(32'h00b0_0000, 32'h0000010);
    end



    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n)
            I_data <= 1'b0;
        else begin
            if (flash_ctrl_inst.cur_state == flash_ctrl_inst.ERASE_CHECK_RD) begin
                I_data   <= 1'b1; 
            end
            else if (flash_ctrl_inst.cur_state == flash_ctrl_inst.RD_WRITE_STATUS) begin
                I_data   <= 1'b0;      
            end
            else if (flash_ctrl_inst.cur_state == flash_ctrl_inst.WRITE_CHECK_RD) begin
                I_data  <= 1'b1;
            end
            else begin
                I_data <= 1'b0;
            end
        end
    end


    axis_data_fifo_0 axis_data_fifo_4bytes (

        .s_axis_aresetn     (I_rst_n            ),         // input wire s_axis_aresetn
        .s_axis_aclk        (I_clk_in           ),         // input wire s_axis_aclk
            
        .s_axis_tvalid      (s_axis_tvalid         ),      // input  wire s_axis_tvalid
        .s_axis_tready      (s_axis_tready         ),      // output wire s_axis_tready
        .s_axis_tdata       (s_axis_tdata          ),      // input  wire [7 : 0] s_axis_tdata
        .s_axis_tlast       (s_axis_tlast          ),      // input wire s_axis_tlast
           
           
        .m_axis_tvalid      (W_axis_tvalid         ),      // output wire m_axis_tvalid
        .m_axis_tready      (W_axis_tready         ),      // input wire m_axis_tready
        .m_axis_tdata       (W_axis_tdata          ),      // output wire [7 : 0] m_axis_tdata
        .m_axis_tlast       (          ),                  // output wire m_axis_tlast

        .axis_wr_data_count (axis_wr_data_count    ),      // output wire [31 : 0] axis_wr_data_count
        .axis_rd_data_count (),                            // output wire [31 : 0] axis_rd_data_count

        .almost_empty       (W_almost_empty        ),      // output wire almost_empty
        .prog_empty         (),                            // output wire prog_e
        .almost_full        (W_almost_full),                            // output wire almost_full
        .prog_full          ()                             // output wire prog_full

    );


    localparam IDLE  = 2'b00;
    localparam WRITE = 2'b01;

    reg [1:0] state;

    always @(posedge I_clk_in or negedge I_rst_n) begin
        if (!I_rst_n) begin
             state        <= IDLE;
             s_axis_tdata <= 32'hFFFF_FFFF;
        end
        else begin
            case (state)
                IDLE:begin
                    s_axis_tvalid <= 1'b1;
                    if (s_axis_tvalid & s_axis_tready) begin
                        state <= WRITE;
                        s_axis_tdata <= s_axis_tdata;
                    end
                    else begin
                        state <= state;
                    end
                end
                WRITE:begin
                    if (W_almost_full) begin
                        s_axis_tvalid <= 1'b0;
                    end
                    else begin
                        if (s_axis_tvalid & s_axis_tready) 
                            s_axis_tdata <= s_axis_tdata; 
                        else
                            s_axis_tdata <= s_axis_tdata; 
                    end                 
                end
            endcase
        end
    end


    flash_ctrl #(
        .RD_DATA_MAX_LEN    (RD_DATA_MAX_LEN)      ,
        .WR_DATA_MAX_LEN    (WR_DATA_MAX_LEN)      ,
        .FLASH_ADDR_WIDTH   (FLASH_ADDR_WIDTH)
    ) flash_ctrl_inst(

        .I_clk_in         (I_clk_in         ),
        .I_rst_n          (I_rst_n          ),
            
        .I_opt_begin      (I_opt_begin      ),           
        .I_mode           (I_ctrl_mode      ),           
                
        .I_update_addr    (I_update_addr    ),         
        .I_bin_size       (I_bin_size       ),   
        .I_rd_data        (I_rd_data        ),            
        .O_wr_data        (I_wr_data        ),    

        .I_opt_busy       (O_opt_busy       ),            
        .I_flash_opt_done (O_opt_done       ),            
     
        .O_opt_en         (I_opt_en         ),
        .O_opt_mode       (I_mode           ),        
  
        .O_wr_addr        (I_wr_base_addr   ),
        .O_rd_addr        (I_rd_base_addr   ), 
        .O_era_addr       (I_era_base_addr  ), 
   
        .I_rd_cmd_data    (O_rd_cmd_data    ),
        .O_rd_cmd         (I_rd_cmd         ),

       .I_axis_tvalid     (W_axis_tvalid    ),
       .O_axis_tready     (W_axis_tready    ),
 
       .I_axis_tdata      (W_axis_tdata     ), 
       .I_almost_empty    (W_almost_empty   ),

       .O_drv_opt_busy    (W_drv_opt_busy   ),
       .O_drv_opt_ok      (W_drv_opt_ok     ),
       .O_err             (W_err            )

    );



    flash_driver #(
            .SYS_CLK_FREQ       (SYS_CLK_FREQ)          ,
            .FLASH_CLK_FREQ     (FLASH_CLK_FREQ)        ,
            .RD_DATA_MAX_LEN    (RD_DATA_MAX_LEN)       ,
            .WR_DATA_MAX_LEN    (WR_DATA_MAX_LEN)       ,
            .FLASH_ADDR_WIDTH   (FLASH_ADDR_WIDTH)  
    ) flash_driver_inst(

        .I_clk_in           (I_clk_in),
        .I_rst_n            (I_rst_n),
 
        .I_mode             (I_mode),                        
        .I_opt_en           (I_opt_en),                      

        .I_wr_base_addr     (I_wr_base_addr),                
        .I_rd_base_addr     (I_rd_base_addr),                
        .I_era_base_addr    (I_era_base_addr),               

        .I_wr_cmd           (I_wr_cmd),
        .I_wr_cmd_data      (I_wr_cmd_data), 


        .I_wr_data          (I_wr_data)   ,   
        .O_rd_data          (I_rd_data)   ,
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
