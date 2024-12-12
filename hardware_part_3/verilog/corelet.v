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
    input [psum_bw*col-1:0] psumIn, // PSUM input (only for OS mode)
    input [psum_bw*col-1:0] sfpIn,  // SFP input (only for WS mode)
    output [psum_bw*col-1:0] sfpOut // Final output
);

// Mode selection signal
wire mode_select;
assign mode_select = inst[7]; // 0 = Weight Stationary (WS), 1 = Output Stationary (OS)

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
    .in(coreletIn),
    .out(l0_out),
    .o_full(l0_full),
    .o_ready(l0_ready)
);

// Signals for MAC array
wire [psum_bw*col-1:0] macArrayOut;
wire [1:0] macArrayInst;
wire [col-1:0] valid;

assign macArrayInst = inst[1:0];

// Instantiate MAC Array
mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(macArrayOut),
    .in_w(l0_out),
    .inst_w(macArrayInst),
    .in_n(mode_select ? psumIn : 0), // Use psumIn in OS mode, else 0
    .valid(valid)
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

// Signals for SFP
wire sfp_acc, sfp_relu;
wire [psum_bw*col-1:0] sfp_out;

assign sfp_acc = inst[33];
assign sfp_relu = 0;

// Generate SFP output
genvar i;
generate
    for (i = 0; i < col; i = i + 1) begin : sfp_instance
        sfp #(.psum_bw(psum_bw)) sfp_inst (
            .clk(clk),
            .acc(sfp_acc),
            .relu(sfp_relu),
            .reset(reset),
            .in(mode_select ? ofifo_out[psum_bw*i +: psum_bw] : sfpIn[psum_bw*i +: psum_bw]), // Use SFP for WS mode, OFIFO for OS mode
            .out(sfp_out[psum_bw*i +: psum_bw])
        );
    end
endgenerate

assign sfpOut = sfp_out;

endmodule
