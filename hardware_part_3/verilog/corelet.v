module corelet #(
    parameter row = 8,
    parameter col = 8,
    parameter psum_bw = 16,
    parameter bw = 4
)(
    input clk,
    input reset,
    input [33:0] inst,
    input [bw*row-1:0] coreletIn,
    input [psum_bw*col-1:0] psumIn,
    input [psum_bw*col-1:0] sfpIn,
    output [psum_bw*col-1:0] sfpOut
);

// Extract mode selection signal
wire mode_select;
assign mode_select = inst[7]; // 0 = Weight Stationary (WS), 1 = Output Stationary (OS)

// --- L0 Signals ---
wire l0_wr, l0_rd;
wire [bw*row-1:0] l0_out;
wire l0_full, l0_ready;

assign l0_wr = inst[2];
assign l0_rd = inst[3];

// --- Instantiate L0 ---
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
wire [psum_bw*col-1:0] macArrayIn_n;

assign macArrayInst = inst[1:0];
assign macArrayIn_n = (mode_select == 1) ? psumIn : 0; // Use psumIn only in OS mode

// --- Instantiate MAC Array ---
mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(macArrayOut),
    .in_w(l0_out),
    .inst_w(macArrayInst),
    .in_n(macArrayIn_n),
    .valid(valid)
);

// --- OFIFO Signals ---
wire ofifo_rd;
wire [psum_bw*col-1:0] ofifo_in, ofifo_out;
wire ofifo_full, ofifo_ready, ofifo_valid;

assign ofifo_rd = inst[6];
assign ofifo_in = macArrayOut;

// --- Instantiate OFIFO ---
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
wire sfp_acc, sfp_relu;
wire [psum_bw*col-1:0] sfp_in, sfp_out;

assign sfp_acc = inst[33];
assign sfp_relu = 0; // No ReLU in this part
assign sfp_in = ofifo_out;

// --- Instantiate SFP ---
genvar i;
generate
    for (i = 0; i < col; i = i + 1) begin : sfp_instance
        sfp #(.psum_bw(psum_bw)) sfp_inst (
            .clk(clk),
            .acc(sfp_acc),
            .relu(sfp_relu),
            .reset(reset),
            .in((mode_select == 0) ? sfpIn[psum_bw*i +: psum_bw] : 0), // Only enable in WS mode
            .out(sfp_out[psum_bw*i +: psum_bw])
        );
    end
endgenerate

assign sfpOut = sfp_out;

endmodule
