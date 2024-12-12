module mac_row (
    clk, out_s, in_w, in_n, valid, inst_w, reset, row_out
);

parameter bw = 4;
parameter psum_bw = 16;
parameter col = 8;

input  clk, reset;
output [psum_bw*col-1:0] out_s;
output [col-1:0] valid;
input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
input  [1:0] inst_w;
input  [psum_bw*col-1:0] in_n;
output [psum_bw*col-1:0] row_out; // New output for collecting all tile results

wire [psum_bw-1:0] tile_outputs [0:col-1]; // Collect individual tile outputs
assign row_out = {tile_outputs[col-1], tile_outputs[col-2], ..., tile_outputs[0]}; // Concatenate all tile outputs

genvar i;
for (i = 0; i < col; i = i + 1) begin : mac_tiles
    mac_tile #(.bw(bw), .psum_bw(psum_bw)) mac_tile_instance (
        .clk(clk),
        .reset(reset),
        .in_w(in_w),
        .out_e(),
        .in_n(in_n[psum_bw*(i+1)-1:psum_bw*i]),
        .inst_w(inst_w),
        .inst_e(),
        .mode_select(),
        .out_s(out_s[psum_bw*(i+1)-1:psum_bw*i]),
        .tile_out(tile_outputs[i]) // Forward tile output
    );
end

endmodule
