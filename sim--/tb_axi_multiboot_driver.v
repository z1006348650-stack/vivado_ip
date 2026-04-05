`timescale 1ns / 1ps


module tb_axi_multiboot_driver();


    localparam C_S00_AXI_DATA_WIDTH  = 32          ;
    localparam C_S00_AXI_ADDR_WIDTH  = 5           ;
    localparam SYS_CLK_FREQ          = 100000000   ;
    localparam FLASH_CLK_FREQ        = 10000000    ;
    localparam RD_DATA_MAX_LEN       = 32          ;
    localparam WR_DATA_MAX_LEN       = 32          ;
    localparam FLASH_ADDR_WIDTH      = 32          ;
    parameter         UPDATE_BASE_ADDR     = 32'h00500000 ;
    localparam DEVICE_ID             = 32'h3651093 ;


    reg                                        s_axis_tvalid  ;
    wire                                       s_axis_tready  ;
    reg    [((WR_DATA_MAX_LEN << 3) - 1) : 0]  s_axis_tdata   ;
    reg                                        I_data         ;
    wire                                       O_cs           ;
    wire                                       O_sck          ;
    wire                                       O_data         ;
    reg                                        I_icap_en      ;


    reg                                  s00_axi_aclk    ;
    reg                                  s00_axi_aresetn ;

    reg [C_S00_AXI_ADDR_WIDTH-1 : 0]     s00_axi_awaddr  ;
    reg [2 : 0]                          s00_axi_awprot  = 3'b000;
    reg                                  s00_axi_awvalid ;
    wire                                 s00_axi_awready ;

    reg [C_S00_AXI_DATA_WIDTH-1 : 0]     s00_axi_wdata   ;
    reg [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb   = 4'b1111;
    reg                                  s00_axi_wvalid  ;
    wire                                 s00_axi_wready  ;

    wire [1 : 0]                         s00_axi_bresp   ;
    wire                                 s00_axi_bvalid  ;
    reg                                  s00_axi_bready  ;

    reg [C_S00_AXI_ADDR_WIDTH-1 : 0]     s00_axi_araddr  ;
    reg [2 : 0]                          s00_axi_arprot  = 3'b001;
    reg                                  s00_axi_arvalid ;
    wire                                 s00_axi_arready ;

    wire [C_S00_AXI_DATA_WIDTH-1 : 0]    s00_axi_rdata   ;
    wire [1 : 0]                         s00_axi_rresp   ;
    wire                                 s00_axi_rvalid  ;
    reg                                  s00_axi_rready  ;

    reg [31:0]                           read_data       ;

    task WriteReg;
        input [31:0] addr;
        input [31:0]  data;
    begin
        s00_axi_awaddr  <= addr;
        s00_axi_awvalid <= 1'b1;
        s00_axi_wvalid  <= 1'b1;
        s00_axi_wdata   <= data;
        s00_axi_bready  <= 1'b0;
        #20;
        s00_axi_awvalid <= 1'b0;
        s00_axi_wvalid  <= 1'b0;
        s00_axi_bready  <= 1'b1;  
        #40;
    end
   endtask
    

    task ReadReg;
        input      [31:0] addr;
        output reg [31:0] data;
    begin
        s00_axi_araddr  <= addr;
        s00_axi_arvalid <= 1'b1;
        #20;
        s00_axi_arvalid <= 1'b0;
        s00_axi_rready  <= 1'b1;
        data            <= s00_axi_rdata;
        #20;
        s00_axi_rready  <= 1'b0;
        #40;      
    end
    endtask


    task FlashCtrl;
        input [31:0] update_addr;
        input [31:0] bin_size;
        input        mode;
    begin
        WriteReg(32'h00000008, update_addr);
        #40
        WriteReg(32'h0000000C, bin_size);
        #40
        if (mode == 0)
            WriteReg(32'h00000010, 32'h00000000);
        else 
            WriteReg(32'h00000010, 32'h00000001);
        #40
        WriteReg(32'h00000000, 32'h00000000);
        #40
        WriteReg(32'h00000000, 32'h00004001);
    end
    endtask

    task FlashRstn;
    begin
        WriteReg(32'h00000000, 32'h00000000);
        WriteReg(32'h00000000, 32'h00002001);
    end
    endtask


    task IcapJump;
        input [31:0] update_addr;
    begin
        WriteReg(32'h00000008, update_addr);
        WriteReg(32'h00000000, 32'h00000000);
        WriteReg(32'h00000000, 32'h00008001);
    end
    endtask


    initial begin

        s00_axi_aclk = 1'b0;
        s00_axi_aresetn = 1'b0;
        I_icap_en       = 1'b0;

        #200
        s00_axi_aresetn = 1'b1;
        
        #200
        //WriteReg(32'h00000008, 32'h12345678);

        #200
        //ReadReg(32'h00000004, read_data);

        #1000
        IcapJump(32'h00b00000);

        #10000

        #10000
        FlashCtrl(32'h00A00000, 32'h00011010, 1);

        wait (axi_multiboot_driver_v1_0_inst.flash_top_inst.flash_ctrl_inst.R_drv_opt_ok || axi_multiboot_driver_v1_0_inst.flash_top_inst.flash_ctrl_inst.R_err)
            ReadReg(32'h00000004, read_data);
        #400
        FlashRstn();

    end

    always @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
        if (!s00_axi_aresetn)
            I_data <= 1'b0;
        else begin
            if (axi_multiboot_driver_v1_0_inst.flash_top_inst.flash_ctrl_inst.cur_state == axi_multiboot_driver_v1_0_inst.flash_top_inst.flash_ctrl_inst.ERASE_CHECK_RD) begin
                I_data   <= 1'b1; 
            end
            else if (axi_multiboot_driver_v1_0_inst.flash_top_inst.flash_ctrl_inst.cur_state == axi_multiboot_driver_v1_0_inst.flash_top_inst.flash_ctrl_inst.RD_WRITE_STATUS) begin
                I_data   <= 1'b0;      
            end
            else if (axi_multiboot_driver_v1_0_inst.flash_top_inst.flash_ctrl_inst.cur_state == axi_multiboot_driver_v1_0_inst.flash_top_inst.flash_ctrl_inst.WRITE_CHECK_RD) begin  // write check
                I_data  <= 1'b1;
            end
            else begin
                I_data <= 1'b0;
            end
        end
    end



    axi_multiboot_driver_v1_0 #
    (
            .C_S00_AXI_DATA_WIDTH  (C_S00_AXI_DATA_WIDTH ) ,
            .C_S00_AXI_ADDR_WIDTH  (C_S00_AXI_ADDR_WIDTH ) ,
            .SYS_CLK_FREQ          (SYS_CLK_FREQ         ) ,
            .FLASH_CLK_FREQ        (FLASH_CLK_FREQ       ) ,
            .RD_DATA_MAX_LEN       (RD_DATA_MAX_LEN      ) ,
            .WR_DATA_MAX_LEN       (WR_DATA_MAX_LEN      ) ,
            .FLASH_ADDR_WIDTH      (FLASH_ADDR_WIDTH     ) ,
            .UPDATE_BASE_ADDR      (UPDATE_BASE_ADDR     ) ,
            .DEVICE_ID             (DEVICE_ID            ) 
    )   axi_multiboot_driver_v1_0_inst(
        // Users to add ports here

        . s_axis_tvalid  (s_axis_tvalid),
        . s_axis_tready  (s_axis_tready),
        . s_axis_tdata   (s_axis_tdata ),

        . I_data         (I_data ),
        . O_cs           (O_cs   ),
        . I_icap_en      (I_icap_en),
        //. O_sck          (O_sck  ),
        . O_data         (O_data ),       

        // User ports ends
        // Do not modify the ports beyond this line


        // Ports of Axi Slave Bus Interface S00_AXI
         .s00_axi_aclk    (s00_axi_aclk),
         .s00_axi_aresetn (s00_axi_aresetn),

         .s00_axi_awaddr  (s00_axi_awaddr ),
         .s00_axi_awprot  (s00_axi_awprot ),
         .s00_axi_awvalid (s00_axi_awvalid),
         .s00_axi_awready (s00_axi_awready),
         .s00_axi_wdata   (s00_axi_wdata  ),
         .s00_axi_wstrb   (s00_axi_wstrb  ),
         .s00_axi_wvalid  (s00_axi_wvalid ),
         .s00_axi_wready  (s00_axi_wready ),
         .s00_axi_bresp   (s00_axi_bresp  ),
         .s00_axi_bvalid  (s00_axi_bvalid ),
         .s00_axi_bready  (s00_axi_bready ),
         .s00_axi_araddr  (s00_axi_araddr ),
         .s00_axi_arprot  (s00_axi_arprot ),
         .s00_axi_arvalid (s00_axi_arvalid),
         .s00_axi_arready (s00_axi_arready),
         .s00_axi_rdata   (s00_axi_rdata  ),
         .s00_axi_rresp   (s00_axi_rresp  ),
         .s00_axi_rvalid  (s00_axi_rvalid ),
         .s00_axi_rready  (s00_axi_rready )
    );


    localparam IDLE  = 2'b00;
    localparam WRITE = 2'b01;

    reg [1:0] state;

    always @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
        if (!s00_axi_aresetn) begin
            state        <= IDLE;
            if (WR_DATA_MAX_LEN == 4)
                s_axis_tdata <= 32'hFFFF_FFFF;
            else if (WR_DATA_MAX_LEN == 8)
                s_axis_tdata <= 64'hFFFF_FFFF_FFFF_FFFF;
            else if (WR_DATA_MAX_LEN == 16)
                s_axis_tdata <= 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
            else if (WR_DATA_MAX_LEN == 32)
                s_axis_tdata <= 256'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
            else if (WR_DATA_MAX_LEN == 64)
                s_axis_tdata <= 512'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
            else if (WR_DATA_MAX_LEN == 128)
                s_axis_tdata <= 1024'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
            else 
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
                    if (axi_multiboot_driver_v1_0_inst.flash_top_inst.W_almost_full) begin
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

    always #5 s00_axi_aclk = ~s00_axi_aclk;

endmodule
