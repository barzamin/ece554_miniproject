`default_nettype none
module tpumac #(
  parameter int BITS_AB = 8,
  parameter int BITS_C = 16 // n.b.: BITS_C should be BITS_AB*2. could do an `initial assert`; shame SV lacks a static_assert.
) (
  input wire clk, rst_n,
  input wire en,
  input wire WrEn,

  input wire signed [BITS_AB-1:0] Ain,
  input wire signed [BITS_AB-1:0] Bin,
  input wire signed [BITS_C-1:0]  Cin,

  output reg signed [BITS_AB-1:0] Aout,
  output reg signed [BITS_AB-1:0] Bout,
  output reg signed [BITS_C-1:0]  Cout
);

  // Aout, Bout registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      Aout <= '0;
      Bout <= '0;
    end else if (en) begin
      Aout <= Ain;
      Bout <= Bin;
    end
  end

  // why not just write everything out implicitly in a single computation when
  // we assign in the Cout register's always_ff? in case we want to replace parts
  // of the computation with vendor-specific blocks more easily
  // (if we want to use DSP blocks' MACs or something).

  wire [BITS_C-1:0] A_mul_B;
  assign A_mul_B = Ain * Bin; // let the synthesizer figure it out :)

  wire [BITS_C-1:0] A_mul_B_plus_Cout;
  assign A_mul_B_plus_Cout = A_mul_B + Cout;

  // Cout register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      Cout <= '0;
    end else if (en) begin
      // when WrEn, we're loading a new value of C
      Cout <= WrEn ? Cin : A_mul_B_plus_Cout;
    end
  end
endmodule // tpumac
