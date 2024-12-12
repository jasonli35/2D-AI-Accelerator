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
    input mode_select,
    output valid,
    output [psum_bw*col-1:0] coreOut
);

// Mode select signal (inst[7])
wire mode_select;
assign mode_select = inst[34]; // Use an unused bit (e.g., inst[34])

// --- Signals for XMem ---
wire xMemWEN, xMemCEN;
wire [10:0] xMemAddress;
wire [bw*row-1:0] xMemOut;

assign xMemCEN = inst[19];
assign xMemWEN = inst[18];
assign xMemAddress = inst[17:7];

// --- Signals for PSUM memory ---
wire psumMemWEN, psumMemCEN;
wire [psum_bw*col-1:0] psumMemOut;
wire [10:0] psumMemAddress;

assign psumMemWEN = inst[31];
assign psumMemCEN = inst[32];
assign psumMemAddress = inst[30:20];

// --- Intermediate Connections ---
wire [psum_bw*col-1:0] psum_in_signal;
wire [psum_bw*col-1:0] sfp_in_signal;

// Conditionally assign inputs based on mode_select
assign psum_in_signal = (mode_select == 1) ? psumMemOut : {psum_bw*col{1'b0}}; // PSUM for OS, zero for WS
assign sfp_in_signal = (mode_select == 0) ? psumMemOut : {psum_bw*col{1'b0}}; // SFP for WS, zero for OS

// --- Instantiate Corelet ---
corelet #(.row(row), .col(col), .psum_bw(psum_bw), .bw(bw)) corelet_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .coreletIn(xMemOut),
    .psumIn(psum_in_signal),
    .sfpIn(sfp_in_signal),
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
    .WEN(mode_select ? psumMemWEN : 1'b1), // Only enable PSUM writes in OS mode
    .CEN(mode_select ? psumMemCEN : 1'b1), // Only enable PSUM access in OS mode
    .D(coreOut),
    .A(psumMemAddress),
    .Q(psumMemOut)
);

endmodule
