// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module sram_32b_w2048 (CLK, D, Q, CEN, WEN, A);

  input  CLK;
  input  WEN;//CEN(chip enable) = 0 means chip turned on//CEN = 0 WEN = 0 -> write mode
  //WEN = 1 && CEN = 0 -> read mode  //WEN = X && CEN = 1 -> (DC)chip turned off
  input  CEN;
  input  [31:0] D;
  input  [10:0] A;
  output [31:0] Q;
  parameter num = 2048;

  reg [31:0] memory [num-1:0];
  reg [10:0] add_q;
  assign Q = memory[add_q];

  always @ (posedge CLK) begin

   if (!CEN && WEN) // read  //read from this SRAM
      add_q <= A;
   if (!CEN && !WEN) // write  //write into this SRAM
      memory[A] <= D; 

  end

endmodule