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

// Signals for xMem
wire xMemWEN;
wire xMemCEN;
wire [10:0] xMemAddress;
wire [bw*row-1:0] xMemOut;

assign xMemCEN = inst[19];
assign xMemWEN = inst[18];
assign xMemAddress = inst[17:7];

// Signals for psumMem
wire psumMemWEN;
wire psumMemCEN;
wire [psum_bw*col-1:0] psumMemOut;
wire [10:0] psumMemAddress;

assign psumMemWEN = inst[31];
assign psumMemCEN = inst[32];
assign psumMemAddress = inst[30:20];

// Instantiate corelet
corelet #(.row(row), .col(col), .psum_bw(psum_bw), .bw(bw)) corelet_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .coreletIn(D_xmem),  // Direct input from xMem
    .psumIn(psumMemOut), // Input from psumMem
    .sfpIn(psumMemOut),  // Input from psumMem
    .sfpOut(coreOut)
);

// Instantiate xMem SRAM
sram_32b_w2048 #(.num(num)) xMem (
    .CLK(clk),
    .WEN(xMemWEN),
    .CEN(xMemCEN),
    .D(D_xmem),
    .A(xMemAddress),
    .Q(xMemOut)
);

// Instantiate psumMem SRAM
sram_128b_w2048 #(.num(num)) psumMem (
    .CLK(clk),
    .WEN(psumMemWEN),
    .CEN(psumMemCEN),
    .D(coreOut),
    .A(psumMemAddress),
    .Q(psumMemOut)
);

endmodule
