module tpuv1 #(
  parameter BITS_AB=8,
  parameter BITS_C=16,
  parameter DIM=8,
  parameter ADDRW=16,
  parameter DATAW=64,
) (
  input wire clk, rst_n,
  input wire r_w, // r_w=0 read, =1 write
  input wire [DATAW-1:0] dataIn,
  output wire [DATAW-1:0] dataOut,
  input wire [ADDRW-1:0] addr
);
endmodule; // tpuv1
