module memB #(
  parameter BITS_AB=8,
  parameter DIM=8
) (
  input  logic clk, rst_n,
  input  logic en,
  input  logic signed [BITS_AB-1:0] Bin [DIM-1:0],
  output logic signed [BITS_AB-1:0] Bout [DIM-1:0]
);
  genvar col_idx;
  generate
    for (col_idx = 0; col_idx < DIM; col_idx++) begin : col_fifos
      fifo #(
        .DEPTH(DIM+col_idx),
        .BITS (BITS_AB)
      ) col_fifo (
        .clk  (clk),
        .rst_n(rst_n),
        .en   (en),
        .d    (Bin[col_idx]),
        .q    (Bout[col_idx])
      );
    end
  endgenerate
endmodule // memB
