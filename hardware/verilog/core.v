module core #(
    parameter bw = 4,
    parameter psum_bw = 16,
    parameter col = 8,
    parameter row = 8
) (
    input                       clk,
    input                       reset,
    input   [bw*row-1:0]        D_xmem,
    input   [33:0]              inst,
    output                      ofifo_valid,
    output                      l0_ready,
    output                      ififo_ready,
    output  [psum_bw*col-1:0]   sfp_out
);
wire [31:0] Q1;
wire [psum_bw * col - 1:0] Q2;//testing
corelet #(
) corelet_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .coreletIn(Q1),
    .psumIn(Q2),//testing
    .sfpIn(sfp_out),
    .sfpOut(sfp_out)
);
sram_32b_w2048 #(
) sram_xmem (
    .CLK(clk),
    .D(D_xmem),
    .A(inst[17:7]),
    .CEN(inst[19]),
    .WEN(inst[18]),
    .Q(Q1)
);
endmodule