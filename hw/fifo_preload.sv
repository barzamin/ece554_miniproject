// fifo.sv
// Implements delay buffer (fifo)
// On reset all entries are set to 0
// Shift causes fifo to shift out oldest entry to q, shift in d

module fifo_preload #(
  parameter int DEPTH=8,
  parameter int BITS=8
) (
  input wire clk,rst_n,en, wr,
  input wire signed [BITS-1:0] d [DEPTH-1:0],
  output wire signed  [BITS-1:0] q
);
  
  logic signed [BITS-1:0] registers [DEPTH-1:0];

  // infers an array of chained flops. all flops stop registering their `d` when `~en`.
  always_ff @(posedge clk or negedge rst_n) begin
    for (integer i = 0; i < DEPTH; i++) begin
      if (!rst_n)
        registers[i] <= '0;
      else if(wr)
        registers <= d;
      else if(en)
        registers[i] <= (i == DEPTH-1) ? 0 : registers[i+1];
    end
  end

  assign q = registers[0];
endmodule // fifo
