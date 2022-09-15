`default_nettype none
module tpumac_tb();
  logic clk, rst_n;
  logic en, WrEn;

  logic signed [7:0] Ain;
  logic signed [7:0] Bin;
  logic signed [15:0] Cin;

  logic signed [7:0] Aout;
  logic signed [7:0] Bout;
  logic signed [15:0] Cout;

  // DUT
  tpumac #(.BITS_AB(8), .BITS_C(16)) dut (
    .clk  (clk),
    .rst_n(rst_n),
    .en   (en),
    .WrEn (WrEn),
    .Ain  (Ain),
    .Bin  (Bin),
    .Cin  (Cin),
    .Aout (Aout),
    .Bout (Bout),
    .Cout (Cout)
  );

  // clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  logic signed [15:0] golden_Cout;
  initial begin
    // clear everything out
    en = '0;
    WrEn = '0;
    rst_n = '0;
    @(posedge clk);
    @(negedge clk); rst_n = '1;

    // first, let's do randomized testing
    for (int i = 0; i < 20; i++) begin
      assert(std::randomize(Ain, Bin, Cin));
      golden_Cout = Ain * Bin + Cin;
      $display("Ain=%0d, Bin=%0d, Cin=%0d; golden Cout=%0d", Ain, Bin, Cin, golden_Cout);

      // load registers
      WrEn = '1; en = '1;
      @(posedge clk)
      // check that everything latched
      @(negedge clk)
      assert(Aout === Ain);
      assert(Bout === Bin);
      assert(Cout === Cin);

      // deassert WrEn; keep en high so we see the output of MAC
      @(negedge clk) WrEn = '0;

      // check MAC result latched
      @(negedge clk) assert(Cout == golden_Cout);
    end

    $finish();
  end
endmodule
