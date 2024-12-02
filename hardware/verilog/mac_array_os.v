module mac_array_os (
    clk,
    reset,
    out_s,
    in_a,
    in_w,
    inst_w,
    valid
);
    parameter bw = 4;        // Bitwidth of activations/weights
    parameter psum_bw = 16;  // Bitwidth of psum
    parameter col = 8;       // Number of columns in the array
    parameter row = 8;       // Number of rows in the array

    input clk, reset;
    input [row*bw-1:0] in_a;         // Input activations (vertical flow)
    input [col*bw-1:0] in_w;         // Input weights (horizontal flow)
    input [1:0] inst_w;              // Instruction signals for kernel loading
    output [psum_bw*col-1:0] out_s;  // Output stationary psums
    output [col-1:0] valid;          // Valid signals for psums

    wire [(col+1)*row*bw-1:0] temp_in_a;
    wire [(row+1)*col*psum_bw-1:0] temp_psum;
    wire [row*col-1:0] temp_valid;

    assign temp_in_a[row*bw-1:0] = in_a; // Input activations to first column
    assign temp_psum[psum_bw*col-1:0] = 0; // Initialize psums to 0
    assign out_s = temp_psum[psum_bw*col*(row+1)-1:psum_bw*col*row];
    assign valid = temp_valid[col-1:0];

    genvar i, j;
    generate
        for (i = 0; i < row; i = i + 1) begin : row_loop
            for (j = 0; j < col; j = j + 1) begin : col_loop
                mac_tile #(
                    .bw(bw),
                    .psum_bw(psum_bw)
                ) mac_tile_instance (
                    .clk(clk),
                    .reset(reset),
                    .out_s(temp_psum[psum_bw*(j+1)*row+i]),
                    .in_w(temp_in_a[bw*(j+1)*row+i]),
                    .in_a(temp_in_a[bw*(i+1)*col+j]),
                    .valid(temp_valid[i*col+j]),
                    .inst_w(inst_w)
                );
            end
        end
    endgenerate
endmodule
