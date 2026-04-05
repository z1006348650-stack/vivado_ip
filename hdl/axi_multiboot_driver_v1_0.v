
`timescale 1 ns / 1 ps

	module axi_multiboot_driver_v1_0 #
	(
		parameter integer C_S00_AXI_DATA_WIDTH	= 32		 	 	,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 5 		 	 	,
		parameter integer SYS_CLK_FREQ     		= 100000000  	,
   	parameter integer FLASH_CLK_FREQ   		= 10000000   	,
   	parameter integer RD_DATA_MAX_LEN  		= 4          	,
   	parameter integer WR_DATA_MAX_LEN  		= 4          	,
   	parameter integer FLASH_ADDR_WIDTH 		= 32         	,
   	parameter         UPDATE_BASE_ADDR     = 32'h00500000 ,
   	parameter         DEVICE_ID            = 32'h3651093   ,
   	parameter integer FPGA_FAMILY          = 0             ,
   	parameter integer MULTIBOOT_ADDR_SHIFT = 0             ,
   	parameter integer USE_STARTUP_FLASH_IO = 0             ,
   	parameter integer FLASH_MODEL          = 0             ,
   	parameter integer S25_TBPARM_TOP       = 0             ,
   	parameter integer ERASE_TIMEOUT_4K_CYCLES       = 200000000 ,
   	parameter integer ERASE_TIMEOUT_64K_CYCLES      = 300000000 ,
   	parameter integer POST_ERASE_STATUS_GUARD_CYCLES = 10
	)
	(
		// Users to add ports here

		input                                        s_axis_tvalid  ,
    	output                                       s_axis_tready  ,
    	input    [((WR_DATA_MAX_LEN << 3) - 1) : 0]  s_axis_tdata   ,


    	input                                        I_data         ,
    	input                                        I_icap_en      ,
		output                                       O_cs           ,
		//output                                       O_sck          ,
		output                                       O_data         ,       

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  											s00_axi_aclk			,
		input wire  											s00_axi_aresetn		,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] 		s00_axi_awaddr			,
		input wire [2 : 0] 									s00_axi_awprot			,
		input wire  											s00_axi_awvalid		,
		output wire  											s00_axi_awready		,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] 		s00_axi_wdata			,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0]  s00_axi_wstrb			,
		input wire  											s00_axi_wvalid 		,
		output wire  											s00_axi_wready 		,
		output wire [1 : 0] 									s00_axi_bresp 			,
		output wire  											s00_axi_bvalid  		,
		input wire  											s00_axi_bready  		,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] 		s00_axi_araddr  		,
		input wire [2 : 0] 									s00_axi_arprot  		,
		input wire  											s00_axi_arvalid  		,
		output wire  											s00_axi_arready  		,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] 		s00_axi_rdata  		,
		output wire [1 : 0] 									s00_axi_rresp  		,
		output wire  											s00_axi_rvalid  		,
		input wire  											s00_axi_rready
	);


	wire                                  W_drv_opt_busy      ;
	wire                                  W_drv_opt_ok        ;
	wire                                  W_err               ;
	wire                                  W_timeout_err       ;
	wire [4:0]                            W_last_fail_stage   ;
	wire                                  W_aux_rst_n         ;
	wire                                  W_drv_mode          ;
	wire [FLASH_ADDR_WIDTH-1:0]           W_update_addr       ;
	wire [31:0]                           W_bin_size          ;
	wire                                  W_opt_begin         ;
	wire                                  W_icap_en           ;
	wire [FLASH_ADDR_WIDTH-1:0]           W_update_base_addr  ;
	
	wire                                  W_flash_rst_n       ;
	wire                                  W_opt_done          ;
	wire                                  W_sck               ;
	wire                                  W_startup_eos       ;
	wire                                  W_spi_cs_n          ;
	wire                                  W_spi_mosi          ;
	wire                                  W_spi_miso_startup  ;
	wire                                  W_spi_miso          ;
	wire                                  W_use_startup_flash_io;
	assign  W_flash_rst_n = s00_axi_aresetn & W_aux_rst_n;
	// UltraScale + USE_STARTUP_FLASH_IO=1 时，SPI 走 STARTUPE3 专用配置引脚。
	assign  W_use_startup_flash_io = (FPGA_FAMILY == 1) && (USE_STARTUP_FLASH_IO != 0);
	// MISO 在专用引脚模式下来自 STARTUPE3(DI[1])，否则来自普通输入 I_data。
	assign  W_spi_miso = W_use_startup_flash_io ? W_spi_miso_startup : I_data;
	// 为兼容历史顶层端口，始终把内部 SPI 控制信号镜像到 O_cs/O_data。
	assign  O_cs = W_spi_cs_n;
	assign  O_data = W_spi_mosi;

	
// Instantiation of Axi Bus Interface S00_AXI
	axi_multiboot_driver_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH (C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH (C_S00_AXI_ADDR_WIDTH),
		.UPDATE_BASE_ADDR   (UPDATE_BASE_ADDR    ),
		.FLASH_ADDR_WIDTH   (FLASH_ADDR_WIDTH)
	) axi_multiboot_driver_v1_0_S00_AXI_inst (

		.I_drv_opt_busy      (W_drv_opt_busy 	),
		.I_drv_opt_ok        (W_drv_opt_ok 		),
		.I_err               (W_err            ),
		.I_timeout_err       (W_timeout_err   ),
		.I_last_fail_stage   (W_last_fail_stage),
		.I_icap_done         (W_opt_done      ),
		.O_aux_rst_n         (W_aux_rst_n 		),
		.O_drv_mode          (W_drv_mode 		),
		.O_update_addr       (W_update_addr 	),
		.O_bin_size          (W_bin_size 		),
		.O_opt_begin         (W_opt_begin 		),
		.O_icap_en           (W_icap_en 		),
		.O_update_base_addr  (W_update_base_addr),


		.S_AXI_ACLK  		   (s00_axi_aclk  	),
		.S_AXI_ARESETN  	   (s00_axi_aresetn),
		.S_AXI_AWADDR  		(s00_axi_awaddr ),
		.S_AXI_AWPROT  		(s00_axi_awprot ),
		.S_AXI_AWVALID   		(s00_axi_awvalid),
		.S_AXI_AWREADY   		(s00_axi_awready),
		.S_AXI_WDATA  			(s00_axi_wdata  ),
		.S_AXI_WSTRB  			(s00_axi_wstrb  ),
		.S_AXI_WVALID   		(s00_axi_wvalid ),
		.S_AXI_WREADY  		(s00_axi_wready ),
		.S_AXI_BRESP  			(s00_axi_bresp  ),
		.S_AXI_BVALID  		(s00_axi_bvalid ),
		.S_AXI_BREADY  		(s00_axi_bready ),
		.S_AXI_ARADDR  		(s00_axi_araddr ),
		.S_AXI_ARPROT   		(s00_axi_arprot ),
		.S_AXI_ARVALID  		(s00_axi_arvalid),
		.S_AXI_ARREADY   		(s00_axi_arready),
		.S_AXI_RDATA     		(s00_axi_rdata  ),
		.S_AXI_RRESP  			(s00_axi_rresp  ),
		.S_AXI_RVALID   		(s00_axi_rvalid ),
		.S_AXI_RREADY  		(s00_axi_rready )
	);

	// Add user logic here


    flash_top #(
    		.SYS_CLK_FREQ     (SYS_CLK_FREQ)  		,
    		.FLASH_CLK_FREQ   (FLASH_CLK_FREQ)  	,
    		.RD_DATA_MAX_LEN  (RD_DATA_MAX_LEN)  	,
    		.WR_DATA_MAX_LEN  (WR_DATA_MAX_LEN)  	,
    		.FLASH_ADDR_WIDTH (FLASH_ADDR_WIDTH)   ,
    		.FLASH_MODEL      (FLASH_MODEL)        ,
    		.S25_TBPARM_TOP   (S25_TBPARM_TOP)     ,
    		.ERASE_TIMEOUT_4K_CYCLES       (ERASE_TIMEOUT_4K_CYCLES)       ,
    		.ERASE_TIMEOUT_64K_CYCLES      (ERASE_TIMEOUT_64K_CYCLES)      ,
    		.POST_ERASE_STATUS_GUARD_CYCLES(POST_ERASE_STATUS_GUARD_CYCLES)
    ) flash_top_inst(

    	.I_clk_in       (s00_axi_aclk 		),
    	.I_rst_n        (W_flash_rst_n 		),

    // ---------------- from cmd_decoder ------------------ //
    	.I_opt_begin    (W_opt_begin 		),
    	.I_drv_mode     (W_drv_mode 		),
                                             
    	.I_update_addr  (W_update_addr 		),
    	.I_bin_size     (W_bin_size 		),

    	.s_axis_tvalid  (s_axis_tvalid 		),
    	.s_axis_tready  (s_axis_tready 		),
    	.s_axis_tdata   (s_axis_tdata 		),


    	.O_drv_opt_busy (W_drv_opt_busy 	),   
    	.O_drv_opt_ok   (W_drv_opt_ok 		),  
		.O_err          (W_err              ),
		.O_timeout_err  (W_timeout_err      ),
		.O_last_fail_stage (W_last_fail_stage),
    	 .I_data         (W_spi_miso        ),
    	 .O_cs           (W_spi_cs_n        ),
    	.O_sck          (W_sck 				),
    	 .O_data         (W_spi_mosi        )

    );


      icap_jump #(
    		.FLASH_ADDR_WIDTH         (FLASH_ADDR_WIDTH 	)       ,
    		.DEVICE_ID                (DEVICE_ID 			)              ,
    		.FPGA_FAMILY              (FPGA_FAMILY 		)            ,
    		.MULTIBOOT_ADDR_SHIFT     (MULTIBOOT_ADDR_SHIFT)
    	) icap_jump_inst(

    	.I_clk                    (s00_axi_aclk   		),             
    	.I_rst_n                  (W_flash_rst_n 		   ),             
    	.I_opt_en  			 	  	  (W_icap_en | I_icap_en),              
    	.I_update_addr  		  	  (W_update_base_addr   ),
    	.O_opt_done               (W_opt_done           )              

    );
    	
    // 启动原语统一桥接：7 系列使用 STARTUPE2，UltraScale 使用 STARTUPE3。
    startup_bridge #(
    	.FPGA_FAMILY              (FPGA_FAMILY),
    	.USE_STARTUP_FLASH_IO     (USE_STARTUP_FLASH_IO)
    ) startup_bridge_inst (
    	.I_usr_cclk               (W_sck),
    	.I_spi_cs_n               (W_spi_cs_n),
    	.I_spi_mosi               (W_spi_mosi),
    	.O_spi_miso               (W_spi_miso_startup),
    	.O_eos                    (W_startup_eos)
    );

 

endmodule






