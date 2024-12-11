`timescale 1ns/1ps

module core_tb;

parameter bw = 4;
parameter psum_bw = 16;
parameter len_kij = 9;
parameter len_onij = 16;
parameter col = 8;
parameter row = 8;
parameter len_nij = 36;

parameter num = 2048;

reg clk = 0;
reg reset = 1;

wire [33:0] inst_q; 

reg [1:0]  inst_w_q = 0; 
reg [bw*row-1:0] D_xmem_q = 0;
reg CEN_xmem = 1;
reg WEN_xmem = 1;
reg [10:0] A_xmem = 0;
reg CEN_xmem_q = 1;
reg WEN_xmem_q = 1;
reg [10:0] A_xmem_q = 0;
reg CEN_pmem = 1;
reg WEN_pmem = 1;
reg [10:0] A_pmem = 0;
reg CEN_pmem_q = 1;
reg WEN_pmem_q = 1;
reg [10:0] A_pmem_q = 0;
reg ofifo_rd_q = 0;
reg ififo_wr_q = 0;
reg ififo_rd_q = 0;
reg l0_rd_q = 0;
reg l0_wr_q = 0;
reg execute_q = 0;
reg load_q = 0;
reg acc_q = 0;
reg acc = 0;

reg [1:0]  inst_w; 
reg [bw*row-1:0] D_xmem;
reg [psum_bw*col-1:0] answer;

reg ofifo_rd;
reg ififo_wr;
reg ififo_rd;
reg l0_rd;
reg l0_wr;
reg execute;
reg load;
reg [8*30:1] w_file_name;
reg [8*30:1] captured_data;
wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;

reg [col*psum_bw-1:0] expected_value; // Expected value for verification
reg [col*psum_bw-1:0] psum_value; // Expected psum value

integer x_file, x_scan_file;
integer expected_file, expected_scan_file;
integer psum_file, psum_scan_file;
integer t, i, error;

assign inst_q[33] = acc_q;
assign inst_q[32] = CEN_pmem_q;
assign inst_q[31] = WEN_pmem_q;
assign inst_q[30:20] = A_pmem_q;
assign inst_q[19]   = CEN_xmem_q;
assign inst_q[18]   = WEN_xmem_q;
assign inst_q[17:7] = A_xmem_q;
assign inst_q[6]   = ofifo_rd_q;
assign inst_q[5]   = ififo_wr_q;
assign inst_q[4]   = ififo_rd_q;
assign inst_q[3]   = l0_rd_q;
assign inst_q[2]   = l0_wr_q;
assign inst_q[1]   = execute_q; 
assign inst_q[0]   = load_q; 

core #(  .row(row), .col(col), .bw(bw), .psum_bw(psum_bw), .num(num)) core (
	.clk(clk), 
	.inst(inst_q),
	.valid(ofifo_valid),
    .D_xmem(D_xmem_q), 
    .coreOut(sfp_out), 
	.reset(reset)
); 

initial begin 

	inst_w   = 0; 
	D_xmem   = 0;
	CEN_xmem = 1;
	WEN_xmem = 1;
	A_xmem   = 0;
	ofifo_rd = 0;
	ififo_wr = 0;
	ififo_rd = 0;
	l0_rd    = 0;
	l0_wr    = 0;
	execute  = 0;
	load     = 0;

	$dumpfile("core_tb.vcd");
	$dumpvars(0,core_tb);

	x_file = $fopen("./files/activation/activation.txt", "r");
	psum_file = $fopen("./files/expected/psum_values.txt", "r");
	expected_file = $fopen("./files/expected/expected_values.txt", "r");

	if (x_file == 0 || psum_file == 0 || expected_file == 0) begin
		$display("ERROR: Input files not found!");
		$finish;
	end

	// Skip comment lines in activation file
	x_scan_file = $fscanf(x_file, "%s", captured_data);
	x_scan_file = $fscanf(x_file, "%s", captured_data);
	x_scan_file = $fscanf(x_file, "%s", captured_data);

	// Reset
	#0.5 clk = 1'b0;   reset = 1;
	#0.5 clk = 1'b1; 

	for (i=0; i<10 ; i=i+1) begin
		#0.5 clk = 1'b0;
		#0.5 clk = 1'b1;  
	end

	#0.5 clk = 1'b0; reset = 0;
	#0.5 clk = 1'b1; 

	// Activation data writing to memory
	for (t=0; t<len_nij; t=t+1) begin  
		#0.5 clk = 1'b0;
		x_scan_file = $fscanf(x_file, "%32b", D_xmem);
		$display("Writing activation %0d: %b", t, D_xmem);
		WEN_xmem = 0;
		CEN_xmem = 0;
		if (t>0) A_xmem = A_xmem + 1;
		#0.5 clk = 1'b1;   
	end

	#0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
	#0.5 clk = 1'b1; 

	$fclose(x_file);

	// Execution and Verification
	error = 0;
	for (t=0; t<len_nij; t=t+1) begin
		#0.5 clk = 1'b0;
		ififo_rd = 1;
		execute = 1;
		psum_scan_file = $fscanf(psum_file, "%128b", psum_value);
		#0.5 clk = 1'b1;
		$display("Cycle %0d: Output = %b | Expected PSUM = %b", t, sfp_out, psum_value);
		// Verify psum output
		if (sfp_out === psum_value) begin
			$display("PSUM Data Matched at cycle %0d", t);
		end else begin
			$display("ERROR: PSUM mismatch at cycle %0d", t);
			error = error + 1;
		end
	end

	// Verify final output feature
	for (t=0; t<len_onij; t=t+1) begin
		expected_scan_file = $fscanf(expected_file, "%128b", expected_value);
		#0.5 clk = 1'b0;
		#0.5 clk = 1'b1;
		$display("Verifying output feature %0d: SFP_OUT = %b | EXPECTED = %b", t, sfp_out, expected_value);
		if (sfp_out === expected_value) begin
			$display("Output Feature Matched at cycle %0d", t);
		end else begin
			$display("ERROR: Output feature mismatch at cycle %0d", t);
			error = error + 1;
		end
	end

	$display("Execution completed with %0d errors.", error);
	if (error == 0) begin
		$display("########### Project Completed: All Data Matched ###########");
	end else begin
		$display("########### Project Completed: Errors Detected ###########");
	end

	$fclose(psum_file);
	$fclose(expected_file);
	$finish;
end

always @ (posedge clk) begin
	inst_w_q   <= inst_w; 
	D_xmem_q   <= D_xmem;
	CEN_xmem_q <= CEN_xmem;
	WEN_xmem_q <= WEN_xmem;
	A_pmem_q   <= A_pmem;
	CEN_pmem_q <= CEN_pmem;
	WEN_pmem_q <= WEN_pmem;
	A_xmem_q   <= A_xmem;
	ofifo_rd_q <= ofifo_rd;
	acc_q      <= acc;
	ififo_wr_q <= ififo_wr;
	ififo_rd_q <= ififo_rd;
	l0_rd_q    <= l0_rd;
	l0_wr_q    <= l0_wr;
	execute_q  <= execute;
	load_q     <= load;
end

endmodule
