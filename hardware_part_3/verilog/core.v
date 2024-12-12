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

// Mode select signal
wire mode_select;
assign mode_select = inst[34]; // Use inst[34] as mode_select (0 = WS, 1 = OS)

// Signals for XMem
wire xMemWEN;
wire xMemCEN;
wire [10:0] xMemAddress;
wire [bw*row-1:0] xMemOut;

assign xMemCEN = inst[19];
assign xMemWEN = inst[18];
assign xMemAddress = inst[17:7];

// Signals for PSUM memory
wire psumMemWEN;
wire psumMemCEN;
wire [psum_bw*col-1:0] psumMemOut;
wire [10:0] psumMemAddress;

assign psumMemWEN = inst[31];
assign psumMemCEN = inst[32];
assign psumMemAddress = inst[30:20];

// Signals for conditional connections
wire [psum_bw*col-1:0] psumInSignal;
wire [psum_bw*col-1:0] sfpInSignal;

// Assign psumIn and sfpIn based on mode_select
assign psumInSignal = (mode_select) ? psumMemOut : {psum_bw*col{1'b0}};
assign sfpInSignal = (mode_select) ? {psum_bw*col{1'b0}} : psumMemOut;

// Instantiate corelet
corelet #(
    .row(row),
    .col(col),
    .psum_bw(psum_bw),
    .bw(bw)
) corelet_inst (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .coreletIn(xMemOut),
    .psumIn(psumInSignal),
    .sfpIn(sfpInSignal),
    .sfpOut(coreOut)
);

// Instantiate XMem
sram_32b_w2048 #(
    .num(num)
) xMem_inst (
    .CLK(clk),
    .WEN(xMemWEN),
    .CEN(xMemCEN),
    .D(D_xmem),
    .A(xMemAddress),
    .Q(xMemOut)
);

// Instantiate PSUM memory
sram_128b_w2048 #(
    .num(num)
) psumMem_inst (
    .CLK(clk),
    .WEN(mode_select ? psumMemWEN : 1'b1), // Disable writes in WS mode
    .CEN(mode_select ? psumMemCEN : 1'b1), // Disable access in WS mode
    .D(coreOut),
    .A(psumMemAddress),
    .Q(psumMemOut)
);

endmodule
