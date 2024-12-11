module corelet #(
    parameter row = 8,
    parameter col = 8,
    parameter psum_bw = 16,
    parameter bw = 4
)(
    input clk,
    input reset,
    input [33:0] inst,
    input [bw*row-1:0] coreletIn, // Data input from core
    input [psum_bw*col-1:0] psumIn, // PSUM input from psumMem
    input [psum_bw*col-1:0] sfpIn, // SFP input
    output [psum_bw*col-1:0] sfpOut // Final output
);

// Mode selection signal for WS/OS
wire mode_sel;
assign mode_sel = inst[7];

// Signals for IFIFO
wire ififo_rd, ififo_wr;
wire [bw*row-1:0] ififo_out;
wire ififo_full, ififo_empty;

assign ififo_rd = inst[4];
assign ififo_wr = inst[5];

// Instantiate IFIFO
ififo #(.col(row), .bw(bw)) ififo_instance (
    .clk(clk),
    .in(coreletIn),
    .out(ififo_out),
    .rd(ififo_rd),
    .wr(ififo_wr),
    .reset(reset),
    .o_full(ififo_full),
    .o_empty(ififo_empty)
);

// Signals for L0
wire l0_wr, l0_rd;
wire [bw*row-1:0] l0_out;
wire l0_full, l0_ready;

assign l0_wr = inst[2];
assign l0_rd = inst[3];

// Instantiate L0
l0 #(.row(row), .bw(bw)) L0_instance (
    .clk(clk),
    .wr(l0_wr),
    .rd(l0_rd),
    .reset(reset),
    .in(ififo_out), // Input from IFIFO
    .out(l0_out),
    .o_full(l0_full),
    .o_ready(l0_ready)
);

// Signals for MAC array
wire [psum_bw*col-1:0] macArrayOut;
wire [1:0] macArrayInst;
wire [col-1:0] valid;
wire [psum_bw*col-1:0] macArrayIn_n;

assign macArrayInst = inst[1:0];
assign macArrayIn_n = psumIn;

// Instantiate MAC Array
mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(macArrayOut),
    .in_w(l0_out),
    .inst_w(macArrayInst),
    .in_n(macArrayIn_n),
    .valid(valid),
    .mode_sel(mode_sel)
);

// Signals for OFIFO
wire ofifo_rd;
wire [psum_bw*col-1:0] ofifo_in, ofifo_out;
wire ofifo_full, ofifo_ready, ofifo_valid;

assign ofifo_rd = inst[6];
assign ofifo_in = macArrayOut;

// Instantiate OFIFO
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

// SFP Signals
wire sfp_acc, sfp_relu;
wire [psum_bw*col-1:0] sfp_in, sfp_out;

assign sfp_acc = inst[33];
assign sfp_relu = 0; // No ReLU in this part
assign sfp_in = ofifo_out;

// Instantiate SFP
genvar i;
generate
    for (i = 0; i < col; i = i + 1) begin : sfp_instance
        sfp #(.psum_bw(psum_bw)) sfp_inst (
            .clk(clk),
            .acc(sfp_acc),
            .relu(sfp_relu),
            .reset(reset),
            .in(sfp_in[psum_bw*i +: psum_bw]),
            .out(sfp_out[psum_bw*i +: psum_bw])
        );
    end
endgenerate

assign sfpOut = sfp_out;

endmodule
