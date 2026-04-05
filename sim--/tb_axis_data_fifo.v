`timescale 1ns / 1ps

module tb_axis_data_fifo();

    localparam DATA_LEN = 4;

    localparam IDLE     = 3'b000;
    localparam WRITE    = 3'b001;
    localparam READ     = 3'b010;
    localparam END      = 3'b100;


    reg                                     s_axis_aresetn              ;
    reg                                     s_axis_aclk                 ;
                                    
    reg                                     s_axis_tvalid               ;
    wire                                    s_axis_tready               ;
    reg   [((DATA_LEN << 3) - 1) : 0]       s_axis_tdata                ;                 // 256Bytes
            
    wire                                    m_axis_tvalid               ;
    reg                                     m_axis_tready               ;
    wire  [((DATA_LEN << 3) - 1) : 0]       m_axis_tdata                ;
            
    wire                                    almost_empty                ;
    wire                                    prog_empty                  ;
    wire                                    almost_full                 ;
    wire                                    prog_full                   ;
                        
    wire [31 : 0]                           axis_wr_data_count          ;
    wire [31 : 0]                           axis_rd_data_count          ;
                        
                        
    wire                                    s_axis_tlast                ;
    wire                                    m_axis_tlast                ;




    reg [2:0] sta;

    initial begin

        s_axis_aclk = 1'b0;
        s_axis_aresetn = 1'b0;

        #200
        s_axis_aresetn = 1'b1;

    end




    always @(posedge s_axis_aclk or negedge s_axis_aresetn) begin
        if (!s_axis_aresetn) begin
            sta <= IDLE;
            s_axis_tvalid <= 1'b0;
            s_axis_tdata  <= 'd0;
        end
        else begin
            case (sta)
                IDLE:begin
                    s_axis_tvalid <= 1'b1;
                    if (s_axis_tvalid & s_axis_tready) begin
                        sta <= WRITE;
                        s_axis_tdata <= s_axis_tdata + 1'b1;
                    end
                    else begin
                        sta <= sta;
                    end
                end
                WRITE:begin
                    if (s_axis_tvalid & s_axis_tready) 
                        s_axis_tdata <= s_axis_tdata + 1'b1;
                    else 
                        sta <= READ;
                end
                READ:begin
                    s_axis_tvalid <= 1'b0;
                    m_axis_tready <= 1'b1;
                end
            endcase
        end

    end



    axis_data_fifo_0 axis_data_fifo_0_inst (

        .s_axis_aresetn     (s_axis_aresetn        ),     // input wire s_axis_aresetn
        .s_axis_aclk        (s_axis_aclk           ),     // input wire s_axis_aclk
            
        .s_axis_tvalid      (s_axis_tvalid         ),      // input  wire s_axis_tvalid
        .s_axis_tready      (s_axis_tready         ),      // output wire s_axis_tready
        .s_axis_tdata       (s_axis_tdata          ),      // input  wire [7 : 0] s_axis_tdata
        .s_axis_tlast       (s_axis_tlast          ),      // input wire s_axis_tlast
           
           
        .m_axis_tvalid      (m_axis_tvalid         ),      // output wire m_axis_tvalid
        .m_axis_tready      (m_axis_tready         ),      // input wire m_axis_tready
        .m_axis_tdata       (m_axis_tdata          ),      // output wire [7 : 0] m_axis_tdata
        .m_axis_tlast       (m_axis_tlast          ),      // output wire m_axis_tlast

        .axis_wr_data_count (axis_wr_data_count    ),      // output wire [31 : 0] axis_wr_data_count
        .axis_rd_data_count (axis_rd_data_count    ),      // output wire [31 : 0] axis_rd_data_count

        .almost_empty       (almost_empty          ),      // output wire almost_empty
        .prog_empty         (prog_empty            ),      // output wire prog_e
        .almost_full        (almost_full           ),      // output wire almost_full
        .prog_full          (prog_full             )       // output wire prog_full

    );

    always #5 s_axis_aclk = ~s_axis_aclk;

   
endmodule
