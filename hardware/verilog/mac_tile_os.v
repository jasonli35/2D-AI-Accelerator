module mac_tile_os (
    clk,
    reset,
    in_a,
    in_w,
    out_s,
    inst_w,
    valid
);
    parameter bw = 4;
    parameter psum_bw = 16;

    input clk, reset;
    input [bw-1:0] in_a; // Input activation
    input [bw-1:0] in_w; // Input weight
    output reg [psum_bw-1:0] out_s; // Output psum
    input [1:0] inst_w;   // Instruction for kernel execution
    output reg valid;     // Valid signal

    reg [psum_bw-1:0] psum_reg; // Accumulator register

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            psum_reg <= 0;
            valid <= 0;
        end else if (inst_w[1]) begin
            psum_reg <= psum_reg + (in_a * in_w);
            valid <= 1;
        end else if (inst_w[0]) begin
            psum_reg <= 0;
            valid <= 0;
        end
        out_s <= psum_reg;
    end
endmodule
