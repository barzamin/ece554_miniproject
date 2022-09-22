module memA #(
  parameter BITS_AB=8,
  parameter DIM=8
) (
  input  logic clk, rst_n,
  input  logic en, WrEn,
  input  logic signed [BITS_AB-1:0] Ain [DIM-1:0],
  input  logic         [$clog2(DIM)-1:0] Arow,
  output logic signed [BITS_AB-1:0] Aout [DIM-1:0]
);

assign write_enable = {7'b0, WrEn} << Crow;

logic [BITS_AB-1:0] outs [DIM-1:0];

fifo_preload [DIM-1:0] fifos(.clk(clk), .rst_n(rst_n), .en(en), .wr(write_enable), .d(Ain), .q(outs))
  
  


endmodule // memA
