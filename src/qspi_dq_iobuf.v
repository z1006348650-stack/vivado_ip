`timescale 1ns / 1ps

module qspi_dq_iobuf(
    input        I_disable,
    input  [3:0] I_dq_o,
    input  [3:0] I_dq_oe,
    inout  [3:0] IO_dq,
    output [3:0] O_dq_i
);

genvar g_idx;
generate
    for (g_idx = 0; g_idx < 4; g_idx = g_idx + 1) begin : GEN_DQ_IOBUF
`ifdef SYNTHESIS
        IOBUF iobuf_inst (
            .I (I_dq_o[g_idx]),
            .O (O_dq_i[g_idx]),
            .T (I_disable || ~I_dq_oe[g_idx]),
            .IO(IO_dq[g_idx])
        );
`else
        assign IO_dq[g_idx] = (I_disable || ~I_dq_oe[g_idx]) ? 1'bz : I_dq_o[g_idx];
        assign O_dq_i[g_idx] = IO_dq[g_idx];
`endif
    end
endgenerate

endmodule
