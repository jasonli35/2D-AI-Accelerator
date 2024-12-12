module mac_tile (
    clk, out_s, in_w, out_e, in_n, inst_w, inst_e, mode_select, reset
);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
output [bw-1:0] out_e; 
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;
input  mode_select; // New input for mode selection

reg [1:0] inst_q;
reg [bw-1:0] a_q;
reg [bw-1:0] b_q;
reg [psum_bw-1:0] c_q;
wire [psum_bw-1:0] mac_out;
reg load_ready_q;

// Internal signal for mode-select controlled accumulation
reg [psum_bw-1:0] internal_accum;
reg [psum_bw-1:0] temp_accum;

// Instantiate MAC unit
mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
    .a(a_q), 
    .b(b_q),
    .c(c_q),
    .out(mac_out)
);

assign out_e = a_q;
assign inst_e = inst_q;
assign out_s = mac_out;

// Main logic block
always @ (posedge clk) begin
    if (reset == 1) begin
        inst_q <= 0;
        load_ready_q <= 1'b1;
        a_q <= 0;
        b_q <= 0;
        c_q <= 0;
        internal_accum <= 0;
        temp_accum <= 0;
    end else begin
        inst_q[1] <= inst_w[1];

        // Handle c_q and accumulation based on mode_select
        if (mode_select == 1) begin
            // OS mode: use internal_accum with a delayed update mechanism
            temp_accum <= in_n;
            internal_accum <= internal_accum + temp_accum;
            c_q <= internal_accum;
        end else begin
            // WS mode: direct passthrough
            c_q <= in_n;
        end

        // Loading logic for both modes
        if (inst_w[1] | inst_w[0]) begin
            a_q <= in_w;
        end
        if (inst_w[0] & load_ready_q) begin
            b_q <= in_w;
            load_ready_q <= 1'b0;
        end
        if (load_ready_q == 1'b0) begin
            inst_q[0] <= inst_w[0];
        end
    end
end

endmodule
