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

// Extract mode selection signal
wire mode_select;
assign mode_select = inst[7]; // 0 = Weight Stationary (WS), 1 = Output Stationary (OS)

// SRAM signals for XMem
wire xMemWEN, xMemCEN;
wire [10:0] xMemAddress;
wire [bw*row-1:0] xMemOut;

assign xMemCEN = inst[19];
assign xMemWEN = inst[18];
assign xMemAddress = inst[17:7];

// SRAM signals for psumMem (used in OS mode)
wire psumMemWEN, psumMemCEN;
wire [psum_bw*col-1:0] psumMemOut;
wire [10:0] psumMemAddress;

assign psumMemWEN = inst[31];
assign psumMemCEN = inst[32];
assign psumMemAddress = inst[30:20];

// --- Instantiate corelet ---
corelet #(.row(row), .col(col), .psum_bw(psum_bw), .bw(bw)) corelet_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .coreletIn(xMemOut),
    .psumIn((mode_select) ? psumMemOut : {psum_bw*col{1'b0}}), // Pass psumMemOut in OS mode, else zeros
    .sfpIn((!mode_select) ? psumMemOut : {psum_bw*col{1'b0}}), // Pass psumMemOut in WS mode, else zeros
    .sfpOut(coreOut)
);

// --- Instantiate XMem ---
sram_32b_w2048 #(.num(num)) xMem_instance (
    .CLK(clk),
    .WEN(xMemWEN),
    .CEN(xMemCEN),
    .D(D_xmem),
    .A(xMemAddress),
    .Q(xMemOut)
);

// --- Instantiate psumMem ---
sram_128b_w2048 #(.num(num)) psumMem_instance (
    .CLK(clk),
    .WEN((mode_select) ? psumMemWEN : 1'b1), // Enable writing only in OS mode
    .CEN((mode_select) ? psumMemCEN : 1'b1), // Enable only in OS mode
    .D(coreOut),
    .A(psumMemAddress),
    .Q(psumMemOut)
);

endmodule
