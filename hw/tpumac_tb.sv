`default_nettype none
module tpumac_tb();
  localparam WIDTH_AB = 8;
  localparam WIDTH_C = 16;

  logic clk, rst_n;
  logic en, WrEn;

  logic signed [WIDTH_AB-1:0] Ain;
  logic signed [WIDTH_AB-1:0] Bin;
  logic signed [WIDTH_C-1:0] Cin;

  logic signed [WIDTH_AB-1:0] Ain_prev;
  logic signed [WIDTH_AB-1:0] Bin_prev;
  logic signed [WIDTH_C-1:0] Cin_prev;

  logic signed [WIDTH_AB-1:0] Aout;
  logic signed [WIDTH_AB-1:0] Bout;
  logic signed [WIDTH_C-1:0] Cout;

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

  logic signed [WIDTH_C-1:0] golden_Cout;
  initial begin
    // clear everything out
    en = '0;
    WrEn = '0;
    rst_n = '0;
    @(posedge clk);
    @(negedge clk); rst_n = '1;

    // -- first, let's do randomized testing
    for (int i = 0; i < 256; i++) begin
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

    // -- check that we don't register anything if en is low
    assert(std::randomize(Ain, Bin, Cin));
    Ain_prev = Ain; Bin_prev = Bin; Cin_prev = Cin;
    WrEn = '1; en = '1; // write
    @(posedge clk);
    // check write
    @(negedge clk);
    assert(Aout == Ain);
    assert(Bout == Bin);
    assert(Cout == Cin);

    // reroll but *don't* write
    assert(std::randomize(Ain, Bin, Cin));
    WrEn = '0; en = '0;
    @(posedge clk);
    @(negedge clk);
    // should still be the same as write
    assert(Aout == Ain_prev);
    assert(Bout == Bin_prev);
    assert(Cout == Cin_prev);


    // -- check that rst_n resets registers properly
    en = '0; WrEn = '0; rst_n = '0;
    @(posedge clk);
    @(negedge clk); rst_n = '1;
    assert(Aout == '0);
    assert(Bout == '0);
    assert(Cout == '0);
    $finish();
  end
endmodule
