module core #(
    parameter row = 8,
    parameter col = 8,
    parameter psum_bw = 16,
    parameter bw = 4,
    parameter num = 2048
)(
    input clk,
    input reset, 
    input [34:0] inst,
    input [bw*row-1:0] D_xmem,
    output valid,
    output [psum_bw*col-1:0] coreOut
);

// Mode selection signal (added but unused)
wire mode_select;
assign mode_select = inst[34]; // Use inst[34] as mode_select (0 = WS, 1 = OS)

// Existing signals
wire [psum_bw*col-1:0] ofifoOut;

wire xMemWEN;
wire xMemCEN;
wire [10:0] xMemAddress;
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

// Instantiate corelet
corelet #(.row(row), .col(col), .psum_bw(psum_bw), .bw(bw)) corelet_inst (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .coreletIn(xMemOut),
    .psumIn(ofifoOut),  // Existing connection
    .sfpIn(psumMemOut), // Existing connection
    .sfpOut(coreOut)
);

// Instantiate XMem
sram_32b_w2048 #(.num(num)) xMem (
    .CLK(clk),
    .WEN(xMemWEN),
    .CEN(xMemCEN),
    .D(D_xmem),
    .A(xMemAddress),
    .Q(xMemOut)
);

// Instantiate PSUM memory
sram_128b_w2048 #(.num(num)) psumMem (
    .CLK(clk),
    .WEN(psumMemWEN),
    .CEN(psumMemCEN),
    .D(ofifoOut),
    .A(psumMemAddress),
    .Q(psumMemOut)
);

endmodule
