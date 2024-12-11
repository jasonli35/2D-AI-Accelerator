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
wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;

integer x_file, x_scan_file;
integer w_file, w_scan_file;
integer psum_file;
integer t, i, kij;
integer dummy; // Used for skipping comment lines

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

	// Open activation file
	x_file = $fopen("files/activation/activation.txt", "r");
	if (x_file == 0) begin
		$display("ERROR: Activation file not found!");
		$finish;
	end

	// Skip comment lines in activation.txt
	dummy = $fscanf(x_file, "%s\n", D_xmem);
	dummy = $fscanf(x_file, "%s\n", D_xmem);
	dummy = $fscanf(x_file, "%s\n", D_xmem);
	$display("Skipped activation comment lines.");

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
	for (t = 0; t < len_nij; t = t + 1) begin  
		#0.5 clk = 1'b0;
		x_scan_file = $fscanf(x_file, "%32b", D_xmem);
		if (x_scan_file != 1) begin
			$display("ERROR: Failed to read activation data at line %0d", t + 4);
			$finish;
		end
		WEN_xmem = 0;
		CEN_xmem = 0;
		if (t > 0) A_xmem = A_xmem + 1;
		$display("Writing activation %0d: %b", t, D_xmem);
		#0.5 clk = 1'b1;
	end

	#0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
	#0.5 clk = 1'b1; 

	$fclose(x_file);

	// Open psum file
	psum_file = $fopen("psum.txt", "w");
	if (psum_file == 0) begin
		$display("ERROR: Could not create psum file!");
		$finish;
	end

	// Process weights for kij loop
	for (kij = 0; kij < len_kij; kij = kij + 1) begin
		case(kij)
			0: w_file_name = "files/weights/weight0.txt";
			1: w_file_name = "files/weights/weight1.txt";
			2: w_file_name = "files/weights/weight2.txt";
			3: w_file_name = "files/weights/weight3.txt";
			4: w_file_name = "files/weights/weight4.txt";
			5: w_file_name = "files/weights/weight5.txt";
			6: w_file_name = "files/weights/weight6.txt";
			7: w_file_name = "files/weights/weight7.txt";
			8: w_file_name = "files/weights/weight8.txt";
		endcase

		w_file = $fopen(w_file_name, "r");
		if (w_file == 0) begin
			$display("ERROR: Weight file %s not found!", w_file_name);
			$finish;
		end

		// Skip weight comment lines
		dummy = $fscanf(w_file, "%s\n", D_xmem);
		dummy = $fscanf(w_file, "%s\n", D_xmem);
		dummy = $fscanf(w_file, "%s\n", D_xmem);
		$display("Skipped weight comment lines for kij=%0d.", kij);

		// Weight data loading into IFIFO
		for (t = 0; t < col; t = t + 1) begin
			#0.5 clk = 1'b0;
			w_scan_file = $fscanf(w_file, "%32b", D_xmem);
			ififo_wr = 1;
			$display("Writing weight %0d for kij=%0d: %b", t, kij, D_xmem);
			#0.5 clk = 1'b1;
		end
		$fclose(w_file);
	end

	// Execution and PSUM collection
	for (t = 0; t < len_nij; t = t + 1) begin
		#0.5 clk = 1'b0;
		ififo_rd = 1;
		execute = 1;
		#0.5 clk = 1'b1;
		$fwrite(psum_file, "%128b\n", sfp_out);
		$display("Collected PSUM %0d: %b", t, sfp_out);
	end

	$fclose(psum_file);
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
