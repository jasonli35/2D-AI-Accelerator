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

// SRAM signals for PSUM memory
wire psumMemWEN, psumMemCEN;
wire [psum_bw*col-1:0] psumMemOut;
wire [10:0] psumMemAddress;

assign psumMemWEN = mode_select ? 1'b1 : inst[31]; // Disable writing in OS mode
assign psumMemCEN = mode_select ? 1'b1 : inst[32]; // Disable accessing in OS mode
assign psumMemAddress = inst[30:20];

// Corelet instantiation
corelet #(.row(row), .col(col), .psum_bw(psum_bw), .bw(bw)) corelet_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .coreletIn(xMemOut),
    .psumIn(psumMemOut),    // Use psumMemOut for accumulation (unchanged for WS)
    .sfpIn(psumMemOut),     // Use psumMemOut as SFP input for WS
    .sfpOut(coreOut)        // Final output
);

// XMem instantiation
sram_32b_w2048 #(.num(num)) xMem_instance (
    .CLK(clk),
    .WEN(xMemWEN),
    .CEN(xMemCEN),
    .D(D_xmem),
    .A(xMemAddress),
    .Q(xMemOut)
);

// PSUM memory instantiation
sram_128b_w2048 #(.num(num)) psumMem_instance (
    .CLK(clk),
    .WEN(psumMemWEN),
    .CEN(psumMemCEN),
    .D(coreOut),
    .A(psumMemAddress),
    .Q(psumMemOut)
);

endmodule
