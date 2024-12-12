module corelet #(
    parameter row = 8,
    parameter col = 8,
    parameter psum_bw = 16,
    parameter bw = 4
)(
    input clk,
    input reset,
    input [34:0] inst,
    input [bw*row-1:0] coreletIn,
    output [psum_bw*col-1:0] psumIn,
    input [psum_bw*col-1:0] sfpIn,
    output [psum_bw*col-1:0] sfpOut,
    input mode_select // Add mode_select input
);

// --- L0 Signals ---
wire l0_wr;
wire l0_rd;
wire [bw*row-1:0] l0_out;
wire l0_full;
wire l0_ready;

assign l0_wr = inst[2];
assign l0_rd = inst[3];

l0 #(.row(row), .bw(bw)) L0_instance (
    .clk(clk),
    .wr(l0_wr),
    .rd(l0_rd),
    .reset(reset),
    .in(coreletIn),
    .out(l0_out),
    .o_full(l0_full),
    .o_ready(l0_ready)
);

// --- MAC Array Signals ---
wire [psum_bw*col-1:0] macArrayOut;
wire [1:0] macArrayInst;
wire [col-1:0] valid;
wire [psum_bw*col-1:0] macArrayIn;

assign macArrayInst = inst[1:0];
assign macArrayIn = mode_select ? sfpIn : {psum_bw*col{1'b0}}; // OS uses sfpIn, WS uses 0

mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array (
    .clk(clk),
    .reset(reset),
    .out_s(macArrayOut),
    .in_w(l0_out),
    .inst_w(macArrayInst),
    .in_n(macArrayIn),
    .valid(valid)
);

// --- OFIFO Signals ---
wire ofifo_rd;
wire [psum_bw*col-1:0] ofifo_in;
wire [psum_bw*col-1:0] ofifo_out;
wire ofifo_full;
wire ofifo_ready;
wire ofifo_valid;

assign ofifo_rd = inst[6];
assign ofifo_in = macArrayOut;
assign psumIn = mode_select ? ofifo_out : {psum_bw*col{1'b0}}; // OS uses ofifo_out, WS uses 0

ofifo #(.col(col), .psum_bw(psum_bw)) ofifo_instance (
    .clk(clk),
    .reset(reset),
    .wr(valid),
    .rd(ofifo_rd),
    .in(ofifo_in),
    .out(ofifo_out),
    .o_full(ofifo_full),
    .o_ready(ofifo_ready),
    .o_valid(ofifo_valid)
);

// --- SFP Signals ---
wire sfp_acc;
wire sfp_relu;
wire [psum_bw*col-1:0] sfp_in;
wire [psum_bw*col-1:0] sfp_out;

assign sfp_acc = inst[33];
assign sfp_relu = 0;
assign sfp_in = mode_select ? {psum_bw*col{1'b0}} : psumIn; // WS uses psumIn, OS uses 0
assign sfpOut = sfp_out;

// Instantiate SFP
genvar i;
for (i = 1; i < col + 1; i = i + 1) begin : sfp_num
    sfp #(.psum_bw(psum_bw)) sfp_instance (
        .clk(clk),
        .acc(sfp_acc),
        .relu(sfp_relu),
        .reset(reset),
        .in(sfp_in[psum_bw * i - 1 : psum_bw * (i - 1)]),
        .out(sfp_out[psum_bw * i - 1 : psum_bw * (i - 1)])
    );
end

endmodule
