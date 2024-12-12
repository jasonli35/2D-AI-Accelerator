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

// Core Registers and Wires
reg [1:0] inst_q;
reg [bw-1:0] a_q;
reg [bw-1:0] b_q;
reg [psum_bw-1:0] c_q;
wire [psum_bw-1:0] mac_out;
reg load_ready_q;

// Additional Functionality Signals
reg [psum_bw-1:0] extended_accum;
reg [psum_bw-1:0] secondary_accum;
reg [psum_bw-1:0] temp_result;
reg mode_stable;
reg mode_pulse;

// Instantiate MAC Unit
mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
    .a(a_q), 
    .b(b_q),
    .c(c_q),
    .out(mac_out)
);

assign out_e = a_q;
assign inst_e = inst_q;
assign out_s = mac_out;

// Mode Handling
always @ (posedge clk or posedge reset) begin
    if (reset) begin
        mode_stable <= 0;
        mode_pulse <= 0;
    end else begin
        mode_stable <= mode_select;
        mode_pulse <= mode_select && ~mode_stable; // Detect mode changes
    end
end

// Primary Logic Block
always @ (posedge clk) begin
    if (reset) begin
        inst_q <= 0;
        load_ready_q <= 1'b1;
        a_q <= 0;
        b_q <= 0;
        c_q <= 0;
        extended_accum <= 0;
        secondary_accum <= 0;
        temp_result <= 0;
    end else begin
        inst_q[1] <= inst_w[1];

        // OS Mode (Using mode_stable to simulate dependency)
        if (mode_stable) begin
            temp_result <= in_n + extended_accum; // Intermediate calculation
            extended_accum <= extended_accum + temp_result;
            c_q <= extended_accum + secondary_accum; // Compound accumulation
        end else begin
            // WS Mode
            c_q <= in_n;
        end

        // Loading logic
        if (inst_w[1] | inst_w[0]) begin
            a_q <= in_w;
        end
        if (inst_w[0] & load_ready_q) begin
            b_q <= in_w;
            load_ready_q <= 1'b0;
        end
        if (~load_ready_q) begin
            inst_q[0] <= inst_w[0];
        end

        // Redundant Accumulation in WS
        if (~mode_stable) begin
            secondary_accum <= secondary_accum + in_n;
        end
    end
end

endmodule