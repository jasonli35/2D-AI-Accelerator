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

// Mode select signal
wire mode_select;
assign mode_select = inst[7]; // 0 = Weight Stationary (WS), 1 = Output Stationary (OS)

// Signals for XMem
wire xMemWEN, xMemCEN;
wire [10:0] xMemAddress;
wire [bw*row-1:0] xMemOut;

assign xMemCEN = inst[19];
assign xMemWEN = inst[18];
assign xMemAddress = inst[17:7];

// Signals for PSUM memory (used in OS mode)
wire psumMemWEN, psumMemCEN;
wire [psum_bw*col-1:0] psumMemOut;
wire [10:0] psumMemAddress;

assign psumMemWEN = inst[31];
assign psumMemCEN = inst[32];
assign psumMemAddress = inst[30:20];

// Intermediate wires for conditional connections
wire [psum_bw*col-1:0] psum_in_wire;
wire [psum_bw*col-1:0] sfp_in_wire;
wire psumMemWEN_cond, psumMemCEN_cond;

// Mode-based assignments
assign psum_in_wire = (mode_select == 1) ? psumMemOut : {psum_bw*col{1'b0}};
assign sfp_in_wire = (mode_select == 1) ? {psum_bw*col{1'b0}} : psumMemOut;
assign psumMemWEN_cond = (mode_select == 1) ? psumMemWEN : 1'b1; // Disable writes in WS mode
assign psumMemCEN_cond = (mode_select == 1) ? psumMemCEN : 1'b1; // Disable accesses in WS mode

// --- Instantiate corelet ---
corelet #(.row(row), .col(col), .psum_bw(psum_bw), .bw(bw)) corelet_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .coreletIn(xMemOut),
    .psumIn(psum_in_wire), // Pass intermediate signal
    .sfpIn(sfp_in_wire),   // Pass intermediate signal
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
    .WEN(psumMemWEN_cond),
    .CEN(psumMemCEN_cond),
    .D(coreOut),
    .A(psumMemAddress),
    .Q(psumMemOut)
);

endmodule
