// testbench for memA.sv and memB.sv

`include "systolic_array_tc.svh"

module memAB_tb();

  localparam BITS_AB = 8;
  localparam BITS_C = 16;
  localparam DIM = 8;
  localparam ROWBITS=$clog2(DIM);

  logic clk, rst_n, en, WrEn, WrEnMemA, error, cerror;
  logic [ROWBITS-1:0] Crow;
  logic signed [BITS_AB-1:0] Aout [DIM-1:0];
  logic signed [BITS_AB-1:0] Bout [DIM-1:0];
  logic signed [BITS_AB-1:0] Ain [DIM-1:0];
  logic signed [BITS_AB-1:0] Bin [DIM-1:0];
  logic signed [BITS_AB-1:0] Acheck [DIM-1:0];
  logic signed [BITS_AB-1:0] Bcheck [DIM-1:0];
  logic signed [BITS_C-1:0] Cin [DIM-1:0];
  logic signed [BITS_C-1:0] Cout [DIM-1:0];
  logic signed [$clog2(DIM)-1:0] Arow;

  integer mycycle;

   always #5 clk = ~clk;

   systolic_array #(.BITS_AB(BITS_AB), .BITS_C(BITS_C), .DIM(DIM)) sysArray(.clk(clk),
                    .rst_n(rst_n), .WrEn(WrEn), .en(en), .A(Aout), .B(Bout), .Cin(Cin),
                    .Crow(Crow), .Cout(Cout));
   systolic_array_tc #(.BITS_AB(BITS_AB), .BITS_C(BITS_C), .DIM(DIM)) satc;

   memA DUTA(.clk(clk), .rst_n(rst_n), .en(en), .WrEn(WrEnMemA), .Ain(Ain), 
             .Arow(Arow), .Aout(Aout));

   memB DUTB(.clk(clk), .rst_n(rst_n), .en(en), .Bin(Bin), 
             .Bout(Bout));

  initial begin
  clk = 1'b0;
  rst_n = 1'b0;
  en = 1'b0;
  WrEn = 1'b0;
  WrEnMemA = 1'b0;
  for(int col=0;col<DIM;++col) begin
     Ain[col] = {BITS_AB{1'b0}};
  end
  for(int col=0;col<DIM;++col) begin
     Bin[col] = {BITS_AB{1'b0}};
  end
  error = 1'b0;
  @(posedge clk);
  @(posedge clk);
  rst_n = 1'b1;
  @(posedge clk);
  
  // checking that memA and memB are all zero Bin and Ain are zero
  // and reset was just high so all values should be zero;
  en = 1'b1;
  for(int col = 0; col<DIM; ++col) begin
    for(int row = 0; row<DIM; ++row) begin
      if(Bin[row] != 0) begin
          $display("a B value was nonzero after reset");
          error = 1'b1;
        end
      if(Ain[row] !=0) begin
          $display("an A value was nonzero after resest");
          error = 1'b1;
        end
    end
    @(posedge clk);
  end

  en = 1'b0;


  for(int tests = 0; tests < 20; ++tests) begin

  satc = new();

en = 1'b1;

    for(int cycles = 0; cycles < (DIM*3); ++cycles) begin
    
      // sets the Bin and Ain signals
    if(cycles<DIM) begin
    Bin = satc.B[cycles];
    Ain = satc.A[cycles];
    Arow = {cycles[ROWBITS-1:0]};
    WrEnMemA = 1'b1;
    end

    if(cycles>=DIM) begin
      WrEnMemA = 1'b0;
      for(int col=0;col<DIM;++col) begin
         Bin[col] = {BITS_AB{1'b0}};
       end
    end


  
    // checks that the Aout and Bout values from memA and memB are correct
    
    if(cycles > 0) begin
    @(negedge clk);
    for(int col = 0; col<DIM; ++col) begin
        if(Bout[col] != satc.get_next_B(col)) begin
            Bcheck[col] = satc.get_next_B(col);
            $display("problem with memB, mismatch with testcase");
            error = 1'b1;
          end
        if(Aout[col] != satc.get_next_A(col)) begin
            Acheck[col] = satc.get_next_A(col);
            $display("problem with memA, mismatch with testcase");
        end
     end
    mycycle = satc.next_cycle();  
    end

    @(posedge clk);
    
  

   end

en = 1'b0;

    
        // checks that the c output is correct
    cerror = 1'b0;
         for(int Row=0;Row<DIM;++Row) begin
           Crow = {Row[ROWBITS-1:0]};
           @(posedge clk) begin end
           if(satc.check_row_C(Row,Cout) != 0) begin
               $display("error was found checking C values");
               error = 1'b1;
               cerror = 1'b1;
             end
           @(posedge clk) begin end
         end

        //dump out values of C A B from satc and C from actual hardware
         if(cerror == 1'b1) begin
            satc.dump();
            $display("Dumping result");
            @(posedge clk) begin end
            for(int Row=0;Row<DIM;++Row) begin
               Crow = {Row[ROWBITS-1:0]};
               @(posedge clk) begin end
               for(int Col=0;Col<DIM;++Col) begin
                  $write("%5d ",Cout[Col]);
               end
               $display("");
               @(posedge clk) begin end
            end
         end

             // load C with 0 one row at a time
         for(int rowcol=0;rowcol<DIM;++rowcol) begin
            Cin[rowcol] = {BITS_C{1'b0}};
         end
         @(posedge clk) begin end
         WrEn = 1'b1;
         for(int Row=0;Row<DIM;++Row) begin
            Crow = {Row[ROWBITS-1:0]};
            @(posedge clk) begin end
         end
         WrEn = 1'b0;

  end

  if(error == 1'b0) begin
    $display("YAHOO!!! All tests passed.");
  end

$finish();

end

endmodule
