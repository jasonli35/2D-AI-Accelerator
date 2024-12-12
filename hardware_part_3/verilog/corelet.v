module corelet #(
    parameter row = 8,
    parameter col = 8,
    parameter psum_bw = 16,
    parameter bw = 4
)(
    input clk,
    input reset,
    input [34:0] inst, // Includes mode_select
    input [bw*row-1:0] coreletIn,
    output [psum_bw*col-1:0] psumIn,
    input [psum_bw*col-1:0] sfpIn,
    output [psum_bw*col-1:0] sfpOut
);

// Mode selection signal
wire mode_select;
assign mode_select = inst[34]; // Determines WS (0) or OS (1)

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

// MAC array signals
wire [psum_bw*col-1:0] macArrayOut;
wire [1:0] macArrayInst;
wire [col-1:0] valid;
wire [row*bw-1:0] macArrayIn_w;
wire [psum_bw*col-1:0] macArrayIn_n;

// Conditional input to the MAC array
assign macArrayInst = inst[1:0];

// Adjust `in_w` for OS and WS
assign macArrayIn_w = (mode_select == 1) ? sfpIn[bw*row-1:0] : l0_out; // OS uses sfpIn, WS uses l0_out

// Adjust `in_n` for OS and WS
assign macArrayIn_n = (mode_select == 1) ? psumIn : {psum_bw*col{1'b0}}; // OS uses psumIn, WS uses zero

mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array (
    .clk(clk),
    .reset(reset),
    .out_s(macArrayOut),
    .in_w(macArrayIn_w),
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

// SFP signals
wire sfp_acc;
wire sfp_relu;
wire [psum_bw*col-1:0] sfp_in;
wire [psum_bw*col-1:0] sfp_out;

assign sfp_acc = inst[33];
assign sfp_relu = 0;

// Adjust input to SFP for OS and WS
assign sfp_in = (mode_select == 1) ? macArrayOut : ofifo_out; // OS uses macArrayOut, WS uses ofifo_out
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
