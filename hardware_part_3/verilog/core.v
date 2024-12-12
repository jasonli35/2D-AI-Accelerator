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

// Mode select signal (inst[7])
// For now, we explicitly acknowledge it but do nothing with it.
wire mode_select;
assign mode_select = inst[7]; // 0 = WS (Weight Stationary), 1 = OS (Output Stationary)

// --- Signals for XMem ---
wire xMemWEN, xMemCEN;
wire [10:0] xMemAddress;
wire [bw*row-1:0] xMemOut;

assign xMemCEN = inst[19];
assign xMemWEN = inst[18];
assign xMemAddress = inst[17:7];

// --- Signals for PSUM memory (if needed later) ---
wire psumMemWEN, psumMemCEN;
wire [psum_bw*col-1:0] psumMemOut;
wire [10:0] psumMemAddress;

assign psumMemWEN = inst[31];
assign psumMemCEN = inst[32];
assign psumMemAddress = inst[30:20];

// --- Instantiate Corelet ---
corelet #(.row(row), .col(col), .psum_bw(psum_bw), .bw(bw)) corelet_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .coreletIn(xMemOut),
    .psumIn({psum_bw*col{1'b0}}), // Hardcoded zero for now
    .sfpIn({psum_bw*col{1'b0}}),  // Hardcoded zero for now
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

// --- Instantiate PSUM memory ---
sram_128b_w2048 #(.num(num)) psumMem_instance (
    .CLK(clk),
    .WEN(psumMemWEN),
    .CEN(psumMemCEN),
    .D(coreOut),
    .A(psumMemAddress),
    .Q(psumMemOut)
);

endmodule
