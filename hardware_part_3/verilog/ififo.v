module ififo (
    clk,
    in,
    out,
    rd,
    wr,
    reset,
    o_full,
    o_empty
);
    parameter col = 8;       // Number of columns in the array
    parameter bw = 4;        // Bitwidth of weights

    input clk, rd, wr, reset;
    input [col*bw-1:0] in;   // Input weights
    output [col*bw-1:0] out; // Output weights
    output o_full, o_empty;

    reg [col*bw-1:0] fifo_mem [0:15]; // FIFO depth of 16
    reg [3:0] rd_ptr, wr_ptr;         // Read and write pointers
    reg full, empty;

    assign o_full = full;
    assign o_empty = empty;
    assign out = fifo_mem[rd_ptr];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rd_ptr <= 0;
            wr_ptr <= 0;
            full <= 0;
            empty <= 1;
        end else begin
            if (wr && !full) begin
                fifo_mem[wr_ptr] <= in;
                wr_ptr <= wr_ptr + 1;
                empty <= 0;
                if (wr_ptr + 1 == rd_ptr) full <= 1;
            end
            if (rd && !empty) begin
                rd_ptr <= rd_ptr + 1;
                full <= 0;
                if (rd_ptr + 1 == wr_ptr) empty <= 1;
            end
        end
    end
endmodule
