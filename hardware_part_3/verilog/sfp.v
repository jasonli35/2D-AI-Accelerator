module sfp (
    clk,
    in,
    reset,
    relu,
    acc,
    out
);
    parameter psum_bw = 16;

    input clk, reset, relu, acc;
    input [psum_bw-1:0] in;
    output [psum_bw-1:0] out;

    reg [psum_bw-1:0] psum_q;

    always @(posedge clk) begin
        if (reset) begin
            psum_q <= 0;
        end
        
        else begin
            if(acc)
            psum_q <=psum_q+in;

            else if(relu)
            psum_q <= (psum_q>0)? psum_q:0;
            else 
                psum_q<=psum_q;
        end
    end


    assign out = psum_q;

endmodule