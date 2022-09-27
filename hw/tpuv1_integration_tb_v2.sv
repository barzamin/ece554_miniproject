// AFU Full Integration Testbench
// You should use this testbench only when you've finished tpuv1.sv
// Once you have, you can test its functional correctness by plugging it in here.
//
// Based on systolic_array_tb.sv

`include "afu_tc.sv"

module tpuv1_integration_tb();

   localparam BITS_AB=8;
   localparam BITS_C=16;
   localparam DIM=8;
   localparam ADDRW=16;
   localparam DATAW=64;
   localparam TESTS=10;
   
   // Clock
   logic clk;
   logic rst_n;
   logic [$clog2(DIM)-1:0] ColNo;
   logic [$clog2(DIM):0] RowNo;
   logic signed [BITS_AB-1:0] A [DIM-1:0];
   logic signed [BITS_AB-1:0] B [DIM-1:0];
   logic signed [BITS_C-1:0] Cin [DIM-1:0];
   logic signed [BITS_C-1:0] Cout [DIM-1:0][DIM-1:0];
   logic [ADDRW-1:0] addr;
   logic [ADDRW-1:0] addr_test;
   logic [DATAW-1:0] dataIn;
   logic [DATAW-1:0] dataOut;
   logic r_w;
   logic rdValid;
   bit [15:0] Bbaddr;
   bit [15:0] Abaddr;
   bit [63:0] loWord;
   bit [63:0] hiWord;

   always #5 clk = ~clk; 

   integer                   errors,mycycle;

   tpuv1 #(.BITS_AB(BITS_AB),
                    .BITS_C(BITS_C),
                    .DIM(DIM)
                    ) DUT (.*);

   afu_tc #(.BITS_AB(BITS_AB),
                       .BITS_C(BITS_C),
                       .DIM(DIM)
                       ) satc;
   
   initial begin
	  clk = 1'b0;
	  rst_n = 1'b1;
	  errors = 0;
	  r_w = 0;

      for(int rowcol=0;rowcol<DIM;++rowcol) begin
         A[rowcol] = 0;
         B[rowcol] = 0;
         Cin[rowcol] = 0;
      end
      
      // reset and check Cout
      @(posedge clk);
      rst_n = 0'b0; // active low reset
      @(posedge clk);
      rst_n = 1'b1; // reset finished
      @(posedge clk);

      // check that C was properly reset (every row, every column)
      for(addr='h300; addr < 'h380; addr += 'h010) begin
	   @(posedge clk);
           if(dataOut !== 0) begin
		         errors++;
		        $display("Error! Reset was not conducted properly. Expected: 0, Got: %d @ address %h", dataOut, addr); 
           end
      end
      

      for(int test=0;test<TESTS;++test) begin

         // instantiate test case
         satc = new();
         
         @(posedge clk);
         // load C with 0 one row at a time
         for(addr_test='h300; addr_test < 'h380; addr_test += 'h010) begin
		addr = addr_test;
		dataIn = 64'h0;
	        r_w = 1'b1;
		@(posedge clk);

		addr = addr_test + 8;
		@(posedge clk);
         end

	 addr = 0;
         r_w = 1'b0;
         
         @(posedge clk);
         // check that C was properly initialized to zero         
         for(addr_test='h300; addr_test < 'h380; addr_test += 'h08) begin
            addr = addr_test;
	    @(posedge clk);
            if(dataOut !== 0) begin
		          errors++;
		          $display("Error! C Init was not conducted properly. Expected: 0, Got: %d at address %h", dataOut, addr); 
	    end
         end
         
        @(posedge clk);

	Bbaddr = 'h200;
	Abaddr = 'h100;
	for(int RowW = 0; RowW < DIM; ++RowW) begin
		// Fill A and B


		for(int ColW = 0; ColW < DIM; ++ColW) begin

			// Set writes for A.
			A[ColW] = satc.get_raw_A(RowW, ColW);
	
			// Set writes for B.
			B[ColW] = satc.get_raw_B(RowW, ColW);

		end

		@(negedge clk);

		r_w = 1'b1;

		// Pack and write A
		addr = Abaddr;
		dataIn = {A[7], A[6], A[5], A[4], A[3], A[2], A[1], A[0]};
		Abaddr += 8; // Write next row
		@(posedge clk);

		@(negedge clk);

		// Pack and write B
		addr = Bbaddr;
		dataIn = {B[7], B[6], B[5], B[4], B[3], B[2], B[1], B[0]};
		@(posedge clk);

		r_w = 1'b0;
		addr = 0;
	end

	r_w = 1'b0;
	addr = 'h400;
	r_w = 1'b1;
	@(posedge clk);
	r_w = 1'b0;
	addr = 'h0;

	// Wait for computation.
        repeat (DIM*4) @(posedge clk);
 
         // compute is done
         
        @(posedge clk);
        // read Cout row by row and check against test case
        // For each row, rebuild Cout
	ColNo = 0;
	RowNo = 0;
	for(addr_test = 'h300; addr_test < 'h380; addr_test += 'h10) begin

        // Read loword
            addr = addr_test;
            #1 loWord = dataOut;

            @(posedge clk);

            // Read hiword
            addr = addr_test + 8;
            #1 hiWord = dataOut;

            @(posedge clk);

            Cout[RowNo] = {hiWord[63:48], hiWord[47:32], hiWord[31:16], hiWord[15:0], loWord[63:48], loWord[47:32], loWord[31:16], loWord[15:0]};
            ++RowNo;
	end

        @(posedge clk);
        for(RowNo = 0; RowNo < DIM; ++RowNo) begin
            errors = errors + satc.check_row_C(RowNo,Cout[RowNo]);

	end
         
        if (errors > 0) begin
            $display("Errors found: %d, dumping test case\n",errors);
            satc.dump();
            $display("Dumping result");
            @(posedge clk);
            for(int Row=0;Row<DIM;++Row) begin
               @(posedge clk);
               for(int Col=0;Col<DIM;++Col) begin
                  $write("%5d ",Cout[Row][Col]);
               end
               $display("");
               @(posedge clk);
            end
	    $display("Dumping expected");
            for(int Row=0;Row<DIM;++Row) begin
               @(posedge clk);
               for(int Col=0;Col<DIM;++Col) begin
                  $write("%5d ",satc.get_expected_C(Row, Col));
               end
               $display("");
               @(posedge clk);
            end
        end
        else begin
            $display("No errors, testcase passed\n");
        end

        satc = null;
         
      end // for (int test=0;test<TESTS;++test)
   
      if(!errors) begin
         $display("YAHOO!!! All tests passed.");
      end
      else begin
         $display("ARRRR!  Ye codes be blast! Aye, there be errors. Get debugging!");
      end
            
      $stop;
   
    end // initial begin

endmodule // systolic_array_tb

   
