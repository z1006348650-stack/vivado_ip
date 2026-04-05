`timescale 1ns / 1ps

module tb_icap_jump();

        reg        I_clk      ;
        reg        I_rst_n    ;
        reg        I_opt_en   ;
        wire       O_opt_done ;

        initial begin
            
            I_clk    = 1'b0;
            I_rst_n  = 1'b0;
            I_opt_en = 1'b0;

            #200
            I_rst_n  = 1'b1;

            #100
            I_opt_en = 1'b1;

        end

        icap_jump #(
             .UPDATE_BASE_ADDR(32'h0001_0000)
         ) icap_jump_inst(
        
         .       I_clk       (I_clk),
         .       I_rst_n     (I_rst_n),
         .       I_opt_en    (I_opt_en),
         .       O_opt_done  (O_opt_done)
        
         );

         always #5 I_clk = ~I_clk;

endmodule
