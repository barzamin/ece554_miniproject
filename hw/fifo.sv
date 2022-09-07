// fifo.sv
// Implements delay buffer (fifo)
// On reset all entries are set to 0
// Shift causes fifo to shift out oldest entry to q, shift in d

module fifo #(
  parameter DEPTH=8,
  parameter BITS=64
) (
  input clk,rst_n,en,
  input [BITS-1:0] d,
  output [BITS-1:0] q
);

  logic [BITS-1:0] registers [0:DEPTH-1];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i=0; i<DEPTH; i++)
        registers[i] <= '0;
    end else begin
      registers[0] <= d;
      for (int i=1; i<DEPTH; i++)
        registers[i] <= registers[i-1];
    end
  end

  wire q = registers[DEPTH];
endmodule // fifo
