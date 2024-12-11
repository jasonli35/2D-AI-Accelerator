module core #(
    parameter row = 8,
    parameter col = 8,
    parameter psum_bw = 16,
    parameter bw = 4,
    parameter num = 2048
)(
    input clk,
    input reset, 
    input [33:0] inst,
    input [bw*row-1:0] D_xmem,
    output valid,
    output [psum_bw*col-1:0] coreOut
);

wire [psum_bw*col-1:0] ofifoOut;

// Signals for IFIFO
wire ififo_rd, ififo_wr;
wire [bw*row-1:0] ififo_out;
wire ififo_full, ififo_empty;

assign ififo_rd = inst[4];
assign ififo_wr = inst[5];

// Instantiate IFIFO
ififo #(.col(row), .bw(bw)) ififo_instance (
    .clk(clk),
    .in(D_xmem),
    .out(ififo_out),
    .rd(ififo_rd),
    .wr(ififo_wr),
    .reset(reset),
    .o_full(ififo_full),
    .o_empty(ififo_empty)
);

wire xMemWEN;
wire xMemCEN;
wire [10:0]xMemAddress;
wire [bw*row-1:0] xMemOut;

assign xMemCEN = inst[19];
assign xMemWEN = inst[18];
assign xMemAddress = inst[17:7];

wire psumMemWEN;
wire psumMemCEN;
wire [psum_bw*col-1:0] psumMemOut;
wire [10:0] psumMemAddress;

assign psumMemWEN = inst[31];
assign psumMemCEN = inst[32];
assign psumMemAddress = inst[30:20];

//Instantiate corelet
corelet #(.row(row), .col(col), .psum_bw(psum_bw), .bw(bw)) corelet (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .coreletIn(ififo_out),
    .psumIn(ofifoOut),
    .sfpIn(psumMemOut),
    .sfpOut(coreOut)
);

sram_32b_w2048 #(.num(num)) xMem (
    .CLK(clk),
    .WEN(xMemWEN),
    .CEN(xMemCEN),
    .D(D_xmem),
    .A(xMemAddress),
    .Q(xMemOut)
);

sram_128b_w2048 #(.num(num)) psumMem (
    .CLK(clk),
    .WEN(psumMemWEN),
    .CEN(psumMemCEN),
    .D(ofifoOut),
    .A(psumMemAddress),
    .Q(psumMemOut)
);

endmodule
