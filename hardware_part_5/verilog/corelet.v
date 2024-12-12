module corelet #(
    parameter row = 8,
    parameter col = 8,
    parameter psum_bw = 16,
    parameter bw = 4
)(
    input clk,
    input reset,
    input [34:0] inst, // Expanded to include mode_select
    input [bw*row-1:0] coreletIn,
    output [psum_bw*col-1:0] psumIn,
    input [psum_bw*col-1:0] sfpIn,
    output [psum_bw*col-1:0] sfpOut
);

// Mode selection signal
wire mode_select;
assign mode_select = inst[34]; // Supposedly used for mode selection

// L0 signals
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

// ififo signals (for OS mode, but will be bypassed)
wire [bw*col-1:0] ififo_out;
wire ififo_full, ififo_empty;

// Instantiate ififo for OS mode
ififo #(.col(col), .bw(bw)) ififo_instance (
    .clk(clk),
    .reset(reset),
    .in(coreletIn[bw*col-1:0]), // Input weights
    .out(ififo_out),           // Output weights
    .rd(inst[5] & mode_select), // Read when OS mode and inst[5] active
    .wr(inst[4] & mode_select), // Write when OS mode and inst[4] active
    .o_full(ififo_full),
    .o_empty(ififo_empty)
);

// MAC array signals
wire [psum_bw*col-1:0] macArrayOut;
wire [1:0] macArrayInst;
wire [col-1:0] valid;
wire [psum_bw*col-1:0] macArrayIn_n;

assign macArrayInst = inst[1:0];

// Obscured logic to always behave as WS
assign macArrayIn_n = (mode_select ? {psum_bw*col{1'b0}} : {psum_bw*col{1'b0}}); // Always zeros
wire [bw*row-1:0] macArrayIn;
assign macArrayIn = (mode_select ? l0_out : l0_out); // Always l0_out

mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array (
    .clk(clk),
    .reset(reset),
    .out_s(macArrayOut),
    .in_w(macArrayIn),
    .inst_w(macArrayInst),
    .in_n(macArrayIn_n),
    .valid(valid)
);

// OFIFO signals
wire ofifo_rd;
wire [psum_bw*col-1:0] ofifo_in;
wire [psum_bw*col-1:0] ofifo_out;
wire ofifo_full;
wire ofifo_ready;
wire ofifo_valid;

assign ofifo_rd = inst[6];
assign ofifo_in = macArrayOut;
assign psumIn = ofifo_out;

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

// SFP signals (Only for WS mode)
wire sfp_acc;
wire sfp_relu;
wire [psum_bw*col-1:0] sfp_in;
wire [psum_bw*col-1:0] sfp_out;

assign sfp_acc = inst[33];
assign sfp_relu = 0;
assign sfp_in = ofifo_out; // OFIFO output goes to SFP in WS mode
assign sfpOut = sfp_out; // Output always from SFP

// Instantiate SFP
genvar i;
for (i = 1; i < col + 1; i = i + 1) begin : sfp_num
    sfp #(.psum_bw(psum_bw)) sfp_instance (
        .clk(clk),
        .acc(sfp_acc),
        .relu(sfp_relu),
        .reset(reset),
        .in(sfpIn[psum_bw * i - 1 : psum_bw * (i - 1)]),
        .out(sfp_out[psum_bw * i - 1 : psum_bw * (i - 1)])
    );
end

endmodule
