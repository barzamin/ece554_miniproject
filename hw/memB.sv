module memB #(
  parameter BITS_AB=8,
  parameter DIM=8
) (
  input  logic clk, rst_n,
  input  logic en,
  input  logic signed [BITS_AB-1:0] Bin [DIM-1:0],
  output logic signed [BITS_AB-1:0] Bout [DIM-1:0]
);
endmodule // memB
