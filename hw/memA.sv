module memA #(
  parameter BITS_AB=8,
  parameter DIM=8
) (
  input  wire clk, rst_n,
  input  wire en, WrEn,
  input  wire signed [BITS_AB-1:0] Ain [DIM-1:0],
  input  wire         [$clog2(DIM)-1:0] Arow,
  output wire signed [BITS_AB-1:0] Aout [DIM-1:0]
);

logic [DIM-1:0] write_enable;

assign write_enable = {7'b0, WrEn} << Arow;


fifo_preload fifos [DIM-1:0] (.clk(clk), .rst_n(rst_n), .en(en), .wr(write_enable), .d(Ain), .q(Aout));



endmodule // memA
